///|
pub(all) enum StatementKind {
  Group(id~ : String, icon~ : String?, label~ : String?, parent~ : String?)
  Service(
    id~ : String,
    icon~ : String?,
    icon_text~ : String?,
    label~ : String?,
    parent~ : String?
  )
  Junction(id~ : String, parent~ : String?)
  Edge(
    source~ : @model.Endpoint,
    target~ : @model.Endpoint,
    label~ : String?,
    source_head~ : Bool,
    target_head~ : Bool
  )
  Alignment(axis~ : @model.Axis, members~ : ReadOnlyArray[String])
  Title(String)
  AccTitle(String)
  AccDescription(String)
  Comment(String)
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
  statements : ReadOnlyArray[Statement]
  front_matter : String?
  directives : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
pub fn Diagram::new(
  statements : ArrayView[Statement],
  front_matter? : String,
  directives~ : ArrayView[String] = [],
) -> Diagram {
  {
    statements: ReadOnlyArray::from_array(statements),
    front_matter,
    directives: ReadOnlyArray::from_array(directives),
  }
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
