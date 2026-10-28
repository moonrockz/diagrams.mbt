///|
fn source(body : String) -> String {
  "@startuml\n" + body + "\n@enduml\n"
}

///|
fn parsed(body : String) -> @activity.Document raise {
  let result = @activity.read(@envelope.scan(source(body)))
  assert_eq(result.diagnostics, [])
  result.document.unwrap()
}

///|
test "modern and legacy tracers reproduce print and convert" {
  for
    body in [
      "start\n:Read;\n:Read;\nstop", "(*) --> \"Read\" as R\nR --> \"Write\"\n--> (*)",
    ] {
    let input = source(body)
    let scan = @envelope.scan(input)
    let result = @activity.read(scan)
    assert_eq(scan.document(result.nodes[:]).text(), input)
    assert_eq(result.diagnostics, [])
    let ast = result.document.unwrap()
    let printed = @activity.print_body(ast).unwrap()
    let again = @activity.read(
      @envelope.scan_body(Activity, printed),
      dialect=ast.dialect,
    )
    assert_eq(again.diagnostics, [])
    assert_true(ast.logical_equal(again.document.unwrap()))
    assert_eq(@activity.print_body(again.document.unwrap()).unwrap(), printed)
    let converted = @activity.to_flowchart(ast)
    assert_eq(converted.diagnostics, [])
    let model = converted.flowchart.unwrap()
    assert_eq(model.nodes.length(), 4)
    assert_eq(model.connections.length(), 3)
    assert_true(model.nodes[1].id != model.nodes[2].id)
  }
}

///|
test "modern branches loops parallel paths and terminations are structural" {
  let ast = parsed(
    "start\nrepeat\nif (ready?) then (yes)\n:Read;\nelse (no)\n:Wait;\nbreak\nendif\nbackward:Again;\nrepeat while (more?) is (yes) not (no)\nfork\n:Save;\nfork again\n:Notify;\nend merge\nstop",
  )
  let converted = @activity.to_flowchart(ast)
  assert_eq(converted.diagnostics, [])
  let model = converted.flowchart.unwrap()
  assert_eq(model.regions.length(), 3)
  assert_true(model.connections.iter().any(e => e.role == LoopBack))
  assert_true(model.connections.iter().any(e => e.role == LoopExit))
  assert_true(model.nodes.iter().any(n => n.role == Merge))
  assert_true(model.nodes.iter().any(n => n.label == "Again"))
}

///|
test "wrong UML family and quoted note keywords do not select modern dialect" {
  let result = @activity.read(@envelope.scan(source("Alice -> Bob: start")))
  assert_eq(result.document, None)
  let ast = parsed(
    "(*) --> \"Action\"\nnote right\nstart fork if\nend note\n--> (*)",
  )
  assert_eq(ast.dialect, Legacy)
  let model = @activity.to_flowchart(ast).flowchart.unwrap()
  assert_eq(model.notes.length(), 1)
  assert_eq(model.connections.length(), 2)
}

///|
test "canonical text reflects typed edits" {
  let ast = parsed("start\n:Read;\nstop")
  let items = ast.items.iter().to_array()
  items[1] = @activity.Statement::new(Action("Changed", ";", ""))
  let edited = @activity.Document::new(Modern, items[:])
  let text = @activity.print_body(edited).unwrap()
  assert_true(text.contains(":Changed;"))
  assert_true(!text.contains(":Read;"))
}

///|
test "source recovery and processing limits return findings" {
  let input = source(
    "start\r\n:😀;\r\nif (ready?) then (yes)\r\nfrobnicate\r\n:Later;",
  )
  let scan = @envelope.scan(input)
  let result = @activity.read(scan)
  assert_eq(scan.document(result.nodes[:]).text(), input)
  assert_true(result.diagnostics.iter().any(d => d.code == "activity/syntax"))
  assert_true(
    result.diagnostics.iter().any(d => d.code == "activity/unclosed-control"),
  )
  assert_true(
    result.document.unwrap().items
    .iter()
    .any(s => s.kind == Action("Later", ";", "")),
  )
  let result = @activity.read(
    @envelope.scan(source("start\n:Read;\nstop")),
    limits=@envelope.Limits::new(nodes=1),
  )
  assert_true(result.diagnostics.iter().any(d => d.code == "activity/limit"))
  let ast = parsed("start\n:Read;\nstop")
  assert_eq(
    @activity.to_flowchart(ast, limits=@envelope.Limits::new(edges=1)).flowchart,
    None,
  )
  assert_true(
    @activity.print_body(ast, limits=@envelope.Limits::new(output=1)) is Err(_),
  )
}

///|
test "notes on links preserve connection identity without extra flow edges" {
  let ast = parsed(
    "start\n:Read;\nnote on link #blue: connector note\n:Write;\nstop",
  )
  let model = @activity.to_flowchart(ast).flowchart.unwrap()
  assert_eq(model.notes.length(), 1)
  assert_eq(model.notes[0].connection_targets, [model.connections[0].id])
  assert_eq(model.notes[0].targets, [])
  assert_eq(model.connections.length(), 3)
  let body = @activity.print_body(ast).unwrap()
  assert_true(body.contains("note on link #blue"))
}

///|
test "partition lanes source binding and directional hints stay separate" {
  let ast = parsed(
    "|A|\nstart\npartition Shared {\n:Read;\n|B|\n:Write;\n}\nstop",
  )
  let result = @activity.to_flowchart(ast)
  assert_eq(result.diagnostics, [])
  let model = result.flowchart.unwrap()
  assert_eq(model.groups.length(), 1)
  assert_eq(model.groups[0].lane, None)
  assert_eq(model.nodes[1].lane, Some("A"))
  assert_eq(model.nodes[2].lane, Some("B"))
  assert_true(model.nodes.iter().all(n => n.origin != None))
  let legacy = @activity.to_flowchart(
    parsed("(*) -up-> \"First\"\n-left-> \"Second\"\n--> (*)"),
  ).flowchart.unwrap()
  assert_eq(legacy.connections[0].direction_hint, Some(BT))
  assert_eq(legacy.connections[1].direction_hint, Some(RL))
  assert_eq(legacy.connections[0].source, legacy.nodes[0].id)
  assert_eq(legacy.connections[0].target, legacy.nodes[1].id)
}

///|
test "switch has exactly its declared branch connections" {
  let model = @activity.to_flowchart(
    parsed(
      "start\nswitch (kind?)\ncase (A)\n:First;\ncase (B)\n:Second;\nendswitch\nstop",
    ),
  ).flowchart.unwrap()
  let decision = model.nodes
    .iter()
    .filter(n => n.role == Decision)
    .next()
    .unwrap()
  let outgoing = model.connections
    .iter()
    .filter(e => e.source == decision.id)
    .to_array()
  assert_eq(outgoing.length(), 2)
  assert_eq(outgoing.map(e => e.label), ["A", "B"])
}

///|
test "note and action words do not become envelope metadata" {
  let body = "start\n:First line\ntitle is label data\nlast line;\nnote right\ntitle is note data\nend note\nstop"
  let scan = @envelope.scan(source(body))
  let result = @activity.read(scan)
  assert_eq(scan.statements, [])
  assert_eq(result.diagnostics, [])
  assert_true(
    result.document.unwrap().items
    .iter()
    .any(s => {
      s.kind == Action("First line\ntitle is label data\nlast line", ";", "")
    }),
  )
}

///|
test "region and branch condition values retain each authored expression" {
  let model = @activity.to_flowchart(
    parsed(
      "start\nif (first?) then (yes)\n:One;\nelseif (second?) then (yes)\n:Two;\nelse (no)\n:Other;\nendif\nrepeat\n:Read;\nbackward:Retry;\nrepeat while (more?) is (yes) not (no)\nstop",
    ),
  ).flowchart.unwrap()
  let conditional = model.regions
    .iter()
    .filter(r => r.kind == Conditional)
    .next()
    .unwrap()
  assert_eq(conditional.branches.map(b => b.condition), [
    Some("first?"),
    Some("second?"),
    None,
  ])
  let loop_region = model.regions
    .iter()
    .filter(r => r.kind == Loop)
    .next()
    .unwrap()
  assert_eq(loop_region.condition, Some("more?"))
  let backward = model.nodes
    .iter()
    .filter(n => n.label == "Retry")
    .next()
    .unwrap()
  assert_true(backward.regions.contains(loop_region.id))
  assert_true(loop_region.members.contains(backward.id))
}

///|
test "action semicolons hyperlinks and inert suffix presentation round trip" {
  let ast = parsed(
    "start\n:Read; write; <<continuous>> [[https://example.com/docs]]\nstop",
  )
  let body = @activity.print_body(ast).unwrap()
  assert_true(body.contains(":Read; write;"))
  let model = @activity.to_flowchart(ast).flowchart.unwrap()
  assert_eq(model.nodes[1].label, "Read; write")
  assert_eq(
    model.nodes[1].properties.unwrap().link,
    Some("https://example.com/docs"),
  )
}

///|
test "note content and aliases do not override header placement" {
  for placement in ["left", "right", "top", "bottom"] {
    let ast = parsed("start\n:Read;\nnote " + placement + ": Check the left top bottom right input\nstop")
    assert_true(ast.items.iter().any(s => s.kind == Note(placement, "Check the left top bottom right input", None, "")))
    let model = @activity.to_flowchart(ast).flowchart.unwrap()
    assert_eq(model.notes[0].placement, placement)
    let printed = @activity.print_body(ast).unwrap()
    assert_true(printed.contains("note " + placement))
  }
  let ast = parsed("start\n:Read;\nnote right as leftInput\nCheck bottom input\nend note\nstop")
  assert_true(ast.items.iter().any(s => s.kind == Note("right", "Check bottom input", Some("leftInput"), "")))
}
