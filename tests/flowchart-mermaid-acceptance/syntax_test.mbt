///|
fn field(value : Json, name : String) -> Json {
  guard value is Object(values) else { abort("not object") }
  values.get(name).unwrap()
}

///|
fn array(value : Json) -> Array[Json] {
  guard value is Array(values) else { abort("not array") }
  values
}

///|
fn string(value : Json) -> String {
  guard value is String(value) else { abort("not string") }
  value
}

///|
fn read_source(source : String) -> @syntax.ReadResult {
  @syntax.read(source)
}

///|
test "all frozen flowchart docs and grammar cases read print and convert" {
  let failures = []
  let canonicals = []
  for fixture in array(field(@json.parse(@corpus.reference), "fixtures")) {
    let name = string(field(fixture, "name"))
    let source = string(field(fixture, "source"))
    let result = read_source(source)
    assert_eq(result.tree.text(), source)
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
      failures.push(name + " missing flowchart AST")
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
    let again = @syntax.read(output, header=ast.header)
    if again.ast != Some(ast) || !again.diagnostics.is_empty() {
      failures.push(name + " canonical AST differs")
      continue
    }
    if @printer.print(again.ast.unwrap()).output != Some(output) {
      failures.push(name + " second print differs")
    }
    canonicals.push(Json([Json(name), Json(output)]))
    let converted = @conversion.to_flowchart(ast)
    guard converted.flowchart is Some(model) else {
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
    if !model.lanes.is_empty() {
      failures.push(name + " invented lanes")
    }
    let expected = field(fixture, "normalized")
    let actual = Json(
      model.nodes
      .iter()
      .map(node => {
        Json({
          "id": Json(node.id),
          "label": Json(node.label),
          "shape": Json(node.shape),
        })
      })
      .to_array(),
    )
    let expected_nodes = Json(
      array(field(expected, "nodes")).map(node => {
        Json({
          "id": field(node, "id"),
          "label": field(node, "label"),
          "shape": Json(@model.canonical_shape(string(field(node, "shape")))),
        })
      }),
    )
    if actual != expected_nodes {
      failures.push(
        name +
        " nodes: " +
        actual.stringify() +
        " expected " +
        expected_nodes.stringify(),
      )
    }
    if model.connections.length() != array(field(expected, "edges")).length() {
      failures.push(name + " edge count")
    } else {
      for i, edge in model.connections {
        let e = array(field(expected, "edges"))[i]
        if Json([edge.id, edge.source, edge.target, edge.label]) !=
          Json([
            field(e, "id"),
            field(e, "source"),
            field(e, "target"),
            field(e, "label"),
          ]) {
          failures.push(name + " edge " + i.to_string() + " differs")
        }
      }
    }
    if model.groups.length() != array(field(expected, "groups")).length() {
      failures.push(name + " group count")
    }
    assert_eq(
      Some(model.direction),
      @model.direction(string(field(expected, "direction"))),
    )
    let reference_groups = array(field(expected, "groups"))
    let parents : Map[String, String] = Map([])
    for group in reference_groups {
      for child in array(field(group, "members")) {
        parents[string(child)] = string(field(group, "id"))
      }
    }
    if model.groups.iter().map(group => group.id).to_array() !=
      reference_groups.map(group => string(field(group, "id"))) {
      failures.push(
        name +
        " group IDs: " +
        Json(model.groups.iter().map(group => group.id).to_array()).stringify() +
        " expected " +
        field(expected, "groups").stringify(),
      )
      continue
    }
    for group in model.groups {
      let expected_group = reference_groups
        .iter()
        .find_first(value => field(value, "id") == Json(group.id))
        .unwrap()
      assert_eq(group.label, string(field(expected_group, "label")))
      assert_eq(group.parent, parents.get(group.id))
      let direction = match field(expected_group, "direction") {
        String(value) => @model.direction(value)
        _ => None
      }
      assert_eq(group.direction, direction)
    }
    for i, node in model.nodes {
      let expected_kind = string(
        field(array(field(expected, "nodes"))[i], "labelKind"),
      )
      assert_eq(
        node.label_kind,
        match expected_kind {
          "markdown" => @model.LabelKind::Markdown
          "html" => Html
          _ => Text
        },
      )
      let mut owner = parents.get(node.id)
      let reverse = []
      while owner is Some(id) {
        reverse.push(id)
        owner = parents.get(id)
      }
      let path = []
      for i = reverse.length() - 1; i >= 0; i = i - 1 {
        path.push(reverse[i])
      }
      assert_eq(node.groups.iter().to_array(), path)
    }
    for i, edge in model.connections {
      let expected_edge = array(field(expected, "edges"))[i]
      assert_eq(Json(edge.min_length), field(expected_edge, "length"))
      assert_eq(
        edge.style,
        match string(field(expected_edge, "style")) {
          "dotted" => @model.LineStyle::Dotted
          "thick" => Thick
          "invisible" => Invisible
          _ => Solid
        },
      )
      match string(field(expected_edge, "type")) {
        "double_arrow_point" => {
          assert_eq(edge.source_marker, @model.Marker::Arrow)
          assert_eq(edge.target_marker, @model.Marker::Arrow)
        }
        "double_arrow_circle" => {
          assert_eq(edge.source_marker, @model.Marker::Circle)
          assert_eq(edge.target_marker, @model.Marker::Circle)
        }
        "double_arrow_cross" => {
          assert_eq(edge.source_marker, @model.Marker::Cross)
          assert_eq(edge.target_marker, @model.Marker::Cross)
        }
        "arrow_point" => {
          assert_eq(edge.source_marker, @model.Marker::None)
          assert_eq(edge.target_marker, @model.Marker::Arrow)
        }
        "arrow_circle" => {
          assert_eq(edge.source_marker, @model.Marker::None)
          assert_eq(edge.target_marker, @model.Marker::Circle)
        }
        "arrow_cross" => {
          assert_eq(edge.source_marker, @model.Marker::None)
          assert_eq(edge.target_marker, @model.Marker::Cross)
        }
        "arrow_open" => assert_eq(edge.target_marker, @model.Marker::None)
        unexpected => fail("Unexpected upstream edge type " + unexpected)
      }
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n"))
  }
  let snapshot = @test.Test("canonical native flowchart sources")
  snapshot.write(Json(canonicals).stringify())
  snapshot.snapshot(filename="canonical.json")
}
