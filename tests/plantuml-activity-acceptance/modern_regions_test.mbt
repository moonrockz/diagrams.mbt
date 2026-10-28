///|
fn native_children(value : Json) -> Array[Json] {
  let kind = string(field(value, "kind"))
  match kind {
    "InstructionList" => entries(field(value, "all"))
    "InstructionIf" => {
      let all = entries(field(value, "thens"))
      let otherwise = field(value, "elseBranch")
      if otherwise != Json(null) {
        all.push(otherwise)
      }
      all
    }
    "InstructionSwitch" => entries(field(value, "switches"))
    "InstructionFork" => entries(field(value, "forks"))
    "InstructionSplit" => entries(field(value, "splits"))
    "InstructionRepeat" | "InstructionWhile" => [field(value, "repeatList")]
    "InstructionGroup" | "InstructionPartition" | "Branch" =>
      [field(value, "list")]
    _ => []
  }
}

///|
fn native_actions(value : Json, into : Array[String]) -> Unit {
  let kind = string(field(value, "kind"))
  if kind == "InstructionSimple" {
    into.push(string(field(value, "label")))
    return
  }
  if kind == "InstructionRepeat" {
    let start = string(field(value, "startLabel"))
    if !start.is_empty() {
      into.push(start)
    }
  }
  for child in native_children(value) {
    native_actions(child, into)
  }
  if kind == "InstructionRepeat" || kind == "InstructionWhile" {
    let backward = string(field(value, "backward"))
    if !backward.is_empty() {
      into.push(backward)
    }
  }
}

///|
fn native_continues(value : Json) -> Bool {
  let kind = string(field(value, "kind"))
  match kind {
    "InstructionStop"
    | "InstructionEnd"
    | "InstructionBreak"
    | "InstructionGoto" => false
    "InstructionSimple" => field(value, "killed") != Json("true")
    "InstructionList" => {
      let all = entries(field(value, "all"))
      all.last().map(native_continues).unwrap_or(true)
    }
    "Branch" | "InstructionGroup" | "InstructionPartition" =>
      native_continues(field(value, "list"))
    "InstructionIf" | "InstructionSwitch" =>
      native_children(value).iter().any(native_continues)
    _ => true
  }
}

///|
fn model_actions(
  ids : ReadOnlyArray[String],
  nodes : Map[String, @model.Node],
) -> Array[String] {
  ids
  .iter()
  .filter_map(id => {
    nodes.get(id).filter(n => n.role == Action).map(n => n.label)
  })
  .to_array()
}

///|
fn compare_regions(
  value : Json,
  model : @model.Flowchart,
  nodes : Map[String, @model.Node],
  cursor : Array[Int32],
  name : String,
) -> Unit raise {
  for child in native_children(value) {
    compare_regions(child, model, nodes, cursor, name)
  }
  let kind = string(field(value, "kind"))
  if ![
      "InstructionIf", "InstructionSwitch", "InstructionRepeat", "InstructionWhile",
      "InstructionFork", "InstructionSplit",
    ].contains(kind) {
    return
  }
  assert_true(
    cursor[0] < model.regions.length(),
    msg=name + ": missing " + kind + " region",
  )
  let region = model.regions[cursor[0]]
  cursor[0] += 1
  let expected_kind : @model.RegionKind = match kind {
    "InstructionIf" | "InstructionSwitch" => Conditional
    "InstructionRepeat" | "InstructionWhile" => Loop
    "InstructionFork" => Parallel
    _ => Split
  }
  assert_eq(region.kind, expected_kind, msg=name + ": region kind")
  let expected_condition = match kind {
    "InstructionIf" =>
      string(field(entries(field(value, "thens"))[0], "labelTest"))
    "InstructionSwitch" => string(field(value, "labelTest"))
    "InstructionRepeat" | "InstructionWhile" => string(field(value, "test"))
    _ => ""
  }
  assert_eq(
    region.condition.unwrap_or(""),
    expected_condition,
    msg=name + ": region condition",
  )
  if kind == "InstructionIf" || kind == "InstructionSwitch" {
    let branches = if kind == "InstructionIf" {
      entries(field(value, "thens"))
    } else {
      entries(field(value, "switches"))
    }
    if kind == "InstructionIf" {
      branches.push(field(value, "elseBranch"))
    }
    // Native if has an empty implicit else even when source has none. The
    // model keeps that absence in topology rather than inventing a branch value.
    let explicit = region.branches.length()
    assert_true(
      explicit == branches.length() ||
      (kind == "InstructionIf" && explicit + 1 == branches.length()),
      msg=name + ": branch count",
    )
    for i, branch in region.branches {
      let expected = branches[i]
      let actions = []
      native_actions(expected, actions)
      assert_eq(
        model_actions(branch.members, nodes),
        actions,
        msg=name + ": ordered branch actions " + i.to_string(),
      )
      let condition_value = string(field(expected, "labelTest"))
      assert_eq(
        branch.condition.unwrap_or(""),
        condition_value,
        msg=name + ": branch guard " + i.to_string(),
      )
      let label = if kind == "InstructionSwitch" {
        condition_value
      } else {
        string(field(expected, "labelPositive"))
      }
      assert_eq(
        branch.label,
        label,
        msg=name + ": branch label " + i.to_string(),
      )
      let incoming = string(field(expected, "inlabel"))
      if kind == "InstructionIf" && i > 0 && !incoming.is_empty() {
        assert_true(
          model.connections
          .iter()
          .any(e => {
            e.label == incoming &&
            nodes.get(e.source).map(n => n.role == Decision).unwrap_or(false) &&
            nodes
            .get(e.target)
            .map(n => n.role == Decision && n.label == condition_value)
            .unwrap_or(false)
          }),
          msg=name + ": incoming elseif guard label",
        )
      }
    }
  }
  if kind == "InstructionFork" || kind == "InstructionSplit" {
    let branches = entries(
      field(value, if kind == "InstructionFork" { "forks" } else { "splits" }),
    )
    assert_eq(
      region.branches.length(),
      branches.length(),
      msg=name + ": parallel branch count",
    )
    for i, branch in region.branches {
      let actions = []
      native_actions(branches[i], actions)
      assert_eq(
        model_actions(branch.members, nodes),
        actions,
        msg=name + ": parallel branch order " + i.to_string(),
      )
    }
    let exit = nodes[region.exit.unwrap()]
    if kind == "InstructionFork" {
      assert_eq(
        exit.role,
        if string(field(value, "style")) == "MERGE" {
          @model.Role::Merge
        } else {
          @model.Role::Join
        },
        msg=name + ": join versus merge",
      )
      let label = string(field(value, "label"))
        .trim_start(chars="{")
        .trim_end(chars="}")
        .to_owned()
      assert_eq(
        region.join_specification.unwrap_or(""),
        label,
        msg=name + ": native join specification",
      )
    }
  }
  if kind == "InstructionRepeat" || kind == "InstructionWhile" {
    assert_eq(region.branches.length(), 1, msg=name + ": loop body branch")
    let actions = []
    native_actions(field(value, "repeatList"), actions)
    let backward = string(field(value, "backward"))
    if !backward.is_empty() {
      actions.push(backward)
    }
    assert_eq(
      model_actions(region.branches[0].members, nodes),
      actions,
      msg=name + ": loop body/backward membership",
    )
    let entry = region.entry.unwrap()
    let exit = region.exit.unwrap()
    if kind == "InstructionRepeat" {
      let start = string(field(value, "startLabel"))
      assert_eq(nodes[entry].label, start, msg=name + ": repeat entry label")
    } else {
      assert_eq(nodes[entry].role, Decision, msg=name + ": while entry role")
      assert_eq(
        nodes[entry].label,
        expected_condition,
        msg=name + ": while guard",
      )
    }
    let exits = model.connections
      .iter()
      .filter(e => e.role == LoopExit && e.target == exit)
      .to_array()
    assert_true(!exits.is_empty(), msg=name + ": explicit loop exit")
    let condition_value = if kind == "InstructionWhile" {
      entry
    } else {
      model.nodes
      .iter()
      .filter(n => {
        n.role == Decision &&
        n.regions.contains(region.id) &&
        n.label == expected_condition
      })
      .last()
      .unwrap().id
    }
    assert_true(
      exits.iter().any(e => e.source == condition_value),
      msg=name + ": guard-to-exit endpoint",
    )
    let returns = model.connections
      .iter()
      .filter(e => e.role == LoopBack && e.target == entry)
      .to_array()
    if native_continues(field(value, "repeatList")) {
      assert_true(
        !returns.is_empty(),
        msg=name + ": native continuation returns to loop entry",
      )
    }
    let exit_label = string(
      field(value, if kind == "InstructionWhile" { "outColor" } else { "out" }),
    )
    assert_true(
      exits
      .iter()
      .any(e => e.source == condition_value && e.label == exit_label),
      msg=name + ": native loop exit guard label",
    )
    let yes = string(field(value, "yes"))
    assert_true(
      model.connections
      .iter()
      .any(e => {
        e.source == condition_value && e.role != LoopExit && e.label == yes
      }),
      msg=name + ": native loop continue guard label",
    )
    for edge in returns {
      assert_true(
        region.members.contains(edge.source) || edge.source == entry,
        msg=name + ": return endpoint is in loop",
      )
    }
    if !backward.is_empty() {
      let back = region.members
        .iter()
        .filter_map(id => nodes.get(id))
        .filter(n => n.role == Action && n.label == backward)
        .last()
        .unwrap()
      assert_true(
        returns.iter().any(e => e.source == back.id),
        msg=name + ": backward action returns to loop entry",
      )
      if kind == "InstructionRepeat" {
        assert_true(
          model.connections
          .iter()
          .any(e => {
            e.source == condition_value &&
            e.target == back.id &&
            e.role == LoopBack &&
            e.label == yes
          }),
          msg=name + ": repeat guard enters native backward action",
        )
      }
    }
  }
}

///|
test "modern branches loops and parallel regions retain independent native structure" {
  for expected in entries(field(@json.parse(@corpus.reference), "fixtures")) {
    if field(expected, "class") != Json("ActivityDiagram3") {
      continue
    }
    let name = string(field(expected, "name"))
    if field(field(@json.parse(@corpus.expectations), name), "category") ==
      Json("library-refusal") {
      continue
    }
    let fixture = @corpus.fixtures
      .iter()
      .filter(f => f.name == name)
      .next()
      .unwrap()
    let result = @plantuml.to_diagram(
      @plantuml.read(fixture.source).document.unwrap(),
    )
    guard result.diagram is Some(Flowchart(model)) else { fail(name) }
    let nodes : Map[String, @model.Node] = Map([])
    for node in model.nodes {
      nodes[node.id] = node
    }
    let expected_actions = []
    native_actions(field(expected, "instructions"), expected_actions)
    assert_eq(
      model.nodes
      .iter()
      .filter(n => n.role == Action)
      .map(n => n.label)
      .to_array(),
      expected_actions,
      msg=name + ": ordered action occurrences",
    )
    let cursor = [0]
    compare_regions(field(expected, "instructions"), model, nodes, cursor, name)
    assert_eq(
      cursor[0],
      model.regions.length(),
      msg=name + ": all control regions compared",
    )
  }
}
