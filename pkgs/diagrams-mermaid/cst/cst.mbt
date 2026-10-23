///|
/// The kind of a token in the lossless syntax tree.
pub(all) enum TokenKind {
  Keyword
  Identifier
  Arrow
  Colon
  Text
  Whitespace
  Newline
  Comment
  Unknown
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
/// A token.
pub fn Token::new(kind : TokenKind, text : String, offset : Int) -> Token {
  { kind, text, offset }
}

///|
/// The kind of a node. Each line of a sequence diagram is one node below the
/// document node. A line node includes its line break.
pub(all) enum NodeKind {
  Document
  Header
  Participant
  Message
  Comment
  Blank
  Error
} derive(Eq, Debug)

///|
pub extend NodeKind with Eq::{not_equal, equal}

///|
pub extend NodeKind with @debug.Debug::{to_repr}

///|
/// One element of a node: a token or a child node.
pub(all) enum Element {
  Token(Token)
  Node(Node)
} derive(Eq, Debug)

///|
pub extend Element with Eq::{not_equal, equal}

///|
pub extend Element with @debug.Debug::{to_repr}

///|
/// A node of the lossless syntax tree.
pub struct Node {
  kind : NodeKind
  children : ReadOnlyArray[Element]
} derive(Eq, Debug)

///|
pub extend Node with Eq::{not_equal, equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
/// A node. The node keeps a copy of `children`.
pub fn Node::new(kind : NodeKind, children : ArrayView[Element]) -> Node {
  { kind, children: ReadOnlyArray::from_array(children) }
}

///|
/// All tokens below this node, in source order.
pub fn Node::tokens(self : Node) -> Array[Token] {
  let out = []
  fn walk(node : Node) {
    for child in node.children {
      match child {
        Token(t) => out.push(t)
        Node(n) => walk(n)
      }
    }
  }

  walk(self)
  out
}

///|
/// The direct child nodes of this node.
pub fn Node::nodes(self : Node) -> Array[Node] {
  let out = []
  for child in self.children {
    if child is Node(n) {
      out.push(n)
    }
  }
  out
}

///|
/// The source text of this node.
pub fn Node::text(self : Node) -> String {
  let buf = StringBuilder()
  for t in self.tokens() {
    buf.write_string(t.text)
  }
  buf.to_string()
}

///|
/// The UTF-16 offsets of the first code unit of this node and of the code unit
/// after its last token. A node with no tokens gives `None`.
pub fn Node::range(self : Node) -> (Int, Int)? {
  let tokens = self.tokens()
  guard tokens.last() is Some(last) else { return None }
  Some((tokens[0].offset, last.offset + last.text.length()))
}

///|
/// The position of the UTF-16 offset `offset` in `source`. Lines and columns
/// start at 1. `\r\n`, `\n` and a single `\r` each end a line.
pub fn position(source : String, offset : Int) -> @diagrams.Position {
  let mut line = 1
  let mut start = 0
  let mut i = 0
  while i < offset && i < source.length() {
    let c = source.at(i).to_int()
    if c == '\n'.to_int() {
      line += 1
      start = i + 1
    } else if c == '\r'.to_int() {
      if i + 1 < source.length() && source.at(i + 1).to_int() == '\n'.to_int() {
        i += 1
      }
      line += 1
      start = i + 1
    }
    i += 1
  }
  { offset, line, column: offset - start + 1 }
}

///|
/// The span from the UTF-16 offset `start` to `end` in `source`.
pub fn span(source : String, start : Int, end : Int) -> @diagrams.Span {
  { start: position(source, start), end: position(source, end) }
}
