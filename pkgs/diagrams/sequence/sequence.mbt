///|
/// What a participant is. A renderer uses the kind to select a style.
#derive(Eq, Debug)
pub(all) enum ParticipantKind {
  Participant
  Actor
  Boundary
  Control
  Entity
  Database
  Collections
  Queue
  Service
  Resource
  Client
}

///|
pub extend ParticipantKind with Eq::{not_equal, equal}

///|
pub extend ParticipantKind with @debug.Debug::{to_repr}

///|
/// One participant of a sequence. `id` is unique in the sequence.
#derive(Eq, Debug)
pub struct Participant {
  id : String
  label : String
  kind : ParticipantKind
  group : BoxGroup?
  link : Link?
  icon : @icons.Reference?
  properties : ParticipantProperties?
}

///|
pub extend Participant with Eq::{not_equal, equal}

///|
pub extend Participant with @debug.Debug::{to_repr}

///|
/// A participant. The label is the id when no label is given.
pub fn Participant::new(
  id : String,
  label? : String,
  kind~ : ParticipantKind = Participant,
  group? : BoxGroup,
  link? : Link,
  properties? : ParticipantProperties,
  icon? : @icons.Reference,
) -> Participant {
  { id, label: label.unwrap_or(id), kind, group, link, properties, icon, }
}

///|
/// The line of a message.
#derive(Eq, Debug)
pub(all) enum LineStyle {
  Solid
  Dotted
}

///|
pub extend LineStyle with Eq::{not_equal, equal}

///|
pub extend LineStyle with @debug.Debug::{to_repr}

///|
/// What a message line has at one of its ends.
#derive(Eq, Debug)
pub(all) enum Head {
  NoHead
  Arrow
  OpenArrow
  Cross
  Async
  HalfArrow(upper~ : Bool, filled~ : Bool)
  Central(Head)
}

///|
pub extend Head with Eq::{not_equal, equal}

///|
pub extend Head with @debug.Debug::{to_repr}

///|
/// A message from `sender` to `receiver`.
#derive(Eq, Debug)
pub struct Message {
  sender : String
  receiver : String
  line : LineStyle
  sender_head : Head
  receiver_head : Head
  label : String
  link : Link?
  properties : MessageProperties?
  number : Double?
}

///|
pub extend Message with Eq::{not_equal, equal}

///|
pub extend Message with @debug.Debug::{to_repr}

///|
/// A message. The default is a solid line with an arrowhead at the receiver.
pub fn Message::new(
  sender : String,
  receiver : String,
  label : String,
  line~ : LineStyle = Solid,
  sender_head~ : Head = NoHead,
  receiver_head~ : Head = Arrow,
  link? : Link,
  properties? : MessageProperties,
  number? : Double,
) -> Message {
  {
    sender,
    receiver,
    line,
    sender_head,
    receiver_head,
    label,
    link,
    properties,
    number,
  }
}

///|
/// One event of a sequence, in diagram order.
#derive(Eq, Debug)
pub(all) enum Event {
  Message(Message)
  Note(Note)
  Activate(String)
  Deactivate(String)
  Create(String)
  Destroy(String)
  Frame(Frame)
  Autonumber(Autonumber)
}

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub extend Event with @debug.Debug::{to_repr}

///|
/// A sequence diagram without a link to one diagram format.
#derive(Eq, Debug)
pub struct Sequence {
  participants : ReadOnlyArray[Participant]
  events : ReadOnlyArray[Event]
  title : String?
  accessibility_title : String?
  accessibility_description : String?
}

///|
pub extend Sequence with Eq::{not_equal, equal}

///|
pub extend Sequence with @debug.Debug::{to_repr}

///|
/// A sequence. The model keeps copies of `participants` and `events`, so a
/// later change to the input arrays does not change it.
pub fn Sequence::new(
  participants : ArrayView[Participant],
  events : ArrayView[Event],
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
) -> Sequence {
  {
    participants: ReadOnlyArray::from_array(participants),
    events: ReadOnlyArray::from_array(events),
    title,
    accessibility_title,
    accessibility_description,
  }
}

///|
/// The participant with the id `id`.
pub fn Sequence::participant(self : Sequence, id : String) -> Participant? {
  for p in self.participants {
    if p.id == id {
      return Some(p)
    }
  }
  None
}
