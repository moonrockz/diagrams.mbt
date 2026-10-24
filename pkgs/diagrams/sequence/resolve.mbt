///|
/// A pure adapter for a source such as a Smithy model. Implementations return
/// only render properties. `resolve` keeps all diagram structure and links.
pub(open) trait LinkSource {
  participant(Self, Link) -> ParticipantProperties?
  message(Self, Link) -> MessageProperties?
}

///|
/// A resolved model and warnings for targets absent from the source.
pub struct Resolution {
  sequence : Sequence
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Resolve links without changing the input or allowing the source to replace
/// participants, events, labels, numbering or links. Existing properties remain
/// when a source does not know a target.
pub fn[S : LinkSource] resolve(sequence : Sequence, source : S) -> Resolution {
  let diagnostics = []
  fn missing(link : Link) {
    diagnostics.push(@diagrams.Diagnostic::warning(
      "sequence/unresolved-link", "No source item for \{link.target}",
    ))
  }
  let participants = sequence.participants.map(p => {
    match p.link {
      Some(link) => match source.participant(link) {
        Some(properties) => p.with_properties(properties)
        None => { missing(link); p }
      }
      None => p
    }
  })
  fn events(items : ReadOnlyArray[Event]) -> ReadOnlyArray[Event] {
    items.map(e => match e {
      Message(m) => match m.link {
        Some(link) => match source.message(link) {
          Some(properties) => Message(m.with_properties(properties))
          None => { missing(link); e }
        }
        None => e
      }
      Frame(f) => Frame({ ..f, sections: f.sections.map(s => { ..s, events: events(s.events) }) })
      _ => e
    })
  }
  let resolved = { ..sequence, participants, events: events(sequence.events) }
  { sequence: resolved, diagnostics: ReadOnlyArray::from_array(diagnostics) }
}
