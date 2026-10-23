///|
/// The sequence model of a Mermaid AST and the conversion diagnostics.
pub struct Conversion {
  sequence : @model.Sequence
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert a Mermaid AST to the sequence model. A participant that is not
/// declared is added at its first use, as Mermaid does.
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

  for statement in diagram.statements {
    match statement {
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
    }
  }
  { sequence: @model.Sequence::new(participants, events), diagnostics: [] }
}
