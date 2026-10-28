///|
fn styled_plantuml(source : String) -> @render.Diagram {
  let read = @plantuml.read(source)
  @plantuml.to_diagram(read.document.unwrap()).diagram.unwrap()
}

///|
fn styled_examples() -> Array[(String, @render.Diagram)] {
  let architecture = "architecture-beta\nservice api[API]\nservice worker[Worker]\napi:R --> T:worker\n"
  guard @mermaid.read_diagram(architecture).ast is Some(Architecture(ast)) else {
    abort("Missing styled architecture fixture")
  }
  let architecture = @mermaid.to_architecture(ast).architecture.unwrap()
  let flowchart = "flowchart LR\nA[Request] --> B{Review}\nB --> C[Complete]\nC --> A\n"
  guard @mermaid.read_diagram(flowchart).ast is Some(Flowchart(ast)) else {
    abort("Missing styled flowchart fixture")
  }
  let flowchart = @mermaid.to_flowchart(ast).flowchart.unwrap()
  [
    ("sequence", Sequence(exchange())),
    ("bpmn", cyclic()),
    ("swimlane", Swimlane(swimlane(LR))),
    ("flowchart", Flowchart(flowchart)),
    ("architecture", Architecture(architecture)),
    ("regex", styled_plantuml("@startregex\na(b|c)*d\n@endregex")),
    (
      "ebnf",
      styled_plantuml(
        "@startebnf\ncommand = \"a\", [\"b\"], {\"c\"};\n@endebnf",
      ),
    ),
    (
      "data-tree",
      styled_plantuml(
        "@startjson\n{\"a\":{\"b\":[1,2]},\"c\":{\"d\":true}}\n@endjson",
      ),
    ),
  ]
}

///|
test "scene and HTML reject invalid connector options before catalog or layout" {
  let invalid = @render.Diagram::Bpmn(
    @model.Bpmn::new("invalid", [], [@model.Flow::new("missing", "A", "B")]),
  )
  for
    connectors in [
      @svg.ConnectorOptions::new(minimum_approach=-1.0),
      @svg.ConnectorOptions::new(corner_radius=0.0),
      @svg.ConnectorOptions::new(bridge_radius=0.0),
    ] {
    let svg = @svg.SvgRenderer::new(connectors~)
    let result = svg.scene(invalid)
    assert_true(result.scene is None)
    assert_eq(result.diagnostics[0].code, "connector/invalid-option")
    let html = @animated.AnimatedRenderer::new(svg~).render(invalid)
    assert_eq(html.output, None)
    assert_eq(html.diagnostics[0].code, "connector/invalid-option")
  }
}

///|
test "styled scenes use the canonical final paths and preserve graph identity" {
  let snapshots : Array[Json] = []
  for (name, diagram) in styled_examples() {
    let original_result = @svg.SvgRenderer::new().scene(diagram)
    assert_true(
      original_result.scene is Some(_),
      msg="\{name}: \{@debug.to_string(original_result.diagnostics)}",
    )
    let original = original_result.scene.unwrap()
    for
      (style_name, style) in [
        ("elbow", @svg.ConnectorStyle::Elbow),
        ("rounded", @svg.ConnectorStyle::Rounded),
        ("curved", @svg.ConnectorStyle::Curved),
      ] {
      let svg = @svg.SvgRenderer::new(
        connectors=@svg.ConnectorOptions::new(style~),
      )
      let result = svg.scene(diagram)
      assert_true(
        result.scene is Some(_),
        msg="\{name}/\{style_name}: \{@debug.to_string(result.diagnostics)}",
      )
      let scene = result.scene.unwrap()
      assert_eq(scene.canonical_svg, svg.render(diagram).output.unwrap())
      assert_eq(scene.catalog.source, original.catalog.source)
      assert_eq(scene.catalog.occurrences, original.catalog.occurrences)
      assert_eq(scene.catalog.graph.nodes, original.catalog.graph.nodes)
      assert_eq(scene.catalog.graph.edges, original.catalog.graph.edges)
      assert_eq(scene.paths.length(), original.paths.length())
      for i, binding in scene.paths {
        assert_eq(binding.occurrence, original.paths[i].occurrence)
        assert_true(scene.display_svg.contains("d=\"" + binding.path + "\""))
        if binding.mask is Some(mask) {
          assert_true(scene.display_svg.contains("mask=\"" + mask + "\""))
        }
      }
      let selected = scene.paths
        .iter()
        .find_first(p => p.path.contains("C") || p.path.contains("Q"))
        .unwrap_or(scene.paths[0])
      let key = selected.occurrence.key
      let playback = @animation.PlaybackPlan::scenario(
        scene.catalog,
        @animation.Motion::serial([
          Step(key, 1000L),
          OrientedStep(key, 1000L, true),
          Step(key, 1000L),
        ]),
      ).plan.unwrap()
      let html = @animated.AnimatedRenderer::new(svg~, playback~).render(
        diagram,
      )
      assert_true(html.output is Some(_), msg="\{name}/\{style_name} HTML")
      snapshots.push(
        Json([
          Json(name),
          Json(style_name),
          Json(scene.canonical_svg),
          Json(html.output.unwrap()),
        ]),
      )
    }
  }
  let crossing_source = "flowchart LR\nA[Input A] --> C[Output C]\nB[Input B] --> D[Output D]\nA --> D\nB --> C\nC --> E[After C]\nD --> E\nE --> A\n"
  guard @mermaid.read_diagram(crossing_source).ast is Some(Flowchart(ast)) else {
    fail("Missing crossing tracer AST")
  }
  let diagram = @render.Diagram::Flowchart(
    @mermaid.to_flowchart(ast, id="connector-crossing").flowchart.unwrap(),
  )
  for
    (style_name, style) in [
      ("elbow", @svg.ConnectorStyle::Elbow),
      ("rounded", Rounded),
      ("curved", Curved),
    ] {
    for
      (crossing_name, crossing) in [
        ("bridge", @svg.CrossingMode::Bridge),
        ("plain", Plain),
      ] {
      let svg = @svg.SvgRenderer::new(
        connectors=@svg.ConnectorOptions::new(style~, crossing~),
      )
      let result = svg.scene(diagram)
      assert_true(
        result.scene is Some(_),
        msg="tracer/\{style_name}/\{crossing_name}: \{@debug.to_string(result.diagnostics)}",
      )
      let scene = result.scene.unwrap()
      assert_eq(scene.canonical_svg, svg.render(diagram).output.unwrap())
      assert_eq(
        scene.paths.iter().any(p => p.mask is Some(_)),
        crossing == Bridge,
      )
      let selected = scene.paths
        .iter()
        .find_first(p => p.mask is Some(_))
        .unwrap_or(scene.paths[0])
      let key = selected.occurrence.key
      let playback = @animation.PlaybackPlan::scenario(
        scene.catalog,
        @animation.Motion::serial([
          Step(key, 1000L),
          OrientedStep(key, 1000L, true),
          Step(key, 1000L),
        ]),
      ).plan.unwrap()
      let html = @animated.AnimatedRenderer::new(svg~, playback~).render(
        diagram,
      ).output.unwrap()
      snapshots.push(
        Json([
          Json("crossing"),
          Json(style_name + "-" + crossing_name),
          Json(scene.canonical_svg),
          Json(html),
        ]),
      )
    }
  }
  let t = @test.Test("styled offline players")
  t.write(Json(snapshots).stringify())
  t.snapshot(filename="connectors.json")
}
