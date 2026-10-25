///|
test "constructors copy arrays and preserve independent ownership" {
 let source=[Node::new("A",lane="owner",groups=["nested"])]
 let edges=[Connection::new("handoff","A","B")]
 let groups=[Group::new("nested",lane="owner")]
 let lanes=[Lane::new("owner")]
 let diagram=Swimlane::new("view",source[:],edges[:],groups=groups[:],lanes=lanes[:])
 source[0]=Node::new("changed")
 edges.clear(); groups.clear(); lanes.clear()
 assert_eq(diagram.nodes[0].id,"A")
 assert_eq(diagram.connections.length(),1)
 assert_eq(diagram.groups.length(),1)
 assert_eq(diagram.lanes.length(),1)
 assert_eq(diagram.nodes[0].groups,["nested"])
}
///|
test "validation finds ownership cycles missing endpoints and duplicate identities" {
 let diagram=Swimlane::new("view",[Node::new("same"),Node::new("same")],[Connection::new("edge","same","missing")],groups=[Group::new("g",parent="h"),Group::new("h",parent="g")])
 let codes=validate(diagram).iter().map(d => d.code).to_array()
 assert_true(codes.contains("swimlane/duplicate-id"))
 assert_true(codes.contains("swimlane/ownership-cycle"))
 assert_true(codes.contains("swimlane/missing-endpoint"))
 assert_true(validate(diagram,work_limit=0).iter().any(d => d.code == "swimlane/model-limit"))
}
///|
test "marker policy is independent of flow placement and copied metadata" {
 let metadata=[("asset","kept")]; let groups=["group"]
 let node=Node::new("node",shape="database",metadata=metadata[:],groups=groups[:])
 metadata[0]=("changed","changed"); groups.clear()
 assert_eq(node.shape,"cylinder")
 assert_eq(node.metadata,[("asset","kept")])
 assert_eq(node.groups,["group"])
 assert_eq(Connection::new("edge","A","B",source_marker=Arrow,target_marker=None).direction,Backward)
 assert_eq(Connection::new("edge","A","B",source_marker=Arrow,target_marker=Arrow).direction,Both)
 assert_eq(Connection::new("edge","A","B",source_marker=None,target_marker=None).direction,Undirected)
 assert_eq(Connection::new("edge","A","B",style=LineStyle::Invisible).direction,FlowDirection::Invisible)
 assert_eq(direction("TD"),Some(TB))
}
///|
test "validation checks inclusive ancestry depth and group lane consistency" {
 let valid=Swimlane::new("view",[],[],lanes=[Lane::new("L1"),Lane::new("L2")],groups=[Group::new("P",lane="L1"),Group::new("C",lane="L1",parent="P")])
 assert_eq(validate(valid,depth_limit=2).length(),0)
 assert_true(validate(valid,depth_limit=1).iter().any(d => d.code == "swimlane/model-limit"))
 let bad=Swimlane::new("view",[],[],lanes=[Lane::new("L1"),Lane::new("L2")],groups=[Group::new("P",lane="L1"),Group::new("C",lane="L2",parent="P")])
 assert_true(validate(bad).iter().any(d => d.code == "swimlane/ownership"))
 let large="x".repeat(300000)
 let metadata=Array::make(10000,("same",large))
 let bounded=Swimlane::new("view",[Node::new("A",metadata=metadata[:])],[])
 assert_true(validate(bounded).iter().any(d => d.code == "swimlane/model-limit"))
}
