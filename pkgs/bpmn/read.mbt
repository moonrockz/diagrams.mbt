///|
fn kind_of(name : ExpandedName) -> Kind? {
  for kind in [Definitions, Process, StartEvent, Task, EndEvent, SequenceFlow, Incoming, Outgoing, Diagram, Plane, Shape, Edge, Bounds, Waypoint] {
    if name.local_name == kind.local_name() && name.namespace_uri == kind.namespace_uri() { return Some(kind) }
  }
  None
}

///|
/// Typed lowering remains separate from complete XML reading. Later stories add
/// schema-derived BPMN families; unsupported content remains inspectable in CST.
fn lower_minimal(tree : Cst, map : SourceMap, diagnostics : Array[Diagnostic], maximum : Int) -> Document? {
  let lowered : Array[Element?] = Array::make(tree.nodes.length(), None)
  let mut exhausted = false
  fn report(code : String, message : String, span : Span) -> Unit {
    if diagnostics.length() < maximum { diagnostics.push(finding(code, message, span~, map~)) }
    else if !exhausted { diagnostics[maximum-1] = finding("xml/diagnostic-limit", "Diagnostic limit exceeded during typed lowering", span~, map~); exhausted = true }
  }
  for i = tree.nodes.length()-1; i > 0; i = i-1 {
    if exhausted { break }
    let node = tree.nodes[i]
    if node.kind != Element { continue }
    guard node.name is Some(name) && kind_of(name) is Some(kind) else {
      report("bpmn/unsupported-element", "Unsupported BPMN element: \{node.raw_name}", node.span)
      continue
    }
    let attrs : Array[(String, String)] = []
    for attr in node.attributes {
      if exhausted { break }
      if attr.namespace_declaration { continue }
      if attr.name.namespace_uri != "" { report("bpmn/unsupported-attribute", "Typed namespaced fields follow in the document foundations", attr.span) }
      else { attrs.push((attr.name.local_name, attr.value)) }
    }
    let children : Array[Element] = []
    let content = StringBuilder()
    for child in node.children {
      if exhausted { break }
      let child_node = tree.nodes[child]
      if lowered[child] is Some(e) { children.push(e) }
      else if child_node.kind == Text || child_node.kind == CData {
        if kind == Incoming || kind == Outgoing { content.write_string(child_node.value) }
        else if !child_node.value.iter().all(c => space(c.to_int())) { report("bpmn/unsupported-content", "Typed mixed content follows in the document foundations", child_node.span) }
      }
    }
    lowered[i] = Some(Element::new(kind, attributes=attrs, children~, content=content.to_string()))
  }
  let roots = tree.nodes[0].children.filter(i => tree.nodes[i].kind == Element).iter().to_array()
  guard roots.length() == 1 && lowered[roots[0]] is Some(root) && root.kind == Definitions else {
    report("bpmn/definitions-required", "One BPMN definitions root is required", tree.nodes[0].span)
    return None
  }
  if diagnostics.is_empty() { Some(Document::new(root)) } else { None }
}

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
