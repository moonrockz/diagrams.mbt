///|
fn state_catalog(view : @state.StateDiagram) -> @animation.Catalog raise {
  let result = @animation.Catalog::state(view)
  assert_true(
    result.catalog is Some(_),
    msg=@debug.to_string(result.diagnostics),
  )
  result.catalog.unwrap()
}

///|
test "state parallel transitions reverse traversal and unheaded opt-in remain distinct" {
  let model = @state.StateDiagram::new(
    "reverse",
    [@state.State::new("a"), @state.State::new("b"), @state.State::new("c")],
    [
      @state.Transition::new("ab", "a", "b"),
      @state.Transition::new("parallel", "a", "b"),
      @state.Transition::new("bc", "b", "c", target_marker=None),
    ],
    direction=RL,
  )
  let catalog = state_catalog(model)
  assert_true(
    catalog.connection("ab").unwrap().key !=
    catalog.connection("parallel").unwrap().key,
  )
  guard catalog.graph.route("b", "a", direction=Reverse) is Found(route) else {
    fail("missing reverse route")
  }
  assert_eq(route.reversed, [true])
  assert_eq(
    route.edges[0].occurrence,
    Some(catalog.connection("ab").unwrap().key),
  )
  let plan = @animation.PlaybackPlan::route(catalog, route).plan.unwrap()
  assert_true(plan.steps[0].reversed)
  assert_true(plan.sample_at(250L).active[0].reversed)
  assert_eq(catalog.graph.route("a", "c"), Unreachable)
  guard catalog.graph.route("c", "b", kinds=[Undirected]) is Found(unheaded) else {
    fail("missing unheaded opt-in")
  }
  assert_eq(unheaded.reversed, [true])
  assert_eq(
    catalog.graph.route("a", "b", limits=@animation.Limits::new(work=1)),
    Failed(Limit(Work)),
  )
}

///|
test "state descriptions ownership regions history and note attachments create no routes" {
  let model = @state.StateDiagram::new(
    "structure",
    [
      @state.State::new("outer", role=Composite),
      @state.State::new("a", region="left", descriptions=[
        "entry / log", "tick [guard] / act",
      ]),
      @state.State::new("history", region="right", role=DeepHistory),
    ],
    [],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("left", owner="outer"),
      @state.Region::new("right", owner="outer"),
    ],
    notes=[@state.Note::new("note", "data", targets=["a"], region="left")],
  )
  let catalog = state_catalog(model)
  assert_eq(catalog.graph.edges.length(), 0)
  for target in ["outer", "history", "right", "note"] {
    assert_eq(catalog.graph.route("a", target), Unreachable)
  }
  guard catalog.graph.reachable("a") is Complete(nodes) else {
    fail("reachability failed")
  }
  assert_eq(nodes.length(), 1)
  assert_eq(nodes[0].id, "a")
  guard catalog.graph.lookup("history").unwrap().kind is StateNode(state) else {
    fail("missing role")
  }
  assert_eq(state.role, DeepHistory)
  guard catalog.graph.lookup("right").unwrap().kind is StateRegion(region) else {
    fail("missing region")
  }
  assert_eq(region.owner, Some("outer"))
}

///|
test "state finite scenarios repeat self-loops and group explicit concurrent visits" {
  let model = @state.StateDiagram::new(
    "loop",
    [@state.State::new("a"), @state.State::new("isolated")],
    [@state.Transition::new("loop", "a", "a")],
  )
  let catalog = state_catalog(model)
  let loop_key = catalog.connection("loop").unwrap().key
  let visit = catalog.graph.lookup("isolated").unwrap().occurrence.unwrap()
  let motion = @animation.Motion::serial([
    Parallel([Step(loop_key, 500L), Visit(visit, 750L)]),
    Step(loop_key, 250L),
    Visit(visit, 250L),
  ])
  let plan = @animation.PlaybackPlan::scenario(catalog, motion).plan.unwrap()
  assert_eq(plan.duration_ms, 1250L)
  assert_eq(plan.steps.length(), 4)
  assert_eq(plan.sample_at(100L).active.length(), 2)
  assert_true(plan.sample_at(100L).active.any(a => a.visit))
  assert_eq(plan.steps[0].occurrence.key, plan.steps[2].occurrence.key)
  assert_true(plan.sample_at(1250L).finished)
  assert_eq(
    @animation.PlaybackPlan::scenario(catalog, Step(visit, 500L)).diagnostics[0].code,
    "animation/invalid-target-kind",
  )
  assert_eq(
    @animation.PlaybackPlan::scenario(
      catalog,
      motion,
      limits=@animation.Limits::new(steps=1),
    ).plan,
    None,
  )
  assert_eq(
    @animation.PlaybackPlan::scenario(catalog, Step(loop_key, 0L)).plan,
    None,
  )
  assert_eq(
    @animation.PlaybackPlan::scenario(catalog, Step("missing", 10L)).diagnostics[0].code,
    "animation/invalid-identity",
  )
  guard catalog.graph.route("isolated", "isolated") is Found(route) else {
    fail("missing isolated route")
  }
  assert_true(
    @animation.PlaybackPlan::route(catalog, route).plan.unwrap().steps[0].visit,
  )
  let illustrative = @animation.PlaybackPlan::illustrative(catalog).plan.unwrap()
  assert_eq(illustrative.steps.length(), 3)
  assert_true(illustrative.matches(catalog))
  let other = state_catalog(
    model.with_states([
      @state.State::new("a"),
      @state.State::new("isolated", label="different"),
    ]),
  )
  assert_false(plan.matches(other))
  assert_eq(
    @animation.PlaybackPlan::route(other, route).diagnostics[0].code,
    "animation/plan-mismatch",
  )
}

///|
test "collapsed state descendants are outside queries while external display edges stay playable" {
  let model = @state.StateDiagram::new(
    "collapsed",
    [
      @state.State::new("outer", role=Composite, expanded=false),
      @state.State::new("hidden", region="inside"),
      @state.State::new("visible"),
    ],
    [
      @state.Transition::new("edge", "hidden", "visible"),
      @state.Transition::new("internal", "hidden", "hidden"),
    ],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("inside", owner="outer"),
    ],
  )
  let catalog = state_catalog(model)
  assert_eq(
    catalog.graph.route("hidden", "visible"),
    Failed(OutsideView("hidden")),
  )
  assert_eq(
    catalog.graph.route("missing", "visible"),
    Failed(InvalidEndpoint("missing")),
  )
  assert_eq(catalog.graph.lookup("inside"), Err(OutsideView("inside")))
  assert_true(catalog.connection("edge") is Some(_))
  assert_true(catalog.connection("internal") is None)
  assert_eq(catalog.graph.route("outer", "visible"), Unreachable)
}
