///|
/// A note attached to an actual drawn connection rather than a control node.
pub struct ConnectionNote {
  id : String
  connection : String
  note : String
}
///|
pub fn ConnectionNote::new(id : String, connection : String, note : String) -> ConnectionNote {
  {id,connection,note}
}
///|
pub fn Geometry::annotate(self : Geometry, notes : ArrayView[ConnectionNote], limits~ : Limits = Limits::new()) -> Result {
  let budget=Budget::{limits,diagnostics:[],work:0,failed:false}
  let shapes : Map[String,Shape]=Map([])
  for shape in self.shapes { if !budget.charge(shape.id.length()+1) { return layout_failure(budget.diagnostics) };shapes[shape.id]=shape }
  let edges : Map[String,Connection]=Map([])
  for edge in self.connections { if !budget.charge(edge.connection.id.length()+1) { return layout_failure(budget.diagnostics) };edges[edge.connection.id]=edge }
  let connections=self.connections.iter().to_array()
  let authored=self.view.connections.iter().to_array()
  let mut width=self.width.to_double();let mut height=self.height.to_double()
  for note in notes {
    if !budget.charge(note.id.length()+note.connection.length()+note.note.length()+1) { return layout_failure(budget.diagnostics) }
    guard shapes.get(note.note) is Some(target) else { continue }
    guard edges.get(note.connection) is Some(edge) else {
      budget.diagnostics.push(@diagrams.Diagnostic::warning("swimlane/hidden-note-target","An edge-attached note has no visible target connection: "+note.connection))
      continue
    }
    if connections.length() >= limits.edges { budget.error("swimlane/layout-limit","Note attachments exceed the connection limit");return layout_failure(budget.diagnostics) }
    let mut selected : (Point,Double)?=None
    for i in 1..<edge.line.length() {
      if !budget.charge(1) { return layout_failure(budget.diagnostics) }
      let a=edge.line[i-1];let b=edge.line[i]
      let length=(a.x-b.x).abs()+(a.y-b.y).abs()
      for fraction in [0.5,0.25,0.75] {
        let point : Point={x:a.x+(b.x-a.x)*fraction,y:a.y+(b.y-a.y)*fraction}
        let covered=edge.label.map(l => point.x >= l.box.x-8.0 && point.x <= l.box.x+l.box.width+8.0 && point.y >= l.box.y-8.0 && point.y <= l.box.y+l.box.height+8.0).unwrap_or(false)
        if !covered && (selected == None || length > selected.unwrap().1) { selected=Some((point,length)) }
      }
    }
    guard selected is Some((start,_)) else { budget.error("swimlane/layout-limit","No clear point on a note's connection");return layout_failure(budget.diagnostics) }
    let side=if start.x < target.box.x { 2 } else if start.x > target.box.x+target.box.width { 0 } else if start.y < target.box.y { 3 } else { 1 }
    let end=port(target,side,0.5)
    let entry : Point=match side {
      0 => {x:target.outline_box.x+target.outline_box.width+12.0,y:end.y}
      1 => {x:end.x,y:target.outline_box.y+target.outline_box.height+12.0}
      2 => {x:target.outline_box.x-12.0,y:end.y}
      _ => {x:end.x,y:target.outline_box.y-12.0}
    }
    let obstacles=[]
    for shape in self.shapes {
      if !budget.charge(1) { return layout_failure(budget.diagnostics) }
      if shape.kind == Node { obstacles.push(inflated(shape.outline_box,if shape.id == target.id { 0.0 } else { 8.0 })) }
      if shape.label is Some(label) { obstacles.push(inflated(label.box,6.0)) }
    }
    guard orthogonal(start,entry,obstacles,height+64.0,None,budget) is Some(middle) else { if !budget.failed { budget.error("swimlane/layout-limit","No bounded route from a connection to its note") };return layout_failure(budget.diagnostics) }
    let line=compact(middle.iter().concat([end].iter()).to_array())
    for point in line { width=Double::max(width,point.x+32.0);height=Double::max(height,point.y+32.0) }
    let connection=@model.Connection::new(note.id,note.connection,note.note,style=Dotted,target_marker=None)
    let mut anchor_id=note.id+":edge-anchor"
    while shapes.contains(anchor_id) { if !budget.charge(1) { return layout_failure(budget.diagnostics) };anchor_id+="_" }
    connections.push({connection,index:authored.length(),source:anchor_id,target:note.note,line:ReadOnlyArray::from_array(line),label:None})
    authored.push(connection)
  }
  if budget.failed { return layout_failure(budget.diagnostics) }
  let view=@model.Swimlane::new(self.view.id,self.view.nodes[:],authored[:],direction=self.view.direction,lanes=self.view.lanes[:],groups=self.view.groups[:],title?=self.view.title,accessibility_title?=self.view.accessibility_title,accessibility_description?=self.view.accessibility_description)
  {geometry:Some({view,shapes:self.shapes,connections:ReadOnlyArray::from_array(connections),width:width.ceil().to_int(),height:height.ceil().to_int()}),diagnostics:ReadOnlyArray::from_array(budget.diagnostics)}
}
