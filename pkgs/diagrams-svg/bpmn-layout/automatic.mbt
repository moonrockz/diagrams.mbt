///|
/// The complete baseline uses containment scopes and measured rows. The next
/// story adds graph ranks, cycle condensation and obstacle-aware channels.
fn automatic(view : @model.Bpmn, input : Input, budget : Budget) -> (Array[Shape],Array[Connection]) {
  let sizes : Array[(Double,Double)]=[]
  for node in view.nodes {
    let text=node.label+node.properties.bind(p => p.sublabel).map(s => "\n"+s).unwrap_or("")
    let (text_width,text_height)=measure(text,default_font(),budget).unwrap_or((0.0,0.0))
    let size=if event(node.kind) { (40.0,40.0) } else if gateway(node.kind) { (50.0,50.0) }
      else if node.kind == DataObject || node.kind == DataObjectReference || node.kind == DataInput || node.kind == DataOutput { (48.0,64.0) }
      else if node.kind == DataStore || node.kind == DataStoreReference { (64.0,64.0) }
      else if node.kind == Message { (48.0,32.0) }
      else { (Double::max(120.0,text_width+40.0),Double::max(80.0,text_height+36.0)) }
    sizes.push(size)
  }
  let parents : Array[Int?]=Array::make(view.nodes.length(),None)
  let children : Map[Int,Array[Int]]=Map([])
  for i,node in view.nodes {
    if !input.visible[i] || node.ownership.attached_to != None { continue }
    let parent=node.ownership.lanes.last().bind(id => input.nodes.get(id))
      .unwrap_or_else(() => input.containers[i].unwrap_or_else(() => node.ownership.pool.bind(id => input.nodes.get(id)).unwrap_or(-1)))
    if parent >= 0 { parents[i]=Some(parent) }
    match children.get(parent) { Some(values) => values.push(i); None => children[parent]=[i] }
  }
  let boxes : Array[Rect?]=Array::make(view.nodes.length(),None)
  let stack : Array[(Int,Bool)]=[(-1,false)]
  let active : Map[Int,Bool]=Map([])
  while stack.pop() is Some((scope,leave)) {
    if !budget.charge(1) { return ([],[]) }
    if leave {
      let members=children.get(scope).unwrap_or([])
      let horizontal=scope < 0 || (view.nodes[scope].kind != Participant && view.nodes[scope].kind != Lane)
      let mut cursor=48.0; let mut cross=0.0
      for i in members {
        let (width,height)=sizes[i]
        let box : Rect=if horizontal { {x:cursor,y:48.0,width,height} } else { {x:48.0,y:cursor,width,height} }
        boxes[i]=Some(box)
        cursor+=(if horizontal { width } else { height })+80.0
        cross=Double::max(cross,if horizontal { height } else { width })
      }
      if scope >= 0 { sizes[scope]=(Double::max(sizes[scope].0,if horizontal { cursor+32.0 } else { cross+96.0 }),Double::max(sizes[scope].1,if horizontal { cross+96.0 } else { cursor+32.0 })) }
      active[scope]=false
    } else {
      if active.get(scope).unwrap_or(false) { budget.error("bpmn/invalid-reference","Containment ownership cycle in automatic geometry"); return ([],[]) }
      active[scope]=true; stack.push((scope,true))
      for i in children.get(scope).unwrap_or([]) { if children.contains(i) { stack.push((i,false)) } }
    }
  }
  // Translate each local scope after its parent's position is known.
  let queue=children.get(-1).unwrap_or([]).copy(); let mut cursor=0
  while cursor < queue.length() {
    if !budget.charge(1) { return ([],[]) }
    let i=queue[cursor]; cursor+=1
    guard boxes[i] is Some(box) else { continue }
    for child in children.get(i).unwrap_or([]) {
      if boxes[child] is Some(local_box) { boxes[child]=Some({..local_box,x:local_box.x+box.x,y:local_box.y+box.y}) }
      queue.push(child)
    }
  }
  for i,node in view.nodes {
    if !input.visible[i] || node.ownership.attached_to == None { continue }
    let attached=input.nodes[node.ownership.attached_to.unwrap()]
    if boxes[attached] is Some(box) { let (width,height)=sizes[i]; boxes[i]=Some({x:box.x+box.width-width*1.5,y:box.y+box.height-height/2.0,width,height}) }
  }
  let shapes=[]
  for i,node in view.nodes {
    if !input.visible[i] { continue }
    guard boxes[i] is Some(box) else { budget.error("bpmn/invalid-reference","Visible ownership scope is not rooted: \{node.id}"); return ([],[]) }
    shapes.push({node,index:i,bounds:exact_bounds(box),box,label:node_label(node,box,false,budget)})
  }
  let connections=[]
  for i,flow in view.flows {
    guard selected_flow(flow,view,input,budget) is Some((source,target)) else { continue }
    if connections.length() >= budget.limits.edges { budget.error("bpmn/layout-limit","Visible connection limit exceeded"); return ([],[]) }
    guard boxes[source] is Some(a) && boxes[target] is Some(b) else { budget.error("bpmn/invalid-reference","Missing endpoint geometry"); return ([],[]) }
    let line : Array[Point]=if source == target { [{x:a.x+a.width,y:a.y+a.height/2.0},{x:a.x+a.width+40.0,y:a.y+a.height/2.0},{x:a.x+a.width+40.0,y:a.y-32.0},{x:a.x+a.width/2.0,y:a.y-32.0},{x:a.x+a.width/2.0,y:a.y}] }
      else { [{x:a.x+a.width,y:a.y+a.height/2.0},{x:(a.x+a.width+b.x)/2.0,y:a.y+a.height/2.0},{x:(a.x+a.width+b.x)/2.0,y:b.y+b.height/2.0},{x:b.x,y:b.y+b.height/2.0}] }
    connections.push({flow,index:i,source:view.nodes[source].id,target:view.nodes[target].id,points:ReadOnlyArray::from_array(line.map(exact_point)),line:ReadOnlyArray::from_array(line),label:flow_label(flow,line,false,budget)})
  }
  (shapes,connections)
}
