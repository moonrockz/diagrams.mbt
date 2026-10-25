///|
fn placed(g : Geometry, id : String) -> Shape {
  g.shapes.iter().find_first(s => s.id == id).unwrap()
}

///|
fn clean(view : @model.Swimlane) -> Geometry raise {
  let result = layout(view)
  assert_true(result.geometry != None, msg=@debug.to_string(result.diagnostics))
  let geometry = result.geometry.unwrap()
  for p in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
    let findings = check(geometry, palette(p))
    assert_eq(findings, [], msg=@debug.to_string(findings))
  }
  geometry
}

///|
fn example(direction : @model.Direction) -> @model.Swimlane {
  @model.Swimlane::new(
    "review",
    [
      @model.Node::new("A", lane="Customer", label="Request"),
      @model.Node::new("B", lane="Support", label="Review", shape="diamond"),
      @model.Node::new(
        "C",
        lane="Engineering",
        label="Resolve",
        shape="stadium",
      ),
    ],
    [
      @model.Connection::new("AB", "A", "B", label="submit"),
      @model.Connection::new("BC", "B", "C", label="assign"),
      @model.Connection::new("CA", "C", "A", label="return"),
      @model.Connection::new("AB2", "A", "B", label="parallel"),
      @model.Connection::new("BB", "B", "B", label="retry"),
    ],
    direction~,
    lanes=[
      @model.Lane::new("Customer"),
      @model.Lane::new(
        "Support",
        label="Support team\nLong readable responsibility title",
      ),
      @model.Lane::new("Engineering"),
      @model.Lane::new("Empty"),
    ],
  )
}

///|
test "all directions retain ordered lanes with cyclic parallel and self handoffs" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    let g = clean(example(direction))
    let a = placed(g, "Customer")
    let b = placed(g, "Support")
    let c = placed(g, "Engineering")
    if horizontal(direction) {
      assert_true(a.box.y < b.box.y && b.box.y < c.box.y)
    } else {
      assert_true(a.box.x < b.box.x && b.box.x < c.box.x)
    }
    assert_eq(g.connections.length(), 5)
    assert_true(g.connections[0].line != g.connections[3].line)
    for edge in g.connections {
      for i in 1..<edge.line.length() {
        let a = edge.line[i - 1]
        let b = edge.line[i]
        assert_true((a.x - b.x).abs() < 0.001 || (a.y - b.y).abs() < 0.001)
      }
    }
  }
}

///|
test "reverse flow affects placement but keeps source and target semantics" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    let view = @model.Swimlane::new(
      "p",
      [@model.Node::new("A", lane="L"), @model.Node::new("B", lane="L")],
      [@model.Connection::new("AB", "A", "B")],
      lanes=[@model.Lane::new("L")],
      direction~,
    )
    let g = clean(view)
    let a = placed(g, "A")
    let b = placed(g, "B")
    match direction {
      TB => assert_true(a.box.y < b.box.y)
      BT => assert_true(a.box.y > b.box.y)
      LR => assert_true(a.box.x < b.box.x)
      RL => assert_true(a.box.x > b.box.x)
    }
    assert_eq(g.connections[0].connection.source, "A")
    assert_eq(g.connections[0].connection.target, "B")
  }
}

///|
test "nested local directions collapsed boundaries empty lanes and unowned nodes" {
  let view = @model.Swimlane::new(
    "p",
    [
      @model.Node::new("A", lane="L", groups=["G"]),
      @model.Node::new("B", lane="L", groups=["G"]),
      @model.Node::new("Hidden", lane="L", groups=["Closed"]),
      @model.Node::new("Unowned"),
    ],
    [
      @model.Connection::new("AB", "A", "B"),
      @model.Connection::new("BH", "B", "Hidden"),
    ],
    lanes=[@model.Lane::new("L"), @model.Lane::new("Empty")],
    groups=[
      @model.Group::new("G", lane="L", direction=RL),
      @model.Group::new("Closed", lane="L", expanded=false),
    ],
  )
  let g = clean(view)
  assert_true(placed(g, "A").box.x > placed(g, "B").box.x)
  assert_true(placed(g, "G").box.contains(placed(g, "A").box))
  assert_true(placed(g, "L").box.contains(placed(g, "G").box))
  assert_false(g.shapes.iter().any(s => s.id == "Hidden"))
  assert_eq(g.connections[1].target, "Closed")
  assert_eq(g.connections[1].connection.target, "Hidden")
  assert_eq(placed(g, "Unowned").lane, None)
}

///|
test "disconnected nodes keep source order and invisible edges constrain placement" {
  let view = @model.Swimlane::new(
    "p",
    [
      @model.Node::new("Z", lane="L"),
      @model.Node::new("A", lane="L"),
      @model.Node::new("M", lane="L"),
    ],
    [],
    lanes=[@model.Lane::new("L")],
  )
  let g = clean(view)
  assert_true(
    placed(g, "Z").box.x < placed(g, "A").box.x &&
    placed(g, "A").box.x < placed(g, "M").box.x,
  )
  let constrained = @model.Swimlane::new(
    "p",
    view.nodes,
    [@model.Connection::new("ZA", "Z", "A", style=Invisible)],
    lanes=view.lanes,
  )
  let g = clean(constrained)
  assert_true(placed(g, "Z").box.y < placed(g, "A").box.y)
}

///|
test "each built-in vector receives actual outline attached endpoints" {
  for shape in @model.built_in_shapes {
    let view = @model.Swimlane::new(
      "p",
      [
        @model.Node::new("A", shape~, lane="L", label=shape),
        @model.Node::new("B", lane="L"),
      ],
      [@model.Connection::new("AB", "A", "B")],
      lanes=[@model.Lane::new("L")],
    )
    assert_true(
      layout(view).geometry != None,
      msg=shape + @debug.to_string(layout(view).diagnostics),
    )
    let g = clean(view)
    assert_true(on_shape(g.connections[0].line[0], placed(g, "A")), msg=shape)
  }
}

///|
test "explicit limits and asset shapes fail with no partial geometry" {
  for
    limits in [
      Limits::new(nodes=1),
      Limits::new(edges=1),
      Limits::new(work=1),
      Limits::new(depth=0),
    ] {
    let result = layout(example(TB), limits~)
    assert_eq(result.geometry, None)
    assert_eq(result.diagnostics[0].code, "swimlane/layout-limit")
  }
  for shape in ["image", "icon", "future-shape"] {
    let result = layout(
      @model.Swimlane::new("p", [@model.Node::new("A", shape~)], []),
    )
    assert_eq(result.geometry, None)
    assert_eq(result.diagnostics[0].code, "swimlane/unsupported-shape")
  }
}

///|
test "checker detects independently corrupted geometry and palette" {
  let g = clean(
    @model.Swimlane::new(
      "p",
      [@model.Node::new("A", lane="L"), @model.Node::new("B", lane="L")],
      [@model.Connection::new("AB", "A", "B")],
      lanes=[@model.Lane::new("L")],
    ),
  )
  let shapes = g.shapes.iter().to_array()
  let i = shapes.search_by(s => s.id == "B").unwrap()
  let a = placed(g, "A")
  shapes[i] = {
    ..shapes[i],
    box: a.box,
    outline_box: a.outline_box,
    label: shapes[i].label.map(l => { ..l, size: 8.0, box: a.box, }),
  }
  let bad = { ..g, shapes: ReadOnlyArray::from_array(shapes), }
  let findings = check(bad, palette(@theme.Theme::classic().dark))
  assert_true(findings.iter().any(f => f.rule == Overlap))
  assert_true(findings.iter().any(f => f.rule == Endpoint))
  assert_true(findings.iter().any(f => f.rule == Size))
  assert_true(
    check(g, palette(@theme.Theme::classic().dark), work_limit=1)
    .iter()
    .any(f => f.rule == Limit),
  )
  let p = @theme.Theme::classic().dark
  assert_true(
    check(g, { ..p, text: p.bg, backend: { ..p.backend, ink: p.bg, }, })
    .iter()
    .any(f => f.rule == Contrast),
  )
}

///|
test "unowned graphs and local directions use the requested flow axis" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    let g = clean(
      @model.Swimlane::new(
        "unowned",
        [@model.Node::new("A"), @model.Node::new("B")],
        [@model.Connection::new("AB", "A", "B", min_length=3)],
        direction~,
      ),
    )
    let a = placed(g, "A")
    let b = placed(g, "B")
    assert_eq(a.parent, None)
    assert_eq(b.parent, None)
    match direction {
      TB => assert_true(b.box.y - a.box.y > 200.0)
      BT => assert_true(a.box.y - b.box.y > 200.0)
      LR => assert_true(b.box.x - a.box.x > 200.0)
      RL => assert_true(a.box.x - b.box.x > 200.0)
    }
  }
}

///|
test "source-declared group and lane endpoints attach to their own boundaries" {
  let view = @model.Swimlane::new(
    "p",
    [
      @model.Node::new("A", lane="L1", groups=["G"]),
      @model.Node::new("B", lane="L2"),
    ],
    [
      @model.Connection::new("GB", "G", "B", label="group handoff"),
      @model.Connection::new("LL", "L1", "L2", label="lane handoff"),
    ],
    lanes=[@model.Lane::new("L1"), @model.Lane::new("L2")],
    groups=[@model.Group::new("G", lane="L1")],
  )
  let g = clean(view)
  assert_eq(g.connections[0].source, "G")
  assert_eq(g.connections[1].source, "L1")
  assert_eq(g.connections[1].target, "L2")
  for edge in g.connections {
    assert_true(on_shape(edge.line[0], placed(g, edge.source)))
    assert_true(on_shape(edge.line.last().unwrap(), placed(g, edge.target)))
  }
}

///|
test "long multiline labels stay clear of every silhouette and special-symbol glyph" {
  for shape in @model.built_in_shapes {
    let text = "A deliberately long responsibility action\nwith a second detailed line\nand a third line"
    let view = @model.Swimlane::new(
      "long",
      [@model.Node::new("A", shape~, label=text, lane="L")],
      [],
      lanes=[
        @model.Lane::new(
          "L",
          label="Long lane responsibility title\nSecond lane title line",
        ),
      ],
    )
    let result = layout(view)
    assert_true(
      result.geometry != None,
      msg=shape + @debug.to_string(result.diagnostics),
    )
    let g = result.geometry.unwrap()
    let findings = check(g, palette(@theme.Theme::classic().light))
    assert_eq(findings, [], msg=shape + @debug.to_string(findings))
  }
}

///|
test "text projection preserves operators and quote-aware HTML remains inert" {
  assert_eq(label_text("1 < 2 and x < y > z"), "1 < 2 and x < y > z")
  assert_eq(label_text("a ** b and `x`"), "a ** b and `x`")
  assert_eq(project_label("a ** b ** c", Text), "a ** b ** c")
  assert_eq(project_label("**bold** and `x < 2`", Markdown), "bold and x < 2")
  assert_eq(project_label("x<y>z", Text), "x<y>z")
  assert_eq(label_text("before<!-- a > <b>comment</b> -->after"), "beforeafter")
  assert_eq(
    label_text("<b title=\"x > y\">bold</b> and 1 < 2"),
    "bold and 1 < 2",
  )
  assert_eq(
    label_text("<b missing=\"unterminated > text"),
    "<b missing=\"unterminated > text",
  )
  let view = @model.Swimlane::new(
    "operators",
    [
      @model.Node::new("A", label="1 < 2 ** 3"),
      @model.Node::new("B", label="x < y > z", label_kind=Markdown),
    ],
    [@model.Connection::new("AB", "A", "B", label="1 < 2 ** 3")],
  )
  let g = clean(view)
  assert_eq(placed(g, "A").label.unwrap().text, "1 < 2 ** 3")
  assert_eq(placed(g, "B").label.unwrap().text, "x < y > z")
  assert_eq(g.connections[0].label.unwrap().text, "1 < 2 ** 3")
}
