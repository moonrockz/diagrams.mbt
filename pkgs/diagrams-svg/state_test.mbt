///|
test "state hierarchy roles geometry and canonical scene preserve structure" {
  let roles : Array[@state.Role] = [
    Simple,
    Initial,
    Final,
    Choice,
    Fork,
    Join,
    ShallowHistory,
    DeepHistory,
    EntryPoint,
    ExitPoint,
    InputPin,
    OutputPin,
    ExpansionInput,
    ExpansionOutput,
  ]
  for role in roles {
    let view = @state.StateDiagram::new(
      "role",
      [
        @state.State::new("A", role~, label="Role"),
        @state.State::new("B", label="Next"),
      ],
      [@state.Transition::new("edge", "A", "B", label="event [guard] / action")],
    )
    assert_eq(@state.validate(view), [])
    for mode in [@svg.Mode::Fixed(Light), Fixed(Dark), Adaptive] {
      let renderer = @svg.SvgRenderer::new(mode~, id_prefix="state-copy")
      let result = renderer.render(State(view))
      assert_true(
        result.output is Some(_),
        msg=@debug.to_string(result.diagnostics),
      )
      let output = result.output.unwrap()
      assert_true(output.contains("data-diagram=\"state\""))
      assert_true(output.contains("data-role="))
      let scene = renderer.scene(State(view))
      assert_true(
        scene.scene is Some(_),
        msg=@debug.to_string(scene.diagnostics),
      )
      assert_eq(scene.scene.unwrap().canonical_svg, output)
      assert_eq(scene.scene.unwrap().paths.length(), 1)
    }
  }
}

///|
test "state nested concurrent regions collapsed endpoints and visits stay explicit" {
  let model = @state.StateDiagram::new(
    "nested",
    [
      @state.State::new("C", label="Composite", role=Composite),
      @state.State::new("A", label="Ready", region="r1", descriptions=[
        "entry / log",
      ]),
      @state.State::new("B", label="Ready", region="r2"),
      @state.State::new("Outside"),
      @state.State::new("Isolated"),
    ],
    [
      @state.Transition::new("edge", "Outside", "A"),
      @state.Transition::new("loop", "B", "B", label="again"),
    ],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("r1", owner="C"),
      @state.Region::new("r2", owner="C", separator=Vertical),
    ],
    notes=[
      @state.Note::new(
        "note",
        "History stays descriptive",
        targets=["B"],
        region="r2",
      ),
    ],
  )
  assert_eq(@state.validate(model), [])
  let result = @state_layout.layout(model)
  assert_true(
    result.geometry is Some(_),
    msg=@debug.to_string(result.diagnostics),
  )
  let g = result.geometry.unwrap()
  let shapes = Map(g.shapes.map(s => (s.id, s)))
  assert_true(shapes["C"].box.contains(shapes["A"].box))
  assert_true(shapes["C"].box.contains(shapes["B"].box))
  let scene = @svg.SvgRenderer::new().scene(State(model))
  assert_true(scene.scene is Some(_), msg=@debug.to_string(scene.diagnostics))
  assert_eq(scene.scene.unwrap().paths.length(), 2)
  assert_true(scene.scene.unwrap().nodes.any(n => n.endpoint == "Isolated"))
  let collapsed = model.with_states(
    model.states.map(s => {
      if s.id == "C" {
        @state.State::new(s.id, label=s.label, role=Composite, expanded=false)
      } else {
        s
      }
    })[:],
  )
  let closed = @state_layout.layout(collapsed).geometry.unwrap()
  assert_false(closed.shapes.any(s => s.id == "A"))
  assert_eq(closed.connections[0].transition.target, "A")
  assert_eq(closed.connections[0].target, "C")
}

///|
test "state render bounds prefix isolation hostile labels and connector choices" {
  let model = @state.StateDiagram::new(
    "safe",
    [
      @state.State::new("a", label="</script><svg onload='bad'>"),
      @state.State::new("b"),
    ],
    [@state.Transition::new("e", "a", "b")],
  )
  for style in [@svg.ConnectorStyle::Elbow, Rounded, Curved] {
    let result = @svg.render_state(
      model,
      connectors=@svg.ConnectorOptions::new(style~),
      id_prefix="one",
    )
    assert_true(
      result.output is Some(_),
      msg=@debug.to_string(result.diagnostics),
    )
    assert_false(result.output.unwrap().contains("<svg onload"))
  }
  assert_eq(
    @svg.render_state(model, limits=@state_layout.Limits::new(work=1)).output,
    None,
  )
  assert_eq(
    @svg.render_state(model, limits=@state_layout.Limits::new(width=1)).output,
    None,
  )
  assert_eq(
    @svg.render_state(model, limits=@state_layout.Limits::new(output_units=100)).output,
    None,
  )
  assert_not_eq(
    @svg.render_state(model, id_prefix="one").output,
    @svg.render_state(model, id_prefix="two").output,
  )
}

///|
test "mixed concurrent separator orientations retain ordered nonoverlapping compartments" {
  for direction in [@flowchart.Direction::TB, BT, LR, RL] {
    let model = @state.StateDiagram::new(
      "mixed",
      [
        @state.State::new("owner", role=Composite),
        @state.State::new("a", region="one"),
        @state.State::new("b", region="two"),
        @state.State::new("c", region="three"),
      ],
      [],
      regions=[
        @state.Region::new("root"),
        @state.Region::new("one", owner="owner"),
        @state.Region::new("two", owner="owner", separator=Horizontal),
        @state.Region::new("three", owner="owner", separator=Vertical),
      ],
      direction~,
    )
    let geometry = @state_layout.layout(model).geometry.unwrap()
    let lines = geometry.separators()
    assert_eq(lines.length(), 2)
    assert_eq(lines[0].start.y, lines[0].end.y)
    assert_eq(lines[1].start.x, lines[1].end.x)
    assert_eq(@state_layout.check(geometry, @theme.Theme::classic().light), [])
  }
  let unsupported = @state.StateDiagram::new(
    "unsupported",
    [@state.State::new("symbol", role=Unsupported("sdlreceive"))],
    [],
  )
  assert_eq(@svg.render_state(unsupported).output, None)
  assert_eq(
    @svg.render_state(unsupported).diagnostics[0].code,
    "state/unsupported-role",
  )
}
