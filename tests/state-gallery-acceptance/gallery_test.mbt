///|
fn model(name : String, source : String) -> @state.StateDiagram raise {
  if name.has_prefix("state-mermaid") {
    let read = @mermaid.read_diagram(source)
    assert_eq(read.tree.text(), source)
    assert_false(
      read.diagnostics.any(d => d.severity == Error),
      msg=@debug.to_string(read.diagnostics),
    )
    guard read.ast is Some(State(ast)) else { fail("expected state AST") }
    let converted = @mermaid.to_state(ast, id=name)
    assert_true(
      converted.state is Some(_),
      msg=@debug.to_string(converted.diagnostics),
    )
    converted.state.unwrap()
  } else {
    let read = @plantuml.read(source)
    assert_eq(read.tree.text(), source)
    assert_false(
      read.diagnostics.any(d => d.severity == Error),
      msg=@debug.to_string(read.diagnostics),
    )
    let converted = @plantuml.to_diagram(read.document.unwrap(), id=name)
    guard converted.diagram is Some(State(view)) else {
      fail(@debug.to_string(converted.diagnostics))
    }
    view
  }
}

///|
test "state sources themes geometry and offline players are portable qualified artifacts" (
  t : @test.Test,
) {
  let rows : Array[Json] = []
  for
    (name, extension, source) in [
      ("state-mermaid-lifecycle", "mmd", state_mermaid_lifecycle),
      ("state-mermaid-choice", "mmd", state_mermaid_choice),
      ("state-mermaid-concurrent", "mmd", state_mermaid_concurrent),
      ("state-plantuml-lifecycle", "puml", state_plantuml_lifecycle),
      ("state-plantuml-composite", "puml", state_plantuml_composite),
      ("state-plantuml-history", "puml", state_plantuml_history),
    ] {
    rows.push(Json([name + "." + extension, "text/plain", source]))
    let view = model(name, source)
    let geometry = @layout.layout(view)
    guard geometry.geometry is Some(geometry) else {
      fail(
        name +
        " geometry: " +
        geometry.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
    }
    for palette in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
      let findings = @layout.check(geometry, palette)
      if !findings.is_empty() {
        fail(
          name +
          " legibility: " +
          findings.iter().map(d => d.message).to_array().join("; "),
        )
      }
    }
    let catalog = @animation.Catalog::state(view).catalog.unwrap()
    assert_true(catalog.occurrences.length() > 0)
    let first = if name == "state-plantuml-history" {
      @svg.SvgRenderer::new().scene(State(view)).scene.unwrap().paths
      .iter()
      .find_first(p => p.mask != None)
      .unwrap().occurrence
    } else {
      catalog.occurrences.iter().find_first(o => !o.is_visit()).unwrap()
    }
    let visit = catalog.occurrences
      .iter()
      .find_first(o => o.is_visit())
      .unwrap().key
    let second = catalog.occurrences
      .iter()
      .filter(o => !o.is_visit())
      .to_array()[1].key
    let playback = @animation.PlaybackPlan::scenario(
      catalog,
      @animation.Motion::serial([
        Step(first.key, 1000L),
        Step(first.key, 1000L),
        Parallel([Step(second, 1000L), Visit(visit, 1000L)]),
      ]),
    ).plan.unwrap()
    assert_eq(playback.sample_at(3000L).finished, true)
    let variants = [
      ("dark", @svg.Mode::Fixed(Dark), @svg.ConnectorOptions::new()),
      ("light", @svg.Mode::Fixed(Light), @svg.ConnectorOptions::new()),
      ("adaptive", @svg.Mode::Adaptive, @svg.ConnectorOptions::new()),
    ]
    if name == "state-plantuml-history" {
      variants.append([
        (
          "curved-light",
          @svg.Mode::Fixed(Light),
          @svg.ConnectorOptions::new(style=Curved),
        ),
        (
          "curved-dark",
          @svg.Mode::Fixed(Dark),
          @svg.ConnectorOptions::new(style=Curved),
        ),
        (
          "elbow-plain-light",
          @svg.Mode::Fixed(Light),
          @svg.ConnectorOptions::new(style=Elbow, crossing=Plain),
        ),
      ])
    }
    for (variant, mode, connectors) in variants {
      let renderer = @svg.SvgRenderer::new(
        mode~,
        connectors~,
        id_prefix=name + "-" + variant,
      )
      let rendered = @render.Renderer::render(renderer, State(view))
      guard rendered.output is Some(output) else {
        fail(
          name +
          " SVG: " +
          rendered.diagnostics.iter().map(d => d.message).to_array().join("; "),
        )
      }
      rows.push(Json([name + "-" + variant + ".svg", "image/svg+xml", output]))
      let html = @render.Renderer::render(
        @animated.AnimatedRenderer::new(svg=renderer, playback~),
        State(view),
      )
      guard html.output is Some(output) else {
        fail(
          name +
          " HTML: " +
          html.diagnostics.iter().map(d => d.message).to_array().join("; "),
        )
      }
      rows.push(Json([name + "-" + variant + ".html", "text/html", output]))
    }
  }
  t.write(Json(rows).stringify(indent=1))
  t.snapshot(filename="state-gallery.json")
}
