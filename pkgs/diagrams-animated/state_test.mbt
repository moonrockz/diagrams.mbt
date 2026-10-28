///|
test "state player encodes hostile text and exports exactly the canonical source" {
  let hostile = "</script><script>globalThis.stateAttack=true</script>"
  let view = @state.StateDiagram::new(
    "safe",
    [
      @state.State::new("A", label=hostile, descriptions=[hostile]),
      @state.State::new("B"),
    ],
    [@state.Transition::new("edge", "A", "B", label=hostile)],
  )
  let renderer = @svg.SvgRenderer::new(
    id_prefix="state-safe",
    mode=Fixed(Light),
  )
  let scene = renderer.scene(State(view)).scene.unwrap()
  let catalog = scene.catalog
  let key = catalog.connection("edge").unwrap().key
  let plan = @animation.PlaybackPlan::scenario(
    catalog,
    @animation.Motion::serial([Step(key, 500L), Step(key, 500L)]),
  ).plan.unwrap()
  let html = @render.Renderer::render(
    @animated.AnimatedRenderer::new(svg=renderer, playback=plan),
    State(view),
  ).output.unwrap()
  assert_false(html.contains(hostile))
  assert_true(html.contains("\\u003c/script\\u003e"))
  assert_true(html.contains("&lt;/script&gt;"))
  assert_true(html.contains("State role:"))
  assert_true(html.contains("no state machine is executed"))
  assert_true(html.contains("Download SVG"))
  assert_eq(
    scene.canonical_svg,
    @render.Renderer::render(renderer, State(view)).output.unwrap(),
  )
}

///|
test "state HTML refuses a plan for a different immutable source" {
  let a = @state.StateDiagram::new("view", [@state.State::new("A")], [
    @state.Transition::new("self", "A", "A"),
  ])
  let b = a.with_states([@state.State::new("A", label="edited")])
  let plan = @animation.PlaybackPlan::illustrative(
    @animation.Catalog::state(a).catalog.unwrap(),
  ).plan.unwrap()
  let result = @render.Renderer::render(
    @animated.AnimatedRenderer::new(playback=plan),
    State(b),
  )
  assert_eq(result.output, None)
  assert_eq(result.diagnostics[0].code, "animation/plan-mismatch")
}

///|
test "state scene binds isolated composite empty region notes and node visits" {
  let view = @state.StateDiagram::new(
    "visit-structure",
    [
      @state.State::new("Outer", role=Composite, descriptions=[
        "entry / prepare", "do / wait", "exit / finish",
      ]),
      @state.State::new("Inside", region="inside"),
      @state.State::new("Empty", role=Composite),
      @state.State::new("Isolated"),
    ],
    [],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("inside", owner="Outer"),
      @state.Region::new("empty-region", owner="Empty"),
    ],
    notes=[
      @state.Note::new(
        "note",
        "A description without an edge",
        targets=["Inside"],
        region="inside",
      ),
    ],
  )
  let renderer = @svg.SvgRenderer::new(mode=Fixed(Light))
  let result = renderer.scene(State(view))
  assert_true(result.scene is Some(_), msg=@debug.to_string(result.diagnostics))
  let scene = result.scene.unwrap()
  assert_eq(scene.paths.length(), 0)
  assert_eq(scene.catalog.graph.edges.length(), 0)
  for node in scene.catalog.graph.nodes {
    assert_true(
      scene.nodes.any(binding => binding.endpoint == node.id),
      msg="Missing inspection binding: " + node.id,
    )
    if node.occurrence is Some(key) {
      assert_true(
        scene.nodes.any(binding => binding.endpoint == key),
        msg="Missing visit binding: " + node.id,
      )
    }
  }
  let visit = scene.catalog.graph.lookup("Empty").unwrap().occurrence.unwrap()
  let plan = @animation.PlaybackPlan::scenario(
    scene.catalog,
    Visit(visit, 1000L),
  ).plan.unwrap()
  let html = @render.Renderer::render(
    @animated.AnimatedRenderer::new(svg=renderer, playback=plan),
    State(view),
  )
  assert_true(html.output is Some(_), msg=@debug.to_string(html.diagnostics))
  assert_eq(
    scene.canonical_svg,
    @render.Renderer::render(renderer, State(view)).output.unwrap(),
  )
}
