///|
fn inflated(box : Rect, padding : Double) -> Rect { {x:box.x-padding,y:box.y-padding,width:box.width+2.0*padding,height:box.height+2.0*padding} }

///|
fn compact(line : ArrayView[Point]) -> Array[Point] {
  let result : Array[Point]=[]
  for point in line {
    if result.last() == Some(point) { continue }
    if result.length() >= 2 {
      let a=result[result.length()-2]; let b=result[result.length()-1]
      if (a.x == b.x && b.x == point.x && (b.y-a.y)*(point.y-b.y) >= 0.0) || (a.y == b.y && b.y == point.y && (b.x-a.x)*(point.x-b.x) >= 0.0) { ignore(result.pop()) }
    }
    result.push(point)
  }
  result
}

///|
fn clear_line(line : ArrayView[Point], obstacles : ArrayView[Rect], budget : Budget) -> Bool {
  for i in 1..<line.length() {
    for box in obstacles { if !budget.charge(1) { return false }; if crosses(line[i-1],line[i],box) { return false } }
  }
  true
}

///|
fn sorted_axis(values : Array[Double]) -> Array[Double] {
  values.sort_by((a,b) => a.compare(b)); let result=[]
  for value in values { if result.last() != Some(value) { result.push(value) } }
  result
}

///|
fn axis_index(values : ArrayView[Double], target : Double) -> Int {
  for i,value in values { if value == target { return i } }
  abort("route endpoint absent from coordinate axis")
}

///|
fn orthogonal(start : Point, end : Point, obstacles : ArrayView[Rect], channel : Double, area : Rect?, budget : Budget) -> Array[Point]? {
  let mid_x=(start.x+end.x)/2.0; let mid_y=(start.y+end.y)/2.0
  let candidates : Array[Array[Point]]=[
    [start,{x:end.x,y:start.y},end],[start,{x:start.x,y:end.y},end],
    [start,{x:mid_x,y:start.y},{x:mid_x,y:end.y},end],
    [start,{x:start.x,y:mid_y},{x:end.x,y:mid_y},end],
    [start,{x:start.x,y:channel},{x:end.x,y:channel},end],
  ]
  for line in candidates { let line=compact(line); if line.length() >= 2 && line.iter().all(p => area.map(r => r.contains({x:p.x,y:p.y,width:0.0,height:0.0})).unwrap_or(true)) && clear_line(line,obstacles,budget) { return Some(line) }; if budget.failed { return None } }
  let xs=[start.x,end.x]; let ys=[start.y,end.y,channel]
  if area is Some(area) { xs.push(area.x); xs.push(area.x+area.width); ys.push(area.y); ys.push(area.y+area.height) }
  for box in obstacles { if !budget.charge(1) { return None }; xs.push(box.x); xs.push(box.x+box.width); ys.push(box.y); ys.push(box.y+box.height) }
  let xs=sorted_axis(xs); let ys=sorted_axis(ys)
  let sx=axis_index(xs,start.x); let sy=axis_index(ys,start.y)
  let tx=axis_index(xs,end.x); let ty=axis_index(ys,end.y)
  let initial=(sx,sy,2)
  let distance=Map([(initial,0.0)]); let previous : Map[(Int,Int,Int),(Int,Int,Int)]=Map([])
  let queue : @priority_queue.PriorityQueue[(Double,Double,Int,Int,Int)]=@priority_queue.PriorityQueue([])
  queue.push((-(start.x-end.x).abs()-(start.y-end.y).abs(),0.0,sx,sy,2))
  while queue.pop() is Some((_,negative,x,y,direction)) {
    if !budget.charge(1) { return None }
    let key=(x,y,direction); let cost= -negative
    if distance.get(key) != Some(cost) { continue }
    if x == tx && y == ty {
      let reverse : Array[Point]=[{x:xs[x],y:ys[y]}]; let mut cursor=key
      while previous.get(cursor) is Some(parent) { if !budget.charge(1) { return None }; reverse.push({x:xs[parent.0],y:ys[parent.1]}); cursor=parent }
      return Some(compact(Array::makei(reverse.length(),i => reverse[reverse.length()-1-i])))
    }
    let a : Point={x:xs[x],y:ys[y]}
    for (nx,ny,nd) in [(x+1,y,0),(x,y+1,1),(x-1,y,0),(x,y-1,1)] {
      if nx < 0 || nx >= xs.length() || ny < 0 || ny >= ys.length() { continue }
      let b : Point={x:xs[nx],y:ys[ny]}
      if area.map(r => !r.contains({x:b.x,y:b.y,width:0.0,height:0.0})).unwrap_or(false) { continue }
      let next_cost=cost+(a.x-b.x).abs()+(a.y-b.y).abs()+(if direction != 2 && direction != nd { 24.0 } else { 0.0 })
      let next=(nx,ny,nd)
      if distance.get(next).map(old => old <= next_cost).unwrap_or(false) { continue }
      if !clear_line([a,b],obstacles,budget) { if budget.failed { return None }; continue }
      distance[next]=next_cost; previous[next]=key
      let estimate=next_cost+(b.x-end.x).abs()+(b.y-end.y).abs()
      queue.push((-estimate,-next_cost,nx,ny,nd))
    }
  }
  None
}

///|
fn port(shape : Shape, side : Int, fraction : Double) -> Point {
  let box=shape.box
  let mut x=if side == 0 { box.x+box.width } else if side == 2 { box.x } else { box.x+box.width*fraction }
  let mut y=if side == 1 { box.y+box.height } else if side == 3 { box.y } else { box.y+box.height*fraction }
  let cx=box.x+box.width/2.0; let cy=box.y+box.height/2.0
  if event(shape.node.kind) {
    if side == 0 || side == 2 { let offset=(y-cy)/(box.height/2.0); x=cx+(if side == 0 { 1.0 } else { -1.0 })*(box.width/2.0)*(1.0-offset*offset).sqrt() }
    else { let offset=(x-cx)/(box.width/2.0); y=cy+(if side == 1 { 1.0 } else { -1.0 })*(box.height/2.0)*(1.0-offset*offset).sqrt() }
  } else if gateway(shape.node.kind) {
    if side == 0 || side == 2 { x=cx+(if side == 0 { 1.0 } else { -1.0 })*(box.width/2.0)*(1.0-(y-cy).abs()/(box.height/2.0)) }
    else { y=cy+(if side == 1 { 1.0 } else { -1.0 })*(box.height/2.0)*(1.0-(x-cx).abs()/(box.width/2.0)) }
  } else if shape.node.kind == DataStore || shape.node.kind == DataStoreReference {
    if side == 1 || side == 3 { let offset=(x-cx)/(box.width/2.0); let ry=box.height*0.15; let center=if side == 1 { box.y+box.height-ry } else { box.y+ry }; y=center+(if side == 1 { 1.0 } else { -1.0 })*ry*(1.0-offset*offset).sqrt() }
  }
  {x,y}
}

///|
fn side(shape : Shape, other : Shape, source : Bool) -> Int {
  if shape.node.kind == TextAnnotation { return 2 }
  if shape.node.kind == BoundaryEvent { return 1 }
  let dx=other.box.x+other.box.width/2.0-shape.box.x-shape.box.width/2.0
  let dy=other.box.y+other.box.height/2.0-shape.box.y-shape.box.height/2.0
  if dx.abs() >= dy.abs() { if dx > 0.0 || (dx == 0.0 && source) { 0 } else { 2 } }
  else { if dy > 0.0 { 1 } else { 3 } }
}

///|
fn route_connections(view : @model.Bpmn, selected : ArrayView[(Int,Int,Int)], shapes : ArrayView[Shape], parents : ArrayView[Int], budget : Budget) -> Array[Connection] {
  let by_index=Map([]); for shape in shapes { by_index[shape.index]=shape }
  let attached=Map([])
  for shape in shapes { if shape.node.ownership.attached_to is Some(owner) { attached[owner]=true } }
  let counts : Map[(Int,Int),Int]=Map([]); let sides=[]
  for (_,a,b) in selected {
    let source=by_index[a]; let target=by_index[b]
    let mut from=if a == b { 0 } else { side(source,target,true) }; let mut to=if a == b { 3 } else { side(target,source,false) }
    if from == 1 && attached.contains(source.node.id) { from=0 }
    if to == 1 && attached.contains(target.node.id) { to=2 }
    sides.push((from,to)); counts[(a,from)]=counts.get((a,from)).unwrap_or(0)+1; counts[(b,to)]=counts.get((b,to)).unwrap_or(0)+1
  }
  let used : Map[(Int,Int),Int]=Map([]); let connections : Array[Connection]=[]
  let labels : Array[Label]=[]; for shape in shapes { if shape.label is Some(label) { labels.push(label) } }
  let mut lower=0.0; for shape in shapes { lower=Double::max(lower,shape.box.y+shape.box.height) }
  fn ancestor(child : Int, container : Int) -> Bool {
    let mut i=parents[child]
    while i >= 0 { if !budget.charge(1) { return false }; if i == container { return true }; i=parents[i] }
    false
  }
  for occurrence,(i,a,b) in selected {
    if budget.failed { break }
    let flow=view.flows[i]; let source=by_index[a]; let target=by_index[b]; let (from,to)=sides[occurrence]
    fn next_port(shape : Shape, side : Int) -> Point {
      let key=(shape.index,side); let n=used.get(key).unwrap_or(0); used[key]=n+1
      port(shape,side,0.2+0.6*(n+1).to_double()/(counts[key]+1).to_double())
    }
    let start=next_port(source,from); let end=next_port(target,to)
    fn outside(shape : Shape, anchor : Point, side : Int) -> Point {
      match side {
        0 => {x:shape.box.x+shape.box.width+12.0,y:anchor.y}
        1 => {x:anchor.x,y:shape.box.y+shape.box.height+2.0}
        2 => {x:shape.box.x-12.0,y:anchor.y}
        _ => {x:anchor.x,y:shape.box.y-12.0}
      }
    }
    let exit=outside(source,start,from); let entry=outside(target,end,to)
    let obstacles=[]
    for shape in shapes {
      if !budget.charge(1) { break }
      if shape.node.kind == Group || shape.node.kind == Lane || ancestor(a,shape.index) || ancestor(b,shape.index) { continue }
      obstacles.push(inflated(shape.box,if shape.index == a || shape.index == b { 0.0 } else { 8.0 }))
    }
    for label in labels { obstacles.push(inflated(label.box,6.0)) }
    let source_ancestors=Map([]); let mut current=parents[a]
    while current >= 0 { if !budget.charge(1) { break }; source_ancestors[current]=true; current=parents[current] }
    let mut area : Rect?=None; current=parents[b]
    while current >= 0 {
      if !budget.charge(1) { break }
      if source_ancestors.contains(current) && view.nodes[current].kind != Lane && by_index.get(current) is Some(container) { area=Some(inflated(container.box,-8.0)); break }
      current=parents[current]
    }
    guard orthogonal(exit,entry,obstacles,lower+64.0+occurrence.to_double()*32.0,area,budget) is Some(middle) else { if !budget.failed { budget.error("bpmn/layout-limit","No bounded orthogonal route for \{flow.id}") }; break }
    let line=compact([start].iter().concat(middle.iter()).concat([end].iter()).to_array())
    let label=flow_label(flow,line,false,budget)
    let mut chosen : Label?=None
    if label is Some(label) {
      let candidates=[]
      let segments : Array[(Double,Int)]=[]
      for segment in 1..<line.length() { let p=line[segment-1]; let q=line[segment]; segments.push(((p.x-q.x).abs()+(p.y-q.y).abs(),segment)) }
      segments.sort_by((a,b) => { let length=b.0.compare(a.0); if length == 0 { a.1.compare(b.1) } else { length } })
      for (_,segment) in segments {
        let p=line[segment-1]; let q=line[segment]; let cx=(p.x+q.x)/2.0; let cy=(p.y+q.y)/2.0
        for offset in [8.0,32.0,56.0] {
          for box in [Rect::{x:cx-label.box.width/2.0,y:cy-label.box.height-offset,width:label.box.width,height:label.box.height},{x:cx-label.box.width/2.0,y:cy+offset,width:label.box.width,height:label.box.height},{x:cx+offset,y:cy-label.box.height/2.0,width:label.box.width,height:label.box.height},{x:cx-label.box.width-offset,y:cy-label.box.height/2.0,width:label.box.width,height:label.box.height}] { candidates.push(box) }
        }
      }
      for box in candidates {
        let mut clear=area.map(r => r.contains(box)).unwrap_or(true)
        if !clear { continue }
        for shape in shapes {
          if !budget.charge(1) { clear=false; break }
          if shape.node.kind == Group {
            if box.overlaps(shape.box) && !shape.box.contains(inflated(box,6.0)) { clear=false; break }
            continue
          }
          if shape.node.kind == Lane || ancestor(a,shape.index) || ancestor(b,shape.index) { continue }
          if box.overlaps(inflated(shape.box,24.0)) { clear=false; break }
        }
        if !clear { continue }
        for obstacle in obstacles { if !budget.charge(1) { clear=false; break }; if box.overlaps(obstacle) { clear=false; break } }
        if clear {
          for previous in connections { for j in 1..<previous.line.length() { if !budget.charge(1) || crosses(previous.line[j-1],previous.line[j],inflated(box,4.0)) { clear=false; break } }; if !clear { break } }
        }
        if clear { chosen=Some({..label,box}); break }
      }
      if chosen == None { budget.error("bpmn/layout-limit","No bounded label placement for \{flow.id}"); break }
    }
    if chosen is Some(label) { labels.push(label) }
    if line.iter().any(p => p.x.abs() > 1000000000.0 || p.y.abs() > 1000000000.0) { budget.error("bpmn/layout-limit","Automatic route extent exceeded its safe range"); break }
    connections.push({flow,index:i,source:view.nodes[a].id,target:view.nodes[b].id,points:ReadOnlyArray::from_array(line.map(exact_point)),line:ReadOnlyArray::from_array(line),label:chosen})
  }
  connections
}
