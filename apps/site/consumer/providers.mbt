// Consumer-owned compiled diagram providers, Apache-2.0.

///|
fn output(svg : String, source : String) -> @extensions.RenderOutput {
  {
    body_html: "<figure class=\"diagram\">\{svg}</figure>",
    text: source,
    headings: [],
    assets: [],
    problems: [],
  }
}

///|
fn render_mermaid(
  input : @extensions.RenderInput,
) -> Result[@extensions.RenderOutput, @extensions.AdapterError] {
  let parsed = @native_mermaid.read_diagram(input.body)
  let native_kind = match parsed.tree {
    Swimlane(_) | Zenuml(_) | Architecture(_) => true
    _ => false
  }
  if !native_kind {
    return Ok(output(@mermaid.render_mermaid(input.body), input.body)) catch {
      error =>
        Err({
          stage: "render",
          message: "Mermaid diagram \{input.ordinal} does not render: \{error}",
        })
    }
  }
  let diagnostics = parsed.diagnostics.iter().to_array()
  let model = match parsed.ast {
    Some(Swimlane(ast)) => {
      let result = @native_mermaid.to_swimlane(ast)
      diagnostics.append(result.diagnostics)
      result.swimlane.map(model => @render.Diagram::Swimlane(model))
    }
    Some(Zenuml(ast)) => {
      let result = @native_mermaid.to_zenuml_sequence(ast)
      diagnostics.append(result.diagnostics)
      result.sequence.map(model => @render.Diagram::Sequence(model))
    }
    Some(Architecture(ast)) => {
      let result = @native_mermaid.to_architecture(ast)
      diagnostics.append(result.diagnostics)
      result.architecture.map(model => @render.Diagram::Architecture(model))
    }
    _ => None
  }
  if !diagnostics.iter().any(d => d.severity == Error) {
    if model is Some(model) {
      let prefix = if model is Swimlane(_) {
        "site-swimlane-"
      } else {
        "site-mermaid-"
      }
      let rendered = @svg.SvgRenderer::new(
        id_prefix=prefix + input.ordinal.to_string(),
      ).render(model)
      diagnostics.append(rendered.diagnostics)
      if rendered.output is Some(svg) {
        return Ok(output(svg, input.body))
      }
    }
  }
  Err({
    stage: "render",
    message: "Mermaid diagram \{input.ordinal} does not render: " +
    diagnostics.iter().map(d => d.code + ": " + d.message).to_array().join("; "),
  })
}

///|
fn render_plantuml(
  input : @extensions.RenderInput,
) -> Result[@extensions.RenderOutput, @extensions.AdapterError] {
  let rendered = @plantuml.render_svg(
    input.body,
    renderer=@svg.SvgRenderer::new(
      id_prefix="site-plantuml-" + input.ordinal.to_string(),
    ),
  )
  let errors = rendered.diagnostics
    .iter()
    .filter(d => d.severity == Error)
    .map(d => d.code + ": " + d.message)
    .to_array()
  match rendered.output {
    Some(svg) if errors.is_empty() => Ok(output(svg, input.body))
    _ =>
      Err({
        stage: "render",
        message: "PlantUML diagram \{input.ordinal} does not render: " +
        errors.join("; "),
      })
  }
}

///|
fn providers() -> @extensions.Registry {
  {
    pages: [],
    islands: [],
    fences: [
      {
        id: "diagrams-mermaid",
        contract_version: 1,
        labels: ["mermaid"],
        render: render_mermaid,
      },
      {
        id: "diagrams-plantuml",
        contract_version: 1,
        labels: ["plantuml", "puml"],
        render: render_plantuml,
      },
    ],
  }
}
