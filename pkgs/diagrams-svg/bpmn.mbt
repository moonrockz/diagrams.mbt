///|
/// Integer convenience path retained for the first motion-plan API.
pub fn bpmn_path(flow : @bpmn.Flow) -> String {
  let b=StringBuilder()
  for i,p in flow.points { b.write_string("\{if i == 0 { "M" } else { " L" }}\{p.x} \{p.y}") }
  b.to_string()
}

///|
fn BpmnPaint::shape(self : BpmnPaint, shape : @bpmn_layout.Shape, starts : ArrayView[@bpmn.Node]) -> @writer.Node {
  let node=shape.node
  if !self.charge(node.markers.details.length()) || !self.charge(node.markers.events.length()) { return self.element("g") }
  let attrs=self.metadata(node.id,node.source,node.properties)
  attrs.push(("id","node-\{shape.index}")); attrs.push(("class","bpmn-shape")); attrs.push(("data-kind",bpmn_kind(node.kind)))
  attrs.push(("data-expanded",if node.expanded.unwrap_or(false) { "true" } else { "false" }))
  attrs.push(("data-black-box",if node.black_box { "true" } else { "false" }))
  if node.ownership.pool is Some(id) { attrs.push(("data-pool",id)) }
  if node.ownership.subprocess is Some(id) { attrs.push(("data-subprocess",id)) }
  if node.ownership.attached_to is Some(id) { attrs.push(("data-attached-to",id)) }
  let events=StringBuilder(); let mut units=0
  for i,event in node.markers.events {
    let name=(if i == 0 { "" } else { "," })+bpmn_event(event.kind)
    if name.length() > self.limit-self.used-units { self.fail("bpmn/render-limit","Event metadata exceeds the output budget"); break }
    units+=name.length(); events.write_string(name)
  }
  attrs.push(("data-events",events.to_string()))
  let r=shape.bounds
  let children=[self.element("rect",attrs=[("class","bpmn-bounds"),("x",r.x.token),("y",r.y.token),("width",r.width.token),("height",r.height.token),("fill","none"),("stroke","none"),("pointer-events","none"),("aria-hidden","true")]),self.outline(shape)]; children.append(self.markers(shape,starts))
  self.element("g",attrs~,children~)
}

///|
fn bpmn_background(kind : @bpmn.NodeKind, expanded : Bool) -> Bool { kind == Participant || kind == Lane || kind == Group || (expanded && (kind == SubProcess || kind == AdHocSubProcess || kind == Transaction || kind == CallActivity)) }

///|
fn bpmn_prefix(root : @writer.Node, raw : String?, paint : BpmnPaint) -> String? {
  let prefix=match raw {
    Some(raw) => {
      let b=StringBuilder(); let mut length=7; b.write_string("bpmn-u-")
      for c in raw {
        let value=c.to_int().to_string(radix=16)+"-"
        if value.length() > paint.limit-length { paint.fail("bpmn/render-limit","SVG ID prefix exceeds the output budget"); return None }
        length+=value.length(); b.write_string(value)
      }
      b.to_string()
    }
    None => {
      let source=@writer.to_string(root)
      let mut hash : UInt64=14695981039346656037
      for i in 0..<source.length() { hash=(hash ^ source.code_unit_at(i).to_int().to_uint64())*1099511628211 }
      "bpmn-\{hash.to_string(radix=16)}-"
    }
  }
  let stack=[root]; let mut occurrences=1
  while stack.pop() is Some(node) {
    match node {
      Text(_) => ()
      Element(name,attrs,children) => {
        if name == "style" { occurrences+=4 }
        for (key,_) in attrs { if key == "id" || key == "marker-start" || key == "marker-end" { occurrences+=1 } }
        stack.append(children)
      }
    }
  }
  if prefix.length() > (paint.limit-paint.used)/occurrences || !paint.reserve(prefix.length()*occurrences+64) { paint.fail("bpmn/render-limit","Scoped SVG identifiers exceed the output budget"); return None }
  Some(prefix)
}

///|
fn paint_bpmn(view : @bpmn.Bpmn, theme : @theme.Theme, mode : Mode, id_prefix : String?, policy : @bpmn.GeometryPolicy, limits : @bpmn_layout.Limits) -> @render.Rendered {
  let theme=@theme.Theme::{dark:@bpmn_layout.bpmn_palette(theme.dark),light:@bpmn_layout.bpmn_palette(theme.light)}
  let result=@bpmn_layout.layout(view,policy~,limits~)
  let diagnostics=result.diagnostics.iter().to_array()
  guard result.geometry is Some(geometry) else { return @render.Rendered::failed("image/svg+xml",diagnostics) }
  let c=BpmnPaint::{paint:Paint::{theme,mode},limit:limits.output_units,diagnostics,used:0,failed:false,work:0,work_limit:limits.work}
  let starts : Map[String,Array[@bpmn.Node]]=Map([])
  let kinds=Map([])
  if !c.charge(view.nodes.length()) { return @render.Rendered::failed("image/svg+xml",diagnostics) }
  for node in view.nodes {
    kinds[node.id]=node.kind
    if node.kind == StartEvent && node.ownership.subprocess is Some(owner) { match starts.get(owner) { Some(events) => events.push(node); None => starts[owner]=[node] } }
  }
  let background=[]; let foreground=[]; let labels=[]
  let containers : Array[@bpmn_layout.Shape]=[]
  for shape in geometry.shapes {
    if c.failed { break }
    if bpmn_background(shape.node.kind,shape.node.expanded.unwrap_or(false)) { containers.push(shape) } else { foreground.push(c.shape(shape,starts.get(shape.node.id).unwrap_or([]))) }
    if shape.label is Some(label) { labels.push(c.label(label)) }
  }
  // Outer containers paint first even when XML/model order places a child first.
  containers.sort_by((a,b) => {
    let area=(b.box.width*b.box.height).compare(a.box.width*a.box.height)
    if area == 0 { a.index.compare(b.index) } else { area }
  })
  for shape in containers { background.push(c.shape(shape,starts.get(shape.node.id).unwrap_or([]))) }
  let flows=[]
  for edge in geometry.connections {
    if c.failed { break }
    flows.push(c.connection(edge,kinds.get(edge.source)))
    if edge.label is Some(label) { labels.push(c.label(label)) }
  }
  let definitions=c.definitions()
  if mode == Adaptive { definitions.push(c.element("style",children=[c.text(style_sheet(theme))])) }
  let root=c.element("svg",attrs=[("xmlns","http://www.w3.org/2000/svg"),("viewBox","0 0 \{geometry.width} \{geometry.height}"),("width",geometry.width.to_string()),("height",geometry.height.to_string()),("role","img"),("data-diagram","bpmn")],children=[
    c.element("title",children=[c.text(view.label)]),
    c.element("desc",children=[c.text("BPMN view with \{geometry.shapes.length()} visible shapes and \{geometry.connections.length()} connections. Structural flow is illustrative. Conditions, timers and execution outcomes are not evaluated.")]),
    c.element("defs",children=definitions),
    c.element("rect",attrs=[("class","bg"),("x","0"),("y","0"),("width",geometry.width.to_string()),("height",geometry.height.to_string()),("fill",c.paint.color("bg"))]),
    c.element("g",attrs=[("transform","translate(\{geometry.translate_x} \{geometry.translate_y})"),("class","bpmn-viewport")],children=[
      c.element("g",attrs=[("class","bpmn-backgrounds")],children=background),
      c.element("g",attrs=[("class","bpmn-connections")],children=flows),
      c.element("g",attrs=[("class","bpmn-nodes")],children=foreground),
      c.element("g",attrs=[("class","bpmn-labels")],children=labels),
    ]),
  ])
  if c.failed { return @render.Rendered::failed("image/svg+xml",diagnostics) }
  guard bpmn_prefix(root,id_prefix,c) is Some(prefix) else { return @render.Rendered::failed("image/svg+xml",diagnostics) }
  let palettes=match mode { Adaptive => [("dark",theme.dark),("light",theme.light)]; Fixed(Dark) => [("dark",theme.dark)]; Fixed(Light) => [("light",theme.light)] }
  for (name,palette) in palettes {
    for finding in @bpmn_layout.check(geometry,palette,work_limit=limits.work) { diagnostics.push(@diagrams.Diagnostic::warning("bpmn/legibility","\{name}: \{finding.message}")) }
  }
  @render.Rendered::ok(@writer.to_string(scope_svg(root,prefix,theme)),"image/svg+xml",diagnostics~)
}
