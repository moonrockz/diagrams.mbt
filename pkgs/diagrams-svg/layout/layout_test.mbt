///|
fn two(label : String) -> @sequence.Sequence {
  @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [Message(@sequence.Message::new("A", "B", label))],
  )
}

///|
fn right(r : @layout.Rect) -> Int {
  r.x + r.width
}

///|
test "participants are boxes in declaration order, left to right, without overlap" {
  let g = @layout.layout(two("hello"))
  let a = g.participants[0]
  let b = g.participants[1]
  assert_eq((a.id, b.id), ("A", "B"))
  assert_true(right(a.box) < b.box.x)
  assert_true(a.box.x >= 0 && right(b.box) <= g.width)
}

///|
test "a box is wide enough for its label" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("x", label="A rather long participant label")],
    [],
  )
  let p = @layout.layout(s).participants[0]
  assert_true(p.label.box.width + 16 <= p.box.width)
}

///|
test "a long label makes a wider gap between lifelines" {
  let short = @layout.layout(two("hi"))
  let long = @layout.layout(two("x".repeat(60)))
  let gap = (g : @layout.Geometry) => g.participants[1].lifeline_x -
    g.participants[0].lifeline_x
  assert_true(gap(long) > gap(short))
  let m = long.messages[0]
  assert_true(m.chip.x > long.participants[0].lifeline_x)
  assert_true(right(m.chip) < long.participants[1].lifeline_x)
}

///|
test "a message is below the boxes and ends near both lifelines" {
  let g = @layout.layout(two("hello"))
  let m = g.messages[0]
  assert_true(m.chip.y > right_bottom(g.participants[0].box))
  assert_eq(m.x1, g.participants[0].lifeline_x + 7)
  assert_eq(m.x2, g.participants[1].lifeline_x - 7)
  assert_true(g.lifeline_bottom > m.y)
  assert_true(g.height > g.lifeline_bottom)
}

///|
fn right_bottom(r : @layout.Rect) -> Int {
  r.y + r.height
}

///|
test "plain participants get colours from the cycle, and a request uses its sender's colour" {
  let g = @layout.layout(two("hello"))
  assert_eq(g.participants.map(p => p.family).iter().to_array(), [
    @theme.Family::Frontend,
    @theme.Family::Backend,
  ])
  assert_eq(g.messages[0].family, @theme.Family::Frontend)
}

///|
test "the layout of a simple diagram passes the legibility check in both palettes" {
  let g = @layout.layout(two("GET /forecast"))
  let t = @theme.Theme::classic()
  assert_eq(@layout.check(g, t.dark), [])
  assert_eq(@layout.check(g, t.light), [])
}

///|
test "the check finds text that is too small" {
  let g = @layout.layout(two("hello"))
  let m = g.messages[0]
  let small = { ..m, label: { ..m.label, size: 7 } }
  let broken = { ..g, messages: [small] }
  let rules = @layout.check(broken, @theme.Theme::classic().dark).map(f => f.rule)
  assert_eq(rules, [Size])
}

///|
test "the check finds overlapping labels" {
  let g = @layout.layout(two("hello"))
  let a = g.participants[0]
  let moved = { ..a, label: { ..a.label, box: g.participants[1].label.box } }
  let broken = { ..g, participants: [moved, g.participants[1]] }
  let rules = @layout.check(broken, @theme.Theme::classic().dark).map(f => f.rule)
  assert_true(rules.contains(Overlap))
}

///|
test "the check finds a label that does not fit" {
  let g = @layout.layout(two("hello"))
  let m = g.messages[0]
  let narrow = { ..m, chip: { ..m.chip, width: 10 } }
  let broken = { ..g, messages: [narrow] }
  let rules = @layout.check(broken, @theme.Theme::classic().dark).map(f => f.rule)
  assert_true(rules.contains(Fit))
}

///|
test "the check finds text with low contrast" {
  let g = @layout.layout(two("hello"))
  let dark = @theme.Theme::classic().dark
  let flat = { ..dark, text: dark.mask, frontend: { ..dark.frontend, ink: dark.mask } }
  let rules = @layout.check(g, flat).map(f => f.rule)
  assert_eq(rules.filter(r => r == Contrast).length(), 3)
}

///|
test "messages inside nested frames remain in diagram order" {
  let s = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [
      Activate("A"),
      Frame(@sequence.Frame::new(Alt, @sequence.Section::new([
        Message(@sequence.Message::new("A", "B", "one")),
        Frame(@sequence.Frame::new(Loop, @sequence.Section::new([
          Message(@sequence.Message::new("B", "A", "two")),
        ]))),
      ]))),
      Deactivate("A"),
    ],
  )
  assert_eq(@layout.layout(s).messages.map(m => m.label.content).iter().to_array(), ["one", "two"])
}
