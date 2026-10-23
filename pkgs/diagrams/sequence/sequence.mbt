///|
/// What a participant is. A renderer uses the kind to select a style.
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
} derive(Eq, Debug)

///|
pub extend ParticipantKind with Eq::{not_equal, equal}

///|
pub extend ParticipantKind with @debug.Debug::{to_repr}

///|
/// One participant of a sequence. `id` is unique in the sequence.
pub struct Participant {
  id : String
  label : String
  kind : ParticipantKind
} derive(Eq, Debug)

///|
pub extend Participant with Eq::{not_equal, equal}

///|
pub extend Participant with @debug.Debug::{to_repr}

///|
/// A participant. The label is the id when no label is given.
pub fn Participant::new(
  id : String,
  label? : String,
  kind? : ParticipantKind = Participant,
) -> Participant {
  { id, label: label.unwrap_or(id), kind }
}

///|
/// The line of a message.
pub(all) enum LineStyle {
  Solid
  Dotted
} derive(Eq, Debug)

///|
pub extend LineStyle with Eq::{not_equal, equal}

///|
pub extend LineStyle with @debug.Debug::{to_repr}

///|
/// What a message line has at one of its ends.
pub(all) enum Head {
  NoHead
  Arrow
} derive(Eq, Debug)

///|
pub extend Head with Eq::{not_equal, equal}

///|
pub extend Head with @debug.Debug::{to_repr}

///|
/// A message from `sender` to `receiver`.
pub struct Message {
  sender : String
  receiver : String
  line : LineStyle
  sender_head : Head
  receiver_head : Head
  label : String
} derive(Eq, Debug)

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
  line? : LineStyle = Solid,
  sender_head? : Head = NoHead,
  receiver_head? : Head = Arrow,
) -> Message {
  { sender, receiver, line, sender_head, receiver_head, label }
}

///|
/// One event of a sequence, in diagram order.
pub(all) enum Event {
  Message(Message)
} derive(Eq, Debug)

///|
pub extend Event with Eq::{not_equal, equal}

///|
pub extend Event with @debug.Debug::{to_repr}

///|
/// A sequence diagram without a link to one diagram format.
pub struct Sequence {
  participants : ReadOnlyArray[Participant]
  events : ReadOnlyArray[Event]
  title : String?
} derive(Eq, Debug)

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
) -> Sequence {
  {
    participants: ReadOnlyArray::from_array(participants),
    events: ReadOnlyArray::from_array(events),
    title,
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
