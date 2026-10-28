///|
test "every supported frozen vector flowchart has legible fixed-theme SVG" {
  let failures = []
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    let model = @conversion.to_flowchart(@syntax.read(source).ast.unwrap()).flowchart.unwrap()
    if model.nodes
      .iter()
      .any(node => !@model.built_in_shapes.contains(node.shape)) {
      let output = @render.Renderer::render(
        @svg.SvgRenderer::new(),
        Flowchart(model),
      )
      if output.output != None {
        failures.push(name + " unsupported shape produced SVG")
      }
      continue
    }
    let geometry = @layout.layout(model)
    guard geometry.geometry is Some(drawing) else {
      failures.push(
        name +
        " layout: " +
        geometry.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
      continue
    }
    for palette in [@theme.Theme::classic().dark, @theme.Theme::classic().light] {
      let findings = @layout.check(drawing, palette)
      if !findings.is_empty() {
        failures.push(
          name +
          " legibility: " +
          findings.iter().map(d => d.message).to_array().join("; "),
        )
      }
    }
    let output = @render.Renderer::render(
      @svg.SvgRenderer::new(),
      Flowchart(model),
    )
    if output.output == None {
      failures.push(
        name +
        " SVG: " +
        output.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
}
