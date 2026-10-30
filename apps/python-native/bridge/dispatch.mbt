///|
/// Decodes the request record `[op, args...]`, runs the operation and returns
/// the encoded response. It never raises.
///
/// A response is `[0, value]` on success or `[1, code, message]` on failure.
/// Each group of operations has its own table: `render_op`, `traversal_op`
/// and `query_op`. A table returns `None` for an operation it does not have.
pub fn call(request : BytesView) -> Bytes {
  let response = try {
    let (op, args) = match decode_record(request) {
      List(items) if items.length() >= 1 && items[0] is Str(op) =>
        (op, items[1:])
      _ =>
        raise BridgeError(
          "invalid-record", "A request must be a tuple that starts with a str.",
        )
    }
    Rec::list([Rec::int(0), dispatch(op, args)])
  } catch {
    BridgeError(code, message) =>
      Rec::list([Rec::int(1), Str(code), Str(message)])
  }
  encode_record(response)
}

///|
fn dispatch(op : String, args : ArrayView[Rec]) -> Rec raise BridgeError {
  if render_op(op, args) is Some(value) {
    return value
  }
  if traversal_op(op, args) is Some(value) {
    return value
  }
  if query_op(op, args) is Some(value) {
    return value
  }
  match op {
    "abi_version" => Rec::int(abi_version())
    "live_objects" => live_objects()
    _ => raise BridgeError("unknown-op", "Unknown boundary operation \{op}.")
  }
}

///|
/// Registry kinds. Each group of operations owns its kinds.
/// Traversal: 1 document, 2 graph, 3 event reader, 4 tree cursor, 5 resources.
/// Query: 16 plan, 17 query cursor.
fn live_objects() -> Rec {
  let counts = traversal_live()
  counts.append(query_live())
  Rec::list(counts.map(c => Rec::list([Str(c.0), Rec::int(c.1)])))
}
