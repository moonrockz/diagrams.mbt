///|
fn model_of(source : String) -> @model.Sequence {
  @sequence.to_sequence(@ast.lower(@syntax.parse(source).tree).unwrap()).sequence
}

///|
test "an undeclared participant is added at its first use" {
  let s = model_of("sequenceDiagram\nparticipant A\nA->>B: hi\nC->>A: yo\n")
  assert_eq(s.participants.map(p => p.id).iter().to_array(), ["A", "B", "C"])
}

///|
test "an actor gets the actor kind and its label" {
  let s = model_of("sequenceDiagram\nactor C as Client\n")
  let c = s.participant("C").unwrap()
  assert_eq(c.kind, @model.ParticipantKind::Actor)
  assert_eq(c.label, "Client")
}

///|
test "the solid arrow becomes a solid message with a receiver arrowhead" {
  let s = model_of("sequenceDiagram\nA->>B: hello\n")
  assert_eq(s.events.length(), 1)
  assert_eq(
    s.events[0],
    @model.Event::Message(@model.Message::new("A", "B", "hello")),
  )
}
