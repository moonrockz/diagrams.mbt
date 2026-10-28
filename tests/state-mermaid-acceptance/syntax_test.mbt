///|
fn field(v : Json, name : String) -> Json {
  guard v is Object(fields) else { abort("object") }
  fields.get(name).unwrap()
}

///|
fn array(v : Json) -> Array[Json] {
  guard v is Array(values) else { abort("array") }
  values
}

///|
fn string(v : Json) -> String {
  guard v is String(s) else { abort("string") }
  s
}

///|
fn role(v : @model.Role) -> String {
  match v {
    Simple => "Simple"
    Composite => "Composite"
    Initial => "Initial"
    Final => "Final"
    Choice => "Choice"
    Fork => "Fork"
    Join => "Join"
    _ => "other"
  }
}

///|
test "all pinned documentation and feature sources retain source and canonical topology" {
  let failures = []
  let canonical = []
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    let result = @syntax.read(source)
    assert_eq(result.tree.text(), source)
    if field(fixture, "accepted") == Json(false) {
      if !result.diagnostics.iter().any(d => d.severity == Error) &&
        result.ast
        .map(ast => @conversion.to_state(ast).state != None)
        .unwrap_or(false) {
        failures.push(name + " accepted a pinned refusal")
      }
      continue
    }
    if name == "cases/boundary-refusal.mmd" {
      assert_true(result.diagnostics.iter().any(d => d.severity == Error))
      assert_eq(@conversion.to_state(result.ast.unwrap()).state, None)
      continue
    }
    if result.diagnostics.iter().any(d => d.severity == Error) {
      failures.push(
        name +
        " read: " +
        result.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
      continue
    }
    guard result.ast is Some(ast) else {
      failures.push(name + " missing AST")
      continue
    }
    let printed = @printer.print(ast)
    guard printed.output is Some(output) else {
      failures.push(
        name +
        " print: " +
        printed.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
      continue
    }
    assert_eq(@syntax.read(output).ast, Some(ast))
    assert_eq(
      @printer.print(@syntax.read(output).ast.unwrap()).output,
      Some(output),
    )
    canonical.push(Json([Json(name), Json(output)]))
    let converted = @conversion.to_state(ast)
    if name == "cases/reserved-root.mmd" {
      assert_eq(converted.state, None)
      assert_true(
        converted.diagnostics.iter().any(d => d.code == "state/reserved-id"),
      )
      continue
    }
    guard converted.state is Some(model) else {
      failures.push(
        name +
        " convert: " +
        converted.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
      continue
    }
    let expected = field(fixture, "normalized")
    let direction = match model.direction {
      TB => "TB"
      BT => "BT"
      LR => "LR"
      RL => "RL"
    }
    assert_eq(Json(direction), field(expected, "direction"))
    assert_eq(
      Json(model.accessibility_title.unwrap_or("")),
      field(expected, "accessibilityTitle"),
    )
    assert_eq(
      Json(model.accessibility_description.unwrap_or("")),
      field(expected, "accessibilityDescription"),
    )
    if name != "cases/floating-note.mmd" {
      let notes = Json(
        model.notes
        .iter()
        .map(n => {
          Json({
            "target": Json(n.targets[0]),
            "text": Json(n.text),
            "placement": Json(n.placement),
          })
        })
        .to_array(),
      )
      assert_eq(notes, field(expected, "notes"))
    }

    let states = Json(
      model.states
      .iter()
      .map(n => {
        Json({
          "id": Json(n.id),
          "label": Json(n.label),
          "descriptions": Json(
            n.descriptions.iter().map(d => Json(d)).to_array(),
          ),
          "role": Json(role(n.role)),
          "region": Json(n.region),
        })
      })
      .to_array(),
    )
    if name != "cases/hostile.mmd" && states != field(expected, "states") {
      failures.push(
        name +
        " states: " +
        states.stringify() +
        " expected " +
        field(expected, "states").stringify(),
      )
    }
    let edges = Json(
      model.transitions
      .iter()
      .map(e => {
        Json({
          "source": Json(e.source),
          "target": Json(e.target),
          "label": Json(e.label),
        })
      })
      .to_array(),
    )
    if name != "cases/hostile.mmd" && edges != field(expected, "transitions") {
      failures.push(
        name +
        " edges: " +
        edges.stringify() +
        " expected " +
        field(expected, "transitions").stringify(),
      )
    }
    let regions = Json(
      model.regions
      .iter()
      .map(r => {
        Json({
          "id": Json(r.id),
          "owner": r.owner.map(s => Json(s)).unwrap_or(Json(null)),
          "members": Json(r.members.iter().map(s => Json(s)).to_array()),
        })
      })
      .to_array(),
    )
    if regions != field(expected, "regions") {
      failures.push(
        name +
        " regions: " +
        regions.stringify() +
        " expected " +
        field(expected, "regions").stringify(),
      )
    }
  }
  assert_eq(failures, [])
  let snapshot = @test.Test("canonical native state sources")
  snapshot.write(Json(canonical).stringify())
  snapshot.snapshot(filename="canonical.json")
}
