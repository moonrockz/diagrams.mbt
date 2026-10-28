///|
test "headers aliases and source recovery retain exact UTF-16 locations" {
  for header in ["flowchart", "graph", "flowchart-elk"] {
    let source = header + " LR; A[Read] --> B[Write]"
    let result = @syntax.read(source, header~)
    assert_eq(result.tree.text(), source)
    assert_eq(result.diagnostics, [])
    assert_eq(result.ast.unwrap().header, header)
    assert_true(
      @printer.print(result.ast.unwrap()).output
      .unwrap()
      .has_prefix(header + " LR\n"),
    )
  }
  let source = "flowchart\r\nA[\"😀\"]\r\nbroken[\r\nB --> C\r\nbad(\r\nD --> E\r\n"
  let result = @syntax.read(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 2)
  assert_eq(result.diagnostics[0].span.unwrap().start.line, 3)
  assert_eq(result.diagnostics[1].span.unwrap().start.line, 5)
  assert_eq(
    result.diagnostics[0].span.unwrap().start.offset,
    source.find("broken").unwrap(),
  )
  assert_eq(result.ast.unwrap().statements.length(), 3)
  let missing = @syntax.read("flowchart\nsubgraph A\nB --> C")
  assert_true(
    missing.diagnostics.iter().any(d => d.code == "flowchart/missing-end"),
  )
}

///|
test "flowchart limits diagnose source expansion depth metadata work and output" {
  let source = "flowchart\nA & B --> C & D"
  let limited = @syntax.read(source, limits=@shared.Limits::new(source=4))
  assert_eq(limited.ast, None)
  assert_eq(limited.tree.text(), source)
  assert_eq(limited.diagnostics[0].code, "flowchart/source-limit")
  let ast = @syntax.read(source).ast.unwrap()
  let converted = @conversion.to_flowchart(
    ast,
    limits=@shared.Limits::new(edges=3),
  )
  assert_eq(converted.flowchart, None)
  assert_eq(converted.diagnostics[0].code, "flowchart/edge-limit")
  let converted = @conversion.to_flowchart(
    ast,
    limits=@shared.Limits::new(nodes=2),
  )
  assert_eq(converted.flowchart, None)
  assert_eq(converted.diagnostics[0].code, "flowchart/node-limit")
  assert_eq(
    @printer.print(ast, limits=@shared.Limits::new(output=5)).output,
    None,
  )
  assert_eq(@syntax.read(source, limits=@shared.Limits::new(work=2)).ast, None)
  let nested = @syntax.read(
    "flowchart\nsubgraph A\nsubgraph B\nC\nend\nend",
    limits=@shared.Limits::new(depth=1),
  )
  assert_eq(nested.ast, None)
  assert_true(
    nested.diagnostics.iter().any(d => d.code == "flowchart/depth-limit"),
  )
  let metadata = @syntax.read(
    "flowchart\nA@{ custom: [[[[1]]]] }",
    limits=@shared.Limits::new(metadata_depth=2),
  )
  assert_eq(metadata.ast, None)
  assert_true(
    metadata.diagnostics.iter().any(d => d.code == "flowchart/depth-limit"),
  )
}

///|
test "typed AST edits drive canonical printing and invalid values give no output" {
  let original = @syntax.read("graph LR\nA[Original] --> B").ast.unwrap()
  guard original.statements[0].kind is Edges(chain) else {
    fail("expected edge")
  }
  let node = chain.endpoints[0][0]
  let changed = { ..node, label: Some("Changed \"quoted\" 😀 & <text>"), }
  let endpoints = chain.endpoints.iter().to_array()
  endpoints[0] = [changed]
  let statement = {
    ..original.statements[0],
    kind: Edges({ ..chain, endpoints: ReadOnlyArray::from_array(endpoints), }),
  }
  let ast = @ast.Diagram::new([statement], header="graph", direction="LR")
  let printed = @printer.print(ast).output.unwrap()
  let again = @syntax.read(printed, header="graph")
  assert_eq(again.ast, Some(ast))
  assert_eq(@printer.print(again.ast.unwrap()).output, Some(printed))
  let invalid = @ast.Diagram::new([statement], header="unsupported")
  assert_eq(@printer.print(invalid).output, None)
}

///|
test "groups stay groups collapsed state links metadata and source identities survive" {
  let source = "---\ntitle: 'A flowchart title'\n---\nflowchart RL\nsubgraph Outer\nsubgraph Inner\nA[Same] --> B[Same]\nend\nend\nInner@{ view: collapsed }\nA --> C\nclick A href \"https://example.com/docs\" \"Read docs\" _blank\nclick B callback\n"
  let read = @syntax.read(source)
  assert_eq(read.tree.text(), source)
  let converted = @conversion.to_flowchart(read.ast.unwrap())
  let model = converted.flowchart.unwrap()
  assert_eq(model.title, Some("A flowchart title"))
  assert_eq(model.lanes, [])
  assert_eq(model.groups.length(), 2)
  assert_eq(model.groups[0].id, "Inner")
  assert_eq(model.groups[0].parent, Some("Outer"))
  assert_eq(model.groups[0].expanded, false)
  assert_eq(model.nodes[0].groups, ["Outer", "Inner"])
  assert_eq(model.nodes[0].role, @model.Role::Generic)
  assert_eq(
    model.nodes[0].properties.unwrap().link,
    Some("https://example.com/docs"),
  )
  assert_true(model.nodes[0].origin.unwrap().span != None)
  assert_true(model.connections[0].origin.unwrap().span != None)
  assert_true(model.nodes[0].id != model.nodes[1].id)
  assert_eq(model.connections[1].source, "A")
  assert_eq(model.nodes[2].groups, [])
  assert_true(
    converted.diagnostics
    .iter()
    .any(d => d.code == "flowchart/presentation-metadata"),
  )
}

///|
test "shape catalog aliases keep vector identity and asset requests remain source data" {
  for entry in array(@json.parse(@corpus.shapes)) {
    let short = string(field(entry, "shortName"))
    for spelling in array(field(entry, "aliases")) {
      assert_eq(
        @model.canonical_shape(string(spelling)),
        @model.canonical_shape(short),
      )
    }
    if field(entry, "asset") == Json(false) {
      assert_true(
        @model.built_in_shapes.contains(@model.canonical_shape(short)),
      )
    }
  }
  let source = "flowchart\nA@{ shape: image, img: 'https://example.com/a.svg' }\nB@{ shape: icon, icon: 'fas:house' }"
  let ast = @syntax.read(source).ast.unwrap()
  assert_eq(@syntax.read(@printer.print(ast).output.unwrap()).ast, Some(ast))
  let model = @conversion.to_flowchart(ast).flowchart.unwrap()
  assert_eq(model.nodes[0].shape, "image")
  assert_eq(model.nodes[1].shape, "icon")
}

///|
test "each pinned upstream refusal has an explicit syntax or conversion error" {
  let refusals = array(field(@json.parse(@corpus.reference), "refusals"))
  assert_eq(refusals.length(), 3)
  for fixture in refusals {
    let source = string(field(fixture, "input"))
    let result = @syntax.read(source)
    assert_eq(result.tree.text(), source)
    if result.diagnostics.iter().any(d => d.severity == Error) {
      continue
    }
    let converted = @conversion.to_flowchart(result.ast.unwrap())
    assert_eq(converted.flowchart, None)
    assert_true(converted.diagnostics.iter().any(d => d.severity == Error))
  }
}

///|
test "read and print AST budgets are separate from normalized expansion budgets" {
  let source = "flowchart\nA --> B --> C"
  let parsed = @syntax.read(source, limits=@shared.Limits::new(nodes=2))
  assert_eq(parsed.tree.text(), source)
  assert_eq(parsed.ast, None)
  assert_eq(parsed.diagnostics[0].code, "flowchart/node-limit")
  let parsed = @syntax.read(source, limits=@shared.Limits::new(edges=1))
  assert_eq(parsed.ast, None)
  assert_eq(parsed.diagnostics[0].code, "flowchart/edge-limit")
  let ast = @syntax.read(source).ast.unwrap()
  let printed = @printer.print(ast, limits=@shared.Limits::new(nodes=2))
  assert_eq(printed.output, None)
  assert_eq(printed.diagnostics[0].code, "flowchart/node-limit")
  let printed = @printer.print(ast, limits=@shared.Limits::new(edges=1))
  assert_eq(printed.output, None)
  assert_eq(printed.diagnostics[0].code, "flowchart/edge-limit")
  let groups = "flowchart\nsubgraph A\nB\nend"
  assert_eq(@syntax.read(groups, limits=@shared.Limits::new(nodes=1)).ast, None)
  let grouped = @syntax.read(
    "flowchart\nA & B --> C & D",
    limits=@shared.Limits::new(edges=1),
  ).ast.unwrap()
  assert_eq(
    @printer.print(grouped, limits=@shared.Limits::new(edges=1)).diagnostics,
    [],
  )
  assert_eq(
    @conversion.to_flowchart(grouped, limits=@shared.Limits::new(edges=1)).flowchart,
    None,
  )
}

///|
test "structural nesting and metadata nesting have independent limits" {
  let ast = @syntax.read("flowchart\nsubgraph A\nsubgraph B\nC\nend\nend", limits=@shared.Limits::new(depth=256,metadata_depth=1)).ast.unwrap()
  let converted = @conversion.to_flowchart(ast, limits=@shared.Limits::new(depth=256,metadata_depth=1))
  assert_true(converted.flowchart is Some(_))
  assert_eq(converted.diagnostics, [])
  assert_eq(@conversion.to_flowchart(ast, limits=@shared.Limits::new(depth=1,metadata_depth=256)).flowchart,None)
}
