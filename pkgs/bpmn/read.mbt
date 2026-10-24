///|
/// Read decoded XML without resource access. CST reproduction remains available
/// after errors or limit exhaustion; a syntax error prevents typed lowering.
pub fn read(source : String, source_id? : String, limits? : Limits = Limits::new()) -> ReadResult {
  let invalid = limits.source_units <= 0 || limits.output_units <= 0 || limits.nodes <= 0 || limits.depth <= 0 || limits.token_units <= 0 || limits.diagnostics <= 0
  if invalid || source.length() > limits.source_units {
    let code = if invalid { "xml/invalid-limits" } else { "xml/source-limit" }
    let diagnostic = if invalid { finding(code, "All processing limits must be positive") }
    else {
      let point = Position::{ offset: 0, line: 1, column: 1 }
      Diagnostic::{ code, severity: Error, message: "Source exceeds its configured UTF-16 limit", span: Some({ start: 0, end: 0 }), location: Some({ source_id, start: point, end: point }) }
    }
    let tokens : ReadOnlyArray[Token] = if source.is_empty() { [] } else { [{ kind: Error, text: source, span: { start: 0, end: source.length() } }] }
    return { tree: { tokens, nodes: [], complete: false }, document: None, source_map: None, diagnostics: [diagnostic] }
  }
  let map = source_map(source, source_id)
  let (tree, diagnostics) = parse_xml(source, map, limits)
  let document = if tree.complete { lower_minimal(tree, map, diagnostics, limits.diagnostics) } else { None }
  { tree, document, source_map: Some(map), diagnostics: ReadOnlyArray::from_array(diagnostics) }
}
