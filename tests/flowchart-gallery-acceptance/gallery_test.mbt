///|
fn model(name : String, source : String) -> @flowchart.Flowchart raise {
  if name == "flowchart-mermaid-review" {
    let read = @mermaid.read_diagram(source)
    assert_false(read.diagnostics.iter().any(d => d.severity == Error))
    assert_eq(read.tree.text(), source)
    guard read.ast is Some(Flowchart(ast)) else { fail("expected flowchart") }
    let converted = @mermaid.to_flowchart(ast, id=name)
    assert_false(converted.diagnostics.iter().any(d => d.severity == Error))
    converted.flowchart.unwrap()
  } else {
    let read = @plantuml.read(source)
    assert_false(read.diagnostics.iter().any(d => d.severity == Error))
    assert_eq(read.tree.text(), source)
    let converted = @plantuml.to_diagram(read.document.unwrap(), id=name)
    assert_false(converted.diagnostics.iter().any(d => d.severity == Error))
    guard converted.diagram is Some(Flowchart(view)) else {
      fail("expected activity flowchart")
    }
    view
  }
}

///|
test "flowchart sources themes geometry and offline players are portable qualified artifacts" (
  t : @test.Test,
) {
  let rows : Array[Json] = []
  for
    (name, extension, source) in [
      ("flowchart-mermaid-review", "mmd", flowchart_mermaid_review),
      ("flowchart-plantuml-modern", "puml", flowchart_plantuml_modern),
      ("flowchart-plantuml-legacy", "puml", flowchart_plantuml_legacy),
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
    let catalog = @animation.Catalog::flowchart(view).catalog.unwrap()
    assert_true(catalog.occurrences.length() > 0)
    let first = catalog.occurrences
      .iter()
      .find_first(o => !o.is_visit())
      .unwrap()
    // A finite caller-supplied repeated step demonstrates a loop illustration.
    let playback = @animation.PlaybackPlan::scenario(
      catalog,
      @animation.Motion::serial([Step(first.key, 1000L), Step(first.key, 1000L)]),
    ).plan.unwrap()
    assert_eq(playback.sample_at(2000L).finished, true)
    for
      (variant, mode) in [
        ("dark", @svg.Mode::Fixed(Dark)),
        ("light", @svg.Mode::Fixed(Light)),
        ("adaptive", @svg.Mode::Adaptive),
      ] {
      let renderer = @svg.SvgRenderer::new(
        mode~,
        id_prefix=name + "-" + variant,
      )
      let rendered = @render.Renderer::render(renderer, Flowchart(view))
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
        Flowchart(view),
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
  t.snapshot(filename="flowchart-gallery.json")
}
