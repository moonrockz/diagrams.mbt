///|
test "state construction and transformations copy ordered mutable inputs" {
  let descriptions = ["entry / log", "tick [ready] / wait"]
  let members = ["same-1", "same-2"]
  let states = [
    @state.State::new("same-1", label="same", descriptions~),
    @state.State::new("same-2", label="same"),
  ]
  let regions = [@state.Region::new("root", members~)]
  let transitions = [
    @state.Transition::new("first", "same-1", "same-2"),
    @state.Transition::new("parallel", "same-1", "same-2", label="second"),
  ]
  let targets = ["same-1"]
  let notes = [@state.Note::new("note", "hello", targets~)]
  let model = @state.StateDiagram::new(
    "copied",
    states,
    transitions,
    regions~,
    notes~,
  )
  descriptions[0] = "changed"
  members[0] = "changed"
  states[0] = @state.State::new("changed")
  transitions.clear()
  targets[0] = "changed"
  notes.clear()
  assert_eq(model.states[0].descriptions[0], "entry / log")
  assert_eq(model.regions[0].members[0], "same-1")
  assert_eq(model.notes[0].targets[0], "same-1")
  assert_eq(model.transitions.length(), 2)
  assert_eq(model.states.map(s => s.id), ["same-1", "same-2"])
  assert_true(@state.validate(model).is_empty())
  let changed = [model.states[0].with_label("edited")]
  let edited = model.with_states(changed)
  changed.clear()
  assert_eq(edited.states.length(), 1)
  assert_eq(model.states[0].label, "same")
  assert_eq(
    model.states[0].with_descriptions(descriptions).descriptions[0],
    "changed",
  )
}

///|
test "hierarchy concurrent and empty regions retain typed roles without edges" {
  let states = [
    @state.State::new("outer", role=Composite),
    @state.State::new("nested", region="left", role=Composite),
    @state.State::new("start-left", region="left", role=Initial),
    @state.State::new("start-right", region="right", role=Initial),
    @state.State::new("history", region="right", role=ShallowHistory),
    @state.State::new("deep", region="right", role=DeepHistory),
    @state.State::new("entry", region="left", role=EntryPoint),
    @state.State::new("exit", region="left", role=ExitPoint),
    @state.State::new("pin", region="left", role=InputPin),
    @state.State::new("out", region="left", role=OutputPin),
    @state.State::new("expand-in", region="left", role=ExpansionInput),
    @state.State::new("expand-out", region="left", role=ExpansionOutput),
    @state.State::new("choice", region="right", role=Choice),
    @state.State::new("fork", region="right", role=Fork),
    @state.State::new("join", region="right", role=Join),
    @state.State::new("end", region="right", role=Final),
  ]
  let regions = [
    @state.Region::new("root"),
    @state.Region::new("left", owner="outer"),
    @state.Region::new("right", owner="outer", separator=Vertical),
    @state.Region::new("empty", owner="nested"),
  ]
  let model = @state.StateDiagram::new("hierarchy", states, [], regions~)
  assert_true(@state.validate(model).is_empty())
  assert_true(model.transitions.is_empty())
  assert_eq(model.regions[2].separator, Vertical)
  assert_true(model.regions[3].members.is_empty())
  assert_true(model.states[4].role != model.states[5].role)
}

///|
test "state validation distinguishes invalid ownership from bounded exhaustion" {
  let cycle = @state.StateDiagram::new(
    "cycle",
    [@state.State::new("a", region="a-region", role=Composite)],
    [],
    regions=[@state.Region::new("a-region", owner="a")],
  )
  assert_true(
    @state.validate(cycle).any(d => d.code == "state/ownership-cycle"),
  )
  let malformed = @state.StateDiagram::new(
    "bad",
    [@state.State::new("a", region="missing"), @state.State::new("a")],
    [@state.Transition::new("edge", "a", "absent", min_length=0)],
    notes=[@state.Note::new("n", "bad", targets=["missing"], placement="near")],
  )
  let findings = @state.validate(malformed)
  for
    code in [
      "duplicate-id", "missing-region", "missing-endpoint", "invalid-length", "note-target",
      "note-placement",
    ] {
    assert_true(findings.any(d => d.code == "state/" + code), msg=code)
  }
  assert_eq(
    @state.validate(malformed, work_limit=1)[0].code,
    "state/work-limit",
  )
  assert_eq(
    @state.validate(malformed, nodes_limit=1)[0].code,
    "state/model-limit",
  )
  assert_eq(
    @state.validate(malformed, work_limit=0)[0].code,
    "state/invalid-limits",
  )
  assert_true(
    @state.validate(malformed, diagnostics_limit=1).any(d => {
      d.code == "state/diagnostic-limit"
    }),
  )
  let deep = @state.StateDiagram::new(
    "depth",
    [
      @state.State::new("a", role=Composite),
      @state.State::new("b", region="nested"),
    ],
    [],
    regions=[
      @state.Region::new("root"),
      @state.Region::new("nested", owner="a"),
    ],
  )
  assert_true(
    @state.validate(deep, depth_limit=1).any(d => d.code == "state/depth-limit"),
  )
}

///|
test "state direction changes preserve semantic source and target" {
  let model = @state.StateDiagram::new(
    "direction",
    [@state.State::new("a"), @state.State::new("b")],
    [@state.Transition::new("edge", "a", "b")],
  )
  let changed = model.with_direction(RL)
  assert_eq(changed.transitions, model.transitions)
  assert_eq(changed.transitions[0].source, "a")
  assert_eq(changed.transitions[0].target, "b")
  assert_eq(@state.fresh_id("a", ["a", "a:1"]).unwrap(), "a:2")
  guard @state.fresh_id("a", [], work_limit=0) is Err(invalid) else {
    fail("invalid ID budget succeeded")
  }
  assert_eq(invalid.code, "state/invalid-limits")
  guard @state.fresh_id("a", ["a"], work_limit=1) is Err(exhausted) else {
    fail("ID exhaustion succeeded")
  }
  assert_eq(exhausted.code, "state/id-limit")
}
