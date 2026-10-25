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
    let svg = if parsed.ast is Some(Swimlane(ast)) {
      let converted = @native_mermaid.to_swimlane(ast)
      let errors = parsed.diagnostics
        .iter()
        .concat(converted.diagnostics.iter())
        .filter(d => d.severity == Error)
        .to_array()
      if !errors.is_empty() || converted.swimlane == None {
        problems.push(
          @model.problem(
            file,
            "Mermaid diagram \{index} does not render: \{errors.iter().map(d => d.code+": "+d.message).to_array().join("; ")}",
          ),
        )
        ""
      } else {
        let rendered = @svg.SvgRenderer::new(
          id_prefix="site-swimlane-" + index.to_string(),
        ).render(Swimlane(converted.swimlane.unwrap()))
        match rendered.output {
          Some(svg) => svg
          None => {
            problems.push(
              @model.problem(
                file,
                "Mermaid diagram \{index} does not render: \{rendered.diagnostics.iter().map(d => d.code+": "+d.message).to_array().join("; ")}",
              ),
            )
            ""
          }
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
