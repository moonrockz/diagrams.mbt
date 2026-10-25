///|
fn motion_catalog(document : @bpmn.Document, resources? : @bpmn.ResourceSet = @bpmn.ResourceSet::new()) -> @animation.Catalog raise {
  let converted=@adapter.to_diagram(document,resources~)
  guard converted.diagram is Some(Bpmn(view)) else { fail(@debug.to_string(converted.diagnostics)) }
  let projected=@animation.Catalog::bpmn(view)
  guard projected.catalog is Some(catalog) else { fail(@debug.to_string(projected.diagnostics)) }
  catalog
}

///|
fn motion_ids(catalog : @animation.Catalog, route : @animation.Route) -> Array[String] {
  route.edges.iter().map(edge => catalog.occurrence(edge.occurrence.unwrap()).unwrap().flow.unwrap().identity.source_id.unwrap()).to_array()
}

///|
fn document_ids(route : @bpmn.GraphRoute) -> Array[String] { route.edges.iter().map(edge => edge.connection.unwrap().id().unwrap()).to_array() }

///|
test "diagram shortest routes and reachability agree with document flow queries on cycles and ties" {
  let document=validation_document("<b:process id='P'><b:task id='A'/><b:task id='B'/><b:task id='C'/><b:task id='D'/><b:sequenceFlow id='AB' sourceRef='A' targetRef='B'/><b:sequenceFlow id='AC' sourceRef='A' targetRef='C'/><b:sequenceFlow id='BD' sourceRef='B' targetRef='D'/><b:sequenceFlow id='CD' sourceRef='C' targetRef='D'/><b:sequenceFlow id='DA' sourceRef='D' targetRef='A'/></b:process>")
  let catalog=motion_catalog(document)
  let graph=@bpmn.DocumentGraph::new(document).graph.unwrap()
  guard graph.route(Id("A"),Id("D")) is Found(original) else { fail("document route missing") }
  guard catalog.graph.route("A","D") is Found(projected) else { fail("diagram route missing") }
  assert_eq(motion_ids(catalog,projected),document_ids(original))
  assert_eq(motion_ids(catalog,projected),["AB","BD"])
  guard graph.reachable(Id("A")) is Complete(original_nodes) else { fail("document reachability missing") }
  guard catalog.graph.reachable("A") is Complete(projected_nodes) else { fail("diagram reachability missing") }
  assert_eq(projected_nodes.iter().map(n => n.source_node.unwrap().source.source_id.unwrap()).to_array(),original_nodes.iter().map(n => n.id().unwrap()).to_array())
  guard graph.route(Id("D"),Id("A"),direction=Reverse) is Found(reverse_original) else { fail("document reverse route missing") }
  guard catalog.graph.route("D","A",direction=Reverse) is Found(reverse_projected) else { fail("diagram reverse route missing") }
  assert_eq(motion_ids(catalog,reverse_projected),document_ids(reverse_original))
}

///|
test "imported process instances preserve actual document connection identity without cross-instance routes" {
  let imported=@bpmn.read("<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:shared'><b:process id='P'><b:task id='T'/><b:task id='U'/><b:sequenceFlow id='F' sourceRef='T' targetRef='U'/></b:process></b:definitions>").document.unwrap()
  let document=validation_document("<b:import namespace='urn:shared' location='shared' importType='http://www.omg.org/spec/BPMN/20100524/MODEL'/><b:collaboration id='C'><b:participant id='One' processRef='s:P'/><b:participant id='Two' processRef='s:P'/></b:collaboration>",extra="xmlns:s='urn:shared'")
  let resources=@bpmn.ResourceSet::new(documents=[@bpmn.DocumentResource::new("shared",imported)])
  let catalog=motion_catalog(document,resources~)
  let one=catalog.graph.nodes.iter().find_first(n => n.source_node.map(n => n.source.source_id == Some("T") && n.ownership.pool == Some("One")).unwrap_or(false)).unwrap()
  let target=catalog.graph.nodes.iter().find_first(n => n.source_node.map(n => n.source.source_id == Some("U") && n.ownership.pool == Some("One")).unwrap_or(false)).unwrap()
  let other=catalog.graph.nodes.iter().find_first(n => n.source_node.map(n => n.source.source_id == Some("U") && n.ownership.pool == Some("Two")).unwrap_or(false)).unwrap()
  guard catalog.graph.route(one.id,target.id) is Found(projected) else { fail("instance route missing") }
  assert_eq(catalog.graph.route(one.id,other.id),Unreachable)
  let graph=@bpmn.DocumentGraph::new(document,resources~).graph.unwrap()
  guard graph.route(Qualified(@bpmn.ExpandedName::new("urn:shared","T")),Qualified(@bpmn.ExpandedName::new("urn:shared","U"))) is Found(original) else { fail("imported document route missing") }
  assert_eq(motion_ids(catalog,projected),document_ids(original))
  assert_eq(motion_ids(catalog,projected),["F"])
}

///|
test "motion retains expressions and timer descriptions without treating them as execution" {
  let input=@corpus.render_inputs.iter().find_first(i => i.name == "process-di.bpmn").unwrap()
  let document=@bpmn.read(input.source).document.unwrap()
  let catalog=motion_catalog(document)
  guard catalog.graph.route("Start","Sent") is Found(route) else { fail("structural route missing") }
  let source_graph=@bpmn.DocumentGraph::new(document).graph.unwrap()
  guard source_graph.route(Id("Start"),Id("Sent")) is Found(source_route) else { fail("document route missing") }
  assert_eq(motion_ids(catalog,route),document_ids(source_route))
  assert_eq(catalog.flow("Accept").unwrap().flow.unwrap().condition,Some("approved"))
  let reminder=catalog.graph.nodes.iter().find_first(n => n.id == "Reminder").unwrap().source_node.unwrap()
  assert_true(reminder.markers.events[0].settings.iter().any(setting => setting.1 == "R/PT24H"))
  let planned=@animation.PlaybackPlan::route(catalog,route).plan.unwrap()
  assert_eq(planned.steps.length(),4); assert_true(planned.sample_at(86400000L).finished)
  assert_false(planned.steps.iter().any(step => step.occurrence.flow.unwrap().id == "Remind"))
}
