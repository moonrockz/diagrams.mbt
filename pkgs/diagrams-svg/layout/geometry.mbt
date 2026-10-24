///|
/// A rectangle in SVG user units. `x` and `y` are the top-left corner.
pub(all) struct Rect {
  x : Int
  y : Int
  width : Int
  height : Int
} derive(Eq, Debug)

///|
pub extend Rect with Eq::{not_equal, equal}

///|
pub extend Rect with @debug.Debug::{to_repr}

///|
/// True when two rectangles share an area.
pub fn Rect::overlaps(self : Rect, other : Rect) -> Bool {
  self.x < other.x + other.width &&
  other.x < self.x + self.width &&
  self.y < other.y + other.height &&
  other.y < self.y + self.height
}

///|
/// The colour role of a text.
pub(all) enum Ink {
  Primary
  Muted
  Accent(@theme.Family)
  Color(@theme.Color)
} derive(Eq, Debug)

///|
pub extend Ink with Eq::{not_equal, equal}

///|
pub extend Ink with @debug.Debug::{to_repr}

///|
/// One layer that is painted behind a text, above the background.
pub(all) enum Layer {
  Mask
  Fill(@theme.Family)
  Tint(@theme.Color)
} derive(Eq, Debug)

///|
pub extend Layer with Eq::{not_equal, equal}

///|
pub extend Layer with @debug.Debug::{to_repr}

///|
/// A text with its measured box. `x` is the centre, and `baseline` is the y
/// of the baseline. `backdrop` lists the layers behind the text, bottom first.
/// `owner` names the element that the text belongs to.
pub(all) struct Label {
  content : String
  x : Int
  baseline : Int
  size : Int
  weight : Int
  box : Rect
  ink : Ink
  backdrop : ReadOnlyArray[Layer]
  owner : String
} derive(Eq, Debug)

///|
pub extend Label with Eq::{not_equal, equal}

///|
pub extend Label with @debug.Debug::{to_repr}

///|
/// A participant box with its label and the x of its lifeline.
pub(all) struct ParticipantBox {
  id : String
  family : @theme.Family
  box : Rect
  label : Label
  lifeline_x : Int
  lifeline_top : Int
  lifeline_bottom : Int
  destroyed : Bool
  participant : @sequence.Participant
  sublabel : Label?
} derive(Eq, Debug)

///|
pub extend ParticipantBox with Eq::{not_equal, equal}

///|
pub extend ParticipantBox with @debug.Debug::{to_repr}

///|
/// A message line from `x1` to `x2` at `y`, with its label on a chip.
pub(all) struct MessageLine {
  index : Int
  sender : String
  receiver : String
  family : @theme.Family
  x1 : Int
  x2 : Int
  y : Int
  chip : Rect
  label : Label
  sublabel : Label?
  path : ReadOnlyArray[Segment]
  message : @sequence.Message
} derive(Eq, Debug)

///|
pub extend MessageLine with Eq::{not_equal, equal}

///|
pub extend MessageLine with @debug.Debug::{to_repr}

///|
/// The geometry of a sequence diagram. The painter draws it, and the
/// legibility check reads it.
pub(all) struct Geometry {
  width : Int
  height : Int
  lifeline_top : Int
  lifeline_bottom : Int
  participants : ReadOnlyArray[ParticipantBox]
  messages : ReadOnlyArray[MessageLine]
  notes : ReadOnlyArray[NoteBox]
  activations : ReadOnlyArray[ActivationBar]
  frames : ReadOnlyArray[FrameBox]
  groups : ReadOnlyArray[GroupBox]
  title : Label?
  title_box : Rect?
} derive(Eq, Debug)

///|
pub extend Geometry with Eq::{not_equal, equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
/// One axis-aligned path segment. Owners associate a path with its label.
pub(all) struct Segment {
  x1 : Int
  y1 : Int
  x2 : Int
  y2 : Int
  owner : String
} derive(Eq, Debug)

///|
pub extend Segment with Eq::{not_equal, equal}

///|
pub extend Segment with @debug.Debug::{to_repr}

///|
/// A note with measured text. The box spans each anchor for an over note.
pub(all) struct NoteBox {
  index : Int
  note : @sequence.Note
  box : Rect
  label : Label
} derive(Eq, Debug)

///|
pub extend NoteBox with Eq::{not_equal, equal}

///|
pub extend NoteBox with @debug.Debug::{to_repr}

///|
/// One activation, numbered from depth zero. Nested bars move right by 4 px.
pub(all) struct ActivationBar {
  participant : String
  depth : Int
  box : Rect
} derive(Eq, Debug)

///|
pub extend ActivationBar with Eq::{not_equal, equal}

///|
pub extend ActivationBar with @debug.Debug::{to_repr}

///|
/// One frame section, with an optional label and preceding divider.
pub(all) struct FrameSection {
  box : Rect
  label : Label?
  chip : Rect?
  divider : Segment?
} derive(Eq, Debug)

///|
pub extend FrameSection with Eq::{not_equal, equal}

///|
pub extend FrameSection with @debug.Debug::{to_repr}

///|
/// A frame and its ordered sections. The array of frames is in preorder.
pub(all) struct FrameBox {
  index : Int
  parent : Int?
  kind : @sequence.FrameKind
  colour : String?
  box : Rect
  header : Label?
  chip : Rect?
  sections : ReadOnlyArray[FrameSection]
} derive(Eq, Debug)

///|
pub extend FrameBox with Eq::{not_equal, equal}

///|
pub extend FrameBox with @debug.Debug::{to_repr}

///|
/// A participant group and its title. The box includes its members
/// and their lifelines, including members created later in the diagram.
pub(all) struct GroupBox {
  group : @sequence.BoxGroup
  box : Rect
  label : Label
  chip : Rect
} derive(Eq, Debug)

///|
pub extend GroupBox with Eq::{not_equal, equal}

///|
pub extend GroupBox with @debug.Debug::{to_repr}
