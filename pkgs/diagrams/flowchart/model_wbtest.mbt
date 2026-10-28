///|
test "model construction copies collections including control regions and notes" {
  let path = ["g"]
  let members = ["a"]
  let branch = Branch::new("branch", members~)
  let region = Region::new("r", Conditional, members~, branches=[branch])
  let node = Node::new("a", groups=path, regions=["r"], role=Action)
  let targets = ["a"]
  let note = Note::new("note", "Explain", targets~, groups=path)
  let nodes = [node]
  let model = Flowchart::new(
    "f",
    nodes,
    [],
    groups=[Group::new("g")],
    regions=[region],
    notes=[note],
  )
  path[0] = "changed"
  members[0] = "changed"
  targets[0] = "changed"
  nodes.clear()
  assert_eq(model.nodes.length(), 1)
  assert_eq(model.nodes[0].groups[0], "g")
  assert_eq(model.regions[0].branches[0].members[0], "a")
  assert_eq(model.notes[0].targets[0], "a")
  assert_eq(validate(model), [])
}

///|
test "shapes do not infer control roles and final roles remain distinct" {
  let generic = Node::new("diamond", shape="diamond")
  assert_eq(generic.role, Generic)
  let stop = Node::new("stop", role=ActivityFinal, shape="fr-circ")
  let end = Node::new("end", role=FlowFinal, shape="cross-circ")
  assert_true(stop.role != end.role)
  assert_true(stop.shape != end.shape)
}

///|
test "parallel connections and repeated labels remain distinct under transforms" {
  let origin = SourceBinding::new("plantuml", "action/1")
  let a = Node::new("a", label="Read", role=Action, origin~)
  let b = Node::new("b", label="Read", role=Action)
  let model = Flowchart::new(
    "f",
    [a, b],
    [
      Connection::new("x", "a", "b"),
      Connection::new("y", "a", "b", label="again"),
    ],
    direction=RL,
  )
  let replacement = [a.with_label("Changed"), b]
  let changed = model.with_nodes(replacement)
  replacement.clear()
  assert_eq(model.nodes[0].label, "Read")
  assert_eq(changed.nodes[0].label, "Changed")
  assert_eq(changed.nodes[0].origin, Some(origin))
  assert_eq(changed.connections[1].source, "a")
  assert_eq(changed.connections[1].target, "b")
  assert_eq(validate(changed), [])
}

///|
test "validation detects cycles missing note targets and invalid region references" {
  let model = Flowchart::new(
    "f",
    [Node::new("a", regions=["absent"])],
    [],
    groups=[Group::new("g", parent="g")],
    regions=[Region::new("r", Loop, parent="r", entry="absent")],
    notes=[Note::new("n", "text", targets=["missing"])],
  )
  let codes = validate(model).map(d => d.code)
  for
    code in [
      "flowchart/ownership-cycle", "flowchart/region-cycle", "flowchart/region-reference",
      "flowchart/note-target",
    ] {
    assert_true(codes.contains(code))
  }
}

///|
test "model validation distinguishes invalid limits and exhausted work" {
  let model = Flowchart::new("f", [Node::new("a")], [])
  assert_eq(validate(model, work_limit=0)[0].code, "flowchart/invalid-limits")
  assert_eq(validate(model, work_limit=1)[0].code, "flowchart/model-limit")
  assert_eq(validate(model), [])
  assert_eq(direction("TD"), Some(TB))
  assert_eq(direction("invalid"), None)
}

///|
test "generated identities avoid authored collisions and obey the work budget" {
  assert_eq(
    fresh_id("generated", ["generated", "generated:1"]),
    Ok("generated:2"),
  )
  assert_eq(
    fresh_id("generated", ["generated", "generated:1"]),
    fresh_id("generated", ["generated", "generated:1"]),
  )
  guard fresh_id("generated", [], work_limit=1) is Err(diagnostic) else {
    fail("expected limit")
  }
  assert_eq(diagnostic.code, "flowchart/id-limit")
}

///|
test "source bindings use validated UTF-16 half-open source spans" {
  let invalid = SourceBinding::new("mermaid", "node", span={
    start: { offset: 4, line: 1, column: 5, },
    end: { offset: 2, line: 1, column: 3, },
  })
  let model = Flowchart::new("f", [Node::new("a", origin=invalid)], [])
  assert_true(validate(model).any(d => d.code == "flowchart/source-binding"))
}
