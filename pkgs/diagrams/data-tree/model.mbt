///|
/// The key of one member occurrence: an object member name or an array position.
pub(all) enum Key {
  Name(String)
  Index(Int)
} derive(Eq, Debug)

///|
pub extend Key with Eq::{equal, not_equal}

///|
pub extend Key with @debug.Debug::{to_repr}

///|
/// One member occurrence of a container. `value` names the child node.
/// Repeated names and equal values keep separate member identities.
pub struct Member {
  id : String
  key : Key
  value : String
  source : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Member with Eq::{equal, not_equal}

///|
pub extend Member with @debug.Debug::{to_repr}

///|
pub fn Member::named(
  id : String,
  name : String,
  value : String,
  source? : @diagrams.Span,
) -> Member {
  { id, key: Name(name), value, source }
}

///|
pub fn Member::index(
  id : String,
  index : Int,
  value : String,
  source? : @diagrams.Span,
) -> Member {
  { id, key: Index(index), value, source }
}

///|
/// A typed value. Numbers keep their exact decimal lexeme; no machine
/// floating-point value is computed.
pub(all) enum Value {
  Object(ReadOnlyArray[Member])
  Array(ReadOnlyArray[Member])
  Text(String)
  Number(String)
  Boolean(Bool)
  Null
} derive(Eq, Debug)

///|
pub extend Value with Eq::{equal, not_equal}

///|
pub extend Value with @debug.Debug::{to_repr}

///|
pub struct Node {
  id : String
  value : Value
  source : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Node::new(id : String, value : Value, source? : @diagrams.Span) -> Node {
  { id, value, source }
}

///|
pub fn Node::object(
  id : String,
  members : ArrayView[Member],
  source? : @diagrams.Span,
) -> Node {
  { id, value: Object(ReadOnlyArray::from_array(members)), source }
}

///|
pub fn Node::array(
  id : String,
  members : ArrayView[Member],
  source? : @diagrams.Span,
) -> Node {
  { id, value: Array(ReadOnlyArray::from_array(members)), source }
}

///|
/// The member occurrences of a container, or an empty array for a scalar.
pub fn Node::members(self : Node) -> ReadOnlyArray[Member] {
  match self.value {
    Object(members) | Array(members) => members
    _ => []
  }
}

///|
pub fn Node::is_container(self : Node) -> Bool {
  self.value is (Object(_) | Array(_))
}

///|
/// A view highlight. Targets are member or node identities. The optional
/// style is inert author metadata; library themes paint every highlight.
pub struct Highlight {
  targets : ReadOnlyArray[String]
  style : String?
} derive(Eq, Debug)

///|
pub extend Highlight with Eq::{equal, not_equal}

///|
pub extend Highlight with @debug.Debug::{to_repr}

///|
pub fn Highlight::new(targets : ArrayView[String], style? : String) -> Highlight {
  { targets: ReadOnlyArray::from_array(targets), style }
}

///|
/// One immutable structured-data diagram. It does not depend on JSON or YAML.
pub struct DataTree {
  id : String
  root : String
  nodes : ReadOnlyArray[Node]
  highlights : ReadOnlyArray[Highlight]
  title : String?
  accessibility_title : String?
  accessibility_description : String?
} derive(Eq, Debug)

///|
pub extend DataTree with Eq::{equal, not_equal}

///|
pub extend DataTree with @debug.Debug::{to_repr}

///|
pub fn DataTree::new(
  id : String,
  root : String,
  nodes : ArrayView[Node],
  highlights? : ArrayView[Highlight] = [],
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
) -> DataTree {
  {
    id,
    root,
    nodes: ReadOnlyArray::from_array(nodes),
    highlights: ReadOnlyArray::from_array(highlights),
    title,
    accessibility_title,
    accessibility_description,
  }
}

///|
/// The visible text of a scalar value, or `None` for a container.
pub fn Value::scalar_text(self : Value) -> String? {
  match self {
    Text(text) => Some(text)
    Number(lexeme) => Some(lexeme)
    Boolean(true) => Some("true")
    Boolean(false) => Some("false")
    Null => Some("null")
    _ => None
  }
}

///|
/// True when `lexeme` is a valid JSON number spelling.
pub fn valid_number(lexeme : String) -> Bool {
  let n = lexeme.length()
  let mut i = 0
  fn digit(at : Int) -> Bool {
    at < n && lexeme.code_unit_at(at) >= '0'.to_int().to_uint16() &&
    lexeme.code_unit_at(at) <= '9'.to_int().to_uint16()
  }
  fn at(position : Int, c : Char) -> Bool {
    position < n && lexeme.code_unit_at(position).to_int() == c.to_int()
  }
  if at(i, '-') {
    i += 1
  }
  if at(i, '0') {
    i += 1
  } else if digit(i) {
    while digit(i) {
      i += 1
    }
  } else {
    return false
  }
  if at(i, '.') {
    i += 1
    if !digit(i) {
      return false
    }
    while digit(i) {
      i += 1
    }
  }
  if at(i, 'e') || at(i, 'E') {
    i += 1
    if at(i, '+') || at(i, '-') {
      i += 1
    }
    if !digit(i) {
      return false
    }
    while digit(i) {
      i += 1
    }
  }
  i == n
}
