///|
fn supplied_bounds(node : @model.Node) -> @model.ExactBounds? {
  match node.geometry {
    Some(g) => g.bounds
    None => {
      let r=node.bounds
      if r.x == 0 && r.y == 0 && r.width == 0 && r.height == 0 { None }
      else { Some(exact_bounds({x:r.x.to_double(),y:r.y.to_double(),width:r.width.to_double(),height:r.height.to_double()})) }
    }
  }
}

///|
fn supplied_points(flow : @model.Flow) -> Array[@model.ExactPoint] {
  match flow.geometry { Some(g) => g.points.iter().to_array(); None => flow.points.iter().map(p => exact_point({x:p.x.to_double(),y:p.y.to_double()})).to_array() }
}

///|
fn selected_flow(flow : @model.Flow, view : @model.Bpmn, input : Input, budget : Budget) -> (Int,Int)? {
  if !flow.has_source { return None }
  let source=input.nodes[flow.source]; let target=input.nodes[flow.target]
  if input.visible[source] && input.visible[target] { return Some((source,target)) }
  if flow.kind != MessageFlow { return None }
  match (visible_endpoint(flow.source,view,input,budget),visible_endpoint(flow.target,view,input,budget)) {
    (Some(s),Some(t)) if s != t => Some((s,t))
    _ => { budget.error("bpmn/invalid-reference","Message endpoints are hidden within one collapsed scope: \{flow.id}"); None }
  }
}

///|
fn charge_bounds(bounds : @model.ExactBounds, budget : Budget) -> Bool {
  for value in [bounds.x,bounds.y,bounds.width,bounds.height] { if !budget.charge(value.token.length()) { return false } }
  true
}

///|
fn supplied(view : @model.Bpmn, input : Input, budget : Budget) -> (Bool,Array[Shape],Array[Connection]) {
  let shapes=[]; let connections=[]; let mut complete=true
  for i,node in view.nodes {
    if !input.visible[i] { continue }
    if node.geometry.bind(g => g.bounds) is Some(r) && !charge_bounds(r,budget) { break }
    if node.geometry.bind(g => g.label).bind(l => l.bounds) is Some(r) && !charge_bounds(r,budget) { break }
    // Check optional supplied labels even if the required shape bound is absent.
    if node.geometry.bind(g => g.label).bind(l => l.bounds) is Some(r) && rectangle(r) == None { budget.error("bpmn/invalid-geometry","Invalid label bounds on \{node.id}") }
    if node.geometry.bind(g => g.label).bind(l => l.font) is Some(font) { ignore(font_size(font,budget)) }
    guard supplied_bounds(node) is Some(bounds) else { complete=false; continue }
    guard rectangle(bounds) is Some(box) else { budget.error("bpmn/invalid-geometry","Invalid shape bounds on \{node.id}"); continue }
    if event(node.kind) && (box.width-box.height).abs() > 0.001 { budget.error("bpmn/invalid-geometry","Event shape must be circular: \{node.id}") }
    shapes.push({node,index:i,bounds,box,label:node_label(node,box,true,budget)})
  }
  for i,flow in view.flows {
    guard selected_flow(flow,view,input,budget) is Some((source,target)) else { continue }
    if connections.length() >= budget.limits.edges { budget.error("bpmn/layout-limit","Visible connection limit exceeded"); break }
    let points=supplied_points(flow)
    if !budget.charge(points.length()) { break }
    let line=[]
    for p in points { if !budget.charge(p.x.token.length()) || !budget.charge(p.y.token.length()) { break }; match point(p) { Some(p) => line.push(p); None => budget.error("bpmn/invalid-geometry","Invalid waypoint on \{flow.id}") } }
    if flow.geometry.bind(g => g.label).bind(l => l.bounds) is Some(r) && !charge_bounds(r,budget) { break }
    if flow.geometry.bind(g => g.label).bind(l => l.bounds) is Some(r) && rectangle(r) == None { budget.error("bpmn/invalid-geometry","Invalid label bounds on \{flow.id}") }
    if flow.geometry.bind(g => g.label).bind(l => l.font) is Some(font) { ignore(font_size(font,budget)) }
    if points.length() < 2 { complete=false; continue }
    if line.length() != points.length() { continue }
    connections.push({flow,index:i,source:view.nodes[source].id,target:view.nodes[target].id,points:ReadOnlyArray::from_array(points),line:ReadOnlyArray::from_array(line),label:flow_label(flow,line,true,budget)})
  }
  (complete,shapes,connections)
}

///|
fn finish(view : @model.Bpmn, shapes : Array[Shape], connections : Array[Connection], source : Source, budget : Budget) -> Result {
  let mut min_x=0.0; let mut min_y=0.0; let mut max_x=1.0; let mut max_y=1.0; let mut first=true
  fn enclose(r : Rect) -> Unit {
    if first { min_x=r.x; min_y=r.y; max_x=r.x+r.width; max_y=r.y+r.height; first=false }
    else { min_x=Double::min(min_x,r.x); min_y=Double::min(min_y,r.y); max_x=Double::max(max_x,r.x+r.width); max_y=Double::max(max_y,r.y+r.height) }
  }
  for shape in shapes { enclose(shape.box); if shape.label is Some(l) { enclose(l.box) } }
  for edge in connections { for p in edge.line { enclose({x:p.x,y:p.y,width:0.0,height:0.0}) }; if edge.label is Some(l) { enclose(l.box) } }
  let translate_x=32L-min_x.floor().to_int64(); let translate_y=32L-min_y.floor().to_int64()
  let width=(max_x+translate_x.to_double()+32.0).ceil().to_int64(); let height=(max_y+translate_y.to_double()+32.0).ceil().to_int64()
  {geometry:if budget.failed { None } else { Some({view,shapes:ReadOnlyArray::from_array(shapes),connections:ReadOnlyArray::from_array(connections),source,translate_x,translate_y,width,height}) },diagnostics:ReadOnlyArray::from_array(budget.diagnostics)}
}

///|
/// Use all supplied coordinates or compute a complete view. Invalid supplied
/// values never become a partial fallback. Automatic explicitly ignores DI.
pub fn layout(view : @model.Bpmn, policy? : @model.GeometryPolicy = PreferDi, limits? : Limits = Limits::new()) -> Result {
  let budget=Budget::{limits,diagnostics:[],work:0,failed:false}
  fn failed() -> Result { {geometry:None,diagnostics:ReadOnlyArray::from_array(budget.diagnostics)} }
  if limits.nodes <= 0 || limits.edges <= 0 || limits.work <= 0 || limits.output_units <= 0 { budget.error("bpmn/layout-limit","All BPMN geometry limits must be positive"); return failed() }
  guard input(view,budget) is Some(input) else { return failed() }
  if policy != @model.GeometryPolicy::Automatic {
    let (complete,shapes,connections)=supplied(view,input,budget)
    if budget.failed { return failed() }
    if complete { return finish(view,shapes,connections,Supplied,budget) }
    if policy == RequireDi { budget.error("bpmn/incomplete-di","The selected view needs complete shape bounds and edge waypoints"); return failed() }
    budget.diagnostics.push(@diagrams.Diagnostic::warning("bpmn/incomplete-di","Supplied geometry is missing or incomplete; computing the whole view"))
  }
  let (shapes,connections)=automatic(view,input,budget)
  finish(view,shapes,connections,Automatic,budget)
}
