///|
test "a property update preserves the declared participant and input model" {
  let original = @sequence.Participant::new(
    "W",
    link=@sequence.Link::new(Smithy, "example.weather#Weather"),
  )
  let model = @sequence.Sequence::new([original], [])
  let properties = @sequence.ParticipantProperties::new(
    kind=Service,
    sublabel="Weather",
    description="API",
  )
  let changed = original.with_properties(properties)
  assert_eq(model.participants[0].properties, None)
  assert_eq(changed.kind, @sequence.ParticipantKind::Participant)
  assert_eq(changed.render_kind(), @sequence.ParticipantKind::Service)
  assert_eq(changed.link, original.link)
  let message = @sequence.Message::new("C", "W", "call")
  let decorated = message.with_properties(
    @sequence.MessageProperties::new(sublabel="GetForecastOutput"),
  )
  assert_eq(message.properties, None)
  assert_eq(decorated.label, "call")
  assert_eq(decorated.properties.unwrap().sublabel, Some("GetForecastOutput"))
}

///|
test "notes and nested frames copy every mutable input array" {
  let ids = ["B"]
  let note = @sequence.Note::new(Over, ids, "wait")
  ids[0] = "changed"
  let messages = [
    @sequence.Event::Message(@sequence.Message::new("A", "B", "one")),
  ]
  let loop_frame = @sequence.Frame::new(
    Loop,
    @sequence.Section::new(messages, label="retry"),
  )
  messages.clear()
  let rest = [@sequence.Section::new([Note(note)], label="missing")]
  let alt = @sequence.Frame::new(
    Alt,
    @sequence.Section::new([Frame(loop_frame)], label="found"),
    rest~,
  )
  rest.clear()
  assert_eq(note.participants.iter().to_array(), ["B"])
  assert_eq(alt.sections.length(), 2)
  assert_eq(alt.sections[0].label, Some("found"))
  assert_eq(alt.sections[0].events[0], @sequence.Event::Frame(loop_frame))
  assert_eq(loop_frame.sections[0].events.length(), 1)
  assert_eq(alt.sections[1].events[0], @sequence.Event::Note(note))
}

///|
test "the full model keeps ordered events, groups, metadata and message ends" {
  let group = @sequence.BoxGroup::new("backend", "Backend", colour="Purple")
  let a = @sequence.Participant::new("A", group~)
  let b = @sequence.Participant::new("B", kind=Database, group~)
  let message = @sequence.Message::new(
    "A",
    "B",
    "hello",
    line=Dotted,
    sender_head=Arrow,
    receiver_head=Arrow,
  )
  let note = @sequence.Note::new(Over, ["B"], "wait")
  let events = [
    @sequence.Event::Autonumber(On(start=Some(10.0), step=Some(2.0))),
    Create("B"),
    Message(message),
    Activate("B"),
    Note(note),
    Deactivate("B"),
    Message(@sequence.Message::new("B", "B", "self")),
    Destroy("B"),
    Autonumber(Off),
  ]
  let s = @sequence.Sequence::new(
    [a, b],
    events,
    title="Example",
    accessibility_title="Calls",
    accessibility_description="A calls B",
  )
  assert_eq(a.group, b.group)
  assert_eq(b.kind, @sequence.ParticipantKind::Database)
  assert_eq(s.events.iter().to_array(), events)
  assert_eq(s.title, Some("Example"))
  assert_eq(s.accessibility_title, Some("Calls"))
  assert_eq(s.accessibility_description, Some("A calls B"))
  assert_eq(
    (message.line, message.sender_head, message.receiver_head),
    (@sequence.LineStyle::Dotted, @sequence.Head::Arrow, @sequence.Head::Arrow),
  )
  assert_eq(message.link, None)
}

///|
struct TestSource {}

///|
impl @sequence.LinkSource for TestSource with fn participant(_, link) {
  if link.scheme == Smithy && link.target == "example.weather#Weather" {
    Some(@sequence.ParticipantProperties::new(kind=Service, sublabel="Weather"))
  } else {
    None
  }
}

///|
impl @sequence.LinkSource for TestSource with fn message(_, link) {
  if link.scheme == Smithy && link.target == "example.weather#GetForecast" {
    Some(@sequence.MessageProperties::new(sublabel="GetForecastOutput"))
  } else {
    None
  }
}

///|
test "resolution finds participant and nested message targets without structural changes" {
  let p = @sequence.Participant::new(
    "W",
    link=@sequence.Link::new(Smithy, "example.weather#Weather"),
  )
  let m = @sequence.Message::new(
    "W",
    "W",
    "example.weather/GetForecast",
    link=@sequence.Link::new(Smithy, "example.weather#GetForecast"),
    number=10.0,
  )
  let frame = @sequence.Frame::new(
    Loop,
    @sequence.Section::new([Message(m)], label="retry"),
  )
  let s = @sequence.Sequence::new([p], [Frame(frame)])
  let r = @sequence.resolve(s, TestSource::{ })
  assert_eq(r.diagnostics.length(), 0)
  assert_eq(s.participants[0].properties, None)
  assert_eq(
    r.sequence.participants[0],
    p.with_properties(
      @sequence.ParticipantProperties::new(kind=Service, sublabel="Weather"),
    ),
  )
  let expected = @sequence.Frame::new(
    Loop,
    @sequence.Section::new(
      [
        Message(
          m.with_properties(
            @sequence.MessageProperties::new(sublabel="GetForecastOutput"),
          ),
        ),
      ],
      label="retry",
    ),
  )
  assert_eq(r.sequence.events.iter().to_array(), [
    @sequence.Event::Frame(expected),
  ])
  assert_eq(s.events[0], @sequence.Event::Frame(frame))
}

///|
test "unresolved targets warn and preserve existing properties" {
  let p = @sequence.Participant::new(
    "W",
    link=@sequence.Link::new(Smithy, "example.weather#Missing"),
    properties=@sequence.ParticipantProperties::new(description="keep"),
  )
  let m = @sequence.Message::new(
    "W",
    "W",
    "missing",
    link=@sequence.Link::new(OpenRpc, "missing"),
  )
  let s = @sequence.Sequence::new([p], [Message(m)])
  let r = @sequence.resolve(s, TestSource::{ })
  assert_eq(r.sequence, s)
  assert_eq(r.diagnostics.length(), 2)
  assert_eq(r.diagnostics[0].code, "sequence/unresolved-link")
  assert_eq(r.diagnostics[0].severity, @diagrams.Severity::Warning)
  assert_true(r.diagnostics[0].message.contains("example.weather#Missing"))
  assert_true(r.diagnostics[1].message.contains("missing"))
}
