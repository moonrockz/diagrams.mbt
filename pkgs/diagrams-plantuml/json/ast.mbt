///|
/// A JSON string. `text` is the decoded value. `raw` is the source spelling
/// with its quotes, or `None` for a constructed value. Logical comparison
/// and canonical writing use only `text`.
pub struct Str {
  text : String
  raw : String?
} derive(Eq, Debug)

///|
pub extend Str with Eq::{equal, not_equal}

///|
pub extend Str with @debug.Debug::{to_repr}

///|
pub fn Str::new(text : String) -> Str {
  { text, raw: None, }
}

///|
/// The kind and content of one JSON value.
pub(all) enum ValueKind {
  /// Member occurrences in source order. Repeated names stay separate.
  Object(ReadOnlyArray[Member])
  Array(ReadOnlyArray[Value])
  String(Str)
  /// The exact number lexeme. No floating-point value is computed.
  Number(String)
  Boolean(Bool)
  Null
} derive(Eq, Debug)

///|
pub extend ValueKind with Eq::{equal, not_equal}

///|
pub extend ValueKind with @debug.Debug::{to_repr}

///|
/// One JSON value with its source span.
pub struct Value {
  kind : ValueKind
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
/// One object member occurrence.
pub struct Member {
  name : Str
  value : Value
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Member with Eq::{equal, not_equal}

///|
pub extend Member with @debug.Debug::{to_repr}

///|
pub fn Member::new(name : String, value : Value) -> Member {
  { name: Str::new(name), value, span: None, }
}

///|
/// An object. The constructor copies `members`.
pub fn Value::object(members : ArrayView[Member]) -> Value {
  { kind: Object(ReadOnlyArray::from_array(members)), span: None, }
}

///|
/// An array. The constructor copies `items`.
pub fn Value::array(items : ArrayView[Value]) -> Value {
  { kind: Array(ReadOnlyArray::from_array(items)), span: None, }
}

///|
pub fn Value::string(text : String) -> Value {
  { kind: String(Str::new(text)), span: None, }
}

///|
/// A number with an exact decimal lexeme, for example `-0.0` or `1e400`.
/// Writing gives an error when the lexeme is not a valid JSON number.
pub fn Value::number(lexeme : String) -> Value {
  { kind: Number(lexeme), span: None, }
}

///|
pub fn Value::boolean(value : Bool) -> Value {
  { kind: Boolean(value), span: None, }
}

///|
pub fn Value::null() -> Value {
  { kind: Null, span: None, }
}

///|
/// One parsed JSON diagram block.
pub struct Document {
  name : String?
  statements : ReadOnlyArray[@envelope.Statement]
  highlights : ReadOnlyArray[@data.Selector]
  value : Value
} derive(Eq, Debug)

///|
pub extend Document with Eq::{equal, not_equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
/// A document. The constructor copies its arrays.
pub fn Document::new(
  value : Value,
  name? : String,
  statements~ : ArrayView[@envelope.Statement] = [],
  highlights~ : ArrayView[@data.Selector] = [],
) -> Document {
  {
    name,
    statements: ReadOnlyArray::from_array(statements),
    highlights: ReadOnlyArray::from_array(highlights),
    value,
  }
}

///|
/// The kind name of a value: `object`, `array`, `string`, `number`,
/// `boolean` or `null`.
pub fn Value::kind_name(self : Value) -> String {
  match self.kind {
    Object(_) => "object"
    Array(_) => "array"
    String(_) => "string"
    Number(_) => "number"
    Boolean(_) => "boolean"
    Null => "null"
  }
}

///|
/// Compare two values without spans and source spellings. The comparison
/// uses an explicit stack, so deep values do not use the call stack.
pub fn Value::logical_equal(self : Value, other : Value) -> Bool {
  let stack = [(self, other)]
  while stack.pop() is Some((a, b)) {
    match (a.kind, b.kind) {
      (Object(x), Object(y)) => {
        if x.length() != y.length() {
          return false
        }
        for i in 0..<x.length() {
          if x[i].name.text != y[i].name.text {
            return false
          }
          stack.push((x[i].value, y[i].value))
        }
      }
      (Array(x), Array(y)) => {
        if x.length() != y.length() {
          return false
        }
        for i in 0..<x.length() {
          stack.push((x[i], y[i]))
        }
      }
      (String(x), String(y)) => if x.text != y.text { return false }
      (Number(x), Number(y)) => if x != y { return false }
      (Boolean(x), Boolean(y)) => if x != y { return false }
      (Null, Null) => ()
      _ => return false
    }
  }
  true
}

///|
/// Compare two documents without spans and source spellings.
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  if self.name != other.name ||
    self.statements != other.statements ||
    self.highlights.length() != other.highlights.length() {
    return false
  }
  for i in 0..<self.highlights.length() {
    if !self.highlights[i].logical_equal(other.highlights[i]) {
      return false
    }
  }
  self.value.logical_equal(other.value)
}
