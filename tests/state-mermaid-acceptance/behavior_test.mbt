///|
test "typed edits drive canonical output and dispatch preserves old families" {
  let read = @mermaid.read_diagram(
    "stateDiagram-v2\nstate \"Equal\" as A\nstate \"Equal\" as B\nA --> B : old\n",
  )
  guard read.ast is Some(State(ast)) else { fail("state dispatch") }
  let statements = ast.statements
    .iter()
    .map(s => {
      match s.kind {
        Transition(source~, target~, source_classes~, target_classes~, ..) =>
          @ast.Statement::{
            kind: Transition(
              source~,
              target~,
              label=Some("edited [guard] / action"),
              source_classes~,
              target_classes~,
            ),
            span: s.span,
          }
        _ => s
      }
    })
    .to_array()
  let edited = @ast.Diagram::new(statements, header=ast.header)
  let output = @printer.print(edited).output.unwrap()
  assert_true(output.contains("edited [guard] / action"))
  assert_eq(
    @printer.print(@syntax.read(output).ast.unwrap()).output,
    Some(output),
  )
  let model = @conversion.to_state(@syntax.read(output).ast.unwrap()).state.unwrap()
  assert_eq(model.states.length(), 2)
  assert_eq(model.states[0].label, model.states[1].label)
  assert_true(model.states[0].id != model.states[1].id)
  assert_eq(model.transitions[0].label, "edited [guard] / action")
  for
    source in [
      "sequenceDiagram\nA->>B: hello\n", "flowchart LR\nA-->B\n", "swimlane-beta\nA --> B\n",
      "zenuml\nA.method()\n", "architecture-beta\nservice A(server)[A]\n",
    ] {
    assert_true(@mermaid.read_diagram(source).ast != None)
  }
}

///|
test "UTF16 CRLF diagnostics recover later valid statements without complete conversion" {
  let source = "stateDiagram-v2\r\nstate \"😀\" as A\r\nA -> B\r\nLater\r\n"
  let read = @syntax.read(source)
  assert_eq(read.tree.text(), source)
  let diagnostic = read.diagnostics
    .iter()
    .find_first(d => d.code == "state/syntax")
    .unwrap()
  let span = diagnostic.span.unwrap()
  assert_eq(span.start.line, 3)
  assert_eq(span.start.column, 1)
  assert_eq(source[span.start.offset:span.end.offset].to_owned(), "A -> B\r")
  let ast = read.ast.unwrap()
  assert_true(
    ast.statements
    .iter()
    .any(s => {
      match s.kind {
        State(id="Later", ..) => true
        _ => false
      }
    }),
  )
  assert_eq(@conversion.to_state(ast).state, None)
  assert_eq(@printer.print(ast).output, None)
}

///|
test "every explicit state processing budget distinguishes exhaustion" {
  let source = "stateDiagram-v2\nstate Outer {\nstate Inner {\nA --> B\n}\n--\nC --> D\n}\n"
  for
    (limits, code) in [
      (@syntax.Limits::new(source=1), "state/source-limit"),
      (@syntax.Limits::new(depth=1), "state/depth-limit"),
      (@syntax.Limits::new(states=1), "state/state-limit"),
      (@syntax.Limits::new(regions=1), "state/region-limit"),
      (@syntax.Limits::new(transitions=1), "state/transition-limit"),
      (@syntax.Limits::new(work=1), "state/work-limit"),
    ] {
    let read = @syntax.read(source, limits~)
    assert_eq(read.ast, None)
    assert_true(read.diagnostics.iter().any(d => d.code == code))
  }
  let ast = @syntax.read(source).ast.unwrap()
  assert_eq(
    @printer.print(ast, limits=@syntax.Limits::new(output=1)).output,
    None,
  )
  assert_eq(
    @conversion.to_state(ast, limits=@syntax.Limits::new(states=1)).state,
    None,
  )
  assert_eq(
    @conversion.to_state(ast, limits=@syntax.Limits::new(work=1)).state,
    None,
  )
  let errors = @syntax.read(
    "stateDiagram-v2\nA -> B\nC -> D\nLater\n",
    limits=@syntax.Limits::new(diagnostics=1),
  )
  assert_eq(errors.ast, None)
  assert_eq(errors.diagnostics.length(), 1)
  assert_eq(errors.diagnostics[0].code, "state/diagnostic-limit")
}

///|
test "scope ownership parallel transitions descriptions notes and direction preserve semantics" {
  let source = "stateDiagram-v2\ndirection RL\nstate Left {\n[*] --> Same\n}\nstate Right {\n[*] --> Same\nSame : entry / log\nSame : event [guard] / action\nnote left of Same : descriptive\n}\nSame --> Same : first\nSame --> Same : second\n"
  let model = @conversion.to_state(@syntax.read(source).ast.unwrap()).state.unwrap()
  assert_eq(model.direction, RL)
  assert_eq(model.states.iter().filter(s => s.role == Initial).count(), 2)
  let same = model.states.iter().find_first(s => s.id == "Same").unwrap()
  assert_eq(same.region, "Right::region-0")
  assert_eq(same.label, "entry / log")
  assert_eq(same.descriptions.length(), 1)
  assert_eq(model.transitions.length(), 4)
  assert_eq(model.transitions[2].source, "Same")
  assert_eq(model.transitions[2].target, "Same")
  assert_true(model.transitions[2].id != model.transitions[3].id)
  assert_eq(model.notes[0].targets, ["Same"])
}

///|
test "hostile labels stay literal and source options remain inert" {
  let source = "%%{init: {'theme':'dark'}}%%\nstateDiagram-v2\nstate \"<script>alert(1)</script>\" as A\nA --> B : <img src=x onerror=alert(1)>\nclassDef x fill:red\n"
  let read = @syntax.read(source)
  assert_eq(read.tree.text(), source)
  let converted = @conversion.to_state(read.ast.unwrap())
  let model = converted.state.unwrap()
  assert_eq(model.states[0].label, "<script>alert(1)</script>")
  assert_eq(model.transitions[0].label, "<img src=x onerror=alert(1)>")
  assert_true(
    converted.diagnostics
    .iter()
    .any(d => d.code == "state/unapplied-presentation"),
  )
}

///|
test "unrepresentable AST edits return no stale source" {
  let ast = @syntax.read("stateDiagram-v2\nA --> B\n").ast.unwrap()
  let invalid = @ast.Diagram::new([
    {
      kind: Transition(
        source="A",
        target="B\nInjected",
        label=None,
        source_classes=[],
        target_classes=[],
      ),
      span: ast.statements[0].span,
    },
  ])
  assert_eq(@printer.print(invalid).output, None)
  assert_eq(@conversion.to_state(invalid).state, None)
}

///|
test "metadata-like state IDs and quoted note text do not change source meaning" {
  let source = "stateDiagram-v2\naccTitleState : ordinary heading\naccDescrState : ordinary description\naccTitleState --> accDescrState\nnote right of accTitleState : Keep %% literal\n"
  let model = @conversion.to_state(@syntax.read(source).ast.unwrap()).state.unwrap()
  assert_eq(model.states[0].id, "accTitleState")
  assert_eq(model.states[0].label, "ordinary heading")
  assert_eq(model.accessibility_title, None)
  assert_eq(model.accessibility_description, None)
  assert_eq(model.notes[0].text, "Keep %% literal")
}
