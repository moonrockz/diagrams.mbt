///|
/// The result of the PlantUML pass over one page.
pub(all) struct PlantumlPass {
  html : String
  /// One problem for each diagram that does not render.
  problems : Array[@model.Problem]
}

///|
let plantuml_fences : Array[String] = [
  "<pre><code class=\"language-plantuml\">", "<pre><code class=\"language-puml\">",
]

///|
let plantuml_close : String = "</code></pre>"

///|
/// Replace each `plantuml` or `puml` code block with an inline SVG in a
/// `figure.diagram`. The native library reads regex, EBNF, JSON and YAML
/// blocks at build time. Each diagram has its own identifier prefix. A
/// diagram that does not render gives a problem with the file and the
/// diagram number. Ordinary `json`, `yaml`, `regex` and `ebnf` code blocks
/// stay code.
pub fn render_plantuml_blocks(file : String, html : String) -> PlantumlPass {
  let out = StringBuilder()
  let problems = []
  let mut rest = html[:]
  let mut index = 0
  while true {
    let mut first : (Int, Int)? = None
    for fence in plantuml_fences {
      if rest.find(fence) is Some(at) {
        match first {
          Some((best, _)) if best <= at => ()
          _ => first = Some((at, fence.length()))
        }
      }
    }
    guard first is Some((start, width)) else { break }
    let body = rest[start + width:]
    guard body.find(plantuml_close) is Some(end) else { break }
    index += 1
    out.write_view(rest[:start])
    let source = unescape(body[:end].to_owned())
    let rendered = @plantuml.render_svg(
      source,
      renderer=@svg.SvgRenderer::new(id_prefix="site-plantuml-" + index.to_string()),
    )
    let errors = rendered.diagnostics
      .iter()
      .filter(d => d.severity == Error)
      .map(d => d.code + ": " + d.message)
      .to_array()
    match rendered.output {
      Some(svg) if errors.is_empty() =>
        out.write_string("<figure class=\"diagram\">\{svg}</figure>")
      _ =>
        problems.push(
          @model.problem(
            file,
            "PlantUML diagram \{index} does not render: \{errors.join("; ")}",
          ),
        )
    }
    rest = body[end + plantuml_close.length():]
  }
  out.write_view(rest)
  { html: out.to_string(), problems }
}
