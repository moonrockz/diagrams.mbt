///|
fn field(value : Json, name : String) -> Json {
  match value {
    Object(fields) => fields.get(name).unwrap_or(Json(null))
    _ => Json(null)
  }
}

///|
fn string(value : Json) -> String {
  match value {
    String(value) => value
    _ => ""
  }
}

///|
fn entries(value : Json) -> Array[Json] {
  match value {
    Array(items) => items.iter().to_array()
    _ => []
  }
}

///|
fn native_counts(value : Json, counts : Map[String, Int32]) -> Unit {
  match value {
    Object(fields) => {
      if fields.get("kind") is Some(String(kind)) {
        counts[kind] = counts.get(kind).unwrap_or(0) + 1
      }
      for _, child in fields {
        native_counts(child, counts)
      }
    }
    Array(items) =>
      for child in items {
        native_counts(child, counts)
      }
    _ => ()
  }
}

///|
test "all frozen activity examples reproduce and canonically round trip" {
  let canonical : Array[Json] = []
  let expected = @json.parse(@corpus.expectations)
  for fixture in @corpus.fixtures {
    let result = @plantuml.read(fixture.source)
    assert_eq(result.tree.text(), fixture.source, msg=fixture.name)
    if field(field(expected, fixture.name), "stage") == Json("read") {
      assert_true(
        result.diagnostics
        .iter()
        .any(d => d.code == "plantuml/text-outside-block"),
        msg=fixture.name,
      )
      continue
    }
    assert_eq(
      result.diagnostics.iter().filter(d => d.severity == Error).to_array(),
      [],
      msg=fixture.name,
    )
    let document = result.document.unwrap()
    let printed = @plantuml.print(document)
    assert_eq(printed.diagnostics, [], msg=fixture.name + ": print")
    let text = printed.output.unwrap()
    let again = @plantuml.read(text)
    assert_eq(
      again.diagnostics.iter().filter(d => d.severity == Error).to_array(),
      [],
      msg=fixture.name + ": read canonical",
    )
    guard document is Activity(first) &&
      again.document is Some(Activity(second)) else {
      fail("Wrong activity kind " + fixture.name)
    }
    assert_true(first.logical_equal(second), msg=fixture.name)
    assert_eq(
      @plantuml.print(again.document.unwrap()).output,
      Some(text),
      msg=fixture.name,
    )
    canonical.push(Json([Json(fixture.name), Json(text)]))
  }
  let snapshot = @test.Test("canonical activity corpus")
  snapshot.write(Json(canonical).stringify())
  snapshot.snapshot(filename="canonical.json")
}

///|
test "legacy ordered entity and connection topology agrees with pinned upstream" {
  let report = @json.parse(@corpus.reference)
  for expected in entries(field(report, "fixtures")) {
    if field(expected, "class") != Json("ActivityDiagram") {
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
    assert_eq(
      result.diagnostics.iter().filter(d => d.severity == Error).to_array(),
      [],
      msg=name,
    )
    guard result.diagram is Some(Flowchart(model)) else { fail(name) }
    let all_nodes = entries(field(expected, "nodes"))
    let native_nodes = all_nodes
      .iter()
      .filter(n => field(n, "role") != Json("NOTE"))
      .to_array()
    let native_indices : Map[String, Int32] = Map([])
    for i, node in native_nodes {
      native_indices[field(node, "id").stringify()] = i
    }
    let native_edges = entries(field(expected, "edges"))
      .iter()
      .filter(e => {
        native_indices.contains(field(e, "source").stringify()) &&
        native_indices.contains(field(e, "target").stringify())
      })
      .to_array()
    assert_eq(
      model.notes.length(),
      all_nodes.iter().filter(n => field(n, "role") == Json("NOTE")).count(),
      msg=name + ": notes",
    )
    assert_eq(
      model.nodes.length(),
      native_nodes.length(),
      msg=name + ": node count",
    )
    assert_eq(
      model.connections.length(),
      native_edges.length(),
      msg=name + ": edge count",
    )
    let indices : Map[String, Int32] = Map([])
    for i, node in model.nodes {
      indices[node.id] = i
    }
    for i, edge in model.connections {
      assert_eq(
        Json(indices.get(edge.source).unwrap()),
        Json(
          native_indices
          .get(field(native_edges[i], "source").stringify())
          .unwrap(),
        ),
        msg=name + ": edge source " + i.to_string(),
      )
      assert_eq(
        Json(indices.get(edge.target).unwrap()),
        Json(
          native_indices
          .get(field(native_edges[i], "target").stringify())
          .unwrap(),
        ),
        msg=name + ": edge target " + i.to_string(),
      )
    }
  }
}

///|
test "modern control roles agree with independent instruction counts" {
  let report = @json.parse(@corpus.reference)
  for expected in entries(field(report, "fixtures")) {
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
    assert_eq(
      result.diagnostics.iter().filter(d => d.severity == Error).to_array(),
      [],
      msg=name,
    )
    guard result.diagram is Some(Flowchart(model)) else { fail(name) }
    let counts : Map[String, Int32] = Map([])
    native_counts(field(expected, "instructions"), counts)
    let start = counts.get("InstructionStart").unwrap_or(0)
    assert_eq(
      model.nodes.iter().filter(n => n.role == Start).count(),
      start,
      msg=name + ": starts",
    )
    assert_eq(
      model.nodes.iter().filter(n => n.role == ActivityFinal).count(),
      counts.get("InstructionStop").unwrap_or(0),
      msg=name + ": stops",
    )
    assert_eq(
      model.nodes.iter().filter(n => n.role == FlowFinal).count(),
      counts.get("InstructionEnd").unwrap_or(0),
      msg=name + ": flow finals",
    )
    assert_eq(
      model.regions.iter().filter(r => r.kind == Loop).count(),
      counts.get("InstructionWhile").unwrap_or(0) +
      counts.get("InstructionRepeat").unwrap_or(0),
      msg=name + ": loops",
    )
    assert_eq(
      model.regions.iter().filter(r => r.kind == Parallel).count(),
      counts.get("InstructionFork").unwrap_or(0),
      msg=name + ": forks",
    )
  }
}

///|
test "recorded external-asset refusals preserve readable printable source" {
  let expected = @json.parse(@corpus.expectations)
  for fixture in @corpus.fixtures {
    let entry = field(expected, fixture.name)
    if field(entry, "stage") != Json("conversion") {
      continue
    }
    let read = @plantuml.read(fixture.source)
    assert_eq(read.tree.text(), fixture.source, msg=fixture.name)
    assert_true(read.document != None, msg=fixture.name)
    assert_true(
      @plantuml.print(read.document.unwrap()).output != None,
      msg=fixture.name,
    )
    let converted = @plantuml.to_diagram(read.document.unwrap())
    assert_eq(converted.diagram, None, msg=fixture.name)
    assert_true(
      converted.diagnostics
      .iter()
      .any(d => d.code == string(field(entry, "code"))),
      msg=fixture.name,
    )
    assert_eq(
      @plantuml.render_svg(fixture.source).output,
      None,
      msg=fixture.name,
    )
  }
}
