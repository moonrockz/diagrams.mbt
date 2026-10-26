///|
/// The result of the Mermaid pass over one page.
pub(all) struct MermaidPass {
  html : String
  /// One problem for each diagram that does not render.
  problems : Array[@model.Problem]
}

///|
let mermaid_open : String = "<pre><code class=\"language-mermaid\">"

///|
let mermaid_close : String = "</code></pre>"

///|
/// Replace each Mermaid code block with an inline SVG in a `figure.diagram`. A diagram that does
/// not render gives a problem with the file and the diagram number. There is no client renderer.
pub fn render_mermaid_blocks(file : String, html : String) -> MermaidPass {
  let out = StringBuilder()
  let problems = []
  let mut rest = html[:]
  let mut index = 0
  while rest.find(mermaid_open) is Some(start) {
    let body = rest[start + mermaid_open.length():]
    guard body.find(mermaid_close) is Some(end) else { break }
    index += 1
    out.write_view(rest[:start])
    let source = unescape(body[:end].to_owned())
    let parsed = @native_mermaid.read_diagram(source)
    let native_kind = match parsed.tree {
      Swimlane(_) | Zenuml(_) | Architecture(_) => true
      _ => false
    }
    let svg = if native_kind {
      let diagnostics = parsed.diagnostics.iter().to_array()
      let model = match parsed.ast {
        Some(Swimlane(ast)) => {
          let result = @native_mermaid.to_swimlane(ast)
          for d in result.diagnostics {
            diagnostics.push(d)
          }
          result.swimlane.map(model => @render.Diagram::Swimlane(model))
        }
        Some(Zenuml(ast)) => {
          let result = @native_mermaid.to_zenuml_sequence(ast)
          for d in result.diagnostics {
            diagnostics.push(d)
          }
          result.sequence.map(model => @render.Diagram::Sequence(model))
        }
        Some(Architecture(ast)) => {
          let result = @native_mermaid.to_architecture(ast)
          for d in result.diagnostics {
            diagnostics.push(d)
          }
          result.architecture.map(model => @render.Diagram::Architecture(model))
        }
        _ => None
      }
      let mut output = None
      if !diagnostics.iter().any(d => d.severity == Error) {
        if model is Some(model) {
          let prefix = if model is Swimlane(_) {
            "site-swimlane-"
          } else {
            "site-mermaid-"
          }
          let rendered = @svg.SvgRenderer::new(
            id_prefix=prefix + index.to_string(),
          ).render(model)
          for d in rendered.diagnostics {
            diagnostics.push(d)
          }
          output = rendered.output
        }
      }
      match output {
        Some(svg) => svg
        None => {
          problems.push(
            @model.problem(
              file,
              "Mermaid diagram \{index} does not render: \{diagnostics.iter().map(d => d.code+": "+d.message).to_array().join("; ")}",
            ),
          )
          ""
        }
      }
    } else {
      @mermaid.render_mermaid(source) catch {
        error => {
          problems.push(
            @model.problem(
              file,
              "Mermaid diagram \{index} does not render: \{error}",
            ),
          )
          ""
        }
      }
    }
    out.write_string("<figure class=\"diagram\">\{svg}</figure>")
    rest = body[end + mermaid_close.length():]
  }
  out.write_view(rest)
  { html: out.to_string(), problems, }
}
