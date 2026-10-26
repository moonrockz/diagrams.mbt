///|
test "architecture extension preserves legacy graph default work accounting" {
  let view = @bpmn.Bpmn::new("P", [@bpmn.Node::new("A", Task)], [])
  let graph = @animation.Catalog::bpmn(view).catalog.unwrap().graph
  guard graph.reachable("A", limits=@animation.Limits::new(work=6))
    is Complete(nodes) else {
    fail("Legacy one-node discovery needs five kind units and one visit")
  }
  assert_eq(nodes.length(), 1)
  guard graph.route("A", "A", limits=@animation.Limits::new(work=5))
    is Found(route) else {
    fail("Legacy self route needs five default kind units")
  }
  assert_eq(route.nodes.length(), 1)
}
