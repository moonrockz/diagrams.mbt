///|
/// A value of the private structured boundary.
///
/// The C adapter gives Python `Null` as `None`, `Bool` as `bool`, `Int` as
/// `int`, `Str` as `str`, `Bin` as `bytes` and `List` as `tuple`. Python
/// arguments use the same values in the other direction.
pub(all) enum Rec {
  Null
  Bool(Bool)
  Int(Int64)
  Str(String)
  Bin(Bytes)
  List(ReadOnlyArray[Rec])
} derive(Eq, Debug)

///|
pub extend Rec with Eq::{equal, not_equal}

///|
pub extend Rec with @debug.Debug::{to_repr}

///|
/// The tags of the wire format. Each value starts with one tag byte.
/// `Int` has an 8-byte little-endian payload. `Str` (UTF-8), `Bin` and `List`
/// have a 4-byte little-endian length (bytes or items) before their content.
pub let record_tags : ReadOnlyArray[(String, Int32)] = [
  ("null", 0),
  ("false", 1),
  ("true", 2),
  ("int", 3),
  ("str", 4),
  ("bin", 5),
  ("list", 6),
]

///|
/// The deepest list nesting that `decode_record` accepts.
pub let record_max_depth : Int32 = 64

///|
/// A failure of a boundary operation. The adapter raises the Python exception
/// that `code` names; see `diagrams_mbt._boundary`.
pub suberror BridgeError {
  BridgeError(String, String)
} derive(Debug)

///|
pub extend BridgeError with @debug.Debug::{to_repr}

///|
pub fn Rec::int(value : Int32) -> Rec {
  Int(value.to_int64())
}

///|
pub fn Rec::str_opt(value : String?) -> Rec {
  match value {
    Some(text) => Str(text)
    None => Null
  }
}

///|
pub fn Rec::int_opt(value : Int32?) -> Rec {
  match value {
    Some(number) => Int(number.to_int64())
    None => Null
  }
}

///|
pub fn Rec::list(items : Array[Rec]) -> Rec {
  List(ReadOnlyArray::from_array(items))
}

///|
pub fn encode_record(value : Rec) -> Bytes {
  let buffer = Buffer()
  write_record(buffer, value)
  buffer.to_bytes()
}

///|
fn write_record(buffer : Buffer, value : Rec) -> Unit {
  // An explicit stack keeps deep values off the host stack.
  let stack : Array[Rec] = [value]
  while stack.pop() is Some(item) {
    match item {
      Null => buffer.write_byte(b'\x00')
      Bool(false) => buffer.write_byte(b'\x01')
      Bool(true) => buffer.write_byte(b'\x02')
      Int(number) => {
        buffer.write_byte(b'\x03')
        buffer.write_int64_le(number)
      }
      Str(text) => {
        let bytes = @utf8.encode(text)
        buffer.write_byte(b'\x04')
        buffer.write_int_le(bytes.length())
        buffer.write_bytes(bytes)
      }
      Bin(bytes) => {
        buffer.write_byte(b'\x05')
        buffer.write_int_le(bytes.length())
        buffer.write_bytes(bytes)
      }
      List(items) => {
        buffer.write_byte(b'\x06')
        buffer.write_int_le(items.length())
        for i = items.length() - 1; i >= 0; i = i - 1 {
          stack.push(items[i])
        }
      }
    }
  }
}

///|
priv struct Reader {
  bytes : BytesView
  mut at : Int32
}

///|
fn Reader::byte(self : Reader) -> Byte raise BridgeError {
  guard self.at < self.bytes.length() else {
    raise BridgeError("invalid-record", "The record ends early.")
  }
  let value = self.bytes[self.at]
  self.at += 1
  value
}

///|
fn Reader::uint32(self : Reader) -> Int32 raise BridgeError {
  let mut value = 0
  for i in 0..<4 {
    value = value | (self.byte().to_int() << (8 * i))
  }
  guard value >= 0 else {
    raise BridgeError("invalid-record", "A record length is too large.")
  }
  value
}

///|
fn Reader::int64(self : Reader) -> Int64 raise BridgeError {
  let mut value = 0L
  for i in 0..<8 {
    value = value | (self.byte().to_int64() << (8 * i))
  }
  value
}

///|
fn Reader::slice(self : Reader, length : Int32) -> BytesView raise BridgeError {
  guard length <= self.bytes.length() - self.at else {
    raise BridgeError("invalid-record", "A record length exceeds the input.")
  }
  let view = self.bytes[self.at:self.at + length]
  self.at += length
  view
}

///|
priv struct Frame {
  items : Array[Rec]
  count : Int32
}

///|
/// Decodes one complete record. Malformed input, trailing bytes, invalid UTF-8
/// and lists deeper than `record_max_depth` raise `invalid-record`.
pub fn decode_record(bytes : BytesView) -> Rec raise BridgeError {
  let reader = Reader::{ bytes, at: 0, }
  let frames : Array[Frame] = []
  let mut result : Rec? = None
  while result is None {
    let value = match reader.byte() {
      b'\x00' => Some(Rec::Null)
      b'\x01' => Some(Bool(false))
      b'\x02' => Some(Bool(true))
      b'\x03' => Some(Int(reader.int64()))
      b'\x04' => {
        let view = reader.slice(reader.uint32())
        let text = @utf8.decode(view) catch {
          _ =>
            raise BridgeError("invalid-record", "A string is not valid UTF-8.")
        }
        Some(Str(text))
      }
      b'\x05' => Some(Bin(reader.slice(reader.uint32()).to_owned()))
      b'\x06' => {
        let count = reader.uint32()
        guard count <= reader.bytes.length() - reader.at else {
          raise BridgeError(
            "invalid-record", "A list length exceeds the input.",
          )
        }
        if count == 0 {
          Some(List([]))
        } else {
          guard frames.length() < record_max_depth else {
            raise BridgeError(
              "invalid-record", "The record is nested too deeply.",
            )
          }
          frames.push({ items: [], count, })
          None
        }
      }
      _ => raise BridgeError("invalid-record", "A record has an unknown tag.")
    }
    let mut done = value
    while done is Some(item) {
      match frames.last() {
        None => {
          result = Some(item)
          done = None
        }
        Some(frame) => {
          frame.items.push(item)
          if frame.items.length() == frame.count {
            frames.pop() |> ignore
            done = Some(List(ReadOnlyArray::from_array(frame.items)))
          } else {
            done = None
          }
        }
      }
    }
  }
  guard reader.at == reader.bytes.length() else {
    raise BridgeError("invalid-record", "The record has trailing bytes.")
  }
  result.unwrap()
}

///|
/// Argument `index` of `args` as an integer.
pub fn arg_int(args : ArrayView[Rec], index : Int32) -> Int64 raise BridgeError {
  match args.get(index) {
    Some(Int(value)) => value
    _ =>
      raise BridgeError("invalid-argument", "Argument \{index} must be an int.")
  }
}

///|
/// Argument `index` of `args` as a 32-bit integer.
pub fn arg_int32(
  args : ArrayView[Rec],
  index : Int32,
) -> Int32 raise BridgeError {
  let value = arg_int(args, index)
  guard value >= -2147483648L && value <= 2147483647L else {
    raise BridgeError(
      "invalid-argument",
      "Argument \{index} is outside the 32-bit range.",
    )
  }
  value.to_int()
}

///|
pub fn arg_str(
  args : ArrayView[Rec],
  index : Int32,
) -> String raise BridgeError {
  match args.get(index) {
    Some(Str(value)) => value
    _ =>
      raise BridgeError("invalid-argument", "Argument \{index} must be a str.")
  }
}

///|
pub fn arg_str_opt(
  args : ArrayView[Rec],
  index : Int32,
) -> String? raise BridgeError {
  match args.get(index) {
    Some(Str(value)) => Some(value)
    Some(Null) | None => None
    _ =>
      raise BridgeError(
        "invalid-argument",
        "Argument \{index} must be a str or None.",
      )
  }
}

///|
pub fn arg_bool(args : ArrayView[Rec], index : Int32) -> Bool raise BridgeError {
  match args.get(index) {
    Some(Bool(value)) => value
    _ =>
      raise BridgeError("invalid-argument", "Argument \{index} must be a bool.")
  }
}

///|
pub fn arg_list(
  args : ArrayView[Rec],
  index : Int32,
) -> ReadOnlyArray[Rec] raise BridgeError {
  match args.get(index) {
    Some(List(items)) => items
    _ =>
      raise BridgeError(
        "invalid-argument",
        "Argument \{index} must be a tuple.",
      )
  }
}
