///|
fn check_bpmn_svg(svg : String) -> Unit raise {
  let read=@bpmn.read(svg)
  assert_true(read.tree.complete); assert_eq(read.diagnostics.filter(d => d.code.has_prefix("xml/")),[])
  let ids : Array[String]=[]
  let references : Array[String]=[]
  for node in read.tree.nodes {
    if node.kind != Element { continue }
    let name=node.name.unwrap().local_name
    assert_false(["script","foreignObject","image","iframe","audio","video"].contains(name))
    for attribute in node.attributes {
      assert_false(attribute.name.local_name.has_prefix("on"))
      if attribute.name.local_name == "id" { assert_false(ids.contains(attribute.value)); ids.push(attribute.value) }
      if attribute.name.local_name == "marker-start" || attribute.name.local_name == "marker-end" {
        let raw=attribute.value; assert_true(raw.has_prefix("url(#") && raw.has_suffix(")")); references.push(raw[5:raw.length()-1].to_owned())
      }
      if attribute.name.local_name == "href" || attribute.name.local_name == "src" { assert_true(attribute.value.has_prefix("#")) }
    }
  }
  for reference in references { assert_true(ids.contains(reference),msg=reference) }
}

///|
test "all graphical kinds and connection forms have standalone theme snapshots" {
  let snapshots : Array[Json]=[]
  let rendered : Array[String]=[]
  for (kind,name) in [
    (@model.NodeKind::Task,"task"),(UserTask,"userTask"),(ServiceTask,"serviceTask"),(SendTask,"sendTask"),(ReceiveTask,"receiveTask"),(ManualTask,"manualTask"),(BusinessRuleTask,"businessRuleTask"),(ScriptTask,"scriptTask"),
    (SubProcess,"subProcess"),(AdHocSubProcess,"adHocSubProcess"),(Transaction,"transaction"),(CallActivity,"callActivity"),
    (StartEvent,"startEvent"),(EndEvent,"endEvent"),(IntermediateCatchEvent,"intermediateCatchEvent"),(IntermediateThrowEvent,"intermediateThrowEvent"),(BoundaryEvent,"boundaryEvent"),
    (ExclusiveGateway,"exclusiveGateway"),(InclusiveGateway,"inclusiveGateway"),(ParallelGateway,"parallelGateway"),(ComplexGateway,"complexGateway"),(EventBasedGateway,"eventBasedGateway"),
    (Participant,"participant"),(Lane,"lane"),(DataObject,"dataObject"),(DataObjectReference,"dataObjectReference"),(DataInput,"dataInput"),(DataOutput,"dataOutput"),(DataStore,"dataStore"),(DataStoreReference,"dataStoreReference"),(Group,"group"),(TextAnnotation,"textAnnotation"),(Message,"message"),
  ] {
    let circle=[@model.NodeKind::StartEvent,EndEvent,IntermediateCatchEvent,IntermediateThrowEvent,BoundaryEvent].contains(kind)
    let square=[@model.NodeKind::ExclusiveGateway,InclusiveGateway,ParallelGateway,ComplexGateway,EventBasedGateway].contains(kind)
    let bounds : @model.Bounds=if circle { {x:80,y:80,width:40,height:40} } else if square { {x:80,y:80,width:60,height:60} } else if [@model.NodeKind::DataObject,DataObjectReference,DataInput,DataOutput].contains(kind) { {x:80,y:80,width:60,height:80} }
      else if kind == DataStore || kind == DataStoreReference { {x:80,y:80,width:64,height:64} }
      else if kind == Message { {x:80,y:80,width:64,height:42} }
      else { {x:80,y:80,width:160,height:100} }
    let ownership=if kind == BoundaryEvent { @model.Ownership::new(attached_to="Activity") } else { @model.Ownership::new() }
    let node=@model.Node::new("Symbol",kind,bounds~,ownership~,label=if kind == TextAnnotation { "Review & sign" } else { name })
    let nodes=if kind == BoundaryEvent { [@model.Node::new("Activity",Task,bounds={x:20,y:20,width:100,height:80}),node] } else { [node] }
    for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
      let result=@svg.SvgRenderer::new(mode~,bpmn_policy=RequireDi).render(Bpmn(@model.Bpmn::new(name,nodes,[])))
      assert_true(result.output != None,msg=@debug.to_string(result.diagnostics))
      let svg=result.output.unwrap(); check_bpmn_svg(svg)
      assert_true(svg.contains("data-kind=\"\{name}\""))
      snapshots.push(Json([name,variant,svg]))
    }
    rendered.push(name)
  }
  for (kind,name) in [(@model.ConnectionKind::SequenceFlow,"sequenceFlow"),(MessageFlow,"messageFlow"),(Association,"association"),(DataInputAssociation,"dataInputAssociation"),(DataOutputAssociation,"dataOutputAssociation"),(DataAssociation,"dataAssociation")] {
    let view=@model.Bpmn::new(name,[@model.Node::new("A",Task,bounds={x:0,y:0,width:120,height:80},label="A"),@model.Node::new("B",Task,bounds={x:240,y:0,width:120,height:80},label="B")],[@model.Flow::new("F","A","B",points=[{x:120,y:40},{x:240,y:40}],kind~,direction=Both)])
    for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
      let result=@svg.SvgRenderer::new(mode~,bpmn_policy=RequireDi).render(Bpmn(view))
      let svg=result.output.unwrap(); check_bpmn_svg(svg)
      assert_true(svg.contains("data-kind=\"\{name}\""))
      snapshots.push(Json([name,variant,svg]))
    }
    rendered.push(name)
  }
  guard @json.parse(@corpus.graphical_coverage) is {"entries":Array(entries),..} else { fail("manifest missing") }
  for entry in entries { guard entry is {"tag":String(tag),..} else { fail("tag missing") }; assert_true(rendered.contains(tag),msg=tag) }
  let t=@test.Test("symbol inventory"); t.write(Json(snapshots).stringify()); t.snapshot(filename="symbols.json")
}

///|
test "event definitions activity and gateway markers retain recognizable notation" {
  let snapshots : Array[Json]=[]
  for (kind,name) in [(@model.EventKind::Message,"message"),(Timer,"timer"),(Conditional,"conditional"),(Link,"link"),(Signal,"signal"),(Error,"error"),(Escalation,"escalation"),(Cancel,"cancel"),(Compensation,"compensation"),(Terminate,"terminate")] {
    for (node_kind,variant) in [(@model.NodeKind::IntermediateCatchEvent,"catch"),(IntermediateThrowEvent,"throw")] {
      let node=@model.Node::new("Event",node_kind,bounds={x:20,y:20,width:48,height:48},markers=@model.Markers::new(events=[@model.EventMarker::new(kind)]))
      let result=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(@model.Bpmn::new(name,[node],[])))
      let svg=result.output.unwrap(); check_bpmn_svg(svg)
      assert_true(svg.contains("data-events=\"\{name}\""))
      snapshots.push(Json([name,variant,svg]))
    }
  }
  for (loop_kind,name) in [(@model.LoopKind::Standard,"standard"),(Sequential,"sequential"),(Parallel,"parallel")] {
    let markers=@model.Markers::new(loop_kind~,compensation=true)
    let view=@model.Bpmn::new(name,[@model.Node::new("Task",AdHocSubProcess,bounds={x:20,y:20,width:180,height:100},markers~)],[])
    let svg=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(view)).output.unwrap()
    assert_true(svg.contains("M12 2 L1 12 L12 22 Z")); check_bpmn_svg(svg)
    snapshots.push(Json([name,"marker",svg]))
  }
  for (name,kind,markers) in [
    ("multiple",@model.NodeKind::StartEvent,@model.Markers::new(events=[@model.EventMarker::new(Message),@model.EventMarker::new(Timer)])),
    ("parallel-multiple",StartEvent,@model.Markers::new(parallel_multiple=true,events=[@model.EventMarker::new(Message),@model.EventMarker::new(Timer)])),
    ("event-gateway-exclusive",EventBasedGateway,@model.Markers::new(instantiate=true)),
    ("event-gateway-parallel",EventBasedGateway,@model.Markers::new(instantiate=true,details=[("@eventGatewayType","Parallel")])),
    ("call-user",CallActivity,@model.Markers::new(called_kind=UserTask)),
    ("receive-instantiating",ReceiveTask,@model.Markers::new(instantiate=true)),
    ("data-collection",DataObjectReference,@model.Markers::new(collection=true)),
    ("participant-multiple",Participant,@model.Markers::new(details=[("participantMultiplicity/@maximum","003")])),
  ] {
    let circle=kind == StartEvent || kind == EventBasedGateway
    let node=@model.Node::new("N",kind,bounds=if circle { {x:20,y:20,width:60,height:60} } else { {x:20,y:20,width:180,height:100} },markers~)
    let svg=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(@model.Bpmn::new(name,[node],[]))).output.unwrap()
    if name == "event-gateway-parallel" { assert_true(svg.contains("M12 5 V19 M5 12 H19")) }
    check_bpmn_svg(svg); snapshots.push(Json([name,"adaptive",svg]))
  }
  for expanded in [false,true] {
    let parent=@model.Node::new("Sub",SubProcess,bounds={x:20,y:20,width:240,height:180},expanded~,markers=@model.Markers::new(event_subprocess=true))
    let start=@model.Node::new("Trigger",StartEvent,bounds={x:60,y:80,width:40,height:40},ownership=@model.Ownership::new(subprocess="Sub"),markers=@model.Markers::new(interrupting=false,events=[@model.EventMarker::new(Message),@model.EventMarker::new(Timer)]))
    let svg=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(@model.Bpmn::new("event-subprocess",[parent,start],[]))).output.unwrap()
    assert_true(svg.contains("M12 1 L23 9 L19 22 H5 L1 9 Z")); check_bpmn_svg(svg)
    snapshots.push(Json([if expanded { "event-subprocess-expanded" } else { "event-subprocess-collapsed" },"adaptive",svg]))
  }
  for (name,condition,is_default,direction) in [("conditional",Some("inert x < 2"),false,@model.AssociationDirection::None),("default",None,true,None),("association-none",None,false,None),("association-one",None,false,One)] {
    let kind=if name.has_prefix("association") { @model.ConnectionKind::Association } else { SequenceFlow }
    let view=@model.Bpmn::new(name,[@model.Node::new("A",Task,bounds={x:0,y:0,width:120,height:80}),@model.Node::new("B",Task,bounds={x:240,y:0,width:120,height:80})],[@model.Flow::new("F","A","B",points=[{x:120,y:40},{x:240,y:40}],kind~,condition?,is_default~,direction~)])
    let svg=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(view)).output.unwrap()
    check_bpmn_svg(svg); snapshots.push(Json([name,"adaptive",svg]))
  }
  let t=@test.Test("event and activity markers"); t.write(Json(snapshots).stringify()); t.snapshot(filename="markers.json")
}

///|
test "SVG metadata escaping ID isolation and output limits never copy active content" {
  let properties=@model.RenderProperties::new(link=@model.Link::new("javascript:<bad>&\"x"),description="<script>alert('x')</script>")
  let node=@model.Node::new("render",UserTask,bounds={x:20,y:20,width:400,height:100},label="</script><img onerror=boom> 😀 &",source=@model.SourceIdentity::new(source_id="<original>&",resource_id="memory:<source>"),properties~)
  let view=@model.Bpmn::new("Title <unsafe>",[node],[])
  let a=@svg.SvgRenderer::new(id_prefix="A<>&😀").render(Bpmn(view)).output.unwrap()
  let b=@svg.SvgRenderer::new(id_prefix="B").render(Bpmn(view)).output.unwrap()
  check_bpmn_svg(a); check_bpmn_svg(b)
  assert_true(a.contains("data-source-id=\"&lt;original&gt;&amp;\"")); assert_true(a.contains("data-link=\"javascript:&lt;bad&gt;&amp;&quot;x\""))
  assert_false(a.contains("<img")); assert_true(a != b)
  let bad=@model.Bpmn::new("P",[@model.Node::new("T",Task,bounds={x:0,y:0,width:120,height:80},label="bad\u0001")],[])
  let invalid=@svg.SvgRenderer::new().render(Bpmn(bad))
  assert_eq(invalid.output,None); assert_eq(invalid.diagnostics[0].code,"bpmn/invalid-xml-character")
  let limited=@svg.SvgRenderer::new(bpmn_limits=@bpmn_layout.Limits::new(output_units=10)).render(Bpmn(view))
  assert_eq(limited.output,None); assert_eq(limited.diagnostics[0].code,"bpmn/render-limit")
  let t=@test.Test("isolated BPMN copies"); t.write(Json([a,b]).stringify()); t.snapshot(filename="inline.json")
}

///|
test "source policy ignores broken DI only when automatic is explicit" {
  let source=fixture().replace(old="width=\"180\"",new="width=\"-1\"")
  for policy in [@model.GeometryPolicy::PreferDi,RequireDi] { assert_eq(@adapter.render_svg(source,geometry_policy=policy).output,None) }
  let automatic=@adapter.render_svg(source,geometry_policy=Automatic)
  assert_true(automatic.output != None,msg=@debug.to_string(automatic.diagnostics))
  let malformed=fixture().replace(old="width=\"180\"",new="width=\"bad\"")
  assert_true(@adapter.render_svg(malformed,geometry_policy=Automatic).output != None)
  assert_true(@adapter.render_svg(malformed,geometry_policy=Automatic).diagnostics.iter().all(d => d.severity != Error))
}

///|
test "complete supplied process and collaboration views preserve source and render without legibility findings" {
  let snapshots : Array[Json]=[]
  for input in @corpus.render_inputs {
    let read=@bpmn.read(input.source,source_id=input.name)
    assert_eq(read.diagnostics,[]); assert_eq(read.tree.text(),input.source)
    let document=read.document.unwrap()
    assert_eq(@bpmn.read(@bpmn.write(document)).document,Some(document))
    assert_eq(@bpmn.validate(document).findings,[])
    let converted=@adapter.to_diagram(document)
    assert_eq(converted.diagnostics,[])
    assert_true(converted.diagram != None)
    for (mode,variant) in [(@svg.Mode::Adaptive,"adaptive"),(Fixed(Dark),"dark"),(Fixed(Light),"light")] {
      let rendered=@svg.SvgRenderer::new(mode~,bpmn_policy=RequireDi).render(converted.diagram.unwrap())
      assert_eq(rendered.diagnostics,[],msg=@debug.to_string(rendered.diagnostics))
      let svg=rendered.output.unwrap(); check_bpmn_svg(svg)
      snapshots.push(Json([input.name,variant,svg]))
    }
    assert_eq(@bpmn.write(document),@bpmn.write(read.document.unwrap()))
  }
  let t=@test.Test("supplied BPMN views"); t.write(Json(snapshots).stringify()); t.snapshot(filename="views.json")
}

///|
test "outer supplied containers paint before children regardless of model order" {
  let inner=@model.Node::new("Sub",SubProcess,bounds={x:40,y:40,width:240,height:160},expanded=true,ownership=@model.Ownership::new(lanes=["L"],pool="Pool"))
  let lane=@model.Node::new("L",Lane,bounds={x:30,y:20,width:400,height:240},ownership=@model.Ownership::new(pool="Pool"))
  let pool=@model.Node::new("Pool",Participant,bounds={x:0,y:0,width:450,height:280})
  let svg=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(@model.Bpmn::new("P",[inner,lane,pool],[]))).output.unwrap()
  let ids : Array[String]=[]
  for node in @bpmn.read(svg).tree.nodes {
    if node.attributes.iter().any(a => a.name.local_name == "class" && a.value == "bpmn-shape") {
      ids.push(node.attributes.iter().find_first(a => a.name.local_name == "data-id").unwrap().value)
    }
  }
  assert_eq(ids,["Pool","L","Sub"])
}

///|
test "supplied fractional and exponent tokens reach SVG unchanged alongside font settings" {
  let view=converted(model_document("di-views"),selector=Plane("D1"))
  let result=@svg.SvgRenderer::new(bpmn_policy=RequireDi).render(Bpmn(view))
  let svg=result.output.unwrap()
  for token in ["-12.345678901234567890123456789","100.00000000000000001","1.234567890123456789E+2","123.45678901234567890123456789","1.200000000000000000000001E+1"] { assert_true(svg.contains(token)) }
  assert_true(svg.contains("font-weight=\"700\"")); assert_true(svg.contains("text-decoration=\"underline "))
  assert_true(result.diagnostics.iter().any(d => d.code == "bpmn/legibility"))
  check_bpmn_svg(svg)
}

///|
test "geometry policy checks broken supplied bounds for imported process nodes" {
  let imported=@bpmn.read("<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:test'><b:process id='P'><b:task id='T'/></b:process></b:definitions>").document.unwrap()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("other",imported)])
  let root=validation_document("<b:import namespace='urn:test' location='other' importType='http://www.omg.org/spec/BPMN/20100524/MODEL'/><b:collaboration id='C'><b:participant id='Pool' processRef='a:P'/></b:collaboration><bd:BPMNDiagram><bd:BPMNPlane bpmnElement='C'><bd:BPMNShape bpmnElement='Pool'><dc:Bounds x='0' y='0' width='400' height='200'/></bd:BPMNShape><bd:BPMNShape bpmnElement='a:T'><dc:Bounds x='60' y='60' width='-120' height='80'/></bd:BPMNShape></bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:a='urn:test' xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC'")
  for policy in [@model.GeometryPolicy::PreferDi,RequireDi] {
    let conversion=@adapter.to_diagram(root,resources~,geometry_policy=policy)
    assert_true(conversion.diagram != None,msg=@debug.to_string(conversion.diagnostics))
    let result=@svg.SvgRenderer::new(bpmn_policy=policy).render(conversion.diagram.unwrap())
    assert_eq(result.output,None); assert_eq(result.diagnostics[0].code,"bpmn/invalid-geometry")
  }
  let conversion=@adapter.to_diagram(root,resources~,geometry_policy=Automatic)
  assert_true(conversion.diagram != None,msg=@debug.to_string(conversion.diagnostics))
  assert_true(@svg.SvgRenderer::new(bpmn_policy=Automatic).render(conversion.diagram.unwrap()).output != None)
}
