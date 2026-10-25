///|
fn qref(id : String) -> @bpmn.Reference { @bpmn.Reference::new(@bpmn.ExpandedName::new("",id)) }

///|
fn exact(token : String) -> @bpmn.ExactNumber { @bpmn.ExactNumber::parse(token).unwrap() }

///|
test "choreography and conversation families retain typed containment and references" {
  let doc=model_document("choreography-conversation")
  let task=@bpmn.ChoreographyTask::from_element(by_id(doc,"CT")).unwrap()
  assert_eq(task.loop_type(),Present(@bpmn.ChoreographyLoopType::MultiInstanceSequential))
  assert_eq(task.participant_ref().value().unwrap().map(r => r.name.unwrap().local_name).iter().to_array(),["A","B"])
  assert_eq(task.message_flow_ref().value().unwrap()[0].name,Some(@bpmn.ExpandedName::new("","MF")))
  let sub=@bpmn.SubChoreography::from_element(by_id(doc,"SubCT")).unwrap()
  assert_eq(sub.loop_type(),Absent)
  assert_eq(sub.flow_element().value().unwrap()[0].element.kind,ChoreographyTask)
  let call=@bpmn.CallChoreography::from_element(by_id(doc,"CallCT")).unwrap()
  assert_eq(call.called_choreography_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Reusable")))
  assert_eq(call.participant_association().value().unwrap()[0].inner_participant_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","RA")))
  assert_eq(@bpmn.GlobalChoreographyTask::from_element(by_id(doc,"GlobalChoreography")).unwrap().initiating_participant_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","GA")))
  let collaboration=@bpmn.Collaboration::from_element(by_id(doc,"Conversations")).unwrap()
  assert_eq(collaboration.conversation_node().value().unwrap().length(),3)
  assert_eq(@bpmn.Conversation::from_element(by_id(doc,"Conversation")).unwrap().message_flow_ref().value().unwrap()[0].name,Some(@bpmn.ExpandedName::new("","CM")))
  assert_eq(@bpmn.SubConversation::from_element(by_id(doc,"SubConversation")).unwrap().conversation_node().value().unwrap()[0].element.attribute("id"),Some("NestedConversation"))
  assert_eq(@bpmn.CallConversation::from_element(by_id(doc,"CallConversation")).unwrap().called_collaboration_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","GlobalConversation")))
  assert_eq(@bpmn.ConversationLink::from_element(by_id(doc,"ConversationLinkA")).unwrap().source_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","CA")))
  assert_eq(@bpmn.ConversationAssociation::from_element(by_id(doc,"ConversationAssociation")).unwrap().outer_conversation_node_ref().value().unwrap().name,Some(@bpmn.ExpandedName::new("","Conversation")))
  roundtrip(doc)
  let conversion=@adapter.to_diagram(doc,selector=View("Choreography"))
  assert_eq(conversion.diagram,None)
  assert_eq(conversion.diagnostics[0].code,"bpmn/unsupported-view")
}

///|
test "construct choreography and conversation values without a renderer" {
  let participant_contents : Array[@bpmn.Content] = [Element(@bpmn.Element::new(ParticipantRef,content="A")),Element(@bpmn.Element::new(ParticipantRef,content="B"))]
  let contents=participant_contents.copy(); contents.push(Element(@bpmn.Element::new(MessageFlowRef,content="MF")))
  let task=@bpmn.ChoreographyTask::new(id="CT",initiating_participant_ref=qref("A"),contents~)
  let nested=@bpmn.SubChoreography::new(id="Sub",initiating_participant_ref=qref("B"),contents=participant_contents)
  let call=@bpmn.CallChoreography::new(id="Call",initiating_participant_ref=qref("A"),called_choreography_ref=qref("Reusable"),contents=participant_contents)
  let choreography=@bpmn.Choreography::new(id="C",contents=[Element(@bpmn.Participant::new(id="A").element),Element(@bpmn.Participant::new(id="B").element),Element(@bpmn.MessageFlow::new(id="MF",source_ref=qref("A"),target_ref=qref("B")).element),Element(task.element),Element(nested.element),Element(call.element)])
  let conversation=@bpmn.Conversation::new(id="Conversation",name="Exchange",contents=participant_contents)
  let collaboration=@bpmn.Collaboration::new(id="Conversations",contents=[Element(@bpmn.Participant::new(id="CA").element),Element(conversation.element),Element(@bpmn.ConversationLink::new(id="Link",source_ref=qref("CA"),target_ref=qref("Conversation")).element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Choreography::new(id="Reusable").element,choreography.element,collaboration.element]).document()
  assert_eq(task.loop_type(),Absent)
  participant_contents.clear(); assert_eq(task.participant_ref().value().unwrap().length(),2)
  roundtrip(doc)
}

///|
test "two DI planes preserve exact bounds waypoints labels fonts and display fields" {
  let doc=model_document("di-views")
  let first=@bpmn.BpmnDiagram::from_element(by_id(doc,"D1")).unwrap()
  let second=@bpmn.BpmnDiagram::from_element(by_id(doc,"D2")).unwrap()
  assert_eq(first.resolution().value().unwrap().token,"96.000")
  assert_eq(first.bpmn_plane().value().unwrap().diagram_element().value().unwrap().length(),3)
  assert_eq(second.bpmn_plane().value().unwrap().bpmn_element().value().unwrap().name,Some(@bpmn.ExpandedName::new("","C")))
  let shape=@bpmn.BpmnShape::from_element(by_id(doc,"S1")).unwrap()
  assert_eq(shape.bounds().value().unwrap().x().value().unwrap().token,"-12.345678901234567890123456789")
  assert_eq(shape.bounds().value().unwrap().width().value().unwrap().token,"100.00000000000000001")
  assert_eq(shape.is_marker_visible(),Present(false))
  assert_eq(shape.bpmn_label().value().unwrap().bounds().value().unwrap().x().value().unwrap().token,"1.234567890123456789E+2")
  let edge=@bpmn.BpmnEdge::from_element(by_id(doc,"EdgeF")).unwrap()
  assert_eq(edge.waypoint().value().unwrap()[0].x().value().unwrap().token,"123.45678901234567890123456789")
  assert_eq(edge.message_visible_kind(),Present(@bpmn.BpmnMessageVisibleKind::Initiating))
  let font=first.bpmn_label_style().value().unwrap()[0].font().value().unwrap()
  assert_eq(font.size().value().unwrap().token,"1.200000000000000000000001E+1")
  assert_eq(font.is_bold(),Present(true)); assert_eq(font.is_italic(),Present(false))
  let band=@bpmn.BpmnShape::from_element(by_id(doc,"BandA")).unwrap()
  assert_eq(band.participant_band_kind(),Present(@bpmn.BpmnParticipantBandKind::TopInitiating))
  assert_eq(band.choreography_activity_shape().value().unwrap().name,Some(@bpmn.ExpandedName::new("","CS")))
  roundtrip(doc)
}

///|
test "construct DI with an inherited anonymous extension and exact geometry" {
  let data=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("urn:meta","data"),attributes=[(@bpmn.ExpandedName::new("","ref"),"q:Meta")],bindings=[("q","urn:q")])
  let extension=@bpmn.Element::new(DiExtension,children=[data.element])
  let bounds=@bpmn.DcBounds::new(x=exact("123.456789012345678901"),y=exact("0"),width=exact("100"),height=exact("80"))
  let shape=@bpmn.BpmnShape::new(id="Shape",bpmn_element=qref("T"),is_expanded=false,contents=[Element(extension),Element(bounds.element)])
  let plane=@bpmn.BpmnPlane::new(id="Plane",bpmn_element=qref("P"),contents=[Element(shape.element)])
  let diagram=@bpmn.BpmnDiagram::new(id="D",contents=[Element(plane.element)])
  let process=@bpmn.Process::new(id="P",contents=[Element(@bpmn.Task::new(id="T").element)])
  let doc=@bpmn.Definitions::new("urn:t",children=[process.element,diagram.element]).document()
  assert_eq(shape.extension().value().unwrap().element.children[0].xml().unwrap().name(),@bpmn.ExpandedName::new("urn:meta","data"))
  let xml=@bpmn.write(doc)
  assert_false(xml.contains("Anonymous"))
  roundtrip(doc)
}

///|
test "scoped namespace output bounds include preserved declaration names" {
  let prefix=String::make(50,'x')
  let payload=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("urn:v","payload"),bindings=[(prefix,"urn:unused")])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.ExtensionElements::new(contents=[Element(payload.element)]).element]).document()
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(token_units=50)).output,None)
  assert_eq(@bpmn.try_write(doc,limits=@bpmn.Limits::new(token_units=50)).diagnostics[0].code,"bpmn/write-token-limit")
  assert_true(@bpmn.try_write(doc,limits=@bpmn.Limits::new(token_units=56)).output is Some(_))
  let conflicting=@bpmn.XmlElement::new(@bpmn.ExpandedName::new("","payload"),bindings=[("","urn:default")])
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.ExtensionElements::new(contents=[Element(conflicting.element)]).element]).document()
  assert_eq(@bpmn.try_write(doc).diagnostics[0].code,"bpmn/namespace-conflict")
}
