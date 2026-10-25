///|
fn numeric(token : String) -> @model.Number { @model.Number::parse(token).unwrap() }

///|
fn box(x : String, y : String, width : String, height : String) -> @model.ShapeGeometry {
  @model.ShapeGeometry::new(@model.SourceIdentity::new(),bounds=@model.ExactBounds::new(numeric(x),numeric(y),numeric(width),numeric(height)))
}

///|
fn simple() -> @model.Bpmn {
  @model.Bpmn::new("P",[
    @model.Node::new("S",StartEvent,bounds={x:20,y:40,width:36,height:36}),
    @model.Node::new("T",Task,bounds={x:100,y:20,width:120,height:80},label="Review"),
  ],[@model.Flow::new("F","S","T",points=[{x:56,y:58},{x:100,y:58}])])
}

///|
test "supplied geometry keeps exact tokens and one viewport translation" {
  let node=@model.Node::new("T",UserTask,geometry=box("-12.345678901234567890123456789","10.000","100.00000000000000001","80.000"))
  let result=@layout.layout(@model.Bpmn::new("P",[node],[]),policy=RequireDi)
  let geometry=result.geometry.unwrap()
  assert_eq(result.diagnostics,[]); assert_eq(geometry.source,Supplied)
  assert_eq(geometry.shapes[0].bounds.x.token,"-12.345678901234567890123456789")
  assert_eq(geometry.shapes[0].bounds.width.token,"100.00000000000000001")
  assert_eq(geometry.translate_x,45L); assert_eq(geometry.translate_y,22L)
  assert_eq(node.geometry.unwrap().bounds.unwrap().x.token,"-12.345678901234567890123456789")
  assert_eq(@layout.check(@layout.layout(simple(),policy=RequireDi).geometry.unwrap(),@theme.Theme::classic().dark),[])
}

///|
test "policies distinguish missing invalid and ignored geometry without mixing coordinates" {
  let valid=@model.Node::new("A",Task,geometry=box("98765","100","120","80"))
  let absent=@model.Node::new("B",UserTask,label="Review")
  let partial=@model.Bpmn::new("P",[valid,absent],[])
  assert_eq(@layout.layout(partial,policy=RequireDi).geometry,None)
  let fallback=@layout.layout(partial)
  assert_eq(fallback.diagnostics[0].code,"bpmn/incomplete-di")
  assert_eq(fallback.geometry.unwrap().source,Automatic)
  assert_true(fallback.geometry.unwrap().shapes.iter().all(s => s.box.x < 1000.0))
  let bad=@model.Bpmn::new("P",[@model.Node::new("A",Task,geometry=box("0","0","-1","80")),absent],[])
  for policy in [@model.GeometryPolicy::PreferDi,RequireDi] { let result=@layout.layout(bad,policy~); assert_eq(result.geometry,None); assert_eq(result.diagnostics[0].code,"bpmn/invalid-geometry") }
  assert_true(@layout.layout(bad,policy=Automatic).geometry != None)
}

///|
test "hidden scopes and boundary attachments retain distinct source and display endpoints" {
  let sub=@model.Node::new("Sub",SubProcess,geometry=box("0","0","200","160"))
  let hidden=@model.Node::new("Inside",Task,ownership=@model.Ownership::new(subprocess="Sub"))
  let other=@model.Node::new("Other",Participant,geometry=box("400","0","200","160"),black_box=true)
  let edge=@model.EdgeGeometry::new(@model.SourceIdentity::new(),[@model.ExactPoint::new(numeric("200"),numeric("80")),@model.ExactPoint::new(numeric("400"),numeric("80"))])
  let message=@model.Flow::new("M","Inside","Other",kind=MessageFlow,geometry=edge)
  let result=@layout.layout(@model.Bpmn::new("C",[sub,hidden,other],[message]),policy=RequireDi)
  let geometry=result.geometry.unwrap()
  assert_eq(geometry.shapes.length(),2); assert_eq(geometry.connections[0].source,"Sub")
  assert_eq(geometry.connections[0].flow.semantic_source.unwrap().source_id,Some("Inside"))
  let activity=@model.Node::new("T",Task,geometry=box("0","0","120","80"))
  let boundary=@model.Node::new("B",BoundaryEvent,geometry=box("60","60","40","40"),ownership=@model.Ownership::new(attached_to="T"))
  let attached=@layout.layout(@model.Bpmn::new("P",[activity,boundary],[]),policy=RequireDi).geometry.unwrap()
  assert_false(@layout.check(attached,@theme.Theme::classic().dark).iter().any(f => f.rule == Attachment || f.rule == Overlap))
}

///|
test "ownership cycles limits and invalid endpoints return errors instead of partial geometry" {
  let cyclic=@model.Bpmn::new("P",[@model.Node::new("A",Lane,ownership=@model.Ownership::new(lanes=["B"])),@model.Node::new("B",Lane,ownership=@model.Ownership::new(lanes=["A"]))],[])
  assert_eq(@layout.layout(cyclic).geometry,None)
  assert_eq(@layout.layout(cyclic).diagnostics[0].code,"bpmn/invalid-reference")
  let bad=@model.Bpmn::new("P",[@model.Node::new("A",Task)],[@model.Flow::new("F","A","Missing")])
  assert_eq(@layout.layout(bad).geometry,None)
  for limits in [@layout.Limits::new(nodes=1),@layout.Limits::new(work=1),@layout.Limits::new(edges=0)] { assert_eq(@layout.layout(simple(),limits~).geometry,None) }
  assert_true(@layout.check(@layout.layout(simple()).geometry.unwrap(),@theme.Theme::classic().dark,work_limit=1).iter().any(f => f.rule == Limit))
}

///|
test "derived numbers format consistently at negative half ties without host formatting" {
  for (value,expected) in [(0.0,"0"),(-0.0001,"0"),(-0.0005,"-0.001"),(-1.2345,"-1.235"),(1.2345,"1.235"),(1000000000.0,"1000000000")] { assert_eq(@layout.svg_number(value),Some(expected)) }
  assert_eq(@layout.svg_number(10000000000000.0),None)
}

///|
test "legibility reports imported overlaps overflow small text and bad endpoint attachment without moving geometry" {
  let font=@model.Font::new(size=numeric("10"))
  let label=@model.LabelGeometry::new(bounds=@model.ExactBounds::new(numeric("80"),numeric("30"),numeric("20"),numeric("10")),font~)
  let a=@model.Node::new("A",Task,label="A long label",geometry=@model.ShapeGeometry::new(@model.SourceIdentity::new(),bounds=box("0","0","120","80").bounds.unwrap(),label~))
  let b=@model.Node::new("B",ExclusiveGateway,geometry=box("80","20","60","60"))
  let c=@model.Node::new("C",Task,geometry=box("300","0","120","80"))
  let f=@model.Flow::new("F","A","C",points=[{x:100,y:40},{x:300,y:40}])
  let result=@layout.layout(@model.Bpmn::new("P",[a,b,c],[f]),policy=RequireDi)
  let geometry=result.geometry.unwrap()
  let findings=@layout.check(geometry,@layout.bpmn_palette(@theme.Theme::classic().light))
  for rule in [@layout.Rule::Overlap,Fit,Size,Endpoint] { assert_true(findings.iter().any(f => f.rule == rule)) }
  assert_eq(geometry.shapes[0].bounds.x.token,"0"); assert_eq(geometry.connections[0].points[0].x.token,"100")
  let palette=@theme.Theme::classic().dark
  let broken={..palette,text:palette.bg,backend:{..palette.backend,ink:palette.bg}}
  assert_true(@layout.check(geometry,broken).iter().any(f => f.rule == Contrast))
}

///|
test "nested containers are intentional while misplaced boundaries and lane escapes are findings" {
  let outer=@model.Node::new("Outer",SubProcess,geometry=box("0","0","500","400"),expanded=true)
  let inner=@model.Node::new("Inner",SubProcess,geometry=box("40","40","350","260"),ownership=@model.Ownership::new(subprocess="Outer"),expanded=true)
  let task=@model.Node::new("T",Task,geometry=box("80","100","120","80"),ownership=@model.Ownership::new(subprocess="Inner"))
  let boundary=@model.Node::new("B",BoundaryEvent,geometry=box("250","210","40","40"),ownership=@model.Ownership::new(subprocess="Inner",attached_to="T"))
  let geometry=@layout.layout(@model.Bpmn::new("P",[outer,inner,task,boundary],[]),policy=RequireDi).geometry.unwrap()
  let findings=@layout.check(geometry,@layout.bpmn_palette(@theme.Theme::classic().dark))
  assert_true(findings.iter().any(f => f.rule == Attachment)); assert_false(findings.iter().any(f => f.rule == Overlap))
  let lane=@model.Node::new("L",Lane,geometry=box("0","0","100","100"))
  let outside=@model.Node::new("T",Task,geometry=box("90","20","120","80"),ownership=@model.Ownership::new(lanes=["L"]))
  let escaped=@layout.layout(@model.Bpmn::new("P",[lane,outside],[]),policy=RequireDi).geometry.unwrap()
  assert_true(@layout.check(escaped,@layout.bpmn_palette(@theme.Theme::classic().dark)).iter().any(f => f.rule == Containment))
}

///|
test "polyline midpoint follows distance rather than the number of authored vertices" {
  assert_eq(@layout.midpoint([{x:0.0,y:0.0},{x:10.0,y:0.0},{x:100.0,y:0.0}]),Some({x:50.0,y:0.0}))
  assert_eq(@layout.midpoint([{x:0.0,y:0.0},{x:100.0,y:0.0},{x:100.0,y:100.0}]),Some({x:100.0,y:0.0}))
  assert_eq(@layout.midpoint([]),None)
}

///|
test "lane artifacts and group labels are intentional while unowned flow nodes still overlap" {
  let lane=@model.Node::new("L",Lane,geometry=box("0","0","600","200"))
  let group=@model.Node::new("G",Group,geometry=box("80","40","220","140"))
  let data=@model.Node::new("D",DataObjectReference,label="Data",geometry=box("130","70","40","50"))
  let task=@model.Node::new("T",Task,geometry=box("340","60","120","80"))
  let geometry=@layout.layout(@model.Bpmn::new("P",[lane,group,data,task],[]),policy=RequireDi).geometry.unwrap()
  let findings=@layout.check(geometry,@layout.bpmn_palette(@theme.Theme::classic().dark))
  assert_false(findings.iter().any(f => f.rule == Overlap && f.identities.contains("D")))
  assert_true(findings.iter().any(f => f.rule == Overlap && f.identities.contains("T")))
}
