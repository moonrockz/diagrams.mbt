///|
fn swimlane_catalog(view : @swimlane.Swimlane) -> @animation.Catalog raise {
  let result = @animation.Catalog::swimlane(view)
  assert_true(
    result.catalog is Some(_),
    msg=@debug.to_string(result.diagnostics),
  )
  result.catalog.unwrap()
}

///|
test "swimlane bidirectional and backward arcs retain path orientation independently of layout" {
  let view = @swimlane.Swimlane::new(
    "Review",
    [
      @swimlane.Node::new("A", lane="Customer"),
      @swimlane.Node::new("B", lane="Support"),
      @swimlane.Node::new("C", lane="Support"),
    ],
    [
      @swimlane.Connection::new("AB", "A", "B", source_marker=Arrow),
      @swimlane.Connection::new(
        "CB",
        "C",
        "B",
        source_marker=Arrow,
        target_marker=None,
      ),
      @swimlane.Connection::new("parallel", "A", "B"),
    ],
    direction=RL,
    lanes=[@swimlane.Lane::new("Customer"), @swimlane.Lane::new("Support")],
  )
  let catalog = swimlane_catalog(view)
  assert_eq(catalog.occurrences.length(), 3)
  assert_true(
    catalog.connection("AB").unwrap().key !=
    catalog.connection("parallel").unwrap().key,
  )
  guard catalog.graph.route("B", "A") is Found(route) else {
    fail("missing bidirectional return")
  }
  assert_eq(route.reversed, [true])
  assert_eq(route.edges[0].source, "B")
  let selected = plan(@animation.PlaybackPlan::route(catalog, route))
  assert_true(selected.steps[0].reversed)
  assert_true(selected.sample_at(250L).active[0].reversed)
  assert_eq(selected.sample_at(250L).active[0].numerator, 250L)
  guard catalog.graph.route("B", "C") is Found(backward) else {
    fail("missing source-headed arrow")
  }
  assert_eq(backward.reversed, [true])
  guard catalog.graph.route("C", "B", direction=Reverse) is Found(reverse) else {
    fail("missing explicit reverse")
  }
  assert_eq(reverse.reversed, [false])
  let repeated = plan(
    @animation.PlaybackPlan::scenario(
      catalog,
      @animation.Motion::serial([
        OrientedStep(catalog.connection("AB").unwrap().key, 500L, true),
        Step(catalog.connection("AB").unwrap().key, 750L),
      ]),
    ),
  )
  assert_eq(repeated.steps.length(), 2)
  assert_true(repeated.steps[0].reversed)
  assert_false(repeated.steps[1].reversed)
}

///|
test "swimlane headless connections are opt-in and lanes never create paths" {
  let view = @swimlane.Swimlane::new(
    "Unheaded",
    [
      @swimlane.Node::new("A", lane="L"),
      @swimlane.Node::new("B", lane="L"),
      @swimlane.Node::new("C", lane="L"),
    ],
    [
      @swimlane.Connection::new("AB", "A", "B", target_marker=None),
      @swimlane.Connection::new("BC", "B", "C", style=Invisible),
    ],
    lanes=[@swimlane.Lane::new("L")],
  )
  let catalog = swimlane_catalog(view)
  assert_eq(catalog.occurrences.length(), 1)
  assert_eq(catalog.graph.route("A", "B"), Unreachable)
  assert_eq(catalog.graph.route("A", "C", kinds=[Undirected]), Unreachable)
  guard catalog.graph.route("B", "A", kinds=[Undirected]) is Found(route) else {
    fail("missing opt-in reverse headless route")
  }
  assert_eq(route.reversed, [true])
  assert_eq(catalog.graph.route("L", "A", kinds=[Undirected]), Unreachable)
  assert_eq(
    catalog.graph.reachable(
      "A",
      kinds=[Undirected],
      direction=Both,
      limits=@animation.Limits::new(edges=1),
    ),
    Failed(Limit(Edges)),
  )
  assert_eq(
    catalog.graph.route(
      "A",
      "B",
      kinds=[Undirected],
      limits=@animation.Limits::new(work=1),
    ),
    Failed(Limit(Work)),
  )
}

///|
test "collapsed swimlane descendants stay outside route scope while handoffs remain playable" {
  let view = @swimlane.Swimlane::new(
    "Collapsed",
    [
      @swimlane.Node::new("Hidden", lane="L", groups=["G"]),
      @swimlane.Node::new("Visible", lane="L"),
    ],
    [@swimlane.Connection::new("Handoff", "Hidden", "Visible")],
    lanes=[@swimlane.Lane::new("L")],
    groups=[@swimlane.Group::new("G", lane="L", expanded=false)],
  )
  let catalog = swimlane_catalog(view)
  assert_eq(catalog.graph.lookup("Hidden"), Err(OutsideView("Hidden")))
  assert_eq(catalog.graph.route("G", "Visible"), Unreachable)
  assert_eq(catalog.occurrences.length(), 1)
  assert_eq(
    plan(@animation.PlaybackPlan::illustrative(catalog)).steps.length(),
    1,
  )
  assert_true(
    @animation.Catalog::swimlane(view, limits=@animation.Limits::new(nodes=1)).catalog
    is None,
  )
}

///|
test "only explicit group endpoints create arcs and hidden internal connections have no occurrence" {
  let view = @swimlane.Swimlane::new(
    "Anchors",
    [
      @swimlane.Node::new("Hidden1", lane="L", groups=["G"]),
      @swimlane.Node::new("Hidden2", lane="L", groups=["G"]),
      @swimlane.Node::new("Visible", lane="L"),
    ],
    [
      @swimlane.Connection::new("Internal", "Hidden1", "Hidden2"),
      @swimlane.Connection::new("Handoff", "Hidden1", "Visible"),
      @swimlane.Connection::new("GroupEndpoint", "G", "Visible"),
    ],
    lanes=[@swimlane.Lane::new("L")],
    groups=[@swimlane.Group::new("G", lane="L", expanded=false)],
  )
  let catalog = swimlane_catalog(view)
  assert_true(catalog.connection("Internal") is None)
  assert_true(catalog.connection("Handoff") is Some(_))
  guard catalog.graph.route("G", "Visible") is Found(route) else {
    fail("missing explicitly authored group endpoint")
  }
  assert_eq(route.edges.length(), 1)
  assert_eq(
    catalog.occurrence(route.edges[0].occurrence.unwrap()).unwrap().swimlane_connection.unwrap().id,
    "GroupEndpoint",
  )
  assert_eq(
    catalog.graph.route("Hidden1", "Visible"),
    Failed(OutsideView("Hidden1")),
  )
}

///|
test "display-anchor depth exhaustion never returns a catalog missing its handoff" {
  let view = @swimlane.Swimlane::new(
    "Anchor limit",
    [
      @swimlane.Node::new("Hidden", lane="Closed", groups=["G"]),
      @swimlane.Node::new("Visible"),
    ],
    [@swimlane.Connection::new("Handoff", "Hidden", "Visible")],
    lanes=[@swimlane.Lane::new("Closed", expanded=false)],
    groups=[@swimlane.Group::new("G", lane="Closed")],
  )
  let result = @animation.Catalog::swimlane(
    view,
    limits=@animation.Limits::new(depth=1),
  )
  assert_true(result.catalog is None)
  assert_eq(result.diagnostics[0].code, "animation/plan-limit")
  assert_eq(swimlane_catalog(view).occurrences.length(), 1)
}
