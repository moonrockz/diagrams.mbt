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
/// A `participant` or `actor` statement. `created` is true for the `create`
/// form. `config` is the text inside `@{...}` without the spaces at its ends.
pub(all) struct ParticipantDecl {
  created : Bool
  keyword : ParticipantKeyword
  id : String
  config : String?
  label : String?
} derive(Eq, Debug)

///|
pub extend ParticipantDecl with Eq::{not_equal, equal}

///|
pub extend ParticipantDecl with @debug.Debug::{to_repr}

///|
/// The activation shorthand of a message: `+` or `-` after the arrow.
pub(all) enum Activation {
  Activate
  Deactivate
} derive(Eq, Debug)

///|
pub extend Activation with Eq::{not_equal, equal}

///|
pub extend Activation with @debug.Debug::{to_repr}

///|
/// A message statement. `arrow` keeps the exact spelling of the source, and
/// `text` has no spaces at its ends. `central_before` and `central_after` are
/// the `()` central connection markers before and after the arrow.
pub(all) struct MessageStatement {
  sender : String
  arrow : String
  receiver : String
  text : String
  activation : Activation?
  central_before : Bool
  central_after : Bool
} derive(Eq, Debug)

///|
pub extend MessageStatement with Eq::{not_equal, equal}

///|
pub extend MessageStatement with @debug.Debug::{to_repr}

///|
/// Where a note is.
pub(all) enum Placement {
  LeftOf
  RightOf
  Over
} derive(Eq, Debug)

///|
pub extend Placement with Eq::{not_equal, equal}

///|
pub extend Placement with @debug.Debug::{to_repr}

///|
/// A note on one participant, or over one or two participants.
pub(all) struct NoteStatement {
  placement : Placement
  participants : ReadOnlyArray[String]
  text : String
} derive(Eq, Debug)

///|
pub extend NoteStatement with Eq::{not_equal, equal}

///|
pub extend NoteStatement with @debug.Debug::{to_repr}

///|
/// The keyword of a `link`-like statement.
pub(all) enum LinkKind {
  Link
  Links
  Properties
  Details
} derive(Eq, Debug)

///|
pub extend LinkKind with Eq::{not_equal, equal}

///|
pub extend LinkKind with @debug.Debug::{to_repr}

///|
/// A `link`, `links`, `properties` or `details` statement. `text` is the text
/// after `:` as written, for example JSON for `links`.
pub(all) struct LinkStatement {
  kind : LinkKind
  participant : String
  text : String
} derive(Eq, Debug)

///|
pub extend LinkStatement with Eq::{not_equal, equal}

///|
pub extend LinkStatement with @debug.Debug::{to_repr}

///|
/// An `autonumber` statement. The numbers keep their spelling.
pub(all) enum Autonumber {
  On(start~ : String?, step~ : String?)
  Off
} derive(Eq, Debug)

///|
pub extend Autonumber with Eq::{not_equal, equal}

///|
pub extend Autonumber with @debug.Debug::{to_repr}

///|
/// The kind of a frame.
pub(all) enum FrameKind {
  Loop
  Rect
  Opt
  Alt
  Par
  ParOver
  Critical
  Break
} derive(Eq, Debug)

///|
pub extend FrameKind with Eq::{not_equal, equal}

///|
pub extend FrameKind with @debug.Debug::{to_repr}

///|
/// One section of a frame: the text after its keyword and its statements. The
/// first section starts at the frame keyword, and each `else`, `and` or
/// `option` starts another one.
pub(all) struct Section {
  label : String
  statements : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub extend Section with Eq::{not_equal, equal}

///|
pub extend Section with @debug.Debug::{to_repr}

///|
/// A frame such as `loop`, `alt` or `rect`, with one or more sections.
pub(all) struct Frame {
  kind : FrameKind
  sections : ReadOnlyArray[Section]
} derive(Eq, Debug)

///|
pub extend Frame with Eq::{not_equal, equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
/// A `box` group: the text after `box` and the participant statements in it.
pub(all) struct Box {
  label : String
  statements : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub extend Box with Eq::{not_equal, equal}

///|
pub extend Box with @debug.Debug::{to_repr}

///|
/// What a statement says.
pub(all) enum StatementKind {
  Participant(ParticipantDecl)
  Destroy(String)
  Activate(String)
  Deactivate(String)
  Message(MessageStatement)
  Note(NoteStatement)
  Link(LinkStatement)
  Title(String)
  AccTitle(String)
  AccDescr(String)
  Autonumber(Autonumber)
  Frame(Frame)
  Box(Box)
} derive(Eq, Debug)

///|
pub extend StatementKind with Eq::{not_equal, equal}

///|
pub extend StatementKind with @debug.Debug::{to_repr}

///|
/// One statement and its place in the source. Equality does not compare
/// `span`, so two sources with the same statements have equal ASTs.
pub(all) struct Statement {
  kind : StatementKind
  span : @diagrams.Span
} derive(Debug)

///|
pub extend Statement with @debug.Debug::{to_repr}

///|
pub impl Eq for Statement with equal(a, b) {
  a.kind == b.kind
}

///|
pub extend Statement with Eq::{not_equal, equal}

///|
/// The typed AST of a Mermaid sequence diagram. `front_matter` is the front
/// matter block with its `---` lines. `directives` are the `%%{...}%%`
/// directives in source order. Comments are not in the AST.
pub(all) struct Diagram {
  front_matter : String?
  directives : ReadOnlyArray[String]
  statements : ReadOnlyArray[Statement]
} derive(Eq, Debug)

///|
pub extend Diagram with Eq::{not_equal, equal}

///|
pub extend Diagram with @debug.Debug::{to_repr}

///|
/// A diagram with copies of `statements` and `directives`.
pub fn Diagram::new(
  statements : ArrayView[Statement],
  front_matter? : String,
  directives? : ArrayView[String] = [],
) -> Diagram {
  {
    front_matter,
    directives: ReadOnlyArray::from_array(directives),
    statements: ReadOnlyArray::from_array(statements),
  }
}
