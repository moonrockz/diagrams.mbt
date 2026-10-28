///|
test "all supported pinned state topologies render and pass geometry in both themes" {
  let failures = []
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    guard @syntax.read(source).ast is Some(ast) else { continue }
    guard @conversion.to_state(ast).state is Some(model) else { continue }
    let result = @layout.layout(model)
    guard result.geometry is Some(geometry) else {
      failures.push(
        name +
        " layout: " +
        result.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
      continue
    }
    for palette in [@theme.Theme::classic().light, @theme.Theme::classic().dark] {
      let findings = @layout.check(geometry, palette)
      if !findings.is_empty() {
        failures.push(
          name +
          " geometry: " +
          findings.iter().map(d => d.message).to_array().join("; "),
        )
      }
    }
    for
      mode in [
        @svg.Mode::Fixed(@svg.Variant::Light),
        @svg.Mode::Fixed(@svg.Variant::Dark),
      ] {
      let rendered = @render.Renderer::render(
        @svg.SvgRenderer::new(mode~),
        State(model),
      )
      if rendered.output == None ||
        rendered.diagnostics.iter().any(d => d.severity == Error) {
        failures.push(
          name +
          " SVG: " +
          rendered.diagnostics
          .iter()
          .map(d => d.code + " " + d.message)
          .to_array()
          .join("; "),
        )
      }
    }
    let animated = @animated.AnimatedRenderer::new().render(State(model))
    if animated.output == None {
      failures.push(
        name +
        " player: " +
        animated.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
}
