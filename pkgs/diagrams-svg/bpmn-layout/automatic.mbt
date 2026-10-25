///|
fn external_label(kind : @model.NodeKind) -> Bool {
  event(kind) || gateway(kind) || [@model.NodeKind::DataObject,DataObjectReference,DataInput,DataOutput,DataStore,DataStoreReference,Message].contains(kind)
}

///|
fn auto_parent(i : Int, view : @model.Bpmn, input : Input, budget : Budget) -> Int {
  let node=view.nodes[i]
  let mut parent=node.ownership.lanes.last().bind(id => input.nodes.get(id)).unwrap_or(-1)
  if input.containers[i] is Some(sub) {
    let mut lane=if parent >= 0 { Some(parent) } else { None }; let mut inside=false
    while lane is Some(index) {
      if !budget.charge(1) { return -1 }
      if input.containers[index] == Some(sub) { inside=true; break }
      lane=view.nodes[index].ownership.lanes.last().bind(id => input.nodes.get(id))
    }
    if !inside { parent=sub }
  }
  if parent < 0 { parent=node.ownership.pool.bind(id => input.nodes.get(id)).unwrap_or(-1) }
  parent
}

///|
fn scope_links(a : Int, b : Int, parents : ArrayView[Int], budget : Budget) -> (Int,Int,Int)? {
  let ancestors=Map([]); let mut i=a; let mut child=a
  while i >= 0 {
    if !budget.charge(1) { return None }
    ancestors[i]=child; child=i; i=parents[i]
  }
  ancestors[-1]=child; i=b; child=b
  while !ancestors.contains(i) {
    if !budget.charge(1) { return None }
    child=i; i=parents[i]
  }
  let source=ancestors[i]
  if source == child || source == i || child == i { None } else { Some((i,source,child)) }
}

///|
fn automatic(view : @model.Bpmn, input : Input, budget : Budget) -> (Array[Shape],Array[Connection]) {
  let count=view.nodes.length()
  let group_roots=Array::makei(count,i => i)
  fn group_root(i : Int) -> Int {
    let mut root=i
    while group_roots[root] != root { if !budget.charge(1) { return root }; root=group_roots[root] }
    root
  }
  for node in view.nodes {
    let mut first : Int?=None
    for id in node.ownership.groups {
      if !budget.charge(1) { return ([],[]) }
      if input.nodes.get(id) is Some(group) {
        if first is Some(previous) { let a=group_root(previous); let b=group_root(group); group_roots[Int::max(a,b)]=Int::min(a,b) }
        else { first=Some(group) }
      }
    }
  }
  let sizes : Array[(Double,Double)]=[]; let captions : Array[(Double,Double)]=[]
  let slots : Array[(Double,Double)]=[]; let parents=Array::make(count,-1)
  let groups : Map[Int,Array[Int]]=Map([]); let boundaries : Map[Int,Array[Int]]=Map([])
  let boxes : Array[Rect?]=Array::make(count,None)
  let mut gap_x=96.0; let mut gap_y=80.0
  for i,node in view.nodes {
    let text=node.label+node.properties.bind(p => p.sublabel).map(s => "\n"+s).unwrap_or("")
    let (width,height)=measure(text,default_font(),budget).unwrap_or((0.0,0.0))
    captions.push((width,if text.is_empty() { 0.0 } else { height }))
    let size=if event(node.kind) { (40.0,40.0) } else if gateway(node.kind) { (56.0,56.0) }
      else if [@model.NodeKind::DataObject,DataObjectReference,DataInput,DataOutput].contains(node.kind) { (48.0,64.0) }
      else if node.kind == DataStore || node.kind == DataStoreReference { (64.0,64.0) }
      else if node.kind == Message { (56.0,36.0) }
      else { (Double::max(140.0,width+48.0),Double::max(100.0,height+64.0)) }
    sizes.push(size); slots.push(size)
    if !input.visible[i] { continue }
    parents[i]=auto_parent(i,view,input,budget)
    for id in node.ownership.groups {
      if !budget.charge(1) { return ([],[]) }
      guard input.nodes.get(id) is Some(group) && view.nodes[group].kind == Group else { budget.error("bpmn/invalid-reference","Invalid group membership on \{node.id}"); return ([],[]) }
      match groups.get(group) { Some(members) => members.push(i); None => groups[group]=[i] }
    }
    if node.ownership.attached_to.bind(id => input.nodes.get(id)) is Some(owner) {
      match boundaries.get(owner) { Some(events) => events.push(i); None => boundaries[owner]=[i] }
    }
  }
  for flow in view.flows {
    let text=flow.label+flow.properties.bind(p => p.sublabel).map(s => "\n"+s).unwrap_or("")
    let (width,height)=measure(text,default_font(),budget).unwrap_or((0.0,0.0))
    gap_x=Double::max(gap_x,width+64.0); gap_y=Double::max(gap_y,height+48.0)
  }
  // Boundary captions reserve space on the owning activity's row.
  for (owner,events) in boundaries {
    let mut width=80.0
    for event in events { width=Double::max(width,captions[event].0+32.0) }
    sizes[owner]=(Double::max(sizes[owner].0,width*events.length().to_double()+32.0),sizes[owner].1)
    for event in events { parents[event]=parents[owner] }
  }
  let selected : Array[(Int,Int,Int)]=[]
  for i,flow in view.flows {
    guard selected_flow(flow,view,input,budget) is Some((a,b)) else { continue }
    if selected.length() >= budget.limits.edges { budget.error("bpmn/layout-limit","Visible connection limit exceeded"); return ([],[]) }
    selected.push((i,a,b))
  }
  let neighbors : Map[Int,Array[Int]]=Map([])
  for (_,a,b) in selected {
    for (item,other) in [(a,b),(b,a)] {
      if artifact(view.nodes[item].kind) && view.nodes[item].kind != Group && !artifact(view.nodes[other].kind) {
        // Artifacts can follow connected flow nodes into lanes, but cannot cross
        // a subprocess ownership boundary merely because an association does.
        let base=parents[item]; let mut candidate=parents[other]; let mut current=candidate
        while current >= 0 && current != base {
          if !budget.charge(1) { return ([],[]) }
          if view.nodes[current].kind != Lane && view.nodes[current].kind != Participant { candidate=parents[current] }
          current=parents[current]
        }
        match neighbors.get(item) { Some(values) => values.push(candidate); None => neighbors[item]=[candidate] }
      }
    }
  }
  for (item,owners) in neighbors {
    let mut owner=owners[0]
    for other in owners {
      let ancestors=Map([(-1,true)]); let mut current=owner
      while current >= 0 { if !budget.charge(1) { return ([],[]) }; ancestors[current]=true; current=parents[current] }
      current=other
      while !ancestors.contains(current) { if !budget.charge(1) { return ([],[]) }; current=parents[current] }
      owner=current
    }
    let base=parents[item]; let mut current=owner
    while current >= 0 && current != base { if !budget.charge(1) { return ([],[]) }; current=parents[current] }
    if base < 0 || current == base { parents[item]=owner }
  }
  let children : Map[Int,Array[Int]]=Map([])
  for i,node in view.nodes {
    if !input.visible[i] || node.ownership.attached_to != None || (node.kind == Group && groups.get(i).map(g => !g.is_empty()).unwrap_or(false)) { continue }
    match children.get(parents[i]) { Some(values) => values.push(i); None => children[parents[i]]=[i] }
  }
  let links : Map[Int,Array[(Int,Int)]]=Map([])
  for (_,a,b) in selected {
    let a=view.nodes[a].ownership.attached_to.bind(id => input.nodes.get(id)).unwrap_or(a)
    let b=view.nodes[b].ownership.attached_to.bind(id => input.nodes.get(id)).unwrap_or(b)
    if scope_links(a,b,parents,budget) is Some((scope,a,b)) {
      match links.get(scope) { Some(edges) => edges.push((a,b)); None => links[scope]=[(a,b)] }
    }
  }
  let stack=[(-1,false)]
  while stack.pop() is Some((scope,leave)) {
    if !budget.charge(1) { return ([],[]) }
    let members=children.get(scope).unwrap_or([])
    if !leave { stack.push((scope,true)); for i in members { if children.contains(i) { stack.push((i,false)) } }; continue }
    let bands=members.filter(i => view.nodes[i].kind == Lane || view.nodes[i].kind == Participant)
    let ordinary=members.filter(i => view.nodes[i].kind != Lane && view.nodes[i].kind != Participant)
    let mut top=64.0; let mut right=128.0
    for i in bands {
      let (width,height)=sizes[i]; boxes[i]=Some({x:64.0,y:top,width,height}); slots[i]=sizes[i]
      top+=height+gap_y; right=Double::max(right,width+128.0)
    }
    let eligible=Map(ordinary.map(i => (i,true)))
    let edges=links.get(scope).unwrap_or([]).filter(p => eligible.contains(p.0) && eligible.contains(p.1))
    let rank=ranks(ordinary,edges,budget)
    let widths : Map[Int,Double]=Map([]); let rows : Map[Int,Double]=Map([])
    let mut last_rank=0
    for i in ordinary {
      let (width,height)=sizes[i]; let caption=captions[i]
      let mut slot_width=if external_label(view.nodes[i].kind) { Double::max(width,caption.0) } else { width }
      let mut slot_height=height+(if external_label(view.nodes[i].kind) { caption.1+8.0 } else { 0.0 })
      for event in boundaries.get(i).unwrap_or([]) { slot_height=Double::max(slot_height,height+20.0+captions[event].1+8.0) }
      for id in view.nodes[i].ownership.groups { if input.nodes.get(id) is Some(group) { slot_width=Double::max(slot_width,captions[group].0+64.0) } }
      slots[i]=(slot_width,slot_height)
      let r=rank.get(i).unwrap_or(0); widths[r]=Double::max(widths.get(r).unwrap_or(0.0),slot_width); last_rank=Int::max(last_rank,r)
    }
    let lefts=Map([]); let mut left=64.0
    for r in 0..=last_rank { lefts[r]=left; left+=widths.get(r).unwrap_or(0.0)+gap_x }
    let grouped : Map[Int,Array[Int]]=Map([]); let bands : Array[Int]=[]
    for i in ordinary {
      let band=view.nodes[i].ownership.groups.get(0).bind(id => input.nodes.get(id)).map(group_root).unwrap_or(count)
      match grouped.get(band) { Some(values) => values.push(i); None => { grouped[band]=[i]; bands.push(band) } }
    }
    bands.sort_by((a,b) => a.compare(b))
    let mut bottom=top
    for band in bands {
      rows.clear()
      let mut next_top=top
      for i in grouped[band] {
        let r=rank.get(i).unwrap_or(0); let y=rows.get(r).unwrap_or(top)
        let (width,height)=sizes[i]; let slot=slots[i]
        boxes[i]=Some({x:lefts[r]+(widths[r]-width)/2.0,y,width,height})
        rows[r]=y+slot.1+gap_y; next_top=Double::max(next_top,rows[r]); bottom=Double::max(bottom,y+slot.1+64.0)
      }
      top=next_top
    }
    right=Double::max(right,left-gap_x+64.0)
    if scope >= 0 { sizes[scope]=(Double::max(sizes[scope].0,right),Double::max(Double::max(sizes[scope].1,bottom),captions[scope].0+48.0)) }
  }
  let queue=children.get(-1).unwrap_or([]).copy(); let mut cursor=0
  while cursor < queue.length() {
    if !budget.charge(1) { return ([],[]) }
    let i=queue[cursor]; cursor+=1
    guard boxes[i] is Some(box) else { continue }
    for child in children.get(i).unwrap_or([]) { if boxes[child] is Some(local_box) { boxes[child]=Some({..local_box,x:local_box.x+box.x,y:local_box.y+box.y}) }; queue.push(child) }
  }
  for (owner,events) in boundaries {
    guard boxes[owner] is Some(box) else { continue }
    for j,event in events { let fraction=(j+1).to_double()/(events.length()+1).to_double(); boxes[event]=Some({x:box.x+box.width*fraction-20.0,y:box.y+box.height-20.0,width:40.0,height:40.0}) }
  }
  for i,node in view.nodes {
    if node.kind != Group || !input.visible[i] { continue }
    let members=groups.get(i).unwrap_or([]); let mut union : Rect?=None
    for item in members {
      if !budget.charge(1) { return ([],[]) }
      if boxes[item] is Some(box) {
        let height=box.height+(if external_label(view.nodes[item].kind) { captions[item].1+8.0 } else { 0.0 })
        let extra_width=Double::max(box.width,captions[item].0)
        let box={..box,x:box.x+(box.width-extra_width)/2.0,width:extra_width,height}
        union=Some(match union { None => box; Some(old) => {x:Double::min(old.x,box.x),y:Double::min(old.y,box.y),width:Double::max(old.x+old.width,box.x+box.width)-Double::min(old.x,box.x),height:Double::max(old.y+old.height,box.y+box.height)-Double::min(old.y,box.y)} })
      }
    }
    if union is Some(box) { let width=Double::max(box.width+40.0,captions[i].0+24.0); boxes[i]=Some({x:box.x+(box.width-width)/2.0,y:box.y-20.0,width,height:box.height+40.0}) }
  }
  let shapes=[]
  for i,node in view.nodes {
    if !input.visible[i] { continue }
    guard boxes[i] is Some(box) else { budget.error("bpmn/invalid-reference","Visible ownership scope is not rooted: \{node.id}"); return ([],[]) }
    if box.x.abs()+box.width > 1000000000.0 || box.y.abs()+box.height > 1000000000.0 { budget.error("bpmn/layout-limit","Automatic geometry extent exceeded its safe range"); return ([],[]) }
    shapes.push({node,index:i,bounds:exact_bounds(box),box,label:node_label(node,box,false,budget)})
  }
  (shapes,route_connections(view,selected,shapes,parents,budget))
}
