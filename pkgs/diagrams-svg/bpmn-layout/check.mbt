///|
pub(all) enum Rule { Overlap; Fit; Size; Contrast; Containment; Attachment; Endpoint; Limit } derive(Eq, Debug)

///|
pub struct Finding { rule : Rule; identities : ReadOnlyArray[String]; message : String } derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal,not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub extend Finding with Eq::{equal,not_equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
fn border_distance(point : Point, r : Rect) -> Double {
  let horizontal=point.x >= r.x && point.x <= r.x+r.width
  let vertical=point.y >= r.y && point.y <= r.y+r.height
  let mut distance=10000000000.0
  if horizontal { distance=Double::min((point.y-r.y).abs(),(point.y-r.y-r.height).abs()) }
  if vertical { distance=Double::min(distance,Double::min((point.x-r.x).abs(),(point.x-r.x-r.width).abs())) }
  distance
}

///|
fn segment_distance(p : Point, a : Point, b : Point) -> Double {
  let dx=b.x-a.x; let dy=b.y-a.y; let length=dx*dx+dy*dy
  let t=if length == 0.0 { 0.0 } else { Double::max(0.0,Double::min(1.0,((p.x-a.x)*dx+(p.y-a.y)*dy)/length)) }
  let x=p.x-a.x-t*dx; let y=p.y-a.y-t*dy
  (x*x+y*y).sqrt()
}

///|
fn on_shape(point : Point, shape : Shape) -> Bool {
  let r=shape.box; let tolerance=2.0
  if event(shape.node.kind) { let x=(point.x-r.x-r.width/2.0)/(r.width/2.0); let y=(point.y-r.y-r.height/2.0)/(r.height/2.0); return (x*x+y*y-1.0).abs() <= tolerance/Double::max(1.0,r.width/4.0) }
  if gateway(shape.node.kind) { let x=(point.x-r.x-r.width/2.0).abs()/(r.width/2.0); let y=(point.y-r.y-r.height/2.0).abs()/(r.height/2.0); return (x+y-1.0).abs() <= tolerance/Double::max(1.0,r.width/4.0) }
  if [@model.NodeKind::DataObject,DataObjectReference,DataInput,DataOutput].contains(shape.node.kind) {
    let vertices : Array[Point]=[{x:r.x,y:r.y},{x:r.x+r.width*0.75,y:r.y},{x:r.x+r.width,y:r.y+r.height*0.25},{x:r.x+r.width,y:r.y+r.height},{x:r.x,y:r.y+r.height}]
    for i,a in vertices { if segment_distance(point,a,vertices[(i+1)%vertices.length()]) <= tolerance { return true } }
    return false
  }
  if shape.node.kind == DataStore || shape.node.kind == DataStoreReference {
    let ry=r.height*0.15; let rx=r.width/2.0
    if point.y >= r.y+ry && point.y <= r.y+r.height-ry { return (point.x-r.x).abs() <= tolerance || (point.x-r.x-r.width).abs() <= tolerance }
    let cy=if point.y < r.y+ry { r.y+ry } else { r.y+r.height-ry }
    let x=(point.x-r.x-rx)/rx; let y=(point.y-cy)/ry
    return (x*x+y*y-1.0).abs() <= tolerance/Double::max(1.0,Double::min(rx,ry)/2.0)
  }
  if shape.node.kind == TextAnnotation {
    return segment_distance(point,{x:r.x,y:r.y},{x:r.x,y:r.y+r.height}) <= tolerance || segment_distance(point,{x:r.x,y:r.y},{x:r.x+r.width*0.12,y:r.y}) <= tolerance || segment_distance(point,{x:r.x,y:r.y+r.height},{x:r.x+r.width*0.12,y:r.y+r.height}) <= tolerance
  }
  if activity(shape.node.kind) || shape.node.kind == Group {
    let rx=r.width*0.1; let ry=r.height*0.125
    if (point.x >= r.x+rx && point.x <= r.x+r.width-rx) || (point.y >= r.y+ry && point.y <= r.y+r.height-ry) { return border_distance(point,r) <= tolerance }
    let cx=if point.x < r.x+rx { r.x+rx } else { r.x+r.width-rx }; let cy=if point.y < r.y+ry { r.y+ry } else { r.y+r.height-ry }
    let x=(point.x-cx)/rx; let y=(point.y-cy)/ry
    return (x*x+y*y-1.0).abs() <= tolerance/Double::max(1.0,Double::min(rx,ry)/2.0)
  }
  border_distance(point,r) <= tolerance
}

///|
fn crosses(a : Point, b : Point, box : Rect) -> Bool {
  let left=box.x+0.5; let right=box.x+box.width-0.5; let top=box.y+0.5; let bottom=box.y+box.height-0.5
  if left >= right || top >= bottom { return false }
  let dx=b.x-a.x; let dy=b.y-a.y; let mut low=0.0; let mut high=1.0
  for (p,q) in [(-dx,a.x-left),(dx,right-a.x),(-dy,a.y-top),(dy,bottom-a.y)] {
    if p == 0.0 { if q < 0.0 { return false } }
    else { let t=q/p; if p < 0.0 { low=Double::max(low,t) } else { high=Double::min(high,t) }; if low > high { return false } }
  }
  low < high
}

///|
// Artifacts and data elements are not FlowNodes and cannot occur in a lane's
// flowNodeRef list. Their visual inclusion is established by supplied bounds.
fn artifact(kind : @model.NodeKind) -> Bool {
  match kind {
    DataObject | DataObjectReference | DataStore | DataStoreReference | DataInput | DataOutput | Group | TextAnnotation | Message => true
    _ => false
  }
}

///|
fn visual_container(child : Shape, parent : Shape) -> Bool {
  parent.box.contains(child.box) && (parent.node.kind == Group || ((parent.node.kind == Lane || parent.node.kind == Participant) && artifact(child.node.kind)))
}

///|
/// Read-only findings never move supplied geometry. Search exhaustion is an
/// explicit finding rather than a silently incomplete legibility result.
pub fn check(geometry : Geometry, palette : @theme.Palette, work_limit? : Int = 1000000) -> ReadOnlyArray[Finding] {
  let findings=[]; let mut work=0; let mut exhausted=false
  fn charge() -> Bool {
    if exhausted { return false }
    if work >= work_limit {
      if !exhausted { findings.push({rule:Limit,identities:[],message:"Legibility search limit exceeded"}); exhausted=true }
      return false
    }
    work+=1; true
  }
  fn add(rule : Rule, ids : ArrayView[String], message : String) -> Unit {
    if exhausted { return }
    if findings.length() < 255 { findings.push({rule,identities:ReadOnlyArray::from_array(ids),message}) }
    else { findings.push({rule:Limit,identities:[],message:"Legibility finding limit exceeded"}); exhausted=true }
  }
  let by_id=Map([])
  for i,shape in geometry.shapes { by_id[shape.node.id]=i }
  let all_nodes=Map([])
  for node in geometry.view.nodes { all_nodes[node.id]=node }
  fn ancestor(child : String, container : String) -> Bool {
    let stack=[child]; let seen=Map([])
    while stack.pop() is Some(id) {
      if !charge() { return false }
      if seen.contains(id) { continue }; seen[id]=true
      if all_nodes.get(id) is Some(node) {
        for owner in node.ownership.lanes.iter().concat(node.ownership.pool.iter()).concat(node.ownership.subprocess.iter()) {
          if owner == container { return true }; stack.push(owner)
        }
      }
    }
    false
  }
  let edges=Map([])
  for edge in geometry.connections { edges[edge.flow.id]=edge }
  fn label_in_container(label : Label, container : Shape) -> Bool {
    if !container.box.contains(label.box) { return false }
    if ancestor(label.owner,container.node.id) { return true }
    if container.node.kind == Group { return true }
    if all_nodes.get(label.owner) is Some(node) && artifact(node.kind) && (container.node.kind == Lane || container.node.kind == Participant) { return true }
    if edges.get(label.owner) is Some(edge) { return ancestor(edge.source,container.node.id) || ancestor(edge.target,container.node.id) || edge.source == container.node.id || edge.target == container.node.id }
    false
  }
  for i,shape in geometry.shapes {
    if !charge() { break }
    let node=shape.node
    for owner in node.ownership.lanes.iter().concat(node.ownership.pool.iter()).concat(node.ownership.subprocess.iter()) {
      if by_id.get(owner) is Some(parent) && !geometry.shapes[parent].box.contains(shape.box,tolerance=1.0) && node.kind != BoundaryEvent { add(Containment,[node.id,owner],"\{node.id} lies outside \{owner}") }
    }
    if node.ownership.attached_to is Some(owner) && by_id.get(owner) is Some(parent) {
      let center : Point={x:shape.box.x+shape.box.width/2.0,y:shape.box.y+shape.box.height/2.0}
      if border_distance(center,geometry.shapes[parent].box) > 2.0 { add(Attachment,[node.id,owner],"Boundary event \{node.id} is not on its attached activity border") }
    }
    for j in (i+1)..<geometry.shapes.length() {
      if !charge() { break }
      let other=geometry.shapes[j]
      let grouped=(node.kind == Group && other.node.kind == Group) || visual_container(shape,other) || visual_container(other,shape)
      let attached=node.ownership.attached_to == Some(other.node.id) || other.node.ownership.attached_to == Some(node.id)
      if shape.box.overlaps(other.box) && !grouped && !attached && !ancestor(node.id,other.node.id) && !ancestor(other.node.id,node.id) { add(Overlap,[node.id,other.node.id],"Unintended shape overlap: \{node.id} and \{other.node.id}") }
    }
  }
  let labels : Array[Label]=[]
  for shape in geometry.shapes { if shape.label is Some(label) { labels.push(label) } }
  for edge in geometry.connections { if edge.label is Some(label) { labels.push(label) } }
  for i,label in labels {
    if !charge() { break }
    if by_id.get(label.owner) is Some(j) && label.bounds == None {
      let shape=geometry.shapes[j]
      if (activity(shape.node.kind) || shape.node.kind == TextAnnotation || shape.node.kind == Participant || shape.node.kind == Lane) && !shape.box.contains(label.box,tolerance=1.0) { add(Fit,[label.owner],"Text exceeds its shape on \{label.owner}") }
    }
    if label.size < 11.0 { add(Size,[label.owner],"Text on \{label.owner} is below 11 px") }
    let color=label.family.map(f => palette.family(f).ink).unwrap_or(palette.text)
    let backdrop=if label.mask { palette.bg } else { by_id.get(label.owner).map(j => geometry.shapes[j]).map(s => if activity(s.node.kind) { @theme.over(palette.family(family(s.node.kind)).fill,palette.bg) } else { palette.bg }).unwrap_or(palette.bg) }
    if @theme.contrast(color,backdrop) < 4.5 { add(Contrast,[label.owner],"Text contrast on \{label.owner} is below 4.5:1") }
    if label.text.length() > work_limit-work { work=work_limit; ignore(charge()); break }
    work+=label.text.length()
    let budget=Budget::{limits:Limits::new(),diagnostics:[],work:0,failed:false}
    if measure(label.text,label.font,budget) is Some((width,height)) {
      let measured_width=if label.rotation == -90 { height } else { width }; let measured_height=if label.rotation == -90 { width } else { height }
      if measured_width > label.box.width+1.0 || measured_height > label.box.height+1.0 { add(Fit,[label.owner],"Text exceeds label bounds on \{label.owner}") }
    }
    for shape in geometry.shapes {
      if !charge() { break }
      if shape.node.id == label.owner { continue }
      let container=label_in_container(label,shape)
      if label.box.overlaps(shape.box) && !container { add(Overlap,[label.owner,shape.node.id],"Label on \{label.owner} overlaps \{shape.node.id}") }
    }
    for j in (i+1)..<labels.length() { if !charge() { break }; let other=labels[j]; if label.box.overlaps(other.box) { add(Overlap,[label.owner,other.owner],"Labels overlap: \{label.owner} and \{other.owner}") } }
  }
  for edge in geometry.connections {
    if !charge() { break }
    let source=by_id.get(edge.source); let target=by_id.get(edge.target)
    if source is Some(s) && !on_shape(edge.line[0],geometry.shapes[s]) { add(Endpoint,[edge.flow.id,edge.source],"Connection \{edge.flow.id} misses its source border") }
    if target is Some(t) && !on_shape(edge.line[edge.line.length()-1],geometry.shapes[t]) { add(Endpoint,[edge.flow.id,edge.target],"Connection \{edge.flow.id} misses its target border") }
    for shape in geometry.shapes {
      if !charge() { break }
      if shape.node.kind == Group || ancestor(edge.source,shape.node.id) || ancestor(edge.target,shape.node.id) { continue }
      for i in 1..<edge.line.length() {
        if !charge() { break }
        if crosses(edge.line[i-1],edge.line[i],shape.box) { add(Overlap,[edge.flow.id,shape.node.id],"Connection \{edge.flow.id} crosses shape \{shape.node.id}"); break }
      }
    }
    for label in labels {
      if !charge() { break }
      if label.owner == edge.flow.id { continue }
      for i in 1..<edge.line.length() {
        if !charge() { break }
        if crosses(edge.line[i-1],edge.line[i],label.box) { add(Overlap,[edge.flow.id,label.owner],"Connection \{edge.flow.id} crosses label on \{label.owner}"); break }
      }
    }
  }
  ReadOnlyArray::from_array(findings)
}
