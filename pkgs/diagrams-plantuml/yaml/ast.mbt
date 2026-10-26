///|
/// A scalar of the native YAML profile. `text` is the value after the
/// profile removes one pair of matching outer quotes; there is no escape
/// processing. `raw` is the source spelling, or `None` for a constructed
/// value. Logical comparison and canonical writing use only `text`.
pub struct Scalar {
  text : String
  raw : String?
} derive(Eq, Debug)

///|
pub extend Scalar with Eq::{equal, not_equal}

///|
pub extend Scalar with @debug.Debug::{to_repr}

///|
pub fn Scalar::new(text : String) -> Scalar {
  { text, raw: None, }
}

///|
/// The part of a `key:` line after the colon.
pub(all) enum Entry {
  /// `key:` with no value. The native profile reads the next lines to
  /// decide between an empty string, joined text and a nested collection.
  Empty
  /// `key: value`.
  Value(Scalar)
  /// `key: [a, b]`. The items are decoded as the native profile does.
  Flow(ReadOnlyArray[String])
  /// `key: |` with its content lines. Each content line is trimmed.
  Block(ReadOnlyArray[String])
  /// `key: >`. The pinned profile refuses folded text.
  Folded
} derive(Eq, Debug)

///|
pub extend Entry with Eq::{equal, not_equal}

///|
pub extend Entry with @debug.Debug::{to_repr}

///|
/// The content of one native YAML line.
pub(all) enum Content {
  /// A lone `-`: a list item whose content is on the next lines.
  Dash
  /// `- value`: a list item with a scalar.
  Item(Scalar)
  /// A line without a key. It continues an empty `key:` value; anywhere
  /// else the pinned profile refuses it.
  Text(Scalar)
  /// `key: ...`, or `- key: ...` when the flag is true.
  Pair(Bool, Scalar, Entry)
} derive(Eq, Debug)

///|
pub extend Content with Eq::{equal, not_equal}

///|
pub extend Content with @debug.Debug::{to_repr}

///|
/// One native YAML line. `indent` is the number of leading spaces, with a
/// tab counted as four spaces, before any `- `.
pub struct Line {
  indent : Int32
  content : Content
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub extend Line with Eq::{equal, not_equal}

///|
pub extend Line with @debug.Debug::{to_repr}

///|
pub fn Line::new(indent : Int32, content : Content) -> Line {
  { indent, content, span: None, }
}

///|
/// The indentation that the native profile compares: the column after `- `
/// for a list item, one more than the dash for a lone `-`.
pub fn Line::native_indent(self : Line) -> Int32 {
  match self.content {
    Dash => self.indent + 1
    Item(_) | Pair(true, _, _) => self.indent + 2
    _ => self.indent
  }
}

///|
/// One parsed YAML diagram block: the native line forms in source order.
/// Comment-only and blank lines are trivia; block content lines belong to
/// their `key: |` line.
pub struct Document {
  name : String?
  statements : ReadOnlyArray[@envelope.Statement]
  highlights : ReadOnlyArray[@data.Selector]
  lines : ReadOnlyArray[Line]
} derive(Eq, Debug)

///|
pub extend Document with Eq::{equal, not_equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
/// A document. The constructor copies its arrays.
pub fn Document::new(
  lines : ArrayView[Line],
  name? : String,
  statements~ : ArrayView[@envelope.Statement] = [],
  highlights~ : ArrayView[@data.Selector] = [],
) -> Document {
  {
    name,
    statements: ReadOnlyArray::from_array(statements),
    highlights: ReadOnlyArray::from_array(highlights),
    lines: ReadOnlyArray::from_array(lines),
  }
}

///|
fn content_logical_equal(a : Content, b : Content) -> Bool {
  match (a, b) {
    (Dash, Dash) => true
    (Item(x), Item(y)) | (Text(x), Text(y)) => x.text == y.text
    (Pair(i, k, e), Pair(j, l, f)) =>
      i == j &&
      k.text == l.text &&
      (match (e, f) {
        (Value(x), Value(y)) => x.text == y.text
        _ => e == f
      })
    _ => false
  }
}

///|
/// Compare two lines without spans and source spellings.
pub fn Line::logical_equal(self : Line, other : Line) -> Bool {
  self.indent == other.indent &&
  content_logical_equal(self.content, other.content)
}

///|
/// Compare two documents without spans and source spellings.
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  if self.name != other.name ||
    self.statements != other.statements ||
    self.highlights.length() != other.highlights.length() ||
    self.lines.length() != other.lines.length() {
    return false
  }
  for i in 0..<self.highlights.length() {
    if !self.highlights[i].logical_equal(other.highlights[i]) {
      return false
    }
  }
  for i in 0..<self.lines.length() {
    if !self.lines[i].logical_equal(other.lines[i]) {
      return false
    }
  }
  true
}
