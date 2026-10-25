///|
fn model_source(name : String) -> String { @corpus.model_inputs.iter().find_first(i => i.name == name).unwrap().source }

///|
fn model_document(name : String) -> @bpmn.Document raise {
  let result=@bpmn.read(model_source(name+".bpmn"))
  assert_eq(result.diagnostics.iter().map(d => (d.code,d.message)).to_array(),[],msg=name)
  result.document.unwrap()
}

///|
fn by_id(doc : @bpmn.Document, id : String) -> @bpmn.Element {
  let mut found : @bpmn.Element? = None
  doc.walk(e => { if e.attribute("id") == Some(id) { found=Some(e) } })
  found.unwrap()
}

///|
test "all process and collaboration schema fields have generated typed accessors" {
  let deferred=["tChoreography","tChoreographyActivity","tChoreographyTask","tSubChoreography","tCallChoreography","tGlobalChoreographyTask","tConversationNode","tConversation","tSubConversation","tCallConversation","tGlobalConversation","tConversationLink","tConversationAssociation"]
  let manual=["tDefinitions","tImport","tBaseElement","tRootElement","tDocumentation"]
  let expected=@bpmn.schema_types.iter().filter(t => t.name.namespace_uri == model_uri && !t.simple && !deferred.contains(t.name.local_name)).to_array()
  assert_eq(@bpmn.typed_model_types.length(),expected.length())
  for t in expected {
    assert_true(@bpmn.typed_model_types.iter().any(id => id == t.id),msg=t.name.local_name)
    if manual.contains(t.name.local_name) { continue }
    let fields=t.fields().iter().filter(f => f.kind == Attribute || f.kind == Child).to_array()
    let actual=@bpmn.typed_model_fields.iter().filter(f => f.0 == t.id).to_array()
    assert_eq(actual.length(),fields.length(),msg=t.name.local_name)
    for field in fields { assert_true(actual.iter().any(f => f.1 == field.kind && Some(f.2) == field.name),msg=t.name.local_name+":"+field.source_path) }
  }
}

///|
test "activity task call and loop families expose typed fields without defaults or evaluation" {
  let doc=model_document("activities")
  let p=@bpmn.Process::from_element(by_id(doc,"P")).unwrap()
  assert_eq(p.process_type(),Present(@bpmn.ProcessType::Private))
  assert_eq(p.is_executable(),Present(false))
  assert_eq(p.flow_element().value().unwrap().length(),14)
  let user=@bpmn.UserTask::from_element(by_id(doc,"User")).unwrap()
  assert_eq(user.name(),Present("Review"))
  assert_eq(user.is_for_compensation(),Absent)
  assert_eq(user.implementation(),Present(@bpmn.Implementation::Unspecified))
  assert_eq(user.rendering().value().unwrap()[0].id(),Present("Rendering"))
  let task=@bpmn.Task::from_element(by_id(doc,"Task")).unwrap()
  assert_eq(task.start_quantity().value().unwrap().token,"1")
  assert_eq(task.completion_quantity().value().unwrap().token,"2")
  let call=@bpmn.CallActivity::from_element(by_id(doc,"Call")).unwrap()
  assert_eq(call.called_element().value().unwrap().name,Some(@bpmn.ExpandedName::new("","GlobalTask")))
  let sub=@bpmn.SubProcess::from_element(by_id(doc,"Sub")).unwrap()
  assert_eq(sub.triggered_by_event(),Present(false))
  assert_eq(sub.flow_element().value().unwrap().length(),5)
  assert_eq(@bpmn.AdHocSubProcess::from_element(by_id(doc,"AdHoc")).unwrap().ordering(),Present(@bpmn.AdHocOrdering::Parallel))
  assert_eq(@bpmn.Transaction::from_element(by_id(doc,"Transaction")).unwrap().method_(),Present(@bpmn.TransactionMethod::Compensate))
  let standard=@bpmn.StandardLoopCharacteristics::from_element(by_id(doc,"Loop")).unwrap()
  assert_eq(standard.test_before(),Present(true))
  assert_eq(standard.loop_maximum().value().unwrap().token,"999999999999999999999999")
  assert_eq(standard.loop_condition().value().unwrap().element.content,"retry < 3")
  let multi=@bpmn.MultiInstanceLoopCharacteristics::from_element(by_id(doc,"Multi")).unwrap()
  assert_eq(multi.behavior(),Present(@bpmn.MultiInstanceFlowCondition::Complex))
  assert_eq(multi.input_data_item().value().unwrap().id(),Present("InputItem"))
  let behavior=multi.complex_behavior_definition().value().unwrap()[0]
  assert_eq(behavior.condition().value().unwrap().element.content,"count > 1")
  assert_eq(behavior.event().value().unwrap().element.value_type,Some(@bpmn.TypeId::ImplicitThrowEvent.name()))
  assert_eq(@bpmn.GlobalScriptTask::from_element(by_id(doc,"GlobalScript")).unwrap().script().value().unwrap().element.content,"describe-only()")
  roundtrip(doc)
}

///|
test "typed construction keeps activity containment order and exact option values" {
  let expression=@bpmn.FormalExpression::new(language="urn:inert",contents=[Text("retry < 3")]).element.with_kind(LoopCondition)
  let loop_value=@bpmn.StandardLoopCharacteristics::new(test_before=true,loop_maximum=@bpmn.ExactInteger::parse("999999999999999999999999").unwrap(),contents=[Element(expression)])
  let user=@bpmn.UserTask::new(id="User",name="Review",implementation=Unspecified,contents=[Element(loop_value.element)])
  let call=@bpmn.CallActivity::new(id="Call",called_element=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Global")))
  let p=@bpmn.Process::new(id="P",is_executable=false,contents=[Element(user.element),Element(call.element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.GlobalTask::new(id="Global").element,p.element]).document()
  assert_eq(p.flow_element().value().unwrap().map(f => f.element.attribute("id")).iter().to_array(),[Some("User"),Some("Call")])
  assert_eq(user.start_quantity(),Absent)
  roundtrip(doc)
}

///|
test "events gateways boundaries and conditions remain descriptive values" {
  let doc=model_document("events")
  let boundary=@bpmn.BoundaryEvent::from_element(by_id(doc,"Boundary")).unwrap()
  assert_eq(boundary.attached_to_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Task")))
  assert_eq(boundary.cancel_activity(),Present(true))
  assert_eq(boundary.event_definition().value().unwrap()[0].element.kind,ErrorEventDefinition)
  assert_eq(@bpmn.StartEvent::from_element(by_id(doc,"Start")).unwrap().is_interrupting(),Present(true))
  let timer=@bpmn.TimerEventDefinition::from_element(by_id(doc,"Duration")).unwrap()
  assert_eq(timer.time_duration().value().unwrap().element.content,"PT5M")
  assert_eq(@bpmn.EventBasedGateway::from_element(by_id(doc,"EventBased")).unwrap().event_gateway_type(),Present(@bpmn.EventBasedGatewayType::Exclusive))
  assert_eq(@bpmn.ExclusiveGateway::from_element(by_id(doc,"Exclusive")).unwrap().gateway_direction(),Present(@bpmn.GatewayDirection::Diverging))
  assert_eq(@bpmn.ComplexGateway::from_element(by_id(doc,"Complex")).unwrap().activation_condition().value().unwrap().element.content,"ready")
  let flow=@bpmn.SequenceFlow::from_element(by_id(doc,"ConditionalFlow")).unwrap()
  assert_eq(flow.is_immediate(),Present(false))
  assert_eq(flow.source_ref().value().unwrap().kind,Id)
  assert_eq(flow.condition_expression().value().unwrap().element.content,"amount > 10 && ready")
  let kinds : Array[@bpmn.Kind] = []
  doc.walk(e => { if @bpmn.EventDefinition::from_element(e) != None { kinds.push(e.kind) } })
  let expected_kinds : Array[@bpmn.Kind] = [TimerEventDefinition,MessageEventDefinition,ErrorEventDefinition,CancelEventDefinition,CompensateEventDefinition,ConditionalEventDefinition,SignalEventDefinition,LinkEventDefinition,EscalationEventDefinition,TerminateEventDefinition]
  for kind in expected_kinds { assert_true(kinds.contains(kind)) }
  roundtrip(doc)
}

///|
test "collaboration participants nested lanes data artifacts and resources retain types and references" {
  let doc=model_document("collaboration")
  let collaboration=@bpmn.Collaboration::from_element(by_id(doc,"Collaboration")).unwrap()
  assert_eq(collaboration.participant().value().unwrap().map(p => p.id()).iter().to_array(),[Present("BuyerPool"),Present("SellerPool")])
  assert_eq(collaboration.message_flow().value().unwrap()[0].source_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Send")))
  let lane=@bpmn.Lane::from_element(by_id(doc,"Operations")).unwrap()
  assert_eq(lane.child_lane_set().value().unwrap().lane().value().unwrap()[0].id(),Present("Reviewers"))
  assert_eq(lane.flow_node_ref().value().unwrap()[0].name,Some(@bpmn.ExpandedName::new("","Send")))
  let task=@bpmn.UserTask::from_element(by_id(doc,"Review")).unwrap()
  assert_eq(task.io_specification().value().unwrap().data_input().value().unwrap()[0].name(),Present("request"))
  let association=task.data_input_association().value().unwrap()[0]
  assert_eq(association.target_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Input")))
  assert_eq(association.transformation().value().unwrap().element.content,"copy(input)")
  assert_eq(association.assignment().value().unwrap()[0].from().value().unwrap().element.content,"request")
  assert_eq(@bpmn.PotentialOwner::from_element(by_id(doc,"Owner")).unwrap().resource_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Resource")))
  assert_eq(@bpmn.DataStore::from_element(by_id(doc,"Store")).unwrap().capacity().value().unwrap().token,"10000000000000000000000")
  assert_eq(@bpmn.Association::from_element(by_id(doc,"Association")).unwrap().association_direction(),Present(@bpmn.AssociationDirection::One))
  assert_eq(@bpmn.TextAnnotation::from_element(by_id(doc,"Note")).unwrap().text().value().unwrap().element.content,"Illustrative document; no execution.")
  assert_eq(@bpmn.Resource::from_element(by_id(doc,"Resource")).unwrap().resource_parameter().value().unwrap()[0].is_required(),Present(true))
  roundtrip(doc)
}

///|
test "malformed typed child fields return invalid values instead of dropping children" {
  let incoming=@bpmn.Element::from_values(Incoming,text_value=Text("wrong scalar alternative"))
  let task=@bpmn.Task::new(contents=[Element(incoming)])
  assert_true(task.incoming() is InvalidValue(_))
  let loop1=@bpmn.StandardLoopCharacteristics::new()
  let loop2=@bpmn.StandardLoopCharacteristics::new(test_before=true)
  let task=@bpmn.Task::new(contents=[Element(loop1.element),Element(loop2.element)])
  assert_true(task.loop_characteristics() is InvalidValue(_))
}

///|
test "construct event gateway boundary and conditional flow families" {
  let task=@bpmn.UserTask::new(id="Task",name="Review")
  let timer=@bpmn.TimerEventDefinition::new(id="Timer",contents=[Element(@bpmn.FormalExpression::new(contents=[Text("PT5M")]).element.with_kind(TimeDuration))])
  let boundary=@bpmn.BoundaryEvent::new(id="Boundary",attached_to_ref=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Task")),cancel_activity=false,contents=[Element(timer.element)])
  let gateway=@bpmn.ExclusiveGateway::new(id="Gateway",gateway_direction=Diverging)
  let flow=@bpmn.SequenceFlow::new(id="Flow",source_ref=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Task"),kind=Id),target_ref=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Gateway"),kind=Id),is_immediate=false,contents=[Element(@bpmn.FormalExpression::new(language="urn:inert",contents=[Text("approved == true")]).element.with_kind(ConditionExpression))])
  let process=@bpmn.Process::new(id="P",contents=[Element(task.element),Element(boundary.element),Element(gateway.element),Element(flow.element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[process.element]).document()
  assert_eq(boundary.event_definition().value().unwrap()[0].element.kind,TimerEventDefinition)
  assert_eq(flow.condition_expression().value().unwrap().element.content,"approved == true")
  roundtrip(doc)
}

///|
test "construct collaboration lanes data resources and artifacts in authored order" {
  let parameter=@bpmn.ResourceParameter::new(id="Parameter",name="team",type_=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Item")),is_required=true)
  let resource=@bpmn.Resource::new(id="Resource",contents=[Element(parameter.element)])
  let input=@bpmn.DataInput::new(id="Input",item_subject_ref=@bpmn.Reference::new(@bpmn.ExpandedName::new("","Item")),is_collection=false)
  let io=@bpmn.InputOutputSpecification::new(contents=[Element(input.element)])
  let task=@bpmn.UserTask::new(id="T",contents=[Element(io.element)])
  let nested=@bpmn.Lane::new(id="Inner",contents=[Element(@bpmn.Element::new(FlowNodeRef,content="T"))])
  let child_set=@bpmn.LaneSet::new(contents=[Element(nested.element)]).element.with_kind(ChildLaneSet)
  let lane=@bpmn.Lane::new(id="Outer",contents=[Element(child_set)])
  let lanes=@bpmn.LaneSet::new(id="Lanes",contents=[Element(lane.element)])
  let annotation=@bpmn.TextAnnotation::new(id="Note",contents=[Element(@bpmn.Element::new(Text,content="A descriptive note"))])
  let process=@bpmn.Process::new(id="P",contents=[Element(lanes.element),Element(task.element),Element(annotation.element)])
  let participant=@bpmn.Participant::new(id="Pool",process_ref=@bpmn.Reference::new(@bpmn.ExpandedName::new("","P")))
  let collab=@bpmn.Collaboration::new(id="C",is_closed=false,contents=[Element(participant.element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.ItemDefinition::new(id="Item").element,resource.element,process.element,collab.element]).document()
  assert_eq(lane.child_lane_set().value().unwrap().lane().value().unwrap()[0].id(),Present("Inner"))
  assert_eq(collab.participant().value().unwrap()[0].process_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","P")))
  roundtrip(doc)
}
