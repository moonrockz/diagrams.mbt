///|
/// The native PlantUML activity grammar selected by the document.
pub(all) enum Dialect {
  Modern
  Legacy
} derive(Eq, Debug)

///|
pub(all) enum Endpoint {
  Start(Bool)
  Final
  Action(String, String?, String)
  Alias(String)
  Synchronization(String)
} derive(Eq, Debug)

///|
/// Typed statements retain control structure and editable values. The sequence
/// is flat: opening and closing statements retain their native source order.
pub(all) enum Kind {
  Action(String, String, String)
  Start
  Stop
  End
  If(String, String)
  ElseIf(String, String)
  ElseIfIncoming(String, String, String)
  Else(String)
  EndIf
  Switch(String)
  Case(String)
  EndSwitch
  While(String, String)
  EndWhile(String)
  Repeat(String)
  RepeatWhile(String, String, String)
  Backward(String)
  Break
  Fork
  ForkAgain
  EndFork(Bool, String)
  Split
  SplitAgain
  EndSplit
  Kill
  Detach
  Connector(String)
  Label(String)
  Goto(String)
  Group(String, String, String, String)
  EndGroup
  Lane(String, String, String)
  Note(String, String, String?, String)
  NoteOnLink(String, String)
  Arrow(String, String)
  Edge(Endpoint?, String, Endpoint, String)
  LegacyIf(String)
  LegacyDecision(Endpoint?, String, String, String)
  ActionList(String, Int32)
  Presentation(String)
} derive(Eq, Debug)

///|
pub struct Statement {
  kind : Kind
  span : @diagrams.Span?
} derive(Eq, Debug)

///|
pub fn Statement::new(kind : Kind, span? : @diagrams.Span) -> Statement {
  { kind, span, }
}

///|
pub struct Document {
  dialect : Dialect
  name : String?
  statements : ReadOnlyArray[@envelope.Statement]
  items : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub fn Document::new(
  dialect : Dialect,
  items : ArrayView[Statement],
  name? : String,
  statements~ : ArrayView[@envelope.Statement] = [],
) -> Document {
  {
    dialect,
    name,
    items: ReadOnlyArray::from_array(items),
    statements: ReadOnlyArray::from_array(statements),
  }
}

///|
pub fn Document::without_spans(self : Document) -> Document {
  {
    ..self,
    items: ReadOnlyArray::from_iter(
      self.items.iter().map(s => { ..s, span: None, }),
    ),
  }
}

///|
pub fn Document::logical_equal(self : Document, other : Document) -> Bool {
  self.without_spans() == other.without_spans()
}

///|
pub extend Dialect with Eq::{equal, not_equal}

///|
pub extend Dialect with @debug.Debug::{to_repr}

///|
pub extend Endpoint with Eq::{equal, not_equal}

///|
pub extend Endpoint with @debug.Debug::{to_repr}

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
