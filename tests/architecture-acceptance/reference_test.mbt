///|
fn field(value : Json, key : String) -> Json {
  guard value is Object(fields) else { abort("Expected object") }
  fields[key]
}

///|
fn string(value : Json) -> String {
  guard value is String(text) else { abort("Expected string") }
  text
}

///|
fn array(value : Json) -> Array[Json] {
  guard value is Array(values) else { abort("Expected array") }
  values
}

///|
fn optional(value : String?) -> Json {
  value.map(v => Json(v)).unwrap_or(Json(null))
}

///|
fn normalized(model : @model.Architecture) -> Json {
  Json({
    "accepted": Json(true),
    "groups": Json(
      model.groups
      .iter()
      .map(g => {
        Json({
          "id": Json(g.id),
          "icon": optional(g.icon.map(i => i.key)),
          "label": Json(g.label),
          "parent": optional(g.parent),
        })
      })
      .to_array(),
    ),
    "services": Json(
      model.services
      .iter()
      .map(n => {
        Json({
          "id": Json(n.id),
          "icon": optional(n.icon.map(i => i.key)),
          "iconText": optional(n.icon_text),
          "label": Json(n.label),
          "parent": optional(n.parent),
        })
      })
      .to_array(),
    ),
    "junctions": Json(
      model.junctions
      .iter()
      .map(n => Json({ "id": Json(n.id), "parent": optional(n.parent) }))
      .to_array(),
    ),
    "edges": Json(
      model.connections
      .iter()
      .map(e => {
        Json({
          "source": Json(e.source.id),
          "target": Json(e.target.id),
          "sourceSide": Json(e.source.side.to_string()),
          "targetSide": Json(e.target.side.to_string()),
          "sourceGroup": Json(e.source.group),
          "targetGroup": Json(e.target.group),
          "sourceHead": Json(e.source_head),
          "targetHead": Json(e.target_head),
          "label": optional(e.label),
        })
      })
      .to_array(),
    ),
    "alignments": Json(
      model.alignments
      .iter()
      .map(a => {
        Json({
          "direction": Json(if a.axis == Row { "row" } else { "column" }),
          "members": Json(a.members.iter().to_array()),
        })
      })
      .to_array(),
    ),
    "title": Json(model.title.unwrap_or("")),
    "accTitle": Json(model.accessibility_title.unwrap_or("")),
    "accDescription": Json(model.accessibility_description.unwrap_or("")),
  })
}

///|
test "complete architecture frozen oracle agrees with typed conversion" {
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    let expected = field(fixture, "normalized")
    let parsed = @syntax.read(source)
    assert_eq(parsed.tree.text(), source)
    if !parsed.diagnostics.is_empty() {
      if field(expected, "accepted") == Json(false) {
        continue
      }
      fail(
        name +
        " syntax " +
        parsed.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
    }
    let converted = @conversion.to_architecture(parsed.ast.unwrap())
    if field(expected, "accepted") == Json(false) {
      assert_eq(converted.architecture, None)
      continue
    }
    guard converted.architecture is Some(model) else {
      fail(
        name +
        " conversion " +
        converted.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
    }
    if normalized(model) != expected {
      fail(
        name +
        " native " +
        normalized(model).stringify() +
        " reference " +
        expected.stringify(),
      )
    }
    let canonical = @printer.print(parsed.ast.unwrap()).output.unwrap()
    let again = @syntax.read(canonical)
    assert_eq(again.diagnostics.length(), 0)
    assert_eq(again.ast, parsed.ast)
    assert_eq(@printer.print(again.ast.unwrap()).output, Some(canonical))
  }
}

///|
test "all accepted architecture fixtures lay out with readable themes" {
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    if field(field(fixture, "normalized"), "accepted") != Json(true) {
      continue
    }
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    let model = @conversion.to_architecture(@syntax.read(source).ast.unwrap()).architecture.unwrap()
    let result = @layout.layout(model)
    guard result.geometry is Some(g) else {
      fail(
        name +
        " layout " +
        result.diagnostics
        .iter()
        .map(d => d.code + " " + d.message)
        .to_array()
        .join("; "),
      )
    }
    for palette in [@theme.Theme::classic().light, @theme.Theme::classic().dark] {
      let findings = @layout.check(g, palette~)
      if !findings.is_empty() {
        fail(
          name +
          " legibility " +
          findings
          .iter()
          .map(f => f.code + " " + f.message + " " + f.element)
          .to_array()
          .join("; "),
        )
      }
    }
  }
}

///|
test "canonical architecture corpus is deterministic on all four targets" {
  let values = []
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    if field(field(fixture, "normalized"), "accepted") != Json(true) {
      continue
    }
    values.push(
      Json([
        string(field(fixture, "name")),
        @printer.print(
          @syntax.read(string(field(fixture, "source"))).ast.unwrap(),
        ).output.unwrap(),
      ]),
    )
  }
  let snapshot = @test.Test("architecture canonical")
  snapshot.write(Json(values).stringify())
  snapshot.snapshot(filename="canonical.json")
}
