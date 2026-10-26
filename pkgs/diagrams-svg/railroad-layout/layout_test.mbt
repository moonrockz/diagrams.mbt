///|
/// `(x|yy)+z`: a repeated choice inside a sequence.
fn nested() -> @regex.Regex {
  @regex.Regex::new("nested", "s", [
    @regex.Node::new("s", Sequence(["r", "z"])),
    @regex.Node::new("r", Repeat(@regex.Bounds::new(1), "c")),
    @regex.Node::new("c", Choice(["x", "y"])),
    @regex.Node::new("x", Literal("x")),
    @regex.Node::new("y", Literal("a long label for the second branch")),
    @regex.Node::new("z", Literal("z")),
  ])
}

///|
fn geometry() -> @layout.Geometry {
  @layout.layout(Regex(nested())).geometry.unwrap()
}

///|
let palette : @theme.Palette = @theme.Theme::classic().light

///|
test "a repeat loop encloses its choice and no connector crosses a label" {
  let g = geometry()
  assert_eq(@layout.check(g, palette), [])
  let back = g.wires.iter().find_first(w => w.connector.role == Return).unwrap()
  let choice_top = g.terms
    .iter()
    .map(t => t.rect.y)
    .fold(init=1.0e9, Double::min)
  let lowest = g.terms
    .iter()
    .map(t => t.rect.y + t.rect.height)
    .fold(init=0.0, Double::max)
  // The loop runs below every branch of the choice.
  assert_true(back.points.iter().any(p => p.y > lowest))
  assert_true(choice_top > 0.0)
}

///|
test "grammar rules keep source order with an entry and exit each" {
  let grammar = @ebnf.Grammar::new(
    "g",
    [
      Rule(@ebnf.Rule::new("r1", "first", body="a")),
      Note("n", "between"),
      Rule(@ebnf.Rule::new("r2", "second")),
      Rule(@ebnf.Rule::new("r3", "third", body="b")),
    ],
    [
      @ebnf.Node::new("a", Terminal("a", Double)),
      @ebnf.Node::new("b", Reference("first", None)),
    ],
  )
  let g = @layout.layout(Ebnf(grammar)).geometry.unwrap()
  assert_eq(g.tracks.map(t => t.track.name).iter().collect(), [
    "first", "second", "third",
  ])
  for i in 1..<g.tracks.length() {
    assert_true(g.tracks[i].start.y > g.tracks[i - 1].start.y)
  }
  assert_eq(g.notes.length(), 1)
  assert_eq(@layout.check(g, palette), [])
}

///|
fn rebuilt(
  g : @layout.Geometry,
  terms? : Array[@layout.TermBox],
  wires? : Array[@layout.Wire],
) -> @layout.Geometry {
  @layout.Geometry::new(
    g.topology,
    g.width,
    g.height,
    g.tracks[:],
    terms.unwrap_or(g.terms.iter().collect())[:],
    g.frames[:],
    wires.unwrap_or(g.wires.iter().collect())[:],
    g.notes[:],
    g.points()[:],
  )
}

///|
test "the checker finds broken attachment, crossings, padding and contrast" {
  let g = geometry()
  // Move the start of one connector away from its point.
  let wires = g.wires.iter().collect()
  let first = wires[0]
  let moved = first.points.iter().collect()
  moved[0] = { x: moved[0].x - 5.0, y: moved[0].y, }
  wires[0] = first.with_points(moved)
  assert_true(
    @layout.check(rebuilt(g, wires~), palette)
    .iter()
    .any(f => f.rule == Endpoint),
  )
  // A return path drawn through a terminal label.
  let label = g.terms.iter().find_first(t => t.term.id == "x").unwrap()
  let wires = g.wires.iter().collect()
  let index = wires.search_by(w => w.connector.role == Return).unwrap()
  let through = wires[index]
  let p = through.points
  wires[index] = through.with_points([
    p[0],
    { x: label.rect.x + label.rect.width + 2.0, y: p[0].y, },
    {
      x: label.rect.x + label.rect.width + 2.0,
      y: label.rect.y + label.rect.height / 2.0,
    },
    { x: label.rect.x - 2.0, y: label.rect.y + label.rect.height / 2.0, },
    { x: label.rect.x - 2.0, y: p[p.length() - 1].y, },
    p[p.length() - 1],
  ])
  let crossing = @layout.check(rebuilt(g, wires~), palette)
  assert_true(
    crossing.iter().any(f => f.rule == Overlap && f.identities.contains("x")),
  )
  // A label without padding.
  let terms = g.terms.iter().collect()
  let t = terms[0]
  terms[0] = t.with_rect({ ..t.rect, width: t.label.box.width, })
  assert_true(
    @layout.check(rebuilt(g, terms~), palette).iter().any(f => f.rule == Fit),
  )
  // Text with the colour of its background.
  let dull = { ..palette, text: palette.frontend.fill, }
  assert_true(@layout.check(g, dull).iter().any(f => f.rule == Contrast))
  let pale = @theme.Color::hex(0xf4f5f7)
  assert_true(
    @layout.check(g, palette, highlight_colors=[pale])
    .iter()
    .any(f => f.rule == Contrast),
  )
}

///|
test "explicit limits give diagnostics and no geometry" {
  for
    limits in [
      @layout.Limits::new(work=5),
      @layout.Limits::new(depth=1),
      @layout.Limits::new(nodes=2),
      @layout.Limits::new(width=0),
    ] {
    let result = @layout.layout(Regex(nested()), limits~)
    assert_true(result.geometry is None)
    assert_true(result.diagnostics.iter().any(d => d.severity == Error))
  }
}

///|
test "a wide top-level sequence continues on new rows" {
  let items = []
  let nodes = []
  for i in 0..<20 {
    items.push("t\{i}")
    nodes.push(@regex.Node::new("t\{i}", Class(Property("Letter\{i}"))))
  }
  nodes.push(@regex.Node::new("s", Sequence(ReadOnlyArray::from_array(items))))
  let model = @regex.Regex::new("wide", "s", nodes)
  let result = @layout.layout(
    Regex(model),
    limits=@layout.Limits::new(width=400),
  )
  let g = result.geometry.unwrap()
  assert_true(
    result.diagnostics.iter().any(d => d.code == "railroad/continued"),
  )
  assert_true(g.width < 600.0)
  assert_eq(@layout.check(g, palette), [])
  // Every label keeps its full text.
  assert_true(
    g.terms.iter().all(t => t.label.lines.join("").has_prefix("\\p{Letter")),
  )
}
