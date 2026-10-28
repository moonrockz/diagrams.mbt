///|
/// A display container whose membership crosses the primary layout hierarchy.
/// The caller supplies inner containers before their outer containers.
pub struct Overlay {
  id : String
  members : ReadOnlyArray[String]
  parent : String?
}
///|
pub fn Overlay::new(id : String, members : ArrayView[String], parent? : String) -> Overlay {
  {id,members:ReadOnlyArray::from_array(members),parent}
}
///|
/// Reframe crossing containers, then route using the same bounded geometry engine.
/// Ordinary layouts do not use this path and retain their canonical geometry.
pub fn Geometry::overlay(self : Geometry, definitions : ArrayView[Overlay], limits~ : Limits = Limits::new(), direction_hints~ : ArrayView[(String,@model.Direction)] = []) -> Result {
  let budget=Budget::{limits,diagnostics:[],work:0,failed:false}
  let shapes=self.shapes.iter().to_array()
  let by_id : Map[String,Int]=Map([])
  for i,shape in shapes { if !budget.charge(shape.id.length()+1) { return layout_failure(budget.diagnostics) }; by_id[shape.id]=i }
  for definition in definitions {
    if !budget.charge(definition.members.length()+definition.id.length()+1) { return layout_failure(budget.diagnostics) }
    guard by_id.get(definition.id) is Some(index) else {
      budget.error("swimlane/ownership","Overlay group is absent: "+definition.id)
      return layout_failure(budget.diagnostics)
    }
    let shape=shapes[index]
    if !shape.expanded { continue }
    let mut bounds : Rect?=None
    for id in definition.members {
      if !budget.charge(id.length()+1) { return layout_failure(budget.diagnostics) }
      if by_id.get(id) is Some(member_index) {
        let box=shapes[member_index].box
        bounds=Some(match bounds {
          None => box
          Some(old) => {x:Double::min(old.x,box.x),y:Double::min(old.y,box.y),width:Double::max(old.x+old.width,box.x+box.width)-Double::min(old.x,box.x),height:Double::max(old.y+old.height,box.y+box.height)-Double::min(old.y,box.y)}
        })
      }
    }
    if bounds is Some(body) {
      let title=shape.label.map(l => l.text).unwrap_or("")
      let (w,h)=measure(title,weight=700)
      let mut box : Rect={x:body.x-24.0,y:body.y-h-32.0,width:Double::max(body.width+48.0,w+40.0),height:body.height+h+56.0}
      let mut label=make_label(title,shape.id,box,true,None)
      let mut changed=true
      while changed {
        changed=false
        if label is Some(candidate) {
          for other in shapes {
            if !budget.charge(1) { return layout_failure(budget.diagnostics) }
            if other.id != shape.id && other.label is Some(other_label) && candidate.box.overlaps(other_label.box) {
              let top=other_label.box.y-h-24.0
              let bottom=box.y+box.height
              box={..box,y:Double::min(box.y-1.0,top),height:bottom-Double::min(box.y-1.0,top)}
              label=make_label(title,shape.id,box,true,None)
              changed=true
              break
            }
          }
        }
      }
      shapes[index]={..shape,box,outline_box:box,parent:definition.parent,label}
    }
  }
  let mut low_x=32.0; let mut low_y=32.0
  for shape in shapes { low_x=Double::min(low_x,shape.box.x); low_y=Double::min(low_y,shape.box.y) }
  let dx=32.0-low_x; let dy=32.0-low_y
  if dx != 0.0 || dy != 0.0 {
    for i,shape in shapes {
      fn shifted(box : Rect) -> Rect { {..box,x:box.x+dx,y:box.y+dy} }
      shapes[i]={..shape,box:shifted(shape.box),outline_box:shifted(shape.outline_box),label:shape.label.map(l => {..l,box:shifted(l.box)})}
    }
  }
  let positions : Map[String,Int]=Map([])
  let count=self.view.nodes.length()+self.view.groups.length()+self.view.lanes.length()+1
  let parents=Array::make(count,-1)
  for shape in shapes { positions[shape.id]=shape.index }
  for shape in shapes {
    if shape.parent.bind(id => positions.get(id)) is Some(parent) { parents[shape.index]=parent }
  }
  let selected : Array[(Int,Int,Int)]=[]
  for edge in self.connections {
    if positions.get(edge.source) is Some(a) && positions.get(edge.target) is Some(b) { selected.push((edge.index,a,b)) }
  }
  let connections=route_connections(self.view,selected,shapes,parents,budget,direction_hints~)
  if budget.failed { return layout_failure(budget.diagnostics) }
  let mut width=64.0; let mut height=64.0
  for shape in shapes { width=Double::max(width,shape.box.x+shape.box.width+32.0);height=Double::max(height,shape.box.y+shape.box.height+32.0) }
  for edge in connections {
    for p in edge.line { width=Double::max(width,p.x+32.0);height=Double::max(height,p.y+32.0) }
    if edge.label is Some(label) { width=Double::max(width,label.box.x+label.box.width+32.0);height=Double::max(height,label.box.y+label.box.height+32.0) }
  }
  if width > 1000000000.0 || height > 1000000000.0 { budget.error("swimlane/layout-limit","Overlay dimensions exceed numeric bounds");return layout_failure(budget.diagnostics) }
  {geometry:Some({view:self.view,shapes:ReadOnlyArray::from_array(shapes),connections:ReadOnlyArray::from_array(connections),width:width.ceil().to_int(),height:height.ceil().to_int()}),diagnostics:ReadOnlyArray::from_array(budget.diagnostics)}
}
