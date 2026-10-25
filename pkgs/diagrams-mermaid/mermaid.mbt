///|
/// The result of reading a Mermaid source: the lossless syntax tree, the
/// typed AST when the source has the `sequenceDiagram` header, and all
/// diagnostics.
pub struct ReadResult {
  tree : @cst.Node
  ast : @ast.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Read a Mermaid sequence diagram. The text of `tree` is always equal to
/// `source`.
pub fn read(source : String) -> ReadResult {
  let parsed = @syntax.parse(source)
  {
    tree: parsed.tree,
    ast: @ast.lower(parsed.tree),
    diagnostics: parsed.diagnostics,
  }
}

///|
/// Canonical Mermaid text of `diagram`.
pub fn print(diagram : @ast.Diagram) -> String {
  @printer.print(diagram)
}

///|
/// The sequence model of `diagram`, with the conversion diagnostics.
pub fn to_sequence(diagram : @ast.Diagram) -> @sequence.Conversion {
  @sequence.to_sequence(diagram)
}

///|
/// Read `source` and render it with archify's classic theme as adaptive SVG.
/// The result has the diagnostics of reading, converting and rendering. A
/// source without a diagram gives no output.
pub fn render_svg(source : String) -> @render.Rendered {
  let r = read_diagram(source)
  if r.ast == None &&
    r.diagnostics.iter().any(d => d.code == "mermaid/unsupported-diagram") {
    let legacy = read(source)
    if !legacy.diagnostics.is_empty() &&
      legacy.diagnostics.iter().all(d => d.code != "mermaid/unknown-statement") {
      return @render.Rendered::failed("image/svg+xml", legacy.diagnostics[:])
    }
  }
  let diagnostics = r.diagnostics.iter().to_array()
  if diagnostics.iter().any(d => d.severity == @diagrams.Severity::Error) {
    return @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
  guard r.ast is Some(ast) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
  let model = match ast {
    Sequence(ast) => {
      let converted = to_sequence(ast)
      for d in converted.diagnostics {
        diagnostics.push(d)
      }
      Some(@render.Diagram::Sequence(converted.sequence))
    }
    Swimlane(ast) => {
      let converted = to_swimlane(ast)
      for d in converted.diagnostics {
        diagnostics.push(d)
      }
      converted.swimlane.map(model => @render.Diagram::Swimlane(model))
    }
  }
  guard model is Some(model) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
  if diagnostics.iter().any(d => d.severity == @diagrams.Severity::Error) {
    return @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
  let rendered = @render.Renderer::render(@svg.SvgRenderer::new(), model)
  for d in rendered.diagnostics {
    diagnostics.push(d)
  }
  match rendered.output {
    Some(output) =>
      @render.Rendered::ok(output, "image/svg+xml", diagnostics=diagnostics[:])
    None => @render.Rendered::failed("image/svg+xml", diagnostics[:])
  }
}

///|
/// Every diagnostic code that reading can give.
pub let diagnostic_codes : ReadOnlyArray[String] = @syntax.diagnostic_codes

///|
/// Every diagnostic code that conversion can give. Reading uses
/// `diagnostic_codes`; link resolution uses `sequence/unresolved-link`.
pub let conversion_diagnostic_codes : ReadOnlyArray[String] = @sequence.diagnostic_codes
