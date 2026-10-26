///|
/// The pinned PlantUML version whose native behavior this library follows.
pub let plantuml_version : String = "1.2026.9"

///|
/// The source commit of the pinned PlantUML version.
pub let plantuml_commit : String = "18d0aae311a4f1eb3723bb4b0ad939185e22f166"

///|
/// One parsed native block of a supported kind.
pub(all) enum Document {
  Regex(@regex_syntax.Document)
  Ebnf(@ebnf_syntax.Document)
  Json(@json_syntax.Document)
  Yaml(@yaml_syntax.Document)
} derive(Eq, Debug)

///|
pub extend Document with Eq::{not_equal, equal}

///|
pub extend Document with @debug.Debug::{to_repr}

///|
pub fn Document::kind(self : Document) -> @envelope.Kind {
  match self {
    Regex(_) => Regex
    Ebnf(_) => Ebnf
    Json(_) => Json
    Yaml(_) => Yaml
  }
}

///|
/// The result of reading. `tree` reproduces every input code unit; `document`
/// is absent when an error was found.
pub struct ReadResult {
  tree : @cst.Node
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn finish(
  scan : @envelope.Scan,
  nodes : Array[@cst.Node],
  document : Document?,
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic],
) -> ReadResult {
  { tree: scan.document(nodes), document, diagnostics }
}

///|
fn read_scan(scan : @envelope.Scan, limits : @envelope.Limits) -> ReadResult {
  match scan.kind {
    Some(Regex) => {
      let r = @regex_syntax.read(scan, limits~)
      finish(scan, r.nodes, r.document.map(d => Regex(d)), r.diagnostics)
    }
    Some(Ebnf) => {
      let r = @ebnf_syntax.read(scan, limits~)
      finish(scan, r.nodes, r.document.map(d => Ebnf(d)), r.diagnostics)
    }
    Some(Json) => {
      let r = @json_syntax.read(scan, limits~)
      finish(scan, r.nodes, r.document.map(d => Json(d)), r.diagnostics)
    }
    Some(Yaml) => {
      let r = @yaml_syntax.read(scan, limits~)
      finish(scan, r.nodes, r.document.map(d => Yaml(d)), r.diagnostics)
    }
    _ => {
      let nodes = scan.line_nodes(line => Some(@cst.Node::new(Error, line.tokens(Error))))
      let diagnostics = scan.diagnostics.iter().collect()
      if !diagnostics.iter().any(d => d.severity == Error) {
        diagnostics.push(
          @diagrams.Diagnostic::error(
            "plantuml/unsupported-diagram", "Expected @startregex, @startebnf, @startjson or @startyaml",
          ),
        )
      }
      finish(scan, nodes, None, ReadOnlyArray::from_array(diagnostics))
    }
  }
}

///|
/// Read one native block: `@startregex`, `@startebnf`, `@startjson` or
/// `@startyaml` with its matching end marker. Other kinds, extra blocks and
/// text outside the block are errors.
pub fn read(
  source : String,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  read_scan(@envelope.scan(source, limits~), limits)
}

///|
/// Read a raw body of an explicit kind, without block markers.
pub fn read_body(
  kind : @envelope.Kind,
  body : String,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> ReadResult {
  read_scan(@envelope.scan_body(kind, body, limits~), limits)
}

///|
pub struct PrintResult {
  output : String?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub extend PrintResult with Eq::{not_equal, equal}

///|
pub extend PrintResult with @debug.Debug::{to_repr}

///|
fn statements_of(document : Document) -> ReadOnlyArray[@envelope.Statement] {
  match document {
    Regex(d) => d.statements
    Ebnf(d) => d.statements
    Json(d) => d.statements
    Yaml(d) => d.statements
  }
}

///|
fn name_of(document : Document) -> String? {
  match document {
    Regex(d) => d.name
    Ebnf(d) => d.name
    Json(d) => d.name
    Yaml(d) => d.name
  }
}

///|
/// Write only the body of a document, from its typed values.
pub fn print_body(
  document : Document,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> PrintResult {
  let result = match document {
    Regex(d) => @regex_syntax.print_body(d, limits~)
    Ebnf(d) => @ebnf_syntax.print_body(d, limits~)
    Json(d) => @json_syntax.print_body(d, limits~)
    Yaml(d) => @yaml_syntax.print_body(d, limits~)
  }
  match result {
    Ok(text) => { output: Some(text), diagnostics: [] }
    Err(diagnostics) => { output: None, diagnostics }
  }
}

///|
/// Write a complete native block: start marker, retained statements, the
/// body and the end marker. The output limit applies to the whole text.
pub fn print(
  document : Document,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> PrintResult {
  let body = print_body(document, limits~)
  guard body.output is Some(text) else { return body }
  let word = document.kind().word()
  let out = StringBuilder()
  out.write_string("@start" + word)
  if name_of(document) is Some(name) {
    out.write_string(" " + name)
  }
  out.write_char('\n')
  for statement in statements_of(document) {
    for line in statement.lines() {
      out.write_string(line)
      out.write_char('\n')
    }
  }
  out.write_string(text)
  out.write_string("@end" + word + "\n")
  let output = out.to_string()
  if output.length() > limits.output {
    return {
      output: None,
      diagnostics: [
        @diagrams.Diagnostic::error("plantuml/print-limit", "Output limit exceeded"),
      ],
    }
  }
  { output: Some(output), diagnostics: [] }
}

///|
pub struct Conversion {
  diagram : @render.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert a document to its format-independent model.
pub fn to_diagram(
  document : Document,
  id? : String,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  match document {
    Regex(d) => {
      let c = @regex_syntax.to_regex(d, id=id.unwrap_or("regex"), limits~)
      { diagram: c.regex.map(m => Regex(m)), diagnostics: c.diagnostics }
    }
    Ebnf(d) => {
      let c = @ebnf_syntax.to_grammar(d, id=id.unwrap_or("ebnf"), limits~)
      { diagram: c.grammar.map(g => Ebnf(g)), diagnostics: c.diagnostics }
    }
    Json(d) => {
      let c = @json_syntax.to_data_tree(d, id=id.unwrap_or("json"), limits~)
      { diagram: c.tree.map(t => DataTree(t)), diagnostics: c.diagnostics }
    }
    Yaml(d) => {
      let c = @yaml_syntax.to_data_tree(d, id=id.unwrap_or("yaml"), limits~)
      { diagram: c.tree.map(t => DataTree(t)), diagnostics: c.diagnostics }
    }
  }
}

///|
/// Read, convert and render one native block as standalone SVG with the
/// options of `renderer`, including any supplied trace highlights.
/// Diagnostics accumulate; any error gives no output.
pub fn render_svg(
  source : String,
  renderer? : @svg.SvgRenderer = @svg.SvgRenderer::new(),
  limits? : @envelope.Limits = @envelope.Limits::new(),
  id? : String,
) -> @render.Rendered {
  let read = read(source, limits~)
  let diagnostics = read.diagnostics.iter().collect()
  guard read.document is Some(document) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let converted = to_diagram(document, id?, limits~)
  diagnostics.append(converted.diagnostics.iter().collect())
  guard converted.diagram is Some(diagram) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let rendered = @render.Renderer::render(renderer, diagram)
  diagnostics.append(rendered.diagnostics.iter().collect())
  match rendered.output {
    Some(output) => @render.Rendered::ok(output, "image/svg+xml", diagnostics~)
    None => @render.Rendered::failed("image/svg+xml", diagnostics)
  }
}

///|
/// Read and convert one regex or EBNF block, invoke `provider` once for
/// `input` and render the validated trace. `start_rule` names an EBNF start
/// rule by its rule name. This is the only PlantUML entry point that calls a
/// provider.
pub fn[P : @railroad_trace.RailroadTraceProvider] render_traced_svg(
  source : String,
  provider : P,
  input : String,
  start_rule? : String,
  renderer? : @svg.SvgRenderer = @svg.SvgRenderer::new(),
  limits? : @envelope.Limits = @envelope.Limits::new(),
  trace_limits? : @railroad_trace.TraceLimits = @railroad_trace.TraceLimits::new(),
  matched? : @svg.ChannelStyle = @svg.ChannelStyle::new(),
  not_matched? : @svg.ChannelStyle = @svg.ChannelStyle::new(dashed=true),
  taken? : @svg.ChannelStyle = @svg.ChannelStyle::hidden(),
  failure? : @svg.ChannelStyle = @svg.ChannelStyle::new(),
) -> @svg.TracedRender {
  fn refused(diagnostics : ArrayView[@diagrams.Diagnostic]) -> @svg.TracedRender {
    @svg.TracedRender::refused(diagnostics)
  }
  let read = read(source, limits~)
  guard read.document is Some(document) else { return refused(read.diagnostics) }
  let converted = to_diagram(document, limits~)
  guard converted.diagram is Some(diagram) else {
    return refused(converted.diagnostics)
  }
  let rule_id = match (diagram, start_rule) {
    (Ebnf(grammar), Some(name)) => {
      let ids = grammar.rules().filter(r => r.name == name).map(r => r.id)
      match ids {
        [id] => Some(id)
        [] =>
          return refused([
            @diagrams.Diagnostic::error(
              "trace/invalid-request", "No rule is named '\{name}'",
            ),
          ])
        _ =>
          return refused([
            @diagrams.Diagnostic::error(
              "trace/invalid-request", "More than one rule is named '\{name}'",
            ),
          ])
      }
    }
    _ => None
  }
  renderer.render_traced(
    diagram,
    provider,
    input,
    start_rule?=rule_id,
    limits=trace_limits,
    matched~,
    not_matched~,
    taken~,
    failure~,
  )
}

///|
/// The stable diagnostic codes of the PlantUML module.
pub let diagnostic_codes : ReadOnlyArray[String] = ReadOnlyArray::from_iter(
  @envelope.diagnostic_codes
  .iter()
  .concat(@regex_syntax.diagnostic_codes.iter())
  .concat(@ebnf_syntax.diagnostic_codes.iter())
  .concat(@json_syntax.diagnostic_codes.iter())
  .concat(@yaml_syntax.diagnostic_codes.iter())
  .concat(["plantuml/print-limit"].iter()),
)
