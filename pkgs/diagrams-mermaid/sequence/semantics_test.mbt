///|
fn converted(body : String) -> @sequence.Conversion raise {
  let parsed = @syntax.parse("sequenceDiagram\n" + body + "\n")
  assert_eq(parsed.diagnostics.length(), 0)
  @sequence.to_sequence(@ast.lower(parsed.tree).unwrap())
}

///|
test "conversion retains frames, sections, note order and implicit participants" {
  let r = converted("participant C\nC->>A: one\nnote over A,B: wait\nalt found\nloop retry\nB->>C: two\nend\nelse missing\nC->>B: three\nend")
  assert_eq(r.diagnostics.length(), 0)
  assert_eq(r.sequence.participants.map(p => p.id).iter().to_array(), ["C", "A", "B"])
  assert_eq(r.sequence.events[1], @model.Event::Note(@model.Note::new(Over, ["A", "B"], "wait")))
  guard r.sequence.events[2] is Frame(alt) else { fail("alt") }
  assert_eq(alt.kind, @model.FrameKind::Alt)
  assert_eq(alt.sections.map(s => s.label).iter().to_array(), [Some("found"), Some("missing")])
  guard alt.sections[0].events[0] is Frame(loop_frame) else { fail("loop_frame") }
  assert_eq(loop_frame.kind, @model.FrameKind::Loop)
  assert_eq(loop_frame.sections[0].events[0], @model.Event::Message(@model.Message::new("B", "C", "two")))
  assert_eq(alt.sections[1].events[0], @model.Event::Message(@model.Message::new("C", "B", "three")))
}

///|
test "every frame kind, rectangle colour and note placement is retained" {
  for (keyword, expected) in [("loop", @model.FrameKind::Loop), ("alt", Alt), ("opt", Opt), ("par", Par), ("par_over", ParOver), ("critical", Critical), ("break", Break), ("rect", Rect)] {
    let r = converted("\{keyword} rgb(1, 2, 3)\nA->>B: hi\nend")
    guard r.sequence.events[0] is Frame(f) else { fail(keyword) }
    assert_eq(f.kind, expected)
    assert_eq(f.sections.length(), 1)
    if keyword == "rect" { assert_eq(f.colour, Some("rgb(1, 2, 3)")); assert_eq(f.sections[0].label, None) }
  }
  let s = converted("note left of A: left\nnote right of A: right\nnote over A: over").sequence
  assert_eq(s.events.iter().to_array(), [
    @model.Event::Note(@model.Note::new(LeftOf, ["A"], "left")),
    Note(@model.Note::new(RightOf, ["A"], "right")),
    Note(@model.Note::new(Over, ["A"], "over")),
  ])
}

///|
test "participant metadata maps every kind and keeps boxes distinct" {
  for (name, kind) in [("participant", @model.ParticipantKind::Participant), ("actor", Actor), ("boundary", Boundary), ("control", Control), ("entity", Entity), ("database", Database), ("collections", Collections), ("queue", Queue), ("service", Service), ("resource", Resource), ("client", Client)] {
    let r = converted("participant A@{ \"type\": \"\{name}\", \"alias\": \"Store\" }")
    assert_eq(r.diagnostics.length(), 0)
    assert_eq(r.sequence.participants[0].kind, kind)
    assert_eq(r.sequence.participants[0].label, "Store")
  }
  let r = converted("box Purple Backend\nparticipant A\nparticipant B\nend\nbox Backend\nactor C\nend\nbox Backend\nparticipant D\nend")
  assert_eq(r.diagnostics.length(), 0)
  let parts = r.sequence.participants
  assert_eq(parts[0].group, parts[1].group)
  assert_eq(parts[0].group.unwrap().label, "Backend")
  assert_eq(parts[0].group.unwrap().colour, Some("Purple"))
  assert_eq(parts[2].group.unwrap().colour, None)
  assert_true(parts[2].group != parts[3].group)
  let yaml = converted("participant A@{ type: database, alias: 'Store, it''s here' }\nparticipant B@{type: queue, alias: Q} as Explicit")
  assert_eq(yaml.diagnostics.length(), 0)
  assert_eq(yaml.sequence.participants[0].label, "Store, it's here")
  assert_eq(yaml.sequence.participants[1].label, "Explicit")
}

///|
test "shorthand activations apply after messages and support nesting" {
  let r = converted("A->>+B: call\nactivate B\nB-->>-A: inner done\nB-->>-A: done")
  assert_eq(r.diagnostics.length(), 0)
  assert_eq(r.sequence.events.iter().to_array(), [
    @model.Event::Message(@model.Message::new("A", "B", "call")),
    Activate("B"), Activate("B"),
    Message(@model.Message::new("B", "A", "inner done", line=Dotted)), Deactivate("B"),
    Message(@model.Message::new("B", "A", "done", line=Dotted)), Deactivate("B"),
  ])
}

///|
test "creation precedes its message and destruction follows its destroying message" {
  let r = converted("participant A\ncreate participant B as Worker\nA->>B: start\ndestroy B\nB-xA: stop")
  assert_eq(r.diagnostics.length(), 0)
  assert_eq(r.sequence.events.iter().to_array(), [
    @model.Event::Create("B"), Message(@model.Message::new("A", "B", "start")),
    Message(@model.Message::new("B", "A", "stop", receiver_head=Cross)), Destroy("B"),
  ])
  let incoming = converted("destroy B\nA-xB: stop")
  assert_eq(incoming.diagnostics.length(), 0)
  assert_eq(incoming.sequence.events[1], @model.Event::Destroy("B"))
}

///|
test "semantic diagnostics use the offending statement's UTF-16 span" {
  let r = converted("A->>B: 😀\ndeactivate B\ndestroy B\nA-xB: stop\nA->>B: again\nparticipant A\nactor A")
  assert_eq(r.diagnostics.map(d => d.code).iter().to_array(), ["mermaid/inactive-deactivation", "mermaid/destroyed-participant", "mermaid/conflicting-participant-kind"])
  assert_eq(r.diagnostics.map(d => d.span.unwrap().start.line).iter().to_array(), [3, 6, 8])
  assert_eq(r.diagnostics[0].span.unwrap().start.column, 1)
  assert_eq(r.diagnostics[0].span.unwrap().start.offset, 26)
  assert_eq(r.sequence.participant("A").unwrap().kind, @model.ParticipantKind::Participant)
  let more = converted("participant A@{type: invalid}\nlinks A: not-json\ndestroy A")
  assert_eq(more.diagnostics.map(d => d.code).iter().to_array(), ["mermaid/invalid-participant-config", "mermaid/invalid-links", "mermaid/missing-destroying-message"])
  let repeated = converted("participant A\ncreate actor A\nbox One\nparticipant B\nend\nbox Two\nparticipant B\nend")
  assert_eq(repeated.diagnostics.map(d => d.code).iter().to_array(), ["mermaid/conflicting-participant-kind", "mermaid/duplicate-creation", "mermaid/conflicting-box-group"])
}

///|
test "title accessibility and repeated autonumber settings retain state and events" {
  let r = converted("title Calls\naccTitle: Accessible\naccDescr {\nLong\ndescription\n}\nautonumber 10 2\nA->>B: one\nautonumber off\nA->>B: hidden\nautonumber\nA->>B: resumed\nautonumber 5 0.5\nB->>B: reset")
  assert_eq(r.diagnostics.length(), 0)
  let s = r.sequence
  assert_eq(s.title, Some("Calls"))
  assert_eq(s.accessibility_title, Some("Accessible"))
  assert_eq(s.accessibility_description, Some("Long\ndescription"))
  let numbers = s.events.iter().filter_map(e => match e { Message(m) => Some(m.number); _ => None }).to_array()
  assert_eq(numbers, [Some(10.0), None, Some(14.0), Some(5.0)])
  assert_eq(s.events[0], @model.Event::Autonumber(On(start=Some(10.0), step=Some(2.0))))
  assert_eq(s.events[2], @model.Event::Autonumber(Off))
  assert_eq(s.events[4], @model.Event::Autonumber(On(start=None, step=None)))
}

///|
test "each arrow form has independent line and head values" {
  let cases : Array[(String, @model.Head, @model.Head)] = [
    ("->>", NoHead, Arrow), ("<<->>", Arrow, Arrow), ("->", NoHead, OpenArrow), ("-x", NoHead, Cross), ("-)", NoHead, Async),
    ("-|\\", NoHead, HalfArrow(upper=true, filled=true)), ("-|/", NoHead, HalfArrow(upper=false, filled=true)),
    ("-\\\\", NoHead, HalfArrow(upper=true, filled=false)), ("-//", NoHead, HalfArrow(upper=false, filled=false)),
    ("/|-", HalfArrow(upper=true, filled=true), NoHead), ("\\|-", HalfArrow(upper=false, filled=true), NoHead),
    ("//-", HalfArrow(upper=true, filled=false), NoHead), ("\\\\-", HalfArrow(upper=false, filled=false), NoHead),
  ]
  for (arrow, sender, receiver) in cases {
    for dotted in [false, true] {
      let arrow = if dotted { arrow.replace_all(old="-", new="--") } else { arrow }
      let r = converted("A\{arrow}B: hello")
      assert_eq(r.diagnostics.length(), 0)
      guard r.sequence.events[0] is Message(m) else { fail(arrow) }
      assert_eq((m.line, m.sender_head, m.receiver_head), (if dotted { @model.LineStyle::Dotted } else { Solid }, sender, receiver), msg=arrow)
    }
  }
  guard converted("A()->>()B: center").sequence.events[0] is Message(m) else { fail("central") }
  assert_eq((m.sender_head, m.receiver_head), (@model.Head::Central(NoHead), @model.Head::Central(Arrow)))
}

///|
test "links and links JSON recognize known schemes and preserve source labels" {
  let r = converted("participant W\nlink W: shape @ smithy:example.weather/Weather\nlinks R: {\"docs\":\"https://example.com\",\"rpc\":\"openrpc:weather.get\"}\nC->>W: example.weather/GetForecast\nC->>W: read/write\nC->>W: example.weather#GetForecast\nlink Web: docs @ https://example.com/w")
  assert_eq(r.diagnostics.length(), 0)
  assert_eq(r.sequence.participant("W").unwrap().link, Some(@model.Link::new(Smithy, "example.weather#Weather")))
  assert_eq(r.sequence.participant("R").unwrap().link, Some(@model.Link::new(OpenRpc, "weather.get")))
  assert_eq(r.sequence.participant("Web").unwrap().link, None)
  let messages = r.sequence.events.iter().filter_map(e => match e { Message(m) => Some(m); _ => None }).to_array()
  assert_eq(messages[0].link, Some(@model.Link::new(Smithy, "example.weather#GetForecast")))
  assert_eq(messages[0].label, "example.weather/GetForecast")
  assert_eq(messages[1].link, None)
  assert_eq(messages[1].label, "read/write")
  assert_eq(messages[2].link, None)
  assert_eq(messages[2].label, "example.weather")
}

///|
test "shape ID labels require qualified ASCII identifiers and at most one member" {
  for label in ["example.weather/GetForecast", "_a.b2/Shape_1$member2", "a.b/_1", "_1.__2/__3$__4", "a.b/C"] {
    guard converted("A->>B: \{label}").sequence.events[0] is Message(m) else { fail(label) }
    assert_true(m.link is Some(_), msg=label)
  }
  for label in ["read/write", "a..b/C", ".a/C", "a.b./C", "a.b/", "a.b/1C", "1a.b/C", "a.b/C$", "a.b/C$m$n", "a.b/C/D", "a.b/C$2m", "a.b/é", "a.b/C extra", "a.b/_", "_.b/C", "a.b/C$__", "prefix a.b/C", "a-b.c/D"] {
    guard converted("A->>B: \{label}").sequence.events[0] is Message(m) else { fail(label) }
    assert_eq(m.link, None, msg=label)
    assert_eq(m.label, label)
  }
  let p = converted("link W: shape @ smithy:weather/Weather").sequence.participant("W").unwrap()
  assert_eq(p.link.unwrap().target, "weather#Weather")
}


///|
test "box parsing separates colours and titles without consuming plain labels" {
  let r = converted("box Purple\tBackend\nparticipant A\nend\nbox rgb(1, 2, 3) Backend\nparticipant B\nend\nbox Backend()\nparticipant C\nend")
  assert_eq(r.diagnostics.length(), 0)
  let parts = r.sequence.participants
  assert_eq((parts[0].group.unwrap().label, parts[0].group.unwrap().colour), ("Backend", Some("Purple")))
  assert_eq((parts[1].group.unwrap().label, parts[1].group.unwrap().colour), ("Backend", Some("rgb(1, 2, 3)")))
  assert_eq((parts[2].group.unwrap().label, parts[2].group.unwrap().colour), ("Backend()", None))
}

///|
test "semantic errors recover after a wrong destroying message and destroyed self use" {
  let r = converted("destroy B\nA->>C: wrong target\nB->>B: after death\nnote over B: after death\nactivate B")
  assert_eq(r.diagnostics.map(d => d.code).iter().to_array(), [
    "mermaid/missing-destroying-message", "mermaid/destroyed-participant",
    "mermaid/destroyed-participant", "mermaid/destroyed-participant",
  ])
  assert_eq(r.diagnostics.map(d => d.span.unwrap().start.line).iter().to_array(), [2, 4, 5, 6])
  guard r.sequence.events[2] is Message(m) else { fail("self message") }
  assert_eq((m.sender, m.receiver), ("B", "B"))
}
