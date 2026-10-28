///|
/// Editable native statements. Open/close/separator values retain lexical order.
pub(all) enum Kind {
  Declaration(String, String, String, Bool)
  Close
  Separator(Bool)
  Description(String, String)
  Transition(String, String, String, String)
  Note(String, String?, String, String?)
  Direction(@flowchart.Direction)
  Presentation(String)
} derive(Eq, Debug)

///|
pub struct Statement {
  kind : Kind
  explicit_label : Bool
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub fn Statement::new(kind : Kind, span? : @diagrams.Span, explicit_label? : Bool) -> Statement {
  let explicit_label = explicit_label.unwrap_or(match kind { Declaration(code, label, _, _) => code != label; _ => false })
  { kind, explicit_label, span }
}

///|
pub struct Document {
  name : String?
  complete : Bool
  statements : ReadOnlyArray[@envelope.Statement]
  items : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub fn Document::new(
  items : ArrayView[Statement],
  name? : String,
  complete~ : Bool = true,
  statements~ : ArrayView[@envelope.Statement] = [],
) -> Document {
  { name, complete, statements: ReadOnlyArray::from_array(statements), items: ReadOnlyArray::from_array(items) }
}

///|
pub fn Document::without_spans(self : Document) -> Document {
  { ..self, items: ReadOnlyArray::from_iter(self.items.iter().map(s => { ..s, span: None })) }
}

///|
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  self.without_spans() == other.without_spans()
}

///|
pub extend Kind with Eq::{equal, not_equal}
///|
pub extend Kind with @debug.Debug::{to_repr}
///|
pub extend Statement with Eq::{equal, not_equal}
///|
pub extend Statement with @debug.Debug::{to_repr}
///|
pub extend Document with Eq::{equal, not_equal}
///|
pub extend Document with @debug.Debug::{to_repr}
