///|
/// A deterministic path from the authored DI waypoints.
pub fn bpmn_path(flow : @bpmn.Flow) -> String {
  let b = StringBuilder()
  for i, p in flow.points { b.write_string("\{if i == 0 { "M" } else { " L" }}\{p.x} \{p.y}") }
  b.to_string()
}

///|
fn paint_bpmn(view : @bpmn.Bpmn, theme : @theme.Theme, mode : Mode, id_prefix : String?) -> @render.Rendered {
  // The full painter is the next story. Never downgrade a converted kind or
  // marker to the original generic task/event notation.
  if view.nodes.iter().any(n => (n.kind != Task && n.kind != StartEvent && n.kind != EndEvent) || (n.markers.called_kind != None || n.markers.loop_kind != None || n.markers.compensation || n.markers.event_subprocess || !n.markers.interrupting || n.markers.parallel_multiple || n.markers.collection || n.markers.instantiate || !n.markers.events.is_empty()) || n.ownership != @bpmn.Ownership::new()) || view.flows.iter().any(f => f.kind != SequenceFlow || !f.label.is_empty() || f.condition != None || f.is_default) {
    return @render.Rendered::failed("image/svg+xml", [@diagrams.Diagnostic::error("bpmn/unsupported-view", "This view needs the complete BPMN painter")])
  }
  let paint = Paint::{ theme, mode }
  let mut width = 1
  let mut height = 1
  let ids : Array[String] = []
  for n in view.nodes {
    let r = n.bounds
    if ids.contains(n.id) || r.x < 0 || r.y < 0 || r.width <= 0 || r.height <= 0 || r.width > 1000000 || r.height > 1000000 || r.x > 1000000 - r.width || r.y > 1000000 - r.height || (n.kind != Task && r.width != r.height) {
      return @render.Rendered::failed("image/svg+xml", [@diagrams.Diagnostic::error("bpmn/invalid-geometry", "Invalid or duplicate shape \{n.id}")])
    }
    ids.push(n.id)
    width = Int::max(width, r.x + r.width + 32)
    height = Int::max(height, r.y + r.height + 32)
  }
  for f in view.flows {
    if ids.contains(f.id) || f.points.length() < 2 || !view.nodes.iter().any(n => n.id == f.source) || !view.nodes.iter().any(n => n.id == f.target) {
      return @render.Rendered::failed("image/svg+xml", [@diagrams.Diagnostic::error("bpmn/invalid-reference", "Invalid or duplicate flow \{f.id}")])
    }
    ids.push(f.id)
    for p in f.points {
      if p.x < 0 || p.y < 0 || p.x > 1000000 || p.y > 1000000 {
        return @render.Rendered::failed("image/svg+xml", [@diagrams.Diagnostic::error("bpmn/invalid-geometry", "Invalid waypoint")])
      }
      width = Int::max(width, p.x + 32); height = Int::max(height, p.y + 32)
    }
  }
  let children = [@writer.element("title", children=[@writer.text(view.id)]), @writer.element("desc", children=[@writer.text("BPMN process. Flow animation is illustrative; conditions and execution are not evaluated.")])]
  let arrow = paint.color("arrow")
  let definitions = [marker("head", Arrow, arrow, false)]
  if mode == Adaptive { definitions.push(@writer.element("style", children=[@writer.text(style_sheet(theme))])) }
  children.push(@writer.element("defs", children=definitions))
  children.push(@writer.element("rect", attrs=[("class", "bg"), ("width", width.to_string()), ("height", height.to_string()), ("fill", paint.color("bg"))]))
  for i, flow in view.flows {
    children.push(@writer.element("path", attrs=[("id", "flow-\{i}"), ("class", "bpmn-flow"), ("data-source-id", flow.id), ("d", bpmn_path(flow)), ("fill", "none"), ("stroke", arrow), ("stroke-width", "1.5"), ("marker-end", "url(#head)")]))
  }
  for i, node in view.nodes {
    let r = node.bounds
    let attrs = [("id", "node-\{i}"), ("data-source-id", node.id)]
    let shapes : Array[@writer.Node] = []
    if node.kind == Task {
      shapes.push(@writer.element("rect", attrs=[("x", r.x.to_string()), ("y", r.y.to_string()), ("width", r.width.to_string()), ("height", r.height.to_string()), ("rx", "10"), ("fill", paint.color("backend-fill")), ("stroke", paint.color("backend-stroke")), ("stroke-width", "1.5")]))
    } else {
      shapes.push(@writer.element("circle", attrs=[("cx", (r.x+r.width/2).to_string()), ("cy", (r.y+r.height/2).to_string()), ("r", (r.width/2).to_string()), ("fill", paint.color("bg")), ("stroke", arrow), ("stroke-width", if node.kind == EndEvent { "4" } else { "1.5" })]))
    }
    if !node.label.is_empty() {
      shapes.push(@writer.element("text", attrs=[("x", (r.x+r.width/2).to_string()), ("y", (r.y+r.height/2+4).to_string()), ("text-anchor", "middle"), ("font-family", font_stack), ("font-size", "13"), ("fill", paint.color("text"))], children=[@writer.text(node.label)]))
    }
    children.push(@writer.element("g", attrs~, children=shapes))
  }
  let root = @writer.element("svg", attrs=[("xmlns", "http://www.w3.org/2000/svg"), ("viewBox", "0 0 \{width} \{height}"), ("role", "img")], children~)
  let mut hash : UInt64 = 14695981039346656037
  let source = @writer.to_string(root)
  for i in 0..<source.length() { hash = (hash ^ source.code_unit_at(i).to_int().to_uint64()) * 1099511628211 }
  let prefix = match id_prefix {
    Some(s) => {
      let b = StringBuilder()
      for c in s { b.write_string("\{c.to_int().to_string(radix=16)}-") }
      "bpmn-u-\{b.to_string()}"
    }
    None => "bpmn-\{hash.to_string(radix=16)}-"
  }
  @render.Rendered::ok(@writer.to_string(scope_svg(root, prefix, theme)), "image/svg+xml")
}
