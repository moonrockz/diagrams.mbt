///|
/// Typed native statements. Open statements and End retain explicit nesting.
#derive(Eq, Debug)
pub(all) enum StatementKind {
  Participant(id~ : String, label~ : String?, annotator~ : String?)
  Call(
    sender~ : String?,
    receiver~ : String,
    operation~ : String,
    assignment~ : String?,
    creation~ : Bool,
    scope~ : Bool
  )
  Async(sender~ : String, receiver~ : String, label~ : String, reply~ : Bool)
  Starter(String)
  Return(String)
  Begin(keyword~ : String, expression~ : String)
  Section(keyword~ : String, expression~ : String)
  End
  Comment(String)
  Title(String)
  Metadata(String)
}

///|
#derive(Debug)
pub(all) struct Statement {
  kind : StatementKind
  span : @diagrams.Span
}

///|
pub impl Eq for Statement with fn equal(a, b) {
  a.kind == b.kind
}

///|
#derive(Eq, Debug)
pub struct Diagram {
  statements : ReadOnlyArray[Statement]
}

///|
pub fn Diagram::new(statements : ArrayView[Statement]) -> Diagram {
  { statements: ReadOnlyArray::from_array(statements), }
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
