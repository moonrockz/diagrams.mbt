///|
/// Source statements retain declaration order. Composite boundaries and region
/// separators remain explicit; behavior labels are never evaluated.
pub(all) enum StatementKind {
  State(
    id~ : String,
    label~ : String?,
    role~ : String?,
    description~ : String?,
    classes~ : ReadOnlyArray[String]
  )
  Composite(id~ : String, label~ : String?)
  EndComposite
  Concurrent
  Transition(
    source~ : String,
    target~ : String,
    label~ : String?,
    source_classes~ : ReadOnlyArray[String],
    target_classes~ : ReadOnlyArray[String]
  )
  Description(id~ : String, text~ : String)
  Note(target~ : String, placement~ : String, text~ : String)
  FloatingNote(id~ : String, text~ : String)
  Direction(String)
  AccTitle(String)
  AccDescription(String)
  Presentation(String)
  Comment(String)
  Invalid(String)
} derive(Eq, Debug)

///|
pub(all) struct Statement {
  kind : StatementKind
  span : @diagrams.Span
} derive(Debug)

///|
pub impl Eq for Statement with fn equal(a, b) {
  a.kind == b.kind
}

///|
pub struct Diagram {
  header : String
  statements : ReadOnlyArray[Statement]
  front_matter : String?
  directives : ReadOnlyArray[String]
} derive(Debug)

///|
pub fn Diagram::new(
  statements : ArrayView[Statement],
  header~ : String = "stateDiagram-v2",
  front_matter? : String,
  directives~ : ArrayView[String] = [],
) -> Diagram {
  {
    header,
    statements: ReadOnlyArray::from_array(statements),
    front_matter,
    directives: ReadOnlyArray::from_array(directives),
  }
}

///|
pub impl Eq for Diagram with fn equal(a, b) {
  a.header == b.header &&
  a.statements == b.statements &&
  a.front_matter == b.front_matter &&
  a.directives == b.directives
}

///|
pub extend StatementKind with Eq::{equal, not_equal}

///|
pub extend StatementKind with @debug.Debug::{to_repr}

///|
pub extend Statement with Eq::{equal, not_equal}

///|
pub extend Statement with @debug.Debug::{to_repr}

///|
pub extend Diagram with Eq::{equal, not_equal}

///|
pub extend Diagram with @debug.Debug::{to_repr}
