///|
test "BPMN values copy input arrays and preserve source identities and render properties" {
  let path=[0,2]; let lanes=["Lane"]; let settings=[("condition","ready")]
  let source=@bpmn.SourceIdentity::new(source_id="Original",resource_id="memory:a",path~)
  let events=[@bpmn.EventMarker::new(Timer,settings~)]
  let markers=@bpmn.Markers::new(events~,details=settings)
  let ownership=@bpmn.Ownership::new(lanes~,pool="Pool",subprocess="Sub",attached_to="Task")
  let node=@bpmn.Node::new("render-id",BoundaryEvent,source~,ownership~,markers~)
  let decorated=node.with_properties(@bpmn.RenderProperties::new(link=@bpmn.Link::new("smithy:example#Shape"),description="Explanation",sublabel="Detail"))
  path.clear(); lanes.clear(); settings.clear(); events.clear()
  assert_eq(node.source.path,[0,2]); assert_eq(node.ownership.lanes,["Lane"])
  assert_eq(node.markers.events[0].settings,[("condition","ready")]); assert_eq(node.properties,None)
  assert_eq(decorated.properties.unwrap().link.unwrap().target,"smithy:example#Shape")
  let nodes=[node]; let points=[@bpmn.Point::{x:1,y:2},@bpmn.Point::{x:3,y:4}]
  let flow=@bpmn.Flow::new("F","render-id","Other",points~,kind=DataOutputAssociation,semantic_source=source)
  let flows=[flow]; let view=@bpmn.Bpmn::new("View",nodes,flows)
  points.clear(); nodes.clear(); flows.clear()
  assert_eq(view.nodes.length(),1); assert_eq(view.flows[0].points.length(),2)
  assert_eq(view.flows[0].semantic_source,Some(source)); assert_eq(view.flows[0].kind,DataOutputAssociation)
}

///|
test "exact visual numbers retain finite arbitrary decimal and exponent tokens" {
  for token in ["-12.345678901234567890123456789","+0.000","1.234567890123456789E+2","1e999999",".25","2."] { assert_eq(@bpmn.Number::parse(token).unwrap().token,token) }
  for token in ["","NaN","INF","-INF","1e","1x","1,2",".x","-"," 1"] { assert_eq(@bpmn.Number::parse(token),None) }
  let bounds=@bpmn.ExactBounds::new(@bpmn.Number::parse("-0.1234567890123456789").unwrap(),@bpmn.Number::parse("0").unwrap(),@bpmn.Number::parse("100").unwrap(),@bpmn.Number::parse("80").unwrap())
  let font=@bpmn.Font::new(name="Source font")
  let label=@bpmn.LabelGeometry::new(bounds~,font~)
  assert_eq(label.font.unwrap().name,Some("Source font")); assert_eq(label.bounds.unwrap().x.token,"-0.1234567890123456789")
}
