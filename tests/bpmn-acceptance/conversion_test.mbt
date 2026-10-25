///|
fn converted(doc : @bpmn.Document, selector? : @adapter.ViewSelector = Automatic, resources? : @bpmn.ResourceSet = @bpmn.ResourceSet::new()) -> @model.Bpmn raise {
  let c=@adapter.to_diagram(doc,selector~,resources~)
  assert_true(c.diagram != None,msg=@debug.to_string(c.diagnostics))
  guard c.diagram is Some(Bpmn(view)) else { fail("BPMN view missing") }
  view
}

///|
fn process_view(body : String) -> @bpmn.Document { validation_document("<b:process id='P'>\{body}</b:process>") }

///|
test "view selection uses nonempty tiers and explicit process collaboration and plane identities" {
  let two=validation_document("<b:process id='A'><b:task id='AT'/></b:process><b:process id='B'><b:task id='BT'/></b:process>")
  let ambiguous=@adapter.to_diagram(two)
  assert_eq(ambiguous.diagram,None); assert_eq(ambiguous.diagnostics[0].code,"bpmn/ambiguous-view")
  assert_true(ambiguous.diagnostics[0].message.contains("A, B"))
  assert_eq(converted(two,selector=Process("B")).nodes[0].source.source_id,Some("BT"))
  let collab=validation_document("<b:process id='A'><b:task id='AT'/></b:process><b:process id='B'><b:task id='BT'/></b:process><b:collaboration id='C'><b:participant id='PA' processRef='A'/><b:participant id='PB' processRef='B'/><b:participant id='Closed'/><b:messageFlow id='MF' sourceRef='PA' targetRef='PB'/></b:collaboration>")
  let view=converted(collab)
  assert_eq(view.kind,Collaboration); assert_eq(view.source.source_id,Some("C")); assert_eq(view.nodes.length(),5)
  assert_true(view.nodes.iter().find_first(n => n.id == "Closed").unwrap().black_box)
  assert_eq(view.flows[0].kind,MessageFlow); assert_eq(view.flows[0].source,"PA"); assert_eq(view.flows[0].target,"PB")
  assert_eq(view.nodes.iter().find_first(n => n.source.source_id == Some("AT")).unwrap().ownership.pool,Some("PA"))
  assert_eq(converted(collab,selector=Collaboration("C")),view)
  let minimal=@bpmn.read(fixture()).document.unwrap()
  assert_eq(converted(minimal,selector=Plane("Diagram_1")),converted(minimal,selector=Plane("Plane_1")))
  assert_eq(converted(minimal,selector=Process("Process_1")).plane.unwrap().source_id,Some("Plane_1"))
  assert_eq(@adapter.to_diagram(minimal,selector=Plane("missing")).diagnostics[0].code,"bpmn/view-not-found")
  let empty=validation_document("<b:process id='P'/><bd:BPMNDiagram id='D'/>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI'")
  assert_eq(@adapter.to_diagram(empty,selector=Plane("D")).diagnostics[0].code,"bpmn/missing-plane")
  let invalid=@bpmn.read(fixture().replace(old="bpmnElement=\"Process_1\"",new="bpmnElement=\"absent\"")).document.unwrap()
  assert_eq(@adapter.to_diagram(invalid).diagnostics[0].code,"bpmn/invalid-reference")
}

///|
test "graphical inventory converts every standard process and collaboration kind" {
  let asserted : Array[@bpmn.TypeId]=[]
  for (tag,kind) in [
    ("startEvent",@model.NodeKind::StartEvent),("endEvent",EndEvent),("intermediateCatchEvent",IntermediateCatchEvent),("intermediateThrowEvent",IntermediateThrowEvent),
    ("task",Task),("userTask",UserTask),("serviceTask",ServiceTask),("sendTask",SendTask),("receiveTask",ReceiveTask),("manualTask",ManualTask),("businessRuleTask",BusinessRuleTask),("scriptTask",ScriptTask),
    ("subProcess",SubProcess),("adHocSubProcess",AdHocSubProcess),("transaction",Transaction),("callActivity",CallActivity),
    ("exclusiveGateway",ExclusiveGateway),("inclusiveGateway",InclusiveGateway),("parallelGateway",ParallelGateway),("complexGateway",ComplexGateway),("eventBasedGateway",EventBasedGateway),
    ("dataObject",DataObject),("dataObjectReference",DataObjectReference),("dataStoreReference",DataStoreReference),("group",Group),("textAnnotation",TextAnnotation),
  ] {
    let doc=process_view("<b:\{tag} id='Symbol'/>")
    let view=converted(doc)
    assert_eq(view.nodes.length(),1,msg=tag); assert_eq(view.nodes[0].kind,kind,msg=tag)
    assert_eq(view.nodes[0].source.source_id,Some("Symbol"))
    asserted.push(@bpmn.schema_type(by_id(doc,"Symbol").value_type.unwrap()).unwrap().id)
  }
  let boundary=converted(process_view("<b:task id='Activity'/><b:boundaryEvent id='Boundary' attachedToRef='Activity'/>"))
  assert_eq(boundary.nodes[1].kind,BoundaryEvent); assert_eq(boundary.nodes[1].ownership.attached_to,Some("Activity")); asserted.push(BoundaryEvent)
  let io=converted(process_view("<b:ioSpecification><b:dataInput id='I'/><b:dataOutput id='O'/><b:inputSet/><b:outputSet/></b:ioSpecification>"))
  assert_eq(io.nodes.map(n => n.kind),[DataInput,DataOutput]); asserted.push(DataInput); asserted.push(DataOutput)
  let lane=converted(process_view("<b:laneSet><b:lane id='Lane'/></b:laneSet>"))
  assert_eq(lane.nodes[0].kind,Lane); asserted.push(Lane)
  let participant=converted(validation_document("<b:collaboration id='C'><b:participant id='Pool'/></b:collaboration>"))
  assert_eq(participant.nodes[0].kind,Participant); asserted.push(Participant)
  for (tag,kind) in [("sequenceFlow",@model.ConnectionKind::SequenceFlow),("association",Association)] {
    let view=converted(process_view("<b:task id='A'/><b:task id='B'/><b:\{tag} id='F' sourceRef='A' targetRef='B'/>"))
    assert_eq(view.flows[0].kind,kind)
    asserted.push(if kind == SequenceFlow { SequenceFlow } else { Association })
  }
  let message=converted(validation_document("<b:collaboration id='C'><b:participant id='A'/><b:participant id='B'/><b:messageFlow id='F' sourceRef='A' targetRef='B'/></b:collaboration>"))
  assert_eq(message.flows[0].kind,MessageFlow); asserted.push(MessageFlow)
  for (tag,kind,t) in [("dataInputAssociation",@model.ConnectionKind::DataInputAssociation,@bpmn.TypeId::DataInputAssociation),("dataOutputAssociation",DataOutputAssociation,DataOutputAssociation)] {
    let input=kind == DataInputAssociation
    let source=if input { "Data" } else { "Output" }; let target=if input { "Input" } else { "Data" }
    let view=converted(process_view("<b:task id='Activity'><b:ioSpecification><b:dataInput id='Input'/><b:dataOutput id='Output'/><b:inputSet/><b:outputSet/></b:ioSpecification><b:\{tag} id='F'><b:sourceRef>\{source}</b:sourceRef><b:targetRef>\{target}</b:targetRef></b:\{tag}></b:task><b:dataObject id='Data'/>"))
    assert_eq(view.flows[0].kind,kind)
    assert_eq(view.flows[0].target,if input { "Activity" } else { "Data" })
    assert_eq(view.flows[0].source,if input { "Data" } else { "Activity" })
    assert_eq(view.flows[0].semantic_target.source_id,Some(target)); asserted.push(t)
  }
  // Base dataAssociation has no global element and cannot replace its derived
  // local declarations through xsi:type. Reject this unsupported downcast.
  let base=@adapter.to_diagram(process_view("<b:task id='A'><b:ioSpecification><b:dataInput id='I'/><b:inputSet/><b:outputSet/></b:ioSpecification><b:dataInputAssociation xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:type='b:tDataAssociation' id='F'><b:targetRef>I</b:targetRef></b:dataInputAssociation></b:task>"))
  assert_eq(base.diagram,None); assert_true(base.diagnostics.iter().any(d => d.code == "bpmn/invalid-type"))
  for (tag,kind,t) in [("message",@model.NodeKind::Message,@bpmn.TypeId::Message),("dataStore",DataStore,DataStore)] {
    let doc=validation_document("<b:\{tag} id='Symbol'/><b:process id='P'/><bd:BPMNDiagram><bd:BPMNPlane bpmnElement='P'><bd:BPMNShape bpmnElement='Symbol'><dc:Bounds x='1' y='2' width='30' height='40'/></bd:BPMNShape></bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC'")
    assert_eq(converted(doc).nodes[0].kind,kind); asserted.push(t)
  }
  assert_eq(asserted.length(),@adapter.graphical_types.length())
  let manifest=@json.parse(@corpus.graphical_coverage)
  guard manifest is {"entries":Array(entries),..} else { fail("Graphical manifest entries missing") }
  assert_eq(entries.length(),asserted.length())
  for t in @adapter.graphical_types {
    assert_eq(asserted.iter().filter(a => a == t).count(),1,msg=@debug.to_string(t))
    assert_eq(entries.iter().filter(entry => entry is {"schemaType":String(name),..} && name == t.name().local_name).count(),1)
  }
}

///|
test "effective xsi types and inert extension payloads cannot become generic tasks" {
  let doc=process_view("<b:task xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xsi:type='b:tUserTask' id='U'><b:extensionElements><v:payload xmlns:v='urn:vendor'><b:task id='Fake'/></v:payload></b:extensionElements></b:task>")
  let before=@bpmn.write(doc)
  let view=converted(doc)
  assert_eq(view.nodes.length(),1); assert_eq(view.nodes[0].kind,UserTask); assert_eq(view.nodes[0].source.source_id,Some("U"))
  assert_eq(@bpmn.write(doc),before)
  let unknown=@adapter.to_diagram(process_view("<b:futureActivity id='Unknown'/>"))
  assert_eq(unknown.diagram,None); assert_eq(unknown.diagnostics[0].code,"bpmn/unsupported-element")
  assert_eq(@adapter.to_diagram(validation_document("<b:choreography id='C'/>"),selector=View("C")).diagnostics[0].code,"bpmn/unsupported-view")
  let conversation=validation_document("<b:collaboration id='C'><b:conversation id='V'/></b:collaboration>")
  for selector in [@adapter.ViewSelector::Automatic,View("V")] { assert_eq(@adapter.to_diagram(conversation,selector~).diagnostics[0].code,"bpmn/unsupported-view") }
}

///|
test "markers labels nested ownership default flows and source-less data associations stay explicit" {
  let doc=process_view("<b:laneSet><b:lane id='Outer'><b:flowNodeRef>Sub</b:flowNodeRef><b:childLaneSet><b:lane id='Inner'><b:flowNodeRef>Sub</b:flowNodeRef></b:lane></b:childLaneSet></b:lane></b:laneSet><b:subProcess id='Sub' triggeredByEvent='true'><b:userTask id='T' isForCompensation='true' default='F'><b:multiInstanceLoopCharacteristics isSequential='true'/></b:userTask><b:boundaryEvent id='B' attachedToRef='T' cancelActivity='false'><b:timerEventDefinition><b:timeCycle>R3/PT5M</b:timeCycle></b:timerEventDefinition></b:boundaryEvent><b:endEvent id='E'/><b:sequenceFlow id='F' sourceRef='T' targetRef='E' name='Complete'><b:conditionExpression>approved &amp; ready</b:conditionExpression></b:sequenceFlow></b:subProcess><b:textAnnotation id='Note'><b:text>Review &amp; sign</b:text></b:textAnnotation>")
  let view=converted(doc)
  let sub=view.nodes.iter().find_first(n => n.id == "Sub").unwrap()
  assert_true(sub.markers.event_subprocess); assert_eq(sub.ownership.lanes,["Outer","Inner"])
  assert_eq(view.nodes.iter().find_first(n => n.id == "Inner").unwrap().ownership.lanes,["Outer"])
  let task=view.nodes.iter().find_first(n => n.id == "T").unwrap()
  assert_eq(task.markers.loop_kind,Sequential); assert_true(task.markers.compensation); assert_eq(task.ownership.subprocess,Some("Sub"))
  let boundary=view.nodes.iter().find_first(n => n.id == "B").unwrap()
  assert_false(boundary.markers.interrupting); assert_eq(boundary.markers.events[0].kind,Timer)
  assert_true(boundary.markers.events[0].settings.iter().any(p => p.1 == "R3/PT5M"))
  assert_eq(boundary.ownership.attached_to,Some("T"))
  assert_eq(view.nodes.iter().find_first(n => n.id == "Note").unwrap().label,"Review & sign")
  assert_true(view.flows[0].is_default); assert_eq(view.flows[0].condition,Some("approved & ready")); assert_eq(view.flows[0].label,"Complete")
  for (tag,kind) in [("messageEventDefinition",@model.EventKind::Message),("timerEventDefinition",Timer),("conditionalEventDefinition",Conditional),("linkEventDefinition",Link),("signalEventDefinition",Signal),("errorEventDefinition",Error),("escalationEventDefinition",Escalation),("cancelEventDefinition",Cancel),("compensateEventDefinition",Compensation),("terminateEventDefinition",Terminate)] {
    let body=if tag == "conditionalEventDefinition" { "<b:condition>ready</b:condition>" } else { "" }
    let name=if tag == "linkEventDefinition" { "name='Meaning'" } else { "" }
    let symbol=converted(process_view("<b:startEvent id='S'><b:\{tag} id='Definition' \{name}>\{body}</b:\{tag}></b:startEvent>"))
    assert_eq(symbol.nodes[0].markers.events[0].kind,kind)
  }
  let source_less=converted(process_view("<b:task id='T'><b:ioSpecification><b:dataInput id='I'/><b:inputSet/><b:outputSet/></b:ioSpecification><b:dataInputAssociation id='D'><b:targetRef>I</b:targetRef></b:dataInputAssociation></b:task>"))
  assert_false(source_less.flows[0].has_source); assert_eq(source_less.flows[0].semantic_source,None); assert_eq(source_less.flows[0].semantic_target.source_id,Some("I"))
}

///|
test "imported participant processes retain distinct resource identities and actual endpoints" {
  let root=validation_document("<b:import namespace='urn:a' location='a' importType='\{model_uri}'/><b:import namespace='urn:b' location='b' importType='\{model_uri}'/><b:collaboration id='C'><b:participant id='A' processRef='a:P'/><b:participant id='B' processRef='other:P'/><b:messageFlow id='M' sourceRef='a:T' targetRef='other:T'/></b:collaboration>",extra="xmlns:a='urn:a' xmlns:other='urn:b'")
  fn imported(uri : String) -> @bpmn.Document { @bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='\{uri}'><b:process id='P'><b:task id='T'/><b:endEvent id='E'/><b:sequenceFlow id='F' sourceRef='T' targetRef='E'/></b:process></b:definitions>").document.unwrap() }
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",imported("urn:a")),@bpmn.DocumentResource::new("b",imported("urn:b"))])
  let view=converted(root,resources~)
  let tasks=view.nodes.filter(n => n.source.source_id == Some("T"))
  assert_eq(tasks.length(),2); assert_eq(tasks[0].source.resource_id,Some("a")); assert_eq(tasks[1].source.resource_id,Some("b")); assert_true(tasks[0].id != tasks[1].id)
  let message=view.flows.iter().find_first(f => f.kind == MessageFlow).unwrap()
  assert_eq(message.source,tasks[0].id); assert_eq(message.target,tasks[1].id)
  assert_eq(message.semantic_source.unwrap().resource_id,Some("a")); assert_eq(message.semantic_target.resource_id,Some("b"))
  assert_eq(view.flows.iter().filter(f => f.kind == SequenceFlow).count(),2)
  let unrelated=validation_document("<b:import namespace='urn:absent' location='missing' importType='\{model_uri}'/><b:process id='P'><b:task id='T'/></b:process>")
  let c=@adapter.to_diagram(unrelated)
  assert_true(c.diagram != None); assert_eq(c.diagnostics[0].code,"bpmn/unresolved-import"); assert_eq(c.diagnostics[0].severity,Warning)
}

///|
test "missing IDs use immutable containment paths and source spans map UTF16 CRLF correctly" {
  let doc=process_view("<b:task/><b:task/>")
  let before=@bpmn.write(doc)
  let a=converted(doc); let b=converted(doc)
  assert_eq(a,b); assert_true(a.nodes[0].id != a.nodes[1].id)
  assert_eq(a.nodes[0].source.source_id,None); assert_eq(a.nodes[0].source.path,[0,0,0]); assert_eq(@bpmn.write(doc),before)
  let source="<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:x'>\r\n<b:process id='P'><b:task id='T' name='😀'/><b:sequenceFlow id='F' sourceRef='T' targetRef='Missing'/></b:process></b:definitions>"
  let read=@bpmn.read(source)
  let findings=@bpmn.validate(read.document.unwrap()).findings
  let original=findings.iter().find_first(f => f.diagnostic.code == "bpmn/unresolved-reference").unwrap().diagnostic
  let mapped=@adapter.map_diagnostic(original)
  assert_eq(mapped.span.unwrap().start.offset,original.span.unwrap().start)
  assert_eq(mapped.span.unwrap().start.line,2); assert_eq(mapped.span.unwrap().start.column,original.location.unwrap().start.column)
  assert_eq(@adapter.to_diagram(read.document.unwrap()).diagram,None)
  assert_eq(@adapter.to_diagram(doc,limits=@bpmn.Limits::new(nodes=1)).diagnostics[0].code,"bpmn/conversion-limit")
}

///|
test "selected DI keeps exact numbers labels fonts flags and endpoint overrides" {
  let doc=model_document("di-views")
  let view=converted(doc,selector=Plane("D1"))
  assert_eq(view.plane.unwrap().source_id,Some("Plane1"))
  let shape=view.nodes[0].geometry.unwrap()
  assert_eq(shape.identity.source_id,Some("S1"))
  assert_eq(shape.bounds.unwrap().x.token,"-12.345678901234567890123456789")
  assert_eq(shape.bounds.unwrap().width.token,"100.00000000000000001")
  assert_eq(shape.label.unwrap().bounds.unwrap().x.token,"1.234567890123456789E+2")
  assert_eq(shape.label.unwrap().style.unwrap().source_id,Some("Style1"))
  assert_eq(shape.label.unwrap().font.unwrap().size.unwrap().token,"1.200000000000000000000001E+1")
  assert_eq(shape.expanded,Some(true)); assert_eq(shape.marker_visible,Some(false))
  let edge=view.flows[0].geometry.unwrap()
  assert_eq(edge.points[0].x.token,"123.45678901234567890123456789")
  assert_eq(edge.source_shape.unwrap().source_id,Some("S1")); assert_eq(edge.target_shape.unwrap().source_id,Some("S2"))
  assert_eq(edge.message_visible,Some(Initiating)); assert_true(edge.label.unwrap().bounds != None)
  assert_eq(@adapter.to_diagram(doc,selector=Plane("D2")).diagnostics[0].code,"bpmn/unsupported-view")
  assert_eq(converted(doc,selector=Plane("Plane1")),view)
  let override_doc=validation_document("<b:process id='P'><b:task id='Hidden'/></b:process><b:collaboration id='C'><b:participant id='Pool' processRef='P'/><b:participant id='Other'/><b:messageFlow id='M' sourceRef='Other' targetRef='Hidden'/></b:collaboration><bd:BPMNDiagram><bd:BPMNPlane bpmnElement='C'><bd:BPMNShape id='S1' bpmnElement='Pool'><dc:Bounds x='0' y='0' width='300' height='100'/></bd:BPMNShape><bd:BPMNShape id='S2' bpmnElement='Other'><dc:Bounds x='0' y='200' width='300' height='100'/></bd:BPMNShape><bd:BPMNEdge bpmnElement='M' sourceElement='S2' targetElement='S1'><di:waypoint x='100' y='200'/><di:waypoint x='100' y='100'/></bd:BPMNEdge></bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC' xmlns:di='http://www.omg.org/spec/DD/20100524/DI'")
  let closed=converted(override_doc)
  assert_eq(closed.flows[0].target,"Pool"); assert_eq(closed.flows[0].semantic_target.source_id,Some("Hidden"))
  assert_true(closed.nodes.iter().find_first(n => n.id == "Pool").unwrap().black_box)
}

///|
test "call and data markers keep referenced meanings and malformed selected references fail" {
  let doc=validation_document("<b:globalUserTask id='Global'/><b:category id='Category'><b:categoryValue id='Value' value='Review stage'/></b:category><b:process id='P'><b:callActivity id='Call' calledElement='Global'/><b:dataObject id='Data' name='Requests' isCollection='true'/><b:dataObjectReference id='Ref' dataObjectRef='Data'/><b:group id='Group' categoryValueRef='Value'/></b:process>")
  let view=converted(doc)
  assert_eq(view.nodes.length(),3)
  assert_eq(view.nodes[0].markers.called_kind,Some(UserTask)); assert_eq(view.nodes[0].markers.called_element.unwrap().source_id,Some("Global"))
  assert_true(view.nodes[1].markers.collection); assert_eq(view.nodes[1].label,"Requests"); assert_eq(view.nodes[2].label,"Review stage")
  let invalid=@adapter.to_diagram(process_view("<b:task id='T'><b:incoming>Missing</b:incoming></b:task>"))
  assert_eq(invalid.diagram,None); assert_true(invalid.diagnostics.iter().any(d => d.code == "bpmn/unresolved-reference"))
  let multiple=validation_document("<b:process id='P'><b:task id='T'/></b:process><bd:BPMNDiagram id='D1'><bd:BPMNPlane id='Plane1' bpmnElement='P'/></bd:BPMNDiagram><bd:BPMNDiagram id='D2'><bd:BPMNPlane id='Plane2' bpmnElement='P'/></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI'")
  assert_eq(@adapter.to_diagram(multiple).diagnostics[0].code,"bpmn/ambiguous-view")
  assert_eq(@adapter.to_diagram(multiple,selector=Process("P")).diagnostics[0].code,"bpmn/ambiguous-plane")
  assert_true(@adapter.to_diagram(multiple,selector=Plane("Plane2")).diagram != None)
}

///|
test "resolver exposes bounded immutable imported indexes for adapter reuse" {
  let root=validation_document("<b:import namespace='urn:other' location='other' importType='\{model_uri}'/><b:process id='P'/>")
  let imported=@bpmn.Definitions::new("urn:other",children=[@bpmn.Process::new(id="Imported").element]).document()
  let documents=[@bpmn.DocumentResource::new("other",imported)]
  let resolved=@bpmn.resolve_references(@bpmn.validate_structure(root).index,resources=@bpmn.ResourceSet::new(documents~))
  documents.clear()
  let indexed=resolved.indexed_resources()
  assert_eq(indexed.length(),2); assert_eq(indexed[1].resource_id,Some("other")); assert_true(indexed[1].records >= indexed[1].index.nodes.length())
  assert_true(indexed[1].index.lookup("Imported") is Found(_))
  assert_eq(indexed[1].index.document,imported)
}

///|
test "expanded calls project the called process inside the call without changing its document" {
  let doc=validation_document("<b:process id='P'><b:callActivity id='Call' calledElement='Reusable'/></b:process><b:process id='Reusable'><b:userTask id='Inner'/></b:process><bd:BPMNDiagram id='D'><bd:BPMNPlane bpmnElement='P'><bd:BPMNShape bpmnElement='Call' isExpanded='true'><dc:Bounds x='0' y='0' width='300' height='200'/></bd:BPMNShape><bd:BPMNShape bpmnElement='Inner'><dc:Bounds x='30' y='40' width='100' height='80'/></bd:BPMNShape></bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC'")
  let before=@bpmn.write(doc)
  let view=converted(doc)
  assert_eq(view.nodes.length(),2)
  assert_eq(view.nodes[1].source.source_id,Some("Inner")); assert_eq(view.nodes[1].ownership.subprocess,Some("Call"))
  assert_eq(view.nodes[1].kind,UserTask); assert_true(view.nodes[1].geometry != None)
  assert_eq(@bpmn.write(doc),before)
}

///|
test "subprocess planes select their contents without inventing an outer shape" {
  let doc=validation_document("<b:process id='P'><b:subProcess id='Sub'><b:userTask id='Inner'/></b:subProcess></b:process><bd:BPMNDiagram id='D'><bd:BPMNPlane bpmnElement='Sub'/></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI'")
  let view=converted(doc,selector=Plane("D"))
  assert_eq(view.kind,Process); assert_eq(view.source.source_id,Some("Sub")); assert_eq(view.nodes.length(),1)
  assert_eq(view.nodes[0].ownership.subprocess,None)
  let invalid=validation_document("<b:process id='P'><b:task id='T'/></b:process><bd:BPMNDiagram id='D'><bd:BPMNPlane bpmnElement='T'/></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI'")
  assert_eq(@adapter.to_diagram(invalid).diagnostics[0].code,"bpmn/invalid-reference")
}

///|
test "whole process collaboration and event corpus views convert without losing graphical elements" {
  for name in ["activities","events","collaboration"] {
    let document=model_document(name)
    let view=converted(document)
    assert_true(view.nodes.length() > 5,msg=name)
    assert_true(view.nodes.iter().all(n => n.source.source_id != None))
    assert_true(view.flows.iter().all(f => f.identity.source_id != None))
  }
}

///|
test "diagnostic exhaustion is an error even when independent stages only found unrelated warnings" {
  let doc=validation_document("<b:import namespace='urn:missing' location='missing' importType='\{model_uri}'/><b:process id='P'/><b:collaboration id='C'><b:task id='InvalidChild'/></b:collaboration>")
  let result=@adapter.to_diagram(doc,selector=Process("P"),limits=@bpmn.Limits::new(diagnostics=1))
  assert_eq(result.diagram,None); assert_eq(result.diagnostics.length(),1)
  assert_eq(result.diagnostics[0].severity,Error); assert_eq(result.diagnostics[0].code,"bpmn/conversion-limit")
}

///|
test "black box message endpoints fall back to the pool shape when DI omits the override" {
  let source="<b:definitions xmlns:b='\{model_uri}' xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC' xmlns:di='http://www.omg.org/spec/DD/20100524/DI' targetNamespace='urn:x'><b:process id='P'><b:task id='Hidden'/></b:process><b:collaboration id='C'><b:participant id='Pool' processRef='P'/><b:participant id='Other'/><b:messageFlow id='M' sourceRef='Other' targetRef='Hidden'/></b:collaboration><bd:BPMNDiagram><bd:BPMNPlane bpmnElement='C'><bd:BPMNShape bpmnElement='Pool'><dc:Bounds x='0' y='0' width='300' height='100'/></bd:BPMNShape><bd:BPMNShape bpmnElement='Other'><dc:Bounds x='0' y='200' width='300' height='100'/></bd:BPMNShape><bd:BPMNEdge bpmnElement='M'><di:waypoint x='100' y='200'/><di:waypoint x='100' y='100'/></bd:BPMNEdge></bd:BPMNPlane></bd:BPMNDiagram></b:definitions>"
  let view=converted(@bpmn.read(source).document.unwrap())
  assert_eq(view.flows[0].target,"Pool"); assert_eq(view.flows[0].semantic_target.source_id,Some("Hidden"))
}

///|
test "indexed collaboration conversion returns bounded failures under tight work budgets" {
  let participants=StringBuilder(); let shapes=StringBuilder()
  for i in 0..<24 {
    participants.write_string("<b:participant id='Pool\{i}'/>")
    shapes.write_string("<bd:BPMNShape bpmnElement='Pool\{i}'><dc:Bounds x='\{i*200}' y='0' width='100' height='80'/></bd:BPMNShape>")
  }
  let doc=validation_document("<b:collaboration id='C'>\{participants.to_string()}</b:collaboration><bd:BPMNDiagram><bd:BPMNPlane bpmnElement='C'>\{shapes.to_string()}</bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC'")
  for nodes in [512,700] {
  let limits=@bpmn.Limits::new(nodes~)
  let structure=@bpmn.validate_structure(doc,limits~)
  assert_true(structure.complete); assert_eq(structure.findings,[])
  let references=@bpmn.resolve_references(structure.index,limits~)
  assert_true(references.complete); assert_eq(references.findings,[])
  let result=@adapter.to_diagram(doc,limits~)
  if nodes == 512 { assert_eq(result.diagram,None); assert_true(result.diagnostics.iter().any(d => d.code == "bpmn/conversion-limit")) }
  else { assert_true(result.diagram != None,msg=@debug.to_string(result.diagnostics)); assert_eq(result.diagnostics,[]) }
  }
  let exhausted=@adapter.to_diagram(doc,limits=@bpmn.Limits::new(nodes=1))
  assert_eq(exhausted.diagram,None)
  assert_true(exhausted.diagnostics.iter().any(d => d.code == "bpmn/conversion-limit"))
}

///|
test "non-graphical implicit throws stay in multi-instance descriptions without invented event shapes" {
  let doc=process_view("<b:task id='T'><b:multiInstanceLoopCharacteristics><b:complexBehaviorDefinition><b:condition>count &gt; 2</b:condition><b:event id='Implicit'><b:messageEventDefinition/></b:event></b:complexBehaviorDefinition></b:multiInstanceLoopCharacteristics></b:task>")
  let view=converted(doc)
  assert_eq(view.nodes.length(),1)
  assert_eq(view.nodes[0].kind,Task); assert_eq(view.nodes[0].markers.loop_kind,Parallel)
  assert_true(view.nodes[0].markers.details.iter().any(p => p.1 == "count > 2"))
  assert_true(@bpmn.ImplicitThrowEvent::from_element(by_id(doc,"Implicit")) != None)
}

///|
test "activity local IO remains semantic endpoints and cannot gain nonstandard DI shapes" {
  let process="<b:process id='P'><b:task id='T'><b:ioSpecification><b:dataInput id='I'/><b:inputSet/><b:outputSet/></b:ioSpecification></b:task></b:process>"
  assert_eq(converted(validation_document(process)).nodes.length(),1)
  let doc=validation_document(process+"<bd:BPMNDiagram><bd:BPMNPlane bpmnElement='P'><bd:BPMNShape bpmnElement='I'><dc:Bounds x='0' y='0' width='50' height='60'/></bd:BPMNShape></bd:BPMNPlane></bd:BPMNDiagram>",extra="xmlns:bd='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:dc='http://www.omg.org/spec/DD/20100524/DC'")
  let result=@adapter.to_diagram(doc)
  assert_eq(result.diagram,None); assert_eq(result.diagnostics[0].code,"bpmn/unsupported-element")
}

///|
test "category membership survives conversion for automatic group bounds" {
  let input=@corpus.render_inputs.iter().find_first(i => i.name == "process-di.bpmn").unwrap()
  let document=@bpmn.read(input.source).document.unwrap()
  let result=@adapter.to_diagram(document,geometry_policy=Automatic)
  guard result.diagram is Some(Bpmn(view)) else { fail(@debug.to_string(result.diagnostics)) }
  for id in ["Review","Decision"] {
    assert_eq(view.nodes.iter().find_first(n => n.id == id).unwrap().ownership.groups,["ReviewGroup"])
  }
  assert_eq(view.nodes.iter().find_first(n => n.id == "Send").unwrap().ownership.groups,[])
  let groups=["ReviewGroup"]
  let owned=@model.Ownership::new(groups~); groups[0]="changed"
  assert_eq(owned.groups,["ReviewGroup"])
}
