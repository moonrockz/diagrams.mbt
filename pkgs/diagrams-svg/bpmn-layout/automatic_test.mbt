///|
fn placed(geometry : @layout.Geometry, id : String) -> @layout.Shape { geometry.shapes.iter().find_first(s => s.node.id == id).unwrap() }

///|
fn automatic(view : @model.Bpmn) -> @layout.Geometry raise {
  let result=@layout.layout(view,policy=Automatic)
  assert_true(result.geometry != None,msg=@debug.to_string(result.diagnostics))
  let geometry=result.geometry.unwrap()
  for palette in [@theme.Theme::classic().dark,@theme.Theme::classic().light] {
    let findings=@layout.check(geometry,@layout.bpmn_palette(palette))
    assert_eq(findings,[],msg=@debug.to_string(findings))
  }
  geometry
}

///|
test "cycle condensation ranks successors and packs disconnected components deterministically" {
  let nodes=[@model.Node::new("A",StartEvent,label="Start"),@model.Node::new("B",UserTask,label="Review a deliberately long request label"),@model.Node::new("C",ServiceTask,label="Record\nresult"),@model.Node::new("D",Task,label="Independent")]
  let flows=[@model.Flow::new("AB","A","B",label="request"),@model.Flow::new("BC","B","C",label="forward"),@model.Flow::new("CB","C","B",label="return"),@model.Flow::new("BB","B","B",label="retry"),@model.Flow::new("BC2","B","C",label="parallel")]
  let view=@model.Bpmn::new("P",nodes,flows)
  let geometry=automatic(view)
  assert_eq(@layout.layout(view,policy=Automatic).geometry,Some(geometry))
  assert_true(placed(geometry,"A").box.x < placed(geometry,"B").box.x)
  assert_eq(placed(geometry,"B").box.x+placed(geometry,"B").box.width/2.0,placed(geometry,"C").box.x+placed(geometry,"C").box.width/2.0)
  assert_true(placed(geometry,"D").box.y > placed(geometry,"A").box.y)
  assert_true(placed(geometry,"B").box.width > 300.0)
  assert_true(geometry.connections[1].points != geometry.connections[4].points)
  for edge in geometry.connections {
    assert_true(edge.points.length() >= 2)
    for i in 1..<edge.line.length() { let a=edge.line[i-1]; let b=edge.line[i]; assert_true(a.x == b.x || a.y == b.y) }
  }
}

///|
test "nested lanes expanded subprocesses boundary events and groups retain containment" {
  let nodes=[
    @model.Node::new("Pool",Participant,label="Buyer"),
    @model.Node::new("L",Lane,label="Operations",ownership=@model.Ownership::new(pool="Pool")),
    @model.Node::new("InnerLane",Lane,label="Review team",ownership=@model.Ownership::new(pool="Pool",lanes=["L"])),
    @model.Node::new("Sub",SubProcess,label="Expanded",expanded=true,ownership=@model.Ownership::new(pool="Pool",lanes=["L","InnerLane"])),
    @model.Node::new("A",UserTask,label="Review",ownership=@model.Ownership::new(pool="Pool",lanes=["L","InnerLane"],subprocess="Sub",groups=["Group"])),
    @model.Node::new("B",ServiceTask,label="Store",ownership=@model.Ownership::new(pool="Pool",lanes=["L","InnerLane"],subprocess="Sub",groups=["Group"])),
    @model.Node::new("Timer",BoundaryEvent,label="Reminder",ownership=@model.Ownership::new(pool="Pool",subprocess="Sub",attached_to="A"),markers=@model.Markers::new(interrupting=false,events=[@model.EventMarker::new(Timer)])),
    @model.Node::new("Group",Group,label="Work",ownership=@model.Ownership::new(pool="Pool",subprocess="Sub")),
    @model.Node::new("Supplier",Participant,label="Supplier",black_box=true),
  ]
  let flows=[@model.Flow::new("AB","A","B"),@model.Flow::new("Retry","Timer","B",label="remind"),@model.Flow::new("Message","B","Supplier",kind=MessageFlow,label="order"),@model.Flow::new("Again","A","A",label="again")]
  let geometry=automatic(@model.Bpmn::new("C",nodes,flows,kind=Collaboration))
  for (child,parent) in [("L","Pool"),("InnerLane","L"),("Sub","InnerLane"),("A","Sub"),("B","Sub"),("Group","Sub")] { assert_true(placed(geometry,parent).box.contains(placed(geometry,child).box)) }
  assert_true(placed(geometry,"Group").box.contains(placed(geometry,"A").box))
  assert_true(placed(geometry,"Group").box.contains(placed(geometry,"B").box))
  assert_eq(geometry.connections[2].target,"Supplier")
  for edge in geometry.connections {
    if edge.flow.id == "Message" { continue }
    for point in edge.line { assert_true(placed(geometry,"Sub").box.contains({x:point.x,y:point.y,width:0.0,height:0.0})) }
  }
  assert_true(geometry.connections[3].line.length() >= 4)
}

///|
test "automatic limits fail without mixed or partially routed geometry" {
  let nodes=[@model.Node::new("A",Task,bounds={x:99999,y:99999,width:120,height:80}),@model.Node::new("B",Task)]
  let view=@model.Bpmn::new("P",nodes,[@model.Flow::new("F","A","B")])
  let preferred=@layout.layout(view)
  assert_eq(preferred.geometry.unwrap().source,Automatic)
  assert_true(preferred.geometry.unwrap().shapes[0].bounds.x.token != "99999")
  for limits in [@layout.Limits::new(nodes=1),@layout.Limits::new(edges=1,work=25),@layout.Limits::new(work=1)] {
    let failed=@layout.layout(view,policy=Automatic,limits~)
    assert_eq(failed.geometry,None); assert_true(failed.diagnostics.iter().any(d => d.severity == Error))
  }
}

///|
test "ten thousand disconnected nodes fit the default visible bound and excess inputs fail explicitly" {
  let nodes=Array::makei(10000,i => @model.Node::new("N\{i}",Task))
  let result=@layout.layout(@model.Bpmn::new("P",nodes,[]),policy=Automatic)
  assert_true(result.geometry != None,msg=@debug.to_string(result.diagnostics))
  assert_eq(result.geometry.unwrap().shapes.length(),10000)
  nodes.push(@model.Node::new("Excess",Task))
  let exceeded=@layout.layout(@model.Bpmn::new("P",nodes,[]),policy=Automatic)
  assert_eq(exceeded.geometry,None); assert_eq(exceeded.diagnostics[0].code,"bpmn/layout-limit")
  let view=@model.Bpmn::new("P",[@model.Node::new("A",Task),@model.Node::new("B",Task)],[@model.Flow::new("AB","A","B"),@model.Flow::new("BA","B","A")])
  let edges=@layout.layout(view,policy=Automatic,limits=@layout.Limits::new(edges=1))
  assert_eq(edges.geometry,None); assert_eq(edges.diagnostics[0].code,"bpmn/layout-limit")
}
