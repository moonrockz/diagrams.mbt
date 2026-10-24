///|
/// The sequence model of a Mermaid AST and the conversion diagnostics.
pub struct Conversion {
  sequence : @model.Sequence
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert a Mermaid AST to the sequence model. A participant that is not
/// declared is added at its first use, as Mermaid does.
///
/// This version reads participants and messages, also in frames and boxes.
/// The other statements come with task group 4 of `add-mermaid-sequence`.
pub fn to_sequence(diagram : @ast.Diagram) -> Conversion {
  let participants : Array[@model.Participant] = []
  let events : Array[@model.Event] = []
  fn known(id : String) -> Bool {
    participants.iter().any(p => p.id == id)
  }

  fn add_implicit(id : String) {
    if !known(id) {
      participants.push(@model.Participant::new(id))
    }
  }

  fn walk(list : ReadOnlyArray[@ast.Statement]) -> Unit {
    for statement in list {
      match statement.kind {
        Participant(p) =>
          if !known(p.id) {
            let kind : @model.ParticipantKind = match p.keyword {
              Participant => Participant
              Actor => Actor
            }
            participants.push(@model.Participant::new(p.id, label?=p.label, kind~))
          }
        Message(m) => {
          add_implicit(m.sender)
          add_implicit(m.receiver)
          events.push(Message(@model.Message::new(m.sender, m.receiver, m.text)))
        }
        Frame(f) =>
          for section in f.sections {
            walk(section.statements)
          }
        Box(b) => walk(b.statements)
        _ => ()
      }
    }
  }

  walk(diagram.statements)
  { sequence: @model.Sequence::new(participants, events), diagnostics: [] }
}
