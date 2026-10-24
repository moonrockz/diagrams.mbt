///|
/// The keyword of a participant declaration.
pub(all) enum ParticipantKeyword {
  Participant
  Actor
} derive(Eq, Debug)

///|
pub extend ParticipantKeyword with Eq::{not_equal, equal}

///|
pub extend ParticipantKeyword with @debug.Debug::{to_repr}

///|
/// A `participant` or `actor` statement. Equality does not compare `span`.
pub struct ParticipantDecl {
  keyword : ParticipantKeyword
  id : String
  label : String?
  span : @diagrams.Span
} derive(Debug)

///|
pub extend ParticipantDecl with @debug.Debug::{to_repr}

///|
pub impl Eq for ParticipantDecl with equal(a, b) {
  a.keyword == b.keyword && a.id == b.id && a.label == b.label
}

///|
pub extend ParticipantDecl with Eq::{not_equal, equal}

///|
/// A message statement. `arrow` keeps the exact spelling of the source, and
/// `text` has no leading or trailing spaces. Equality does not compare `span`.
pub struct MessageStatement {
  sender : String
  arrow : String
  receiver : String
  text : String
  span : @diagrams.Span
} derive(Debug)

///|
pub extend MessageStatement with @debug.Debug::{to_repr}

///|
pub impl Eq for MessageStatement with equal(a, b) {
  a.sender == b.sender &&
  a.arrow == b.arrow &&
  a.receiver == b.receiver &&
  a.text == b.text
}

///|
pub extend MessageStatement with Eq::{not_equal, equal}

///|
/// One statement of a sequence diagram.
pub(all) enum Statement {
  Participant(ParticipantDecl)
  Message(MessageStatement)
} derive(Eq, Debug)

///|
pub extend Statement with Eq::{not_equal, equal}

///|
pub extend Statement with @debug.Debug::{to_repr}

///|
/// The typed AST of a Mermaid sequence diagram.
pub struct Diagram {
  statements : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub extend Diagram with Eq::{not_equal, equal}

///|
pub extend Diagram with @debug.Debug::{to_repr}

///|
/// A diagram with a copy of `statements`.
pub fn Diagram::new(statements : ArrayView[Statement]) -> Diagram {
  { statements: ReadOnlyArray::from_array(statements) }
}

///|
/// The typed AST of a lossless syntax tree. Error nodes are not in the AST,
/// because the parser already reported them. A tree without the
/// `sequenceDiagram` header gives `None`.
///
/// This version reads top-level `participant`, `actor` and message
/// statements. The other statements come with task group 3 of
/// `add-mermaid-sequence`.
pub fn lower(tree : @cst.Node) -> Diagram? {
  let source = tree.text()
  let nodes = tree.nodes()
  guard nodes.iter().any(n => n.kind == Header) else { return None }
  let statements = []
  for node in nodes {
    let tokens = node
      .tokens()
      .filter(t => t.kind != Whitespace && t.kind != Newline)
    guard tokens.last() is Some(last) else { continue }
    let span = @cst.span(source, tokens[0].offset, last.offset + last.text.length())
    let names = tokens.filter(t => t.kind == Identifier).map(t => t.text)
    let text = match tokens.iter().find_first(t => t.kind == Text) {
      Some(t) => Some(t.text)
      None => None
    }
    match node.kind {
      Participant => {
        let keyword : ParticipantKeyword = if tokens.iter().any(t => t.kind == Keyword &&
            t.text.to_lower() == "actor") {
          Actor
        } else {
          Participant
        }
        let labelled = tokens.iter().any(t => t.kind == Keyword && t.text.to_lower() == "as")
        statements.push(
          Statement::Participant({
            keyword,
            id: names[0],
            label: if labelled { text } else { None },
            span,
          }),
        )
      }
      Message => {
        let arrow = match tokens.iter().find_first(t => t.kind == Arrow) {
          Some(t) => t.text
          None => ""
        }
        statements.push(
          Statement::Message({
            sender: names[0],
            arrow,
            receiver: names[1],
            text: text.unwrap_or(""),
            span,
          }),
        )
      }
      _ => ()
    }
  }
  Some(Diagram::new(statements))
}
