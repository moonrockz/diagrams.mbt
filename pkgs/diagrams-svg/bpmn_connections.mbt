///|
/// Exact authored or deterministically computed path. The limit is checked
/// before appending each segment; no partially returned path escapes.
pub fn bpmn_geometry_path(edge : @bpmn_layout.Connection, max_units? : Int = 16777216) -> String? {
  if max_units <= 0 { return None }
  let result=StringBuilder(); let mut units=0
  for i,p in edge.points {
    let prefix=if i == 0 { "M" } else { " L" }
    for part in [prefix,p.x.token," ",p.y.token] { if part.length() > max_units-units { return None }; units+=part.length(); result.write_string(part) }
  }
  Some(result.to_string())
}

///|
fn BpmnPaint::definitions(self : BpmnPaint) -> Array[@writer.Node] {
  let stroke=self.paint.color("arrow"); let bg=self.paint.color("bg")
  fn marker(id : String, parts : ArrayView[@writer.Node], orient : String) -> @writer.Node {
    self.element("marker",attrs=[("id",id),("viewBox","-12 -7 28 14"),("refX","0"),("refY","0"),("markerWidth","28"),("markerHeight","14"),("markerUnits","userSpaceOnUse"),("orient",orient)],children=parts)
  }
  [marker("sequence-head",[self.path("M-10 -5 L0 0 L-10 5 Z",stroke,fill=stroke)],"auto-start-reverse"),
   marker("open-head",[self.path("M-10 -5 L0 0 L-10 5",stroke)],"auto-start-reverse"),
   marker("message-tail",[self.circle("0","0","3.5",stroke,fill=bg)],"auto-start-reverse"),
   marker("condition-tail",[self.path("M0 0 L6 -4 L12 0 L6 4 Z",stroke,fill=bg)],"auto"),
   marker("default-tail",[self.path("M4 -5 L10 5",stroke)],"auto")]
}

///|
fn BpmnPaint::connection(self : BpmnPaint, edge : @bpmn_layout.Connection, source_kind : @bpmn.NodeKind?) -> @writer.Node {
  let flow=edge.flow; let stroke=self.paint.color("arrow")
  guard bpmn_geometry_path(edge,max_units=self.limit-self.used) is Some(d) else { self.fail("bpmn/render-limit","Connection path exceeds the output budget"); return self.element("g") }
  let attrs=self.metadata(flow.id,flow.identity,flow.properties)
  attrs.push(("id","flow-\{edge.index}")); attrs.push(("class","bpmn-flow")); attrs.push(("data-kind",bpmn_connection(flow.kind)))
  attrs.push(("data-from",edge.source)); attrs.push(("data-to",edge.target))
  if flow.condition is Some(condition) { attrs.push(("data-condition",condition)) }
  let line_attrs=[("d",d),("fill","none"),("stroke",stroke),("stroke-width","1.5"),("stroke-linejoin","round")]
  match flow.kind {
    SequenceFlow => {
      line_attrs.push(("marker-end","url(#sequence-head)"))
      if flow.is_default { line_attrs.push(("marker-start","url(#default-tail)")) }
      else if flow.condition != None && source_kind.map(@bpmn_layout.activity).unwrap_or(false) { line_attrs.push(("marker-start","url(#condition-tail)")) }
    }
    MessageFlow => { line_attrs.push(("stroke-dasharray","6 4")); line_attrs.push(("marker-start","url(#message-tail)")); line_attrs.push(("marker-end","url(#open-head)")) }
    Association => {
      line_attrs.push(("stroke-dasharray","1 4")); line_attrs.push(("stroke-linecap","round"))
      if flow.direction != None { line_attrs.push(("marker-end","url(#open-head)")) }
      if flow.direction == Both { line_attrs.push(("marker-start","url(#open-head)")) }
    }
    DataAssociation | DataInputAssociation | DataOutputAssociation => { line_attrs.push(("stroke-dasharray","1 4")); line_attrs.push(("stroke-linecap","round")); line_attrs.push(("marker-end","url(#open-head)")) }
  }
  let children=[self.element("path",attrs=line_attrs)]
  if flow.kind == MessageFlow && flow.geometry.bind(g => g.message_visible) is Some(visibility) {
    let point=@bpmn_layout.midpoint(edge.line).unwrap()
    children.push(self.element("g",attrs=[("transform","translate(\{bn(point.x-12.0)} \{bn(point.y-12.0)})")],children=self.event_symbol(Message,visibility == NonInitiating,stroke)))
  }
  self.element("g",attrs~,children~)
}
