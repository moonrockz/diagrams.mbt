///|
test "participants keep their declaration order" {
  let s = @sequence.Sequence::new(
    [
      @sequence.Participant::new("C"),
      @sequence.Participant::new("A"),
      @sequence.Participant::new("B"),
    ],
    [],
  )
  assert_eq(s.participants.map(p => p.id).iter().to_array(), ["C", "A", "B"])
}

///|
test "a participant label defaults to its id and its kind to participant" {
  let p = @sequence.Participant::new("API")
  assert_eq(p.label, "API")
  assert_eq(p.kind, @sequence.ParticipantKind::Participant)
  let q = @sequence.Participant::new(
    "db",
    label="Store",
    kind=@sequence.ParticipantKind::Database,
  )
  assert_eq(q.label, "Store")
  assert_eq(q.kind, @sequence.ParticipantKind::Database)
}

///|
test "a solid arrow has a filled head at the receiver end only" {
  let m = @sequence.Message::new("A", "B", "hi")
  assert_eq(m.line, @sequence.LineStyle::Solid)
  assert_eq(m.sender_head, @sequence.Head::NoHead)
  assert_eq(m.receiver_head, @sequence.Head::Arrow)
  assert_eq(m.label, "hi")
}

///|
test "events keep their diagram order" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [
      @sequence.Event::Message(@sequence.Message::new("A", "B", "one")),
      @sequence.Event::Message(@sequence.Message::new("B", "A", "two")),
    ],
  )
  let labels = s.events
    .map(e => {
      match e {
        Message(m) => m.label
        _ => ""
      }
    })
    .iter()
    .to_array()
  assert_eq(labels, ["one", "two"])
}

///|
test "the model does not change when the caller changes its input array" {
  let parts = [@sequence.Participant::new("A")]
  let s = @sequence.Sequence::new(parts, [])
  parts.push(@sequence.Participant::new("B"))
  assert_eq(s.participants.length(), 1)
}

///|
test "a participant is found by its id" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [],
  )
  assert_eq(s.participant("B").map(p => p.id), Some("B"))
  assert_eq(s.participant("Z"), None)
}
