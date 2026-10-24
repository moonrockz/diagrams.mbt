///|
pub struct Conversion { diagram : @render.Diagram?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq, Debug)

///|
pub extend Conversion with Eq::{equal, not_equal}

///|
pub extend Conversion with @debug.Debug::{to_repr}

///|
fn number(e : @bpmn.Element, key : String) -> Int? {
  guard e.attribute(key) is Some(s) else { return None }
  try Some(@string.parse_int(s)) catch { _ => None }
}

///|
/// First-slice conversion: exactly one process and one complete DI plane.
/// Unsupported or incomplete input gives no apparently complete diagram.
pub fn to_diagram(doc : @bpmn.Document) -> Conversion {
  let findings : Array[@diagrams.Diagnostic] = []
  fn error(code : String, message : String) -> Unit { findings.push(@diagrams.Diagnostic::error(code, message)) }
  let processes = doc.root.children.filter(e => e.kind == Process).iter().to_array()
  let planes : Array[@bpmn.Element] = []
  doc.walk(e => { if e.kind == Plane { planes.push(e) } })
  if processes.length() != 1 || planes.length() != 1 {
    error("bpmn/unsupported-view", "The first slice requires one process and one complete DI plane")
    return { diagram: None, diagnostics: ReadOnlyArray::from_array(findings) }
  }
  let process = processes[0]
  let plane = planes[0]
  if process.attribute("id") == None || plane.attribute("bpmnElement") != process.attribute("id") { error("bpmn/invalid-reference", "Plane must refer to the selected process") }
  let ids : Array[String] = []
  let nodes : Array[@model.Node] = []
  let flows : Array[@model.Flow] = []
  for element in process.children {
    guard element.attribute("id") is Some(id) else { error("bpmn/missing-id", "Graphical elements need IDs in this slice"); continue }
    if ids.contains(id) { error("bpmn/duplicate-id", "Duplicate element ID: \{id}") }
    ids.push(id)
    match element.kind {
      StartEvent | Task | EndEvent => {
        if element.attributes.iter().any(a => a.0 != "id" && a.0 != "name") || element.children.iter().any(c => c.kind != Incoming && c.kind != Outgoing) {
          error("bpmn/unsupported-view", "Task/event markers and nested content need the complete renderer")
        }
        let shapes = plane.children.filter(e => e.kind == Shape && e.attribute("bpmnElement") == Some(id)).iter().to_array()
        guard shapes.length() == 1 && shapes[0].children.length() == 1 && shapes[0].children[0].kind == Bounds else { error("bpmn/incomplete-di", "One bound is required for \{id}"); continue }
        let bounds = shapes[0].children[0]
        guard number(bounds, "x") is Some(x) && number(bounds, "y") is Some(y) && number(bounds, "width") is Some(width) && number(bounds, "height") is Some(height) && width > 0 && height > 0 && x >= 0 && y >= 0 && x <= 1000000 - width && y <= 1000000 - height else { error("bpmn/invalid-geometry", "This slice needs bounded nonnegative integer geometry for \{id}"); continue }
        if element.kind != Task && width != height { error("bpmn/invalid-geometry", "Event bounds must be square") }
        let kind = match element.kind { StartEvent => @model.NodeKind::StartEvent; EndEvent => @model.NodeKind::EndEvent; _ => @model.NodeKind::Task }
        nodes.push(@model.Node::new(id, kind, { x, y, width, height }, label=element.attribute("name").unwrap_or("")))
      }
      SequenceFlow => {
        let edges = plane.children.filter(e => e.kind == Edge && e.attribute("bpmnElement") == Some(id)).iter().to_array()
        guard edges.length() == 1 else { error("bpmn/incomplete-di", "One DI edge is required for \{id}"); continue }
        let points : Array[@model.Point] = []
        for point in edges[0].children {
          if point.kind == Waypoint && number(point, "x") is Some(x) && number(point, "y") is Some(y) && x >= 0 && y >= 0 && x <= 1000000 && y <= 1000000 { points.push({ x, y }) }
          else { error("bpmn/invalid-geometry", "Invalid waypoint for \{id}") }
        }
        if points.length() < 2 { error("bpmn/incomplete-di", "Two waypoints are required for \{id}") }
        guard element.attribute("sourceRef") is Some(source) && element.attribute("targetRef") is Some(target) else { error("bpmn/invalid-reference", "Missing flow endpoint for \{id}"); continue }
        if element.attribute("name") != None || !element.children.is_empty() { error("bpmn/unsupported-view", "Flow labels and expressions need the complete renderer") }
        flows.push(@model.Flow::new(id, source, target, points))
      }
      _ => error("bpmn/unsupported-view", "Unsupported process child: \{element.kind.local_name()}")
    }
  }
  if plane.children.length() != nodes.length() + flows.length() {
    error("bpmn/unsupported-view", "Every selected DI element must have one supported graphical element")
  }
  for flow in flows {
    if !nodes.iter().any(n => n.id == flow.source) || !nodes.iter().any(n => n.id == flow.target) { error("bpmn/invalid-reference", "Invalid endpoint on \{flow.id}") }
  }
  let diagram = if findings.is_empty() { Some(@render.Diagram::Bpmn(@model.Bpmn::new(process.attribute("id").unwrap(), nodes, flows))) } else { None }
  { diagram, diagnostics: ReadOnlyArray::from_array(findings) }
}

///|
/// Read, convert, and render the first supported BPMN view.
pub fn render_svg(source : String) -> @render.Rendered {
  let read = @bpmn.read(source)
  guard read.document is Some(doc) else {
    return @render.Rendered::failed("image/svg+xml", read.diagnostics.map(d => @diagrams.Diagnostic::error(d.code, d.message)))
  }
  let converted = to_diagram(doc)
  match converted.diagram {
    Some(diagram) => @svg.SvgRenderer::new().render(diagram)
    None => @render.Rendered::failed("image/svg+xml", converted.diagnostics)
  }
}
