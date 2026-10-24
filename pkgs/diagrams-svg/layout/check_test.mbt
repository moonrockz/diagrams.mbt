///|
fn rules(g : @layout.Geometry) -> Array[@layout.Rule] {
  @layout.check(g, @theme.Theme::classic().dark).map(f => f.rule)
}

///|
fn checked_model() -> @layout.Geometry {
  @layout.layout(@sequence.Sequence::new([
    @sequence.Participant::new("A"), @sequence.Participant::new("B"),
  ], [Frame(@sequence.Frame::new(Alt, @sequence.Section::new([
    Activate("B"), Note(@sequence.Note::new(RightOf, ["B"], "note")),
    Message(@sequence.Message::new("A", "B", "call")), Deactivate("B"),
  ], label="first"), rest=[@sequence.Section::new([
    Message(@sequence.Message::new("B", "A", "reply")),
  ], label="second")]))]))
}

///|
test "fit checks both dimensions containment and measured content" {
  let g = checked_model()
  let note = g.notes[0]
  let too_short = { ..g, notes: [{ ..note, box: { ..note.box, height: 4 } }] }
  assert_true(rules(too_short).contains(Fit))
  let shifted = { ..g, notes: [{ ..note, label: { ..note.label, box: { ..note.label.box, x: note.box.x - 1 } } }] }
  assert_true(rules(shifted).contains(Fit))
  let false_measurement = { ..g, notes: [{ ..note, label: { ..note.label, content: "much longer than the measured box" } }] }
  assert_true(rules(false_measurement).contains(Fit))
  let off_canvas = { ..g, width: 1 }
  assert_true(rules(off_canvas).contains(Fit))
  let missing = { ..g, frames: [{ ..g.frames[0], chip: None }] }
  assert_true(rules(missing).contains(Fit))
}

///|
test "all text types participate in size and contrast checks" {
  let g = checked_model()
  let note = g.notes[0]
  assert_true(rules({ ..g, notes: [{ ..note, label: { ..note.label, size: 7 } }] }).contains(Size))
  let f = g.frames[0]
  let header = f.header.unwrap()
  assert_true(rules({ ..g, frames: [{ ..f, header: Some({ ..header, size: 7 }) }] }).contains(Size))
  let section = f.sections[1]
  let label = section.label.unwrap()
  let changed = { ..section, label: Some({ ..label, size: 7 }) }
  assert_true(rules({ ..g, frames: [{ ..f, sections: [f.sections[0], changed] }] }).contains(Size))
}

///|
test "labels are checked against activation bars frame borders and section dividers" {
  let g = checked_model()
  let m = g.messages[0]
  let bar = g.activations[0]
  let moved_bar = { ..bar, box: { ..bar.box, x: m.label.box.x, y: m.label.box.y, height: m.label.box.height } }
  assert_true(rules({ ..g, activations: [moved_bar] }).contains(Overlap))
  let f = g.frames[0]
  let moved_border = { ..f, box: { ..f.box, x: m.label.box.x + 2 } }
  assert_true(rules({ ..g, frames: [moved_border] }).contains(Overlap))
  let second = f.sections[1]
  let divider = second.divider.unwrap()
  let moved_divider = { ..divider, y1: m.label.box.y + 2, y2: m.label.box.y + 2 }
  assert_true(rules({ ..g, frames: [{ ..f, sections: [f.sections[0], { ..second, divider: Some(moved_divider) }] }] }).contains(Overlap))
}

///|
test "vertical and reversed message path segments block foreign labels" {
  let g = checked_model()
  let m = g.messages[0]
  let other = g.messages[1]
  let label = g.notes[0].label
  let vertical : @layout.Segment = { x1: label.box.x + 2, x2: label.box.x + 2, y1: label.box.y + label.box.height, y2: label.box.y, owner: "message:1" }
  let broken = { ..g, messages: [m, { ..other, path: [vertical] }] }
  assert_true(rules(broken).contains(Overlap))
  let horizontal = { ..vertical, x1: label.box.x + label.box.width, x2: label.box.x, y1: label.box.y + 2, y2: label.box.y + 2 }
  assert_true(rules({ ..g, messages: [m, { ..other, path: [horizontal] }] }).contains(Overlap))
}

///|
test "text alpha and all background layers compose before contrast measurement" {
  let g = @layout.layout(@sequence.Sequence::new([
    @sequence.Participant::new("A"), @sequence.Participant::new("B"),
  ], [Message(@sequence.Message::new("A", "B", "label"))]))
  let m = g.messages[0]
  let white = @theme.Color::hex(0xffffff)
  let palette = { ..@theme.Theme::classic().dark, mask: white, text: @theme.Color::hex(0x000000) }
  let pale = { ..m.label, ink: @layout.Ink::Color(white), backdrop: [Mask, Tint(@theme.Color::rgba(0, 0, 0, 50))] }
  let result = @layout.check({ ..g, messages: [{ ..m, label: pale }] }, palette)
  assert_eq(result.map(f => f.rule), [@layout.Rule::Contrast])
  assert_true(result[0].message.contains("3.95:1"))
  let dark = { ..pale, backdrop: [Mask, Tint(@theme.Color::rgba(0, 0, 0, 70))] }
  assert_eq(@layout.check({ ..g, messages: [{ ..m, label: dark }] }, palette), [])
  let transparent_ink = { ..m.label, ink: @layout.Ink::Color(@theme.Color::rgba(0, 0, 0, 20)), backdrop: [Mask] }
  assert_eq(@layout.check({ ..g, messages: [{ ..m, label: transparent_ink }] }, palette).map(f => f.rule), [@layout.Rule::Contrast])
}

///|
test "a flat palette produces a contrast finding for every text element" {
  let group = @sequence.BoxGroup::new("g", "Group")
  let s = @sequence.Sequence::new([
    @sequence.Participant::new("A", group~, properties=@sequence.ParticipantProperties::new(sublabel="version")),
    @sequence.Participant::new("B", group~),
  ], [Frame(@sequence.Frame::new(Alt, @sequence.Section::new([
    Note(@sequence.Note::new(Over, ["A"], "note")),
    Message(@sequence.Message::new("A", "B", "call", properties=@sequence.MessageProperties::new(sublabel="output"))),
  ], label="first"), rest=[@sequence.Section::new([], label="second")]))], title="Title")
  let black = @theme.Color::hex(0)
  let family : @theme.FamilyColors = { fill: black, stroke: black, ink: black }
  let flat : @theme.Palette = {
    bg: black, text: black, muted: black, mask: black, arrow: black,
    frontend: family, backend: family, database: family, cloud: family,
    security: family, messagebus: family, external: family,
  }
  let g = @layout.layout(s)
  clean(g)
  let findings = @layout.check(g, flat)
  // Two participant labels, two sublabels, a message, a note, a frame header,
  // a section label, a group title and the diagram title.
  assert_eq(findings.map(f => f.rule), Array::make(10, @layout.Rule::Contrast))
}


///|
test "empty rectangles and touching edges do not share an area" {
  let box : @layout.Rect = { x: 0, y: 0, width: 20, height: 20 }
  assert_false(box.overlaps({ x: 5, y: 5, width: 0, height: 10 }))
  assert_false(box.overlaps({ x: 5, y: 5, width: 10, height: 0 }))
  assert_false(box.overlaps({ x: 20, y: 0, width: 10, height: 10 }))
  assert_true(box.overlaps({ x: 19, y: 0, width: 10, height: 10 }))
}
