///|
fn graph_of(body : String) -> @bpmn.DocumentGraph { @bpmn.DocumentGraph::new(validation_document(body)).graph.unwrap() }

///|
fn graph_ids(nodes : ReadOnlyArray[@bpmn.GraphNode]) -> Array[String?] { nodes.iter().map(n => n.id()).to_array() }

///|
fn route_ids(result : @bpmn.RouteResult) -> Array[String?] raise {
  guard result is Found(route) else { fail("route was not found") }
  graph_ids(route.nodes)
}

///|
test "supplied DI does not create edges and connections retain source identities" {
  let result=@bpmn.DocumentGraph::new(@bpmn.read(fixture()).document.unwrap())
  assert_eq(result.diagnostics,[])
  let graph=result.graph.unwrap()
  let result=graph.route(Id("Start"),Id("End"))
  assert_eq(route_ids(result),[Some("Start"),Some("Review"),Some("End")])
  guard result is Found(route) else { fail("route missing") }
  assert_eq(route.edges.iter().map(e => e.connection.unwrap().id()).to_array(),[Some("Flow_1"),Some("Flow_2")])
  assert_true(route.edges.iter().all(e => e.kind == SequenceFlow))
  guard graph.reachable(Id("Start")) is Complete(nodes) else { fail("reachability failed") }
  assert_eq(graph_ids(nodes),[Some("Start"),Some("Review"),Some("End")])
  guard graph.reachable(Id("Start"),kinds=[Reference]) is Complete(nodes) else { fail("reference query failed") }
  assert_eq(graph_ids(nodes),[Some("Start")])
}

///|
test "cycles terminate and equal shortest routes use authored connection order" {
  let graph=graph_of("<b:process><b:task id='A'/><b:task id='B'/><b:task id='C'/><b:task id='D'/><b:task id='E'/><b:sequenceFlow id='AC' sourceRef='A' targetRef='C'/><b:sequenceFlow id='AB' sourceRef='A' targetRef='B'/><b:sequenceFlow id='CD' sourceRef='C' targetRef='D'/><b:sequenceFlow id='BD' sourceRef='B' targetRef='D'/><b:sequenceFlow id='CA' sourceRef='C' targetRef='A'/></b:process>")
  for _ in 0..<3 { assert_eq(route_ids(graph.route(Id("A"),Id("D"))),[Some("A"),Some("C"),Some("D")]) }
  assert_eq(route_ids(graph.route(Id("D"),Id("A"),direction=Reverse)),[Some("D"),Some("C"),Some("A")])
  guard graph.reachable(Id("A"),direction=Both) is Complete(nodes) else { fail("cycle did not finish") }
  assert_eq(graph_ids(nodes),[Some("A"),Some("C"),Some("B"),Some("D")])
  assert_true(graph.route(Id("A"),Id("E")) is Unreachable)
  assert_eq(route_ids(graph.route(Id("A"),Id("A"))),[Some("A")])
  assert_eq(graph.route(Id("A"),Id("D"),kinds=[SequenceFlow,SequenceFlow]),graph.route(Id("A"),Id("D")))
}

///|
test "association message data conversation containment and reference kinds stay distinct" {
  let graph=graph_of("<b:process id='P'><b:task id='A'/><b:task id='B'/><b:sequenceFlow id='F' sourceRef='A' targetRef='B'/><b:textAnnotation id='Note'><b:text>inert</b:text></b:textAnnotation><b:association id='Assoc' sourceRef='A' targetRef='Note'/><b:dataObject id='Data'/><b:userTask id='User'><b:ioSpecification><b:dataInput id='Input'/><b:inputSet/><b:outputSet/></b:ioSpecification><b:dataInputAssociation id='DA'><b:sourceRef>Data</b:sourceRef><b:targetRef>Input</b:targetRef></b:dataInputAssociation></b:userTask></b:process><b:collaboration><b:participant id='Pool' processRef='P'/><b:participant id='OtherPool'/><b:messageFlow id='M' sourceRef='Pool' targetRef='OtherPool'/><b:conversation id='Conversation'/><b:conversationLink id='CL' sourceRef='Pool' targetRef='Conversation'/></b:collaboration>")
  assert_true(graph.route(Id("A"),Id("Note")) is Unreachable)
  assert_eq(route_ids(graph.route(Id("A"),Id("Note"),kinds=[Association])),[Some("A"),Some("Note")])
  assert_eq(route_ids(graph.route(Id("Pool"),Id("OtherPool"),kinds=[MessageFlow])),[Some("Pool"),Some("OtherPool")])
  assert_eq(route_ids(graph.route(Id("Data"),Id("Input"),kinds=[DataAssociation])),[Some("Data"),Some("Input")])
  assert_eq(route_ids(graph.route(Id("Pool"),Id("Conversation"),kinds=[ConversationLink])),[Some("Pool"),Some("Conversation")])
  assert_eq(route_ids(graph.route(Id("Pool"),Id("P"),kinds=[Reference])),[Some("Pool"),Some("P")])
  assert_eq(route_ids(graph.route(Id("P"),Id("A"),kinds=[Containment])),[Some("P"),Some("A")])
}

///|
test "invalid and ambiguous selected references differ from unrelated disconnected components" {
  let graph=graph_of("<b:process><b:task id='A'/><b:task id='B'/><b:task id='E'/><b:sequenceFlow id='Broken' sourceRef='A' targetRef='Missing'/></b:process>")
  assert_true(graph.route(Id("A"),Id("B")) is Failed(InvalidReference(_)))
  assert_true(graph.route(Id("E"),Id("B")) is Unreachable)
  assert_true(graph.route(Id("Missing"),Id("B")) is Failed(InvalidEndpoint))
  let duplicate=graph_of("<b:process><b:task id='A'/><b:task id='A'/><b:task id='B'/><b:sequenceFlow id='F' sourceRef='A' targetRef='B'/></b:process>")
  assert_true(duplicate.route(Id("A"),Id("B")) is Failed(Ambiguous(nodes)) && nodes.length() == 2)
  let start=duplicate.nodes.iter().find_first(n => n.id() == Some("A")).unwrap()
  guard start is Document(node) else { fail("source was not a document node") }
  assert_true(duplicate.route(Node(node.handle()),Id("B")) is Failed(Ambiguous(nodes)) && nodes.length() == 2)
  assert_true(duplicate.route(Node(node.handle()),Id("B"),limits=@bpmn.GraphLimits::new(results=1)) is Failed(Limit(Results)))
}

///|
test "scope failures are explicit and revision mismatch cannot select another same-index node" {
  let graph=graph_of("<b:process><b:task id='A'/><b:subProcess><b:task id='B'/></b:subProcess><b:sequenceFlow id='F' sourceRef='A' targetRef='B'/></b:process>")
  assert_true(graph.route(Id("A"),Id("B")) is Failed(InvalidReference(_)))
  let other=document_tree(validation_document("<b:process><b:task id='Different'/></b:process>"))
  assert_true(graph.reachable(Node(other.root().handle())) is Failed(DocumentMismatch))
}

///|
test "query bounds never report unreachable after an incomplete search" {
  let graph=graph_of("<b:process><b:task id='A'/><b:task id='B'/><b:task id='C'/><b:task id='D'/><b:sequenceFlow id='AB' sourceRef='A' targetRef='B'/><b:sequenceFlow id='BC' sourceRef='B' targetRef='C'/><b:sequenceFlow id='CD' sourceRef='C' targetRef='D'/></b:process>")
  assert_true(graph.route(Id("A"),Id("D"),limits=@bpmn.GraphLimits::new(nodes=1)) is Failed(Limit(Nodes)))
  assert_true(graph.route(Id("A"),Id("D"),limits=@bpmn.GraphLimits::new(edges=1)) is Failed(Limit(Edges)))
  assert_true(graph.route(Id("A"),Id("D"),limits=@bpmn.GraphLimits::new(results=2)) is Failed(Limit(Results)))
  assert_true(graph.reachable(Id("A"),limits=@bpmn.GraphLimits::new(results=1)) is Failed(Limit(Results)))
  assert_true(graph.route(Id("A"),Id("D"),limits=@bpmn.GraphLimits::new(work=2)) is Failed(Limit(Work)))
  assert_true(graph.route(Id("A"),Id("D"),limits=@bpmn.GraphLimits::new(nodes=0)) is Failed(InvalidLimits))
  assert_true(@bpmn.DocumentGraph::new(validation_document("<b:process/>"),graph_limits=@bpmn.GraphLimits::new(nodes=1)).graph is None)
  assert_true(@bpmn.DocumentGraph::new(validation_document("<b:process/>"),graph_limits=@bpmn.GraphLimits::new(edges=1)).graph is None)
}

///|
test "general references cross explicit imported documents with per-document visibility" {
  let root=validation_document("<b:import namespace='urn:other' location='other' importType='\{model_uri}'/><b:process id='P'><b:callActivity id='Call' calledElement='o:Shared'/></b:process><b:process id='Shared'/>",extra="xmlns:o='urn:other'")
  let imported=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' xmlns:m='urn:main' targetNamespace='urn:other'><b:import namespace='urn:main' location='root' importType='\{model_uri}'/><b:process id='Shared'><b:callActivity id='Inner' calledElement='m:P'/></b:process></b:definitions>").document.unwrap()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("other",imported)])
  let result=@bpmn.DocumentGraph::new(root,resources~,resource_id="root")
  assert_eq(result.diagnostics,[])
  let graph=result.graph.unwrap()
  assert_eq(route_ids(graph.route(Id("Call"),Qualified(@bpmn.ExpandedName::new("urn:other","Shared")),kinds=[Reference])),[Some("Call"),Some("Shared")])
  assert_eq(route_ids(graph.route(Id("Call"),Id("P"),kinds=[Reference,Containment])),[Some("Call"),Some("Shared"),Some("Inner"),Some("P")])
  assert_true(graph.route(Id("Call"),Id("Shared"),kinds=[Reference]) is Unreachable)
}

///|
test "explicit external symbols are graph leaves and duplicate occurrences retain ambiguity" {
  let doc=validation_document("<b:import namespace='urn:types' location='types' importType='urn:external'/><b:itemDefinition id='Item' structureRef='t:Order'/>",extra="xmlns:t='urn:types'")
  let resource=@bpmn.ExternalResource::new("types","urn:types","urn:external",["Order"])
  let graph=@bpmn.DocumentGraph::new(doc,resources=@bpmn.ResourceSet::new(external=[resource])).graph.unwrap()
  let symbol=@bpmn.ResolvedSymbol::new("types",@bpmn.ExpandedName::new("urn:types","Order"))
  let route=graph.route(Id("Item"),Symbol(symbol),kinds=[Reference])
  assert_eq(route_ids(route),[Some("Item"),Some("Order")])
  guard route is Found(route) else { fail("external route missing") }
  assert_true(route.nodes.last().unwrap() is External(node) && node.symbol == symbol)
  let duplicate=@bpmn.ExternalResource::new("types","urn:types","urn:external",["Order","Order"])
  let graph=@bpmn.DocumentGraph::new(doc,resources=@bpmn.ResourceSet::new(external=[duplicate])).graph.unwrap()
  assert_true(graph.reachable(Id("Item"),kinds=[Reference]) is Failed(Ambiguous(nodes)) && nodes.length() == 2)
}

///|
test "an imported document cannot borrow another root import's visibility" {
  let root=validation_document("<b:import namespace='urn:a' location='a' importType='\{model_uri}'/><b:import namespace='urn:b' location='b' importType='\{model_uri}'/><b:process><b:callActivity id='RootCall' calledElement='a:A'/></b:process>",extra="xmlns:a='urn:a'")
  let a=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' xmlns:other='urn:b' targetNamespace='urn:a'><b:process id='A'><b:callActivity id='CallToB' calledElement='other:B'/></b:process></b:definitions>").document.unwrap()
  let b=@bpmn.Definitions::new("urn:b",children=[@bpmn.Process::new(id="B").element]).document()
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("a",a),@bpmn.DocumentResource::new("b",b)])
  let result=@bpmn.DocumentGraph::new(root,resources~)
  assert_true(result.diagnostics.iter().any(d => d.code == "bpmn/unresolved-reference"))
  assert_true(result.graph.unwrap().route(Id("RootCall"),Qualified(@bpmn.ExpandedName::new("urn:b","B")),kinds=[Containment,Reference]) is Failed(InvalidReference(owner)) && owner.resource_id() == Some("a"))
}

///|
test "valid source-less data assignments do not invent a graph source" {
  let graph=graph_of("<b:process><b:userTask><b:ioSpecification><b:dataInput id='Input'/><b:inputSet/><b:outputSet/></b:ioSpecification><b:dataInputAssociation id='Assign'><b:targetRef>Input</b:targetRef></b:dataInputAssociation></b:userTask></b:process>")
  assert_true(graph.route(Id("Assign"),Id("Input"),kinds=[DataAssociation]) is Unreachable)
  assert_eq(route_ids(graph.route(Id("Assign"),Id("Input"),kinds=[Reference])),[Some("Assign"),Some("Input")])
}

///|
test "combined graph diagnostics cannot overflow while exposing a complete graph" {
  let doc=validation_document("<b:process><b:sequenceFlow sourceRef='Missing'/></b:process>")
  let result=@bpmn.DocumentGraph::new(doc,limits=@bpmn.Limits::new(diagnostics=1))
  assert_true(result.graph is None)
  assert_eq(result.diagnostics[0].code,"bpmn/validation-diagnostic-limit")
}

///|
test "invalid child reference representations remain graph failures on their owner" {
  let parsed=validation_document("<b:process><b:task id='A'><b:incoming>F</b:incoming></b:task><b:task id='B'/><b:sequenceFlow id='F' sourceRef='B' targetRef='A'/></b:process>")
  let incoming=parsed.root.children[0].children[0].children[0]
  let invalid=@bpmn.Element::from_values(Incoming,contents=[Text("F")],text_value=Text("F"))
  let malformed=incoming.with_contents([Text("F"),Element(@bpmn.Task::new().element)])
  for child in [invalid,malformed] {
    let process=parsed.root.children[0]
    let task=process.children[0].with_contents([Element(child)])
    let doc=@bpmn.Document::new(parsed.root.with_contents([Element(process.with_contents([Element(task),Element(process.children[1]),Element(process.children[2])]))]))
    let result=@bpmn.DocumentGraph::new(doc)
    assert_true(result.diagnostics.iter().any(d => d.code == "bpmn/invalid-field" || d.code == "bpmn/invalid-containment"))
    assert_true(result.graph.unwrap().reachable(Id("A"),kinds=[Reference]) is Failed(InvalidReference(_)))
  }
  let bad_source=@bpmn.Element::from_values(SourceRef,contents=[Text("Data")],text_value=Text("Data"))
  let io=@bpmn.InputOutputSpecification::new(contents=[Element(@bpmn.DataInput::new(id="Input").element),Element(@bpmn.InputSet::new().element),Element(@bpmn.OutputSet::new().element)])
  let association=@bpmn.DataInputAssociation::new(id="DA",contents=[Element(bad_source),Element(@bpmn.Element::new(TargetRef,content="Input"))])
  let user=@bpmn.UserTask::new(contents=[Element(io.element),Element(association.element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(@bpmn.DataObject::new(id="Data").element),Element(user.element)]).element]).document()
  let graph=@bpmn.DocumentGraph::new(doc).graph.unwrap()
  assert_true(graph.reachable(Id("DA"),kinds=[Reference]) is Failed(InvalidReference(_)))
  assert_true(graph.reachable(Id("DA"),kinds=[DataAssociation]) is Failed(InvalidReference(_)))
}
