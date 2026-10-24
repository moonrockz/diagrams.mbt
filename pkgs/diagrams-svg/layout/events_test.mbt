///|
fn model(events : ArrayView[@sequence.Event]) -> @sequence.Sequence {
  @sequence.Sequence::new([
    @sequence.Participant::new("A"), @sequence.Participant::new("B"),
    @sequence.Participant::new("C"), @sequence.Participant::new("D"),
  ], events)
}

///|
fn clean(g : @layout.Geometry) -> Unit raise {
  let theme = @theme.Theme::classic()
  for palette in [theme.dark, theme.light] {
    let findings = @layout.check(g, palette)
    assert_eq(findings, [], msg=findings.map(f => f.message).join("; "))
  }
}

///|
test "cross-gap width deficits are shared equally and lifelines do not block labels" {
  let plain = @layout.layout(model([Message(@sequence.Message::new("A", "D", "hi"))]))
  let wide = @layout.layout(model([Message(@sequence.Message::new("A", "D", "x".repeat(160)))]))
  let deltas = Array::makei(3, i => (wide.participants[i + 1].lifeline_x - wide.participants[i].lifeline_x) - (plain.participants[i + 1].lifeline_x - plain.participants[i].lifeline_x))
  assert_true(deltas[0] > 0)
  assert_true((deltas[0] - deltas[1]).abs() <= 1 && (deltas[1] - deltas[2]).abs() <= 1)
  let m = wide.messages[0]
  assert_true(m.chip.width > wide.participants[1].lifeline_x - wide.participants[0].lifeline_x)
  clean(wide)
}

///|
test "rows keep 28px message spacing and measure each line of text" {
  let g = @layout.layout(model([
    Message(@sequence.Message::new("A", "B", "one<br/>two<br>three")),
    Message(@sequence.Message::new("B", "A", "four")),
  ]))
  assert_eq(g.messages[0].label.content, "one\ntwo\nthree")
  assert_eq(g.messages[0].label.box.height, 45)
  assert_true(g.messages[0].chip.height >= g.messages[0].label.box.height + 8)
  assert_true(g.messages[1].y - g.messages[0].y >= 28)
  assert_true(g.messages[1].chip.y > g.messages[0].y)
  clean(g)
}

///|
test "a self-message is a three-segment loop that reserves its own width and row" {
  let g = @layout.layout(model([
    Message(@sequence.Message::new("A", "A", "a long self-message".repeat(4))),
    Message(@sequence.Message::new("A", "B", "next")),
  ]))
  let m = g.messages[0]
  assert_eq(m.path.length(), 3)
  let a = g.participants[0].lifeline_x
  assert_eq(m.path[0].x1, a + 7)
  assert_eq(m.path[2].x2, a + 7)
  assert_eq(m.path[1].x1, m.path[1].x2)
  assert_eq(m.path[0].y1, m.path[0].y2)
  assert_eq(m.path[2].y1, m.path[2].y2)
  assert_true(m.path[2].y2 > m.path[0].y1)
  assert_true(m.path[1].x1 < g.participants[1].lifeline_x)
  assert_true(m.chip.x > a)
  assert_true(m.chip.x + m.chip.width < m.path[1].x1)
  assert_true(g.messages[1].chip.y > m.path[2].y2)
  clean(g)
}

///|
test "notes reserve side lanes and over notes span all anchors with multiline height" {
  let g = @layout.layout(model([
    Note(@sequence.Note::new(LeftOf, ["A"], "left".repeat(30))),
    Note(@sequence.Note::new(RightOf, ["D"], "right".repeat(30))),
    Note(@sequence.Note::new(Over, ["A", "D"], "first<br/>second")),
  ]))
  assert_eq(g.notes.length(), 3)
  assert_true(g.notes[0].box.x >= 0)
  assert_true(g.notes[0].box.x + g.notes[0].box.width < g.participants[0].lifeline_x)
  assert_true(g.notes[1].box.x > g.participants[3].lifeline_x)
  assert_true(g.notes[1].box.x + g.notes[1].box.width < g.width)
  assert_true(g.notes[2].box.x < g.participants[0].lifeline_x)
  assert_true(g.notes[2].box.x + g.notes[2].box.width > g.participants[3].lifeline_x)
  assert_eq(g.notes[2].label.box.height, 30)
  assert_true(g.notes[2].box.y > g.notes[1].box.y + g.notes[1].box.height)
  clean(g)
}

///|
test "nested activations have 10px bars offset by 4px and labels avoid them" {
  let g = @layout.layout(model([
    Activate("B"), Activate("B"), Activate("C"),
    Message(@sequence.Message::new("A", "D", "long cross-participant call".repeat(8))),
    Note(@sequence.Note::new(Over, ["B"], "still active")),
    Message(@sequence.Message::new("B", "B", "self")),
    Deactivate("B"), Deactivate("C"), Deactivate("B"),
  ]))
  let bars = g.activations.iter().filter(b => b.participant == "B").to_array()
  assert_eq(bars.length(), 2)
  let inner = bars[0]
  let outer = bars[1]
  assert_eq((inner.depth, outer.depth), (1, 0))
  assert_eq((inner.box.width, outer.box.width), (10, 10))
  assert_eq(inner.box.x - outer.box.x, 4)
  assert_true(inner.box.y >= outer.box.y)
  assert_true(inner.box.y + inner.box.height <= outer.box.y + outer.box.height)
  assert_true(g.notes[0].label.box.x > inner.box.x + inner.box.width)
  clean(g)
}

///|
test "nested frames enclose sections and have separate header and divider rows" {
  let inner = @sequence.Frame::new(Loop, @sequence.Section::new([Message(@sequence.Message::new("A", "B", "inside"))], label="retry"))
  let outer = @sequence.Frame::new(Alt, @sequence.Section::new([Frame(inner)], label="found"), rest=[@sequence.Section::new([Message(@sequence.Message::new("B", "A", "missing"))], label="missing")])
  let g = @layout.layout(model([Frame(outer)]))
  assert_eq(g.frames.length(), 2)
  let a = g.frames[0]
  let b = g.frames[1]
  assert_eq((a.parent, b.parent), (None, Some(0)))
  assert_eq(a.header.unwrap().content, "alt found")
  assert_eq(b.header.unwrap().content, "loop retry")
  assert_true(a.box.x < b.box.x && a.box.y < b.box.y)
  assert_true(a.box.x + a.box.width > b.box.x + b.box.width)
  assert_true(a.box.y + a.box.height > b.box.y + b.box.height)
  let second = a.sections[1]
  assert_eq(second.label.unwrap().content, "missing")
  assert_true(second.divider.unwrap().y1 > g.messages[0].y)
  assert_true(second.divider.unwrap().y1 < second.label.unwrap().box.y)
  assert_true(g.messages[1].chip.y > second.label.unwrap().box.y + second.label.unwrap().box.height)
  clean(g)
}

///|
test "each frame kind and long section headers remain inside their frames" {
  for kind in [@sequence.FrameKind::Loop, Alt, Opt, Par, ParOver, Critical, Break, Rect] {
    let g = @layout.layout(model([Frame(@sequence.Frame::new(kind, @sequence.Section::new([], label="very long frame header ".repeat(20)), colour="rgb(191, 223, 255)"))]))
    assert_eq(g.frames[0].kind, kind)
    assert_eq(g.frames[0].colour, Some("rgb(191, 223, 255)"))
    if kind == Rect { assert_eq(g.frames[0].header, None) }
    clean(g)
  }
}

///|
test "creation puts the participant box on its message and destruction ends its lifetime" {
  let g = @layout.layout(model([
    Message(@sequence.Message::new("A", "C", "before")),
    Create("B"), Message(@sequence.Message::new("A", "B", "create")),
    Activate("B"), Message(@sequence.Message::new("B", "A", "done")), Destroy("B"),
    Message(@sequence.Message::new("A", "D", "after")),
  ]))
  let p = g.participants[1]
  assert_true(p.box.y > g.messages[0].y)
  assert_eq(p.box.y + p.box.height / 2, g.messages[1].y)
  assert_eq(g.messages[1].path[0].x2, p.box.x)
  assert_eq(p.lifeline_top, p.box.y + p.box.height)
  assert_eq(p.lifeline_bottom, g.messages[2].y)
  assert_true(p.destroyed)
  assert_true(p.lifeline_bottom < g.messages[3].y)
  assert_eq(g.activations[0].box.y + g.activations[0].box.height, p.lifeline_bottom)
  clean(g)
}

///|
test "groups cover their members and labels without changing declaration order" {
  let group = @sequence.BoxGroup::new("backend", "Backend", colour="Purple")
  let s = @sequence.Sequence::new([
    @sequence.Participant::new("A"),
    @sequence.Participant::new("B", group~),
    @sequence.Participant::new("C", group~),
  ], [Create("C"), Message(@sequence.Message::new("A", "C", "create")), Message(@sequence.Message::new("C", "B", "inside"))])
  let g = @layout.layout(s)
  assert_eq(g.participants.map(p => p.id).iter().to_array(), ["A", "B", "C"])
  assert_eq(g.groups[0].group, group)
  assert_true(g.groups[0].box.x < g.participants[1].box.x)
  assert_true(g.groups[0].box.x > g.participants[0].box.x + g.participants[0].box.width)
  assert_true(g.groups[0].box.x + g.groups[0].box.width > g.participants[2].box.x + g.participants[2].box.width)
  assert_true(g.groups[0].box.y + g.groups[0].box.height > g.participants[2].lifeline_bottom)
  clean(g)
}

///|
test "title render labels and numbering are measured before columns and rows" {
  let p = @sequence.Participant::new("A", properties=@sequence.ParticipantProperties::new(kind=Service, sublabel="a very long version ".repeat(8)))
  let m = @sequence.Message::new("A", "B", "example.weather/City$name", link=@sequence.Link::new(Smithy, "example.weather#City$name"), number=15.0, properties=@sequence.MessageProperties::new(sublabel="a very long output type ".repeat(8)))
  let s = @sequence.Sequence::new([p, @sequence.Participant::new("B")], [Message(m)], title="Long title ".repeat(40))
  let g = @layout.layout(s)
  assert_eq(g.title.unwrap().content, s.title.unwrap())
  assert_eq(g.messages[0].label.content, "15 City$name")
  assert_eq(g.messages[0].sublabel.unwrap().content, m.properties.unwrap().sublabel.unwrap())
  assert_eq(g.participants[0].family, @theme.Family::Backend)
  assert_true(g.participants[0].box.width > 96)
  assert_true(g.messages[0].chip.width > g.messages[0].label.box.width)
  clean(g)
}


///|
test "long frame and section labels avoid activations spanning the whole frame" {
  let f = @sequence.Frame::new(Alt, @sequence.Section::new([
    Message(@sequence.Message::new("A", "B", "one")),
  ], label="long condition ".repeat(12)), rest=[@sequence.Section::new([
    Message(@sequence.Message::new("B", "A", "two")),
  ], label="long alternative ".repeat(12))])
  let g = @layout.layout(model([Activate("A"), Activate("B"), Frame(f), Deactivate("A"), Deactivate("B")]))
  assert_true(g.frames[0].header.unwrap().box.x + g.frames[0].header.unwrap().box.width < g.activations[0].box.x)
  clean(g)
}

///|
test "empty diagrams standalone creations and open activations have bounded geometry" {
  clean(@layout.layout(@sequence.Sequence::new([], [])))
  let g = @layout.layout(model([
    Create("B"), Note(@sequence.Note::new(Over, ["A"], "no creating message")),
    Activate("A"), Message(@sequence.Message::new("A", "D", "open activation")),
  ]))
  assert_true(g.participants[1].box.y < g.notes[0].box.y)
  assert_eq(g.activations[0].box.y + g.activations[0].box.height, g.lifeline_bottom)
  clean(g)
}


///|
test "long group titles remain legible when first-use order interleaves groups" {
  let g1 = @sequence.BoxGroup::new("one", "first group ".repeat(20))
  let g2 = @sequence.BoxGroup::new("two", "second group ".repeat(20))
  let s = @sequence.Sequence::new([
    @sequence.Participant::new("A", group=g1), @sequence.Participant::new("B", group=g2),
    @sequence.Participant::new("C", group=g1), @sequence.Participant::new("D", group=g2),
  ], [Message(@sequence.Message::new("A", "D", "across groups"))])
  let g = @layout.layout(s)
  assert_eq(g.groups.length(), 2)
  assert_eq(g.participants.map(p => p.id).iter().to_array(), ["A", "B", "C", "D"])
  clean(g)
}


///|
test "all state changes after a message share its row until another visual event" {
  let g = @layout.layout(model([
    Activate("B"), Activate("C"),
    Message(@sequence.Message::new("B", "A", "done")), Deactivate("B"),
    Destroy("B"), Destroy("C"), Note(@sequence.Note::new(Over, ["A"], "later")),
  ]))
  assert_eq(g.participants[1].lifeline_bottom, g.messages[0].y)
  assert_eq(g.participants[2].lifeline_bottom, g.messages[0].y)
  for bar in g.activations { assert_eq(bar.box.y + bar.box.height, g.messages[0].y) }
  assert_true(g.notes[0].box.y > g.messages[0].y)
  clean(g)
}


///|
test "a note ends the association with the preceding message row" {
  let g = @layout.layout(model([
    Message(@sequence.Message::new("A", "B", "before")),
    Note(@sequence.Note::new(Over, ["A"], "separate event")), Activate("B"),
    Message(@sequence.Message::new("B", "A", "after")), Deactivate("B"),
  ]))
  assert_true(g.activations[0].box.y >= g.notes[0].box.y + g.notes[0].box.height)
  assert_eq(g.activations[0].box.y + g.activations[0].box.height, g.messages[1].y)
  clean(g)
}
