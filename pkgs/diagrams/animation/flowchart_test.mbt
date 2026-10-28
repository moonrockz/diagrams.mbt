///|
fn flowchart_catalog(view : @flowchart.Flowchart) -> @animation.Catalog raise {
  let result=@animation.Catalog::flowchart(view)
  assert_true(result.catalog is Some(_),msg=@debug.to_string(result.diagnostics))
  result.catalog.unwrap()
}
///|
test "flowchart reverse routes preserve actual connection orientation" {
  let model=@flowchart.Flowchart::new("reverse",[@flowchart.Node::new("a"),@flowchart.Node::new("b")],[@flowchart.Connection::new("ab","a","b",source_marker=Arrow),@flowchart.Connection::new("parallel","a","b")],direction=RL)
  let catalog=flowchart_catalog(model)
  assert_true(catalog.connection("ab").unwrap().key != catalog.connection("parallel").unwrap().key)
  guard catalog.graph.route("b","a") is Found(route) else { fail("missing return route") }
  assert_eq(route.reversed,[true])
  let plan=@animation.PlaybackPlan::route(catalog,route).plan.unwrap()
  assert_true(plan.steps[0].reversed)
  assert_true(plan.sample_at(250L).active[0].reversed)
  assert_eq(plan.sample_at(250L).active[0].numerator,250L)
}
///|
test "flowchart invisible and note relations do not create routes" {
  let model=@flowchart.Flowchart::new("relations",[@flowchart.Node::new("a"),@flowchart.Node::new("b"),@flowchart.Node::new("c")],[@flowchart.Connection::new("ab","a","b",target_marker=None),@flowchart.Connection::new("bc","b","c",style=Invisible)],notes=[@flowchart.Note::new("note","text",targets=["a"])])
  let catalog=flowchart_catalog(model)
  assert_eq(catalog.graph.route("a","b"),Unreachable)
  assert_eq(catalog.graph.route("a","note"),Unreachable)
  assert_eq(catalog.graph.route("a","c",kinds=[Undirected]),Unreachable)
  guard catalog.graph.route("b","a",kinds=[Undirected]) is Found(route) else { fail("missing unheaded opt-in") }
  assert_eq(route.reversed,[true])
  assert_eq(catalog.graph.route("a","b",kinds=[Undirected],limits=@animation.Limits::new(work=1)),Failed(Limit(Work)))
}
///|
test "flowchart scenarios retain repetitions parallel groups and explicit visits" {
  let model=@flowchart.Flowchart::new("loop",[@flowchart.Node::new("a",role=Action),@flowchart.Node::new("b",role=Decision),@flowchart.Node::new("isolated",role=Action)],[@flowchart.Connection::new("forward","a","b"),@flowchart.Connection::new("return","b","a",role=LoopBack)])
  let catalog=flowchart_catalog(model)
  let forward=catalog.connection("forward").unwrap().key
  let back=catalog.connection("return").unwrap().key
  let visit=catalog.graph.lookup("isolated").unwrap().occurrence.unwrap()
  let motion=@animation.Motion::serial([Parallel([Step(forward,500L),Visit(visit,750L)]),Step(back,250L),Step(back,250L)])
  let plan=@animation.PlaybackPlan::scenario(catalog,motion).plan.unwrap()
  assert_eq(plan.duration_ms,1250L)
  assert_eq(plan.steps.length(),4)
  assert_eq(plan.sample_at(100L).active.length(),2)
  assert_true(plan.sample_at(100L).active.any(a => a.visit))
  assert_true(plan.sample_at(1250L).finished)
  assert_eq(plan.steps[2].occurrence.key,plan.steps[3].occurrence.key)
  let invalid=@animation.PlaybackPlan::scenario(catalog,Step(visit,500L))
  assert_eq(invalid.plan,None)
  assert_eq(invalid.diagnostics[0].code,"animation/invalid-target-kind")
  assert_eq(@animation.PlaybackPlan::scenario(catalog,motion,limits=@animation.Limits::new(steps=1)).plan,None)
  assert_eq(@animation.PlaybackPlan::scenario(catalog,Step(forward,0L)).plan,None)
  guard catalog.graph.route("isolated","isolated") is Found(self_route) else { fail("missing isolated endpoint") }
  assert_true(@animation.PlaybackPlan::route(catalog,self_route).plan.unwrap().steps[0].visit)
}
///|
test "collapsed flowchart descendants retain outside-view distinction" {
  let model=@flowchart.Flowchart::new("collapse",[@flowchart.Node::new("hidden",groups=["group"]),@flowchart.Node::new("visible")],[@flowchart.Connection::new("edge","hidden","visible")],groups=[@flowchart.Group::new("group",expanded=false)])
  let catalog=flowchart_catalog(model)
  assert_eq(catalog.graph.route("hidden","visible"),Failed(OutsideView("hidden")))
  assert_eq(catalog.graph.route("missing","visible"),Failed(InvalidEndpoint("missing")))
  assert_true(catalog.connection("edge") is Some(_))
  assert_false(catalog.occurrences.any(o => o.is_visit() && o.key.contains("hidden")))
}
///|
test "default flowchart illustrations are finite even on a cycle" {
  let model=@flowchart.Flowchart::new("cycle",[@flowchart.Node::new("a"),@flowchart.Node::new("b")],[@flowchart.Connection::new("ab","a","b"),@flowchart.Connection::new("ba","b","a")])
  let catalog=flowchart_catalog(model)
  let plan=@animation.PlaybackPlan::illustrative(catalog).plan.unwrap()
  assert_eq(plan.steps.length(),4)
  assert_eq(plan.steps.length(),catalog.occurrences.length())
  assert_true(plan.matches(catalog))
  let other=flowchart_catalog(@flowchart.Flowchart::new("different",[@flowchart.Node::new("a")],[]))
  assert_false(plan.matches(other))
}
///|
test "flowchart control regions retain independent inspection identities without route arcs" {
  let region=@flowchart.Region::new("condition",Conditional,entry="decision",exit="join",members=["decision","action","join"],branches=[@flowchart.Branch::new("yes",label="yes",condition="ready?",members=["action"])],condition="ready?")
  let model=@flowchart.Flowchart::new("regions",[@flowchart.Node::new("decision",role=Decision,regions=["condition"]),@flowchart.Node::new("action",role=Action,regions=["condition"]),@flowchart.Node::new("join",role=Merge,regions=["condition"])],[@flowchart.Connection::new("yes-edge","decision","action",label="yes",role=Branch),@flowchart.Connection::new("merge","action","join")],regions=[region])
  let catalog=flowchart_catalog(model)
  guard catalog.graph.lookup("condition").unwrap().kind is FlowchartRegion(value,anchor) else { fail("missing inspectable control region") }
  assert_eq(value,region)
  assert_eq(anchor,"decision")
  assert_eq(catalog.graph.route("condition","decision"),Unreachable)
  assert_eq(catalog.graph.edges.length(),2)
}
