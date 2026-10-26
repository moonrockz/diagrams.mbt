///|
pub(all) enum TokenKind {
  Header
  Statement
  Comment
  Directive
  FrontMatter
  Whitespace
  Error
} derive(Eq, Debug)

///|
pub(all) struct Token {
  kind : TokenKind
  text : String
  offset : Int32
} derive(Eq, Debug)

///|
pub struct Node {
  children : ReadOnlyArray[Token]
} derive(Eq, Debug)

///|
pub fn Node::new(children : ArrayView[Token]) -> Node {
  { children: ReadOnlyArray::from_array(children), }
}

///|
pub fn Node::text(self : Node) -> String {
  let out = StringBuilder()
  for token in self.children {
    out.write_string(token.text)
  }
  out.to_string()
}

///|
pub fn Token::span(self : Token, source : String) -> @diagrams.Span {
  @positions.span(source, self.offset, self.offset + self.text.length())
}

///|
pub extend TokenKind with Eq::{equal, not_equal}

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}
