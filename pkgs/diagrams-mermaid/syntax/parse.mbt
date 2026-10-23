///|
/// The lossless syntax tree of a source and the syntax diagnostics.
pub struct ParseResult {
  tree : @cst.Node
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Parse a Mermaid sequence diagram. The text of the tree is always equal to
/// `source`. A line that is not a statement becomes an error node with a
/// diagnostic, and the parser continues at the next line.
pub fn parse(source : String) -> ParseResult {
  let nodes : Array[@cst.Element] = []
  let diagnostics = []
  let mut header = false
  for line in lines(source) {
    let cursor = Cursor::new(line.content, line.offset)
    ignore(cursor.space())
    let kind : @cst.NodeKind = if cursor.at_end() {
      Blank
    } else if cursor.looking_at("%%") {
      ignore(cursor.take(Comment, line.content.length()))
      Comment
    } else if !header && cursor.keyword("sequenceDiagram") {
      header = true
      cursor.text_to_end()
      Header
    } else {
      let start = cursor.pos
      let parsed = statement(cursor)
      if !header {
        header = true
        diagnostics.push(
          @diagrams.Diagnostic::error(
            "mermaid/missing-header",
            "a sequence diagram starts with `sequenceDiagram`",
            span=@cst.span(
              source,
              line.offset + start,
              line.offset + line.content.length(),
            ),
          ),
        )
      }
      match parsed {
        Some(kind) => kind
        None => {
          let error_tokens = error_line(line.content, line.offset)
          cursor.tokens.clear()
          for e in error_tokens {
            cursor.tokens.push(e)
          }
          diagnostics.push(
            @diagrams.Diagnostic::error(
              "mermaid/unknown-statement",
              "this line is not a sequence diagram statement",
              span=@cst.span(
                source,
                line.offset + leading_spaces(line.content),
                line.offset + trimmed_end(line.content),
              ),
            ),
          )
          Error
        }
      }
    }
    if line.newline != "" {
      cursor.tokens.push(
        Token(
          @cst.Token::new(
            Newline,
            line.newline,
            line.offset + line.content.length(),
          ),
        ),
      )
    }
    nodes.push(Node(@cst.Node::new(kind, cursor.tokens)))
  }
  {
    tree: @cst.Node::new(Document, nodes),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
/// The offset after the last non-space code unit of `content`.
fn trimmed_end(content : String) -> Int {
  let mut end = content.length()
  while end > 0 && is_space(content.at(end - 1).to_int()) {
    end -= 1
  }
  end
}

///|
/// The tokens of a line that is not a statement: leading spaces, one unknown
/// token and trailing spaces.
fn error_line(content : String, offset : Int) -> Array[@cst.Element] {
  let c = Cursor::new(content, offset)
  ignore(c.space())
  let end = trimmed_end(content)
  if end > c.pos {
    ignore(c.take(Unknown, end))
  }
  ignore(c.space())
  c.tokens
}

///|
/// Read one statement at the cursor. Gives `None` when the line is not a
/// statement that this reader knows.
fn statement(c : Cursor) -> @cst.NodeKind? {
  if c.keyword("participant") || c.keyword("actor") {
    guard c.space() else { return None }
    guard c.identifier() is Some(_) else { return None }
    ignore(c.space())
    if c.at_end() {
      return Some(Participant)
    }
    guard c.keyword("as") else { return None }
    ignore(c.space())
    c.text_to_end()
    return Some(Participant)
  }
  guard c.identifier() is Some(_) else { return None }
  ignore(c.space())
  guard c.arrow() is Some(_) else { return None }
  ignore(c.space())
  guard c.identifier() is Some(_) else { return None }
  ignore(c.space())
  guard c.peek() == ':'.to_int() else { return None }
  ignore(c.take(Colon, c.pos + 1))
  ignore(c.space())
  c.text_to_end()
  Some(Message)
}

///|
/// The number of spaces and tabs at the start of `content`.
fn leading_spaces(content : String) -> Int {
  let mut i = 0
  while i < content.length() && is_space(content.at(i).to_int()) {
    i += 1
  }
  i
}
