///|
/// The kind of a token in the lossless syntax tree. All four body languages
/// share these kinds.
pub(all) enum TokenKind {
  /// `@startregex`, `@endjson` and similar block markers.
  Marker
  /// A statement keyword such as `title` or `skinparam`.
  Keyword
  /// A rule name, member key or group name.
  Name
  /// Free text: a title, a note or an unquoted value.
  Text
  /// A quoted string, including its quotes.
  String
  Number
  /// `true`, `false` or `null`.
  Literal
  /// An escape sequence.
  Escape
  /// An operator or a quantifier.
  Operator
  /// Brackets, separators and other punctuation.
  Punctuation
  Comment
  Whitespace
  Newline
  /// A preprocessor directive or function call.
  Directive
  /// Text that could not be read.
  Error
} derive(Eq, Debug)

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
/// One token. `offset` is the UTF-16 offset of its first code unit in the
/// source. The concatenated token texts of a tree are equal to the source.
pub struct Token {
  kind : TokenKind
  text : String
  offset : Int
} derive(Eq, Debug)

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub fn Token::new(kind : TokenKind, text : String, offset : Int) -> Token {
  { kind, text, offset }
}

///|
/// The kind of a node. Each source line, or each multi-line statement, is one
/// node under the document.
pub(all) enum NodeKind {
  Document
  Start
  End
  Title
  Caption
  Header
  Footer
  Legend
  Skinparam
  Style
  Pragma
  Scale
  Hide
  Comment
  Directive
  Highlight
  /// A regex pattern line.
  Pattern
  /// An EBNF rule.
  Rule
  /// An EBNF note.
  Note
  /// JSON or YAML data.
  Data
  Blank
  /// Text after the end marker.
  Trailing
  Error
} derive(Eq, Debug)

///|
pub extend NodeKind with Eq::{not_equal, equal}

///|
pub extend NodeKind with @debug.Debug::{to_repr}

///|
pub(all) enum Element {
  Token(Token)
  Node(Node)
} derive(Eq, Debug)

///|
/// A node of the lossless syntax tree.
pub struct Node {
  kind : NodeKind
  children : ReadOnlyArray[Element]
} derive(Eq, Debug)

///|
pub extend Element with Eq::{not_equal, equal}

///|
pub extend Element with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Node::new(kind : NodeKind, children : ArrayView[Element]) -> Node {
  { kind, children: ReadOnlyArray::from_array(children) }
}

///|
/// All tokens of the node in source order, without recursion.
pub fn Node::tokens(self : Node) -> Array[Token] {
  let out = []
  let stack : Array[Element] = self.children.rev_iter().collect()
  while stack.pop() is Some(element) {
    match element {
      Token(token) => out.push(token)
      Node(node) => for child in node.children.rev_iter() { stack.push(child) }
    }
  }
  out
}

///|
/// The source text of the node.
pub fn Node::text(self : Node) -> String {
  let out = StringBuilder()
  for token in self.tokens() {
    out.write_string(token.text)
  }
  out.to_string()
}

///|
/// The child nodes of the node.
pub fn Node::nodes(self : Node) -> Array[Node] {
  let out = []
  for child in self.children {
    if child is Node(node) {
      out.push(node)
    }
  }
  out
}

///|
/// The half-open UTF-16 range of the node, or `None` for an empty node.
pub fn Node::range(self : Node) -> (Int, Int)? {
  let tokens = self.tokens()
  match (tokens.get(0), tokens.last()) {
    (Some(first), Some(last)) =>
      Some((first.offset, last.offset + last.text.length()))
    _ => None
  }
}

///|
/// A line index of a source text for UTF-16 positions.
pub struct Lines {
  priv starts : Array[Int]
  priv length : Int
}

///|
pub fn Lines::new(source : String) -> Lines {
  let starts = [0]
  for i in 0..<source.length() {
    if source.code_unit_at(i).to_int() == 10 {
      starts.push(i + 1)
    }
  }
  { starts, length: source.length() }
}

///|
/// The position of a UTF-16 offset. Lines and columns start at 1; columns
/// count UTF-16 code units. A CR before LF belongs to its line.
pub fn Lines::position(self : Lines, offset : Int) -> @diagrams.Position {
  let offset = offset.max(0).min(self.length)
  let mut low = 0
  let mut high = self.starts.length() - 1
  while low < high {
    let middle = (low + high + 1) / 2
    if self.starts[middle] <= offset {
      low = middle
    } else {
      high = middle - 1
    }
  }
  { offset, line: low + 1, column: offset - self.starts[low] + 1 }
}

///|
pub fn Lines::span(self : Lines, start : Int, end : Int) -> @diagrams.Span {
  { start: self.position(start), end: self.position(end) }
}

///|
/// The span of a half-open UTF-16 range of `source`.
pub fn span(source : String, start : Int, end : Int) -> @diagrams.Span {
  Lines::new(source).span(start, end)
}

///|
/// The owned text of the half-open UTF-16 range `start` to `end` of `text`.
pub fn slice(text : String, start : Int, end : Int) -> String {
  text.view(start_offset=start, end_offset=end).to_owned()
}
