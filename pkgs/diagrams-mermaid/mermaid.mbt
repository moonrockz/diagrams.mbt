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
  { tree: parsed.tree, ast: @ast.lower(parsed.tree), diagnostics: parsed.diagnostics }
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
  let r = read(source)
  let diagnostics = r.diagnostics.iter().to_array()
  guard r.ast is Some(ast) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let c = to_sequence(ast)
  for d in c.diagnostics {
    diagnostics.push(d)
  }
  let rendered = @render.Renderer::render(@svg.SvgRenderer::new(), Sequence(c.sequence))
  for d in rendered.diagnostics {
    diagnostics.push(d)
  }
  @render.Rendered::ok(rendered.output.unwrap_or(""), "image/svg+xml", diagnostics~)
}

///|
/// Every diagnostic code that reading can give.
pub let diagnostic_codes : ReadOnlyArray[String] = @syntax.diagnostic_codes
