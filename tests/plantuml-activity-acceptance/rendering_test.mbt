///|
test "every supported frozen activity has legible SVG in both fixed themes" {
  let failures = []
  let expected = @json.parse(@corpus.expectations)
  for fixture in @corpus.fixtures {
    if field(field(expected, fixture.name), "category") ==
      Json("library-refusal") {
      continue
    }
    let read = @plantuml.read(fixture.source)
    let converted = @plantuml.to_diagram(read.document.unwrap())
    guard converted.diagram is Some(Flowchart(model)) else {
      failures.push(
        fixture.name +
        " conversion: " +
        converted.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
      continue
    }
    let result = @layout.layout(model)
    guard result.geometry is Some(drawing) else {
      failures.push(
        fixture.name +
        " layout: " +
        result.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
      continue
    }
    for palette in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
      let findings = @layout.check(drawing, palette)
      if !findings.is_empty() {
        failures.push(
          fixture.name +
          " legibility: " +
          findings.iter().map(d => d.message).to_array().join("; "),
        )
      }
    }
    for mode in [@svg.Mode::Fixed(Dark), @svg.Mode::Fixed(Light)] {
      let output = @render.Renderer::render(
        @svg.SvgRenderer::new(mode~),
        Flowchart(model),
      )
      if output.output == None {
        failures.push(
          fixture.name +
          " SVG: " +
          output.diagnostics.iter().map(d => d.message).to_array().join("; "),
        )
      }
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
}
