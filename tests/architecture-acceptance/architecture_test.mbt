///|
fn source() -> String {
  let text =
    #|architecture-beta
    #|group left(cloud)[Left]
    #|group right(server)[Right]
    #|service api(internet)[API] in left
    #|service db(database)[Database] in right
    #|junction join in right
    #|api{group}:R -[request]-> L:db{group}
    #|db:B <-- T:join
    #|align row api db
    #|accTitle: Service architecture
    #|accDescr: Explicit structure
  text
}

///|
fn model() -> @model.Architecture {
  let parsed = @syntax.read(source())
  @conversion.to_architecture(parsed.ast.unwrap()).architecture.unwrap()
}

///|
test "native architecture typed source and canonical print preserve semantics" {
  let source = source()
  let parsed = @syntax.read(source)
  assert_eq(parsed.tree.text(), source)
  assert_eq(parsed.diagnostics.length(), 0)
  let canonical = @printer.print(parsed.ast.unwrap()).output.unwrap()
  let again = @syntax.read(canonical)
  assert_eq(again.diagnostics.length(), 0)
  assert_eq(again.ast, parsed.ast)
  assert_eq(@printer.print(again.ast.unwrap()).output, Some(canonical))
  let model = model()
  assert_eq(model.groups.length(), 2)
  assert_eq(model.services.length(), 2)
  assert_eq(model.junctions.length(), 1)
  assert_eq(model.connections[0].source.id, "api")
  assert_true(model.connections[0].source.group)
  assert_true(model.connections[0].target_head)
  assert_eq(model.connections[0].label, Some("request"))
  assert_eq(model.connections[1].source_head, true)
}

///|
test "lossless metadata CRLF Unicode and safe recovery" {
  let source = "---\r\ntitle: source\r\n---\r\n%%{init: {}}%%\r\narchitecture-beta\r\n%% 😀\r\nservice a[Alpha]\r\na:Z -- L:a\r\nbroken ???\r\nservice b[Beta]\r\n"
  let parsed = @syntax.read(source)
  assert_eq(parsed.tree.text(), source)
  assert_eq(parsed.diagnostics.length(), 2)
  assert_eq(parsed.diagnostics[0].span.unwrap().start.line, 8)
  assert_eq(parsed.ast.unwrap().statements.length(), 3)
  let result = @conversion.to_architecture(parsed.ast.unwrap())
  assert_true(
    result.diagnostics.iter().any(d => d.code == "architecture/metadata-option"),
  )
}

///|
test "architecture model copies arrays and rejects invalid ownership and endpoints" {
  let services = [@model.Service::new("a")]
  let view = @model.Architecture::new("copy", services[:], [])
  services[0] = @model.Service::new("b")
  assert_eq(view.services[0].id, "a")
  let cycle = @model.Architecture::new("cycle", [], [], groups=[
    @model.Group::new("a", parent="b"),
    @model.Group::new("b", parent="a"),
  ])
  assert_true(
    @model.validate(cycle)
    .iter()
    .any(d => d.code == "architecture/ownership-cycle"),
  )
  let bad = @model.Architecture::new("bad", [@model.Service::new("a")], [
    @model.Connection::new(
      "e",
      @model.Endpoint::new("a", Right, group=true),
      @model.Endpoint::new("missing", Left),
    ),
  ])
  assert_true(
    @model.validate(bad)
    .iter()
    .any(d => d.code == "architecture/invalid-group-attachment"),
  )
  assert_true(
    @model.validate(bad)
    .iter()
    .any(d => d.code == "architecture/invalid-endpoint"),
  )
}

///|
test "bounded deterministic layout retains alignment group endpoint and port geometry" {
  let view = model()
  let result = @layout.layout(view)
  let geometry = result.geometry.unwrap()
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(@layout.check(geometry).length(), 0)
  let a = geometry.shapes.iter().filter(s => s.id == "api").to_array()[0]
  let b = geometry.shapes.iter().filter(s => s.id == "db").to_array()[0]
  assert_eq(a.box.y + a.box.height / 2, b.box.y + b.box.height / 2)
  assert_true(a.box.x < b.box.x)
  let group = geometry.shapes.iter().filter(s => s.id == "left").to_array()[0]
  assert_true(group.box.contains(a.box))
  assert_eq(geometry.connections[0].points[0].x, group.box.x + group.box.width)
  assert_eq(@layout.layout(view).geometry, Some(geometry))
  assert_eq(
    @layout.layout(view, limits=@layout.Limits::new(work=1)).geometry,
    None,
  )
  let conflict = @model.Architecture::new(
    "conflict",
    [@model.Service::new("a"), @model.Service::new("b")],
    [],
    alignments=[
      @model.Alignment::new(Row, ["a", "b"]),
      @model.Alignment::new(Row, ["b", "a"]),
    ],
  )
  let conflict = @layout.layout(conflict)
  assert_eq(conflict.geometry, None)
  assert_true(
    conflict.diagnostics
    .iter()
    .any(d => d.code == "architecture/constraint-conflict"),
  )
}

///|
test "every endpoint side pair and parallel self routes are retained" {
  let sides = [@model.Side::Left, Right, Top, Bottom]
  let edges = []
  for a in sides {
    for b in sides {
      edges.push(
        @model.Connection::new(
          "e\{edges.length()}",
          @model.Endpoint::new("a", a),
          @model.Endpoint::new("b", b),
          source_head=true,
          target_head=true,
        ),
      )
    }
  }
  edges.push(
    @model.Connection::new(
      "self",
      @model.Endpoint::new("a", Right),
      @model.Endpoint::new("a", Top),
      label="self",
      target_head=true,
    ),
  )
  let view = @model.Architecture::new(
    "ports",
    [@model.Service::new("a"), @model.Service::new("b")],
    edges[:],
  )
  let geometry = @layout.layout(view).geometry.unwrap()
  assert_eq(geometry.connections.length(), 17)
  assert_eq(@layout.check(geometry).length(), 0)
}

///|
test "standalone themed architecture SVG and canonical scene" (
  snapshot : @test.Test,
) {
  let view = model()
  let renderer = @svg.SvgRenderer::new(mode=Fixed(Light), id_prefix="one")
  let rendered = renderer.render(Architecture(view))
  assert_true(rendered.output is Some(_))
  let text = rendered.output.unwrap()
  assert_true(text.contains("data-diagram=\"architecture\""))
  assert_true(text.contains("<symbol"))
  assert_true(!text.contains("<script"))
  assert_true(!text.contains("var(--"))
  assert_true(!text.contains("<style"))
  assert_true(!text.contains("https://"))
  let scene = renderer.scene(Architecture(view)).scene.unwrap()
  assert_eq(scene.canonical_svg, text)
  assert_eq(scene.paths.length(), 2)
  assert_eq(scene.catalog.occurrences.length(), 2)
  snapshot.write(text)
  snapshot.snapshot(filename="architecture-light.svg")
}

///|
test "fixed dark architecture is deterministic" (snapshot : @test.Test) {
  snapshot.write(
    @svg.SvgRenderer::new(mode=Fixed(Dark), id_prefix="one").render(
      Architecture(model()),
    ).output.unwrap(),
  )
  snapshot.snapshot(filename="architecture-dark.svg")
}

///|
test "offline architecture player keeps the canonical static SVG" (
  snapshot : @test.Test,
) {
  let view = model()
  let renderer = @svg.SvgRenderer::new(mode=Fixed(Light), id_prefix="one")
  let html = @animated.AnimatedRenderer::new(svg=renderer).render(
    Architecture(view),
  )
  assert_true(html.output is Some(_))
  assert_true(html.output.unwrap().contains("architecture"))
  snapshot.write(html.output.unwrap())
  snapshot.snapshot(filename="architecture.html")
}

///|
test "architecture directed routes retain reverse traversal and opt in unheaded edges" {
  let view = @model.Architecture::new(
    "routes",
    [
      @model.Service::new("a"),
      @model.Service::new("b"),
      @model.Service::new("c"),
    ],
    [
      @model.Connection::new(
        "ab",
        @model.Endpoint::new("a", Right),
        @model.Endpoint::new("b", Left),
        source_head=true,
        target_head=true,
      ),
      @model.Connection::new(
        "bc",
        @model.Endpoint::new("b", Right),
        @model.Endpoint::new("c", Left),
      ),
    ],
  )
  let catalog = @animation.Catalog::architecture(view).catalog.unwrap()
  let route = catalog.graph.route("b", "a")
  guard route is Found(route) else { fail("Missing bidirectional route") }
  assert_true(route.reversed[0])
  assert_true(
    @animation.PlaybackPlan::route(catalog, route).plan.unwrap().steps[0].reversed,
  )
  assert_eq(catalog.graph.route("b", "c"), Unreachable)
  guard catalog.graph.route("b", "c", kinds=[ArchitectureFlow, Undirected])
    is Found(_) else {
    fail("Missing opted-in unheaded route")
  }
}

///|
test "architecture legibility checker detects independently corrupted geometry" {
  let g = @layout.layout(model()).geometry.unwrap()
  let shapes = g.shapes.iter().to_array()
  let first = shapes[0]
  shapes[0] = {
    ..first,
    font_size: 10,
    label: Array::make(100, "wide").join(""),
    box: { ..first.box, x: -1000, },
  }
  let broken : @layout.Geometry = {
    ..g,
    shapes: ReadOnlyArray::from_array(shapes[:]),
  }
  let findings = @layout.check(broken)
  for code in ["small-text", "label-overflow", "overflow", "containment"] {
    assert_true(findings.iter().any(f => f.code == code), msg=code)
  }
  let shapes = g.shapes.iter().to_array()
  shapes[1] = { ..shapes[1], box: first.box, }
  let broken : @layout.Geometry = {
    ..g,
    shapes: ReadOnlyArray::from_array(shapes[:]),
  }
  assert_true(@layout.check(broken).iter().any(f => f.code == "overlap"))
  let palette = @theme.Theme::classic().light
  let palette = { ..palette, text: palette.bg, }
  assert_true(@layout.check(g, palette~).iter().any(f => f.code == "contrast"))
  let routes = g.connections.iter().to_array()
  let points = routes[0].points.iter().to_array()
  points[0] = { ..points[0], x: points[0].x + 3, }
  routes[0] = { ..routes[0], points: ReadOnlyArray::from_array(points[:]), }
  let broken : @layout.Geometry = {
    ..g,
    connections: ReadOnlyArray::from_array(routes[:]),
  }
  assert_true(@layout.check(broken).iter().any(f => f.code == "endpoint"))
  assert_true(@layout.check(g, work_limit=0).iter().any(f => f.code == "limit"))
}

///|
test "architecture resource budgets refuse complete syntax models layout and output" {
  let text = source()
  for
    limits in [
      @syntax.Limits::new(source=1),
      @syntax.Limits::new(nodes=1),
      @syntax.Limits::new(edges=0),
      @syntax.Limits::new(alignments=0),
      @syntax.Limits::new(work=1),
    ] {
    assert_eq(@syntax.read(text, limits~).ast, None)
  }
  assert_eq(
    @printer.print(
      @syntax.read(text).ast.unwrap(),
      limits=@syntax.Limits::new(output=1),
    ).output,
    None,
  )
  let model = model()
  assert_true(
    @model.validate(model, depth_limit=0)
    .iter()
    .any(d => d.code == "architecture/depth-limit"),
  )
  assert_true(
    @model.validate(model, work_limit=1)
    .iter()
    .any(d => d.code == "architecture/work-limit"),
  )
  assert_eq(
    @layout.layout(model, limits=@layout.Limits::new(coordinate=10)).geometry,
    None,
  )
  let output = @svg.render_architecture(
    model,
    limits=@layout.Limits::new(output_units=10),
  )
  assert_eq(output.output, None)
  assert_true(
    output.diagnostics.iter().any(d => d.code == "architecture/output-limit"),
  )
  let output = @svg.render_architecture(
    model,
    limits=@layout.Limits::new(work=30),
  )
  assert_eq(output.output, None)
  assert_true(
    output.diagnostics.iter().any(d => d.code == "architecture/work-limit"),
  )
}

///|
test "architecture escaping unresolved symbols and separate prefixes stay standalone" {
  let icon = @icons.Reference::new("custom", "missing-name")
  let view = @model.Architecture::new(
    "hostile",
    [
      @model.Service::new(
        "a",
        label="<script onload='x'>&",
        icon~,
        icon_text="<img onerror='x'>",
      ),
    ],
    [],
    groups=[@model.Group::new("g", icon~)],
  )
  let one = @svg.render_architecture(view, id_prefix="one", mode=Fixed(Light))
  let two = @svg.render_architecture(view, id_prefix="two", mode=Fixed(Light))
  let text = one.output.unwrap()
  assert_true(
    one.diagnostics.iter().any(d => d.code == "architecture/unknown-icon"),
  )
  assert_true(text.contains("missing-name"))
  assert_true(text.contains("&lt;script"))
  assert_true(!text.contains("<script"))
  assert_true(!text.contains("<img"))
  assert_true(!text.contains("href=\"http"))
  assert_true(one.output != two.output)
}

///|
test "architecture comments titles and malformed quotes recover on statement boundaries" {
  let text = "architecture-beta\ntitle User's topology\n%% don't interpret this quote\nservice a[First] %% don't interpret this either\nservice broken[\"unterminated\nservice next[Next]\n"
  let read = @syntax.read(text)
  assert_eq(read.tree.text(), text)
  assert_eq(read.diagnostics.length(), 1)
  assert_eq(read.diagnostics[0].span.unwrap().start.line, 5)
  assert_eq(read.ast.unwrap().statements.length(), 4)
}

///|
test "dense labelled parallel architecture paths retain separate identities and label space" {
  let edges = Array::makei(12, i => {
    @model.Connection::new(
      "edge-\{i}",
      @model.Endpoint::new("a", Right),
      @model.Endpoint::new("b", Left),
      label="request \{i}",
      target_head=true,
    )
  })
  let view = @model.Architecture::new(
    "dense",
    [
      @model.Service::new("a", label="Long service label\nsecond line"),
      @model.Service::new("b", label="Another long label"),
    ],
    edges[:],
    groups=[
      @model.Group::new(
        "empty",
        label="Long group title\nsecond line\nthird line",
      ),
    ],
  )
  let result = @layout.layout(view)
  guard result.geometry is Some(g) else {
    fail(
      result.diagnostics
      .iter()
      .map(d => d.code + " " + d.message)
      .to_array()
      .join("; "),
    )
  }
  assert_eq(g.connections.length(), 12)
  assert_eq(@layout.check(g).length(), 0)
  for i, a in g.connections {
    for j = i + 1; j < g.connections.length(); j = j + 1 {
      let b = g.connections[j]
      assert_true(a.points != b.points)
      assert_true(!a.label_box.unwrap().overlaps(b.label_box.unwrap()))
    }
  }
}
