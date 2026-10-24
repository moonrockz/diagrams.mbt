///|
/// The schemes understood by diagram adapters.
pub(all) enum LinkScheme {
  Smithy
  OpenRpc
} derive(Eq, Debug)

///|
pub extend LinkScheme with Eq::{not_equal, equal}

///|
pub extend LinkScheme with @debug.Debug::{to_repr}

///|
/// A format-independent link. Smithy targets use the canonical `#` spelling.
pub struct Link {
  scheme : LinkScheme
  target : String
} derive(Eq, Debug)

///|
pub extend Link with Eq::{not_equal, equal}

///|
pub extend Link with @debug.Debug::{to_repr}

///|
pub fn Link::new(scheme : LinkScheme, target : String) -> Link {
  { scheme, target }
}

///|
/// A box group. `id` distinguishes groups that have the same label.
pub struct BoxGroup {
  id : String
  label : String
  colour : String?
} derive(Eq, Debug)

///|
pub extend BoxGroup with Eq::{not_equal, equal}

///|
pub extend BoxGroup with @debug.Debug::{to_repr}

///|
pub fn BoxGroup::new(id : String, label : String, colour? : String) -> BoxGroup {
  { id, label, colour }
}

///|
/// Properties supplied by an adapter. The declared kind stays on the participant.
pub struct ParticipantProperties {
  kind : ParticipantKind?
  sublabel : String?
  description : String?
} derive(Eq, Debug)

///|
pub extend ParticipantProperties with Eq::{not_equal, equal}

///|
pub extend ParticipantProperties with @debug.Debug::{to_repr}

///|
pub fn ParticipantProperties::new(kind? : ParticipantKind, sublabel? : String, description? : String) -> ParticipantProperties {
  { kind, sublabel, description }
}

///|
/// Additional message text supplied by an adapter.
pub struct MessageProperties {
  sublabel : String?
  description : String?
} derive(Eq, Debug)

///|
pub extend MessageProperties with Eq::{not_equal, equal}

///|
pub extend MessageProperties with @debug.Debug::{to_repr}

///|
pub fn MessageProperties::new(sublabel? : String, description? : String) -> MessageProperties {
  { sublabel, description }
}

///|
/// Return a participant with new render properties, leaving the input unchanged.
pub fn Participant::with_properties(self : Participant, properties : ParticipantProperties) -> Participant {
  { ..self, properties: Some(properties) }
}

///|
/// The kind for rendering, falling back to the declared kind.
pub fn Participant::render_kind(self : Participant) -> ParticipantKind {
  self.properties.bind(p => p.kind).unwrap_or(self.kind)
}

///|
pub fn Message::with_properties(self : Message, properties : MessageProperties) -> Message {
  { ..self, properties: Some(properties) }
}

///|
/// The placement of a note.
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
/// A note on one or more participants.
pub struct Note {
  placement : Placement
  participants : ReadOnlyArray[String]
  text : String
} derive(Eq, Debug)

///|
pub extend Note with Eq::{not_equal, equal}

///|
pub extend Note with @debug.Debug::{to_repr}

///|
pub fn Note::new(placement : Placement, participants : ArrayView[String], text : String) -> Note {
  { placement, participants: ReadOnlyArray::from_array(participants), text }
}

///|
/// The meaning of a frame. `ParOver` permits overlapping parallel sections.
pub(all) enum FrameKind {
  Loop
  Alt
  Opt
  Par
  ParOver
  Critical
  Break
  Rect
} derive(Eq, Debug)

///|
pub extend FrameKind with Eq::{not_equal, equal}

///|
pub extend FrameKind with @debug.Debug::{to_repr}

///|
/// One ordered section of a frame.
pub struct Section {
  label : String?
  events : ReadOnlyArray[Event]
} derive(Eq, Debug)

///|
pub extend Section with Eq::{not_equal, equal}

///|
pub extend Section with @debug.Debug::{to_repr}

///|
pub fn Section::new(events : ArrayView[Event], label? : String) -> Section {
  { label, events: ReadOnlyArray::from_array(events) }
}

///|
/// A nested frame. A first section is required; `colour` belongs to rect frames.
/// The colour is stored on the frame rather than as a section label.
pub struct Frame {
  kind : FrameKind
  sections : ReadOnlyArray[Section]
  colour : String?
} derive(Eq, Debug)

///|
pub extend Frame with Eq::{not_equal, equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
pub fn Frame::new(kind : FrameKind, first : Section, rest? : ArrayView[Section] = [], colour? : String) -> Frame {
  { kind, sections: ReadOnlyArray::from_array([first, ..rest]), colour }
}

///|
/// A numbering change at this point in the event stream.
pub(all) enum Autonumber {
  On(start~ : Double?, step~ : Double?)
  Off
} derive(Eq, Debug)

///|
pub extend Autonumber with Eq::{not_equal, equal}

///|
pub extend Autonumber with @debug.Debug::{to_repr}
