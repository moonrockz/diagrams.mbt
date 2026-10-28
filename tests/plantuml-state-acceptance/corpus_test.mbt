///|
test "frozen state sources preserve source, accepted topology and canonical edits" {
  for (name, source, reference) in @corpus.fixtures {
    let result = @plantuml.read(source)
    assert_eq(result.tree.text(), source)
    if result.diagnostics.iter().any(d => d.severity == Error) {
      assert_true(
        ["docs/32.puml", "docs/36.puml", "docs/40.puml"].contains(name),
        msg=name +
          ": " +
          result.diagnostics.iter().map(d => d.message).to_array().join("; "),
      )
      continue
    }
    guard result.document is Some(document) else { fail(name) }
    let converted = @plantuml.to_diagram(document)
    let expected = @json.parse(reference) catch { _ => fail(name) }
    if field(expected, "status") == Json("refused") {
      assert_eq(converted.diagram, None, msg=name)
      continue
    }
    assert_true(converted.diagram != None, msg=name)
    let output = @plantuml.print(document)
    assert_true(
      output.output != None,
      msg=name +
        output.diagnostics.iter().map(d => d.message).to_array().join("; "),
    )
    if !name.has_prefix("canonical/") {
      let canonical = @corpus.fixtures
        .iter()
        .find_first(f => f.0 == "canonical/" + name)
      assert_true(
        canonical != None,
        msg=name + " missing canonical qualification",
      )
      assert_eq(
        output.output.unwrap(),
        canonical.unwrap().1,
        msg=name + " stale canonical fixture",
      )
    }
    let reread = @plantuml.read(output.output.unwrap())
    assert_true(
      !reread.diagnostics.iter().any(d => d.severity == Error),
      msg=name,
    )
    assert_eq(@plantuml.print(reread.document.unwrap()).output, output.output)
  }
}

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
    String(text) => text
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
fn expected_role(value : Json) -> @model.Role {
  if string(field(value, "stereotype")).contains("sdlreceive") {
    return Unsupported("sdlreceive")
  }
  match string(field(value, "position")) {
    "ENTRY_POINT" => EntryPoint
    "EXIT_POINT" => ExitPoint
    "INPUT_PIN" => InputPin
    "OUTPUT_PIN" => OutputPin
    "EXPANSION_INPUT" => ExpansionInput
    "EXPANSION_OUTPUT" => ExpansionOutput
    _ =>
      match string(field(value, "role")) {
        "CIRCLE_START" => Initial
        "CIRCLE_END" => Final
        "STATE_CHOICE" => Choice
        "STATE_FORK_JOIN" => Fork
        "PSEUDO_STATE" => ShallowHistory
        "DEEP_HISTORY" => DeepHistory
        "STATE_SDL_RECEIVE" => Unsupported("sdlreceive")
        _ =>
          if field(value, "group") == Json(true) {
            Composite
          } else {
            Simple
          }
      }
  }
}

///|
test "independent pinned entity ownership roles and ordered transition endpoints" {
  for (name, source, reference) in @corpus.fixtures {
    if ["docs/32.puml", "docs/36.puml", "docs/40.puml"].contains(name) {
      continue
    }
    let expected = @json.parse(reference) catch { _ => fail(name) }
    if field(expected, "status") == Json("refused") {
      continue
    }
    let result = @plantuml.read(source)
    guard result.document is Some(State(document)) else { fail(name) }
    let converted = @syntax.to_state(document)
    guard converted.state is Some(model) else { fail(name) }
    let entities = entries(field(expected, "entities"))
    for entity in entities {
      let role = string(field(entity, "role"))
      if role == "NOTE" || role == "CONCURRENT_STATE" {
        continue
      }
      let id = string(field(entity, "id"))
      let matches = model.states.filter(s => s.id == id)
      assert_eq(matches.length(), 1, msg=name + " missing " + id)
      let state = matches[0]
      let actual_role = if state.role == Join {
        @model.Role::Fork
      } else {
        state.role
      }
      assert_eq(actual_role, expected_role(entity), msg=name + " role " + id)
      assert_eq(
        state.label,
        string(field(entity, "label")),
        msg=name + " label " + id,
      )
      assert_eq(
        state.descriptions.iter().to_array(),
        entries(field(entity, "descriptions")).map(v => string(v)),
        msg=name + " descriptions " + id,
      )
      let owner_region = model.regions
        .iter()
        .find_first(r => r.id == state.region)
        .unwrap()
      let parent = if owner_region.owner == None {
        "root"
      } else {
        owner_region.id.split("::region0").next().unwrap().to_owned()
      }
      assert_eq(
        parent,
        string(field(entity, "parent")),
        msg=name + " parent " + id,
      )
    }
    let links = entries(field(expected, "links")).filter(link => {
      let a = string(field(link, "source"))
      let b = string(field(link, "target"))
      !entities.any(e => {
        string(field(e, "role")) == "NOTE" &&
        (string(field(e, "id")) == a || string(field(e, "id")) == b)
      })
    })
    assert_eq(
      links.length(),
      model.transitions.length(),
      msg=name + " link count",
    )
    for i, link in links {
      let edge = model.transitions[i]
      assert_eq(
        edge.source,
        string(field(link, "source")),
        msg=name + " source " + i.to_string(),
      )
      assert_eq(
        edge.target,
        string(field(link, "target")),
        msg=name + " target " + i.to_string(),
      )
      assert_eq(
        edge.label,
        string(field(link, "label")),
        msg=name + " label " + i.to_string(),
      )
      if name.contains("arrow-direction-") {
        let hint : @flowchart.Direction? = match
          string(field(link, "rank_direction")) {
          "RL" => Some(RL)
          "LR" => Some(LR)
          "BT" => Some(BT)
          "TB" => Some(TB)
          _ => None
        }
        assert_eq(edge.direction_hint, hint, msg=name + " pinned direction")
        assert_true(
          string(field(link, "line_style")).has_prefix("DASHED"),
          msg=name,
        )
        assert_eq(edge.style, Dotted, msg=name + " pinned style")
      }
    }
  }
}

///|
test "every supported pinned state source has legible light and dark geometry" {
  let failures : Array[String] = []
  for (name, source, reference) in @corpus.fixtures {
    let expected = @json.parse(reference) catch { _ => fail(name) }
    if field(expected, "status") == Json("refused") {
      continue
    }
    let read = @plantuml.read(source)
    if read.diagnostics.iter().any(d => d.severity == Error) {
      continue
    }
    guard read.document is Some(State(document)) else { fail(name) }
    let converted = @syntax.to_state(document)
    guard converted.state is Some(model) else { fail(name) }
    if model.states.any(s => {
        match s.role {
          Unsupported(_) => true
          _ => false
        }
      }) {
      let result = @layout.layout(model)
      assert_true(
        result.geometry == None &&
        result.diagnostics.any(d => d.code == "state/unsupported-role"),
        msg=name,
      )
      continue
    }
    let layout = @layout.layout(model)
    guard layout.geometry is Some(geometry) else {
      failures.push(
        name + " layout: " + layout.diagnostics.map(d => d.message).join("; "),
      )
      continue
    }
    for
      (palette, mode) in [
        (@theme.Theme::classic().light, @svg.Mode::Fixed(Light)),
        (@theme.Theme::classic().dark, @svg.Mode::Fixed(Dark)),
      ] {
      let findings = @layout.check(geometry, palette)
      if !findings.is_empty() {
        failures.push(
          name + " check: " + findings.map(d => d.message).join("; "),
        )
      }
      let svg = @svg.render_state(model, mode~)
      if svg.output == None {
        failures.push(
          name + " SVG: " + svg.diagnostics.map(d => d.message).join("; "),
        )
      }
    }
  }
  assert_true(failures.is_empty(), msg=failures.join("\n"))
}

///|
test "state dispatch explicit body recovery UTF16 edits and limits" {
  for
    source in [
      "@startuml\nA --> B\n@enduml\n", "@startuml\nclass Example\n@enduml\n", "@startuml\nAlice -> Bob : state Hidden\n@enduml\n",
      "@startuml\n' state Hidden\nnote right\nstate Hidden\nend note\nA --> B\n@enduml\n",
      "@startuml\nstate A\nstart\n:activity;\n@enduml\n", "@startuml\nstate A\n@endjson\n",
      "@startuml\nstate A\n@enduml\n@startuml\nstate B\n@enduml\n", "@startuml\nstate A\n@enduml\nstate B\n",
    ] {
    let result = @plantuml.read(source)
    assert_true(result.diagnostics.any(d => d.severity == Error))
    assert_eq(result.tree.text(), source)
  }
  let malformed = @plantuml.read_body(State, "A --> ???\n")
  assert_true(malformed.diagnostics.any(d => d.severity == Error))
  let body = @plantuml.read_body(State, "A --> B\n")
  assert_true(!body.diagnostics.any(d => d.severity == Error))
  assert_true(body.document is Some(State(_)))
  let source = "@startuml\r\nstate \"😀\" as A\r\nA ??? B\r\nstate B\r\n@enduml\r\n"
  let recovered = @plantuml.read(source)
  assert_eq(recovered.tree.text(), source)
  guard recovered.document is Some(State(document)) else {
    fail("expected recovery AST")
  }
  assert_true(document.items.any(s => s.kind is Declaration("B", _, _, _)))
  assert_false(document.complete)
  assert_eq(@plantuml.to_diagram(recovered.document.unwrap()).diagram, None)
  let diagnostic = recovered.diagnostics
    .iter()
    .find_first(d => d.code == "state/syntax")
    .unwrap()
  let span = diagnostic.span.unwrap()
  assert_eq(span.start.line, 3)
  assert_eq(span.start.column, 1)
  assert_eq(source[span.start.offset:span.end.offset].to_owned(), "A ??? B")
  let original = @plantuml.read("@startuml\nstate A\nA --> B : old\n@enduml\n")
  guard original.document is Some(State(ast)) else { fail("expected AST") }
  let edited = @syntax.Document::new(
    ast.items.map(item => {
      @syntax.Statement::new(
        match item.kind {
          Transition(a, arrow, b, _) => Transition(a, arrow, b, "edited 😀")
          other => other
        },
      )
    })[:],
  )
  let printed = @plantuml.print(State(edited)).output.unwrap()
  assert_true(printed.contains("edited 😀"))
  assert_eq(
    @plantuml.print(@plantuml.read(printed).document.unwrap()).output,
    Some(printed),
  )
  let invalid = @syntax.Document::new([
    @syntax.Statement::new(Transition("A\ninjected", "-->", "B", "")),
  ])
  assert_eq(@plantuml.print(State(invalid)).output, None)
  for
    limits in [
      @envelope.Limits::new(source=1),
      @envelope.Limits::new(nodes=1),
      @envelope.Limits::new(regions=1),
      @envelope.Limits::new(edges=1),
      @envelope.Limits::new(depth=1),
      @envelope.Limits::new(work=1),
      @envelope.Limits::new(diagnostics=1),
      @envelope.Limits::new(source=0),
    ] {
    let read = @plantuml.read(
      "@startuml\nstate A <<choice>> {\nstate B {\nstate C\n}\n--\nstate D\n}\nA --> A\nA --> D\n@enduml\n",
      limits~,
    )
    assert_true(read.diagnostics.any(d => d.severity == Error))
  }
  assert_eq(
    @plantuml.print(
      original.document.unwrap(),
      limits=@envelope.Limits::new(output=1),
    ).output,
    None,
  )
  for
    directive in [
      "!include https://invalid.example/no", "!define RUN() evil", "!theme internet",
      "state B : <img:https://invalid.example/no>",
    ] {
    let read = @plantuml.read(
      "@startuml\nstate A\n" + directive + "\n@enduml\n",
    )
    assert_true(read.diagnostics.any(d => d.severity == Error))
  }
}

///|
test "generated identities avoid authored aliases and internal descriptions add no edges" {
  let result = @plantuml.read(
    "@startuml\nstate root\nroot : entry / descriptive\nroot : internal [guard] / action\nroot --> root : again\nroot --> root : other\n@enduml\n",
  )
  guard result.document is Some(State(document)) else { fail("state") }
  let model = @syntax.to_state(document).state.unwrap()
  assert_eq(model.states.length(), 1)
  assert_eq(model.states[0].id, "root")
  assert_eq(model.states[0].descriptions.length(), 2)
  assert_eq(model.transitions.length(), 2)
  assert_true(model.transitions[0].id != model.transitions[1].id)
  assert_eq(@model.validate(model), [])
}

///|
test "qualified parent expansion and name resolution charge budgets before expansion" {
  let source = "state A.B.C.D.E.F.G.H.I.J\n"
  let read = @plantuml.read_body(State, source)
  guard read.document is Some(State(ast)) else { fail("state") }
  let limits = @envelope.Limits::new(depth=3)
  let converted = @syntax.to_state(ast, limits~)
  assert_eq(converted.state, None)
  assert_true(converted.diagnostics.any(d => d.code == "state/limit"))
  let items = []
  for n = 0; n < 30; n = n + 1 {
    items.push(
      @syntax.Statement::new(
        Declaration("S" + n.to_string(), "S" + n.to_string(), "", false),
      ),
    )
  }
  for n = 0; n < 20; n = n + 1 {
    items.push(
      @syntax.Statement::new(
        Transition(
          "Missing" + n.to_string(),
          "-->",
          "Other" + n.to_string(),
          "",
        ),
      ),
    )
  }
  let value = @syntax.Document::new(items[:])
  let converted = @syntax.to_state(
    value,
    limits=@envelope.Limits::new(work=5000),
  )
  assert_eq(converted.state, None)
  assert_true(converted.diagnostics.any(d => d.code == "state/limit"))
}

///|
test "cross-composite lookup retains an earlier implicit child's identity" {
  let source = "@startuml\nstate A {\n[*] --> X\n}\nX --> Y\n@enduml\n"
  guard @plantuml.read(source).document is Some(State(document)) else {
    fail("state")
  }
  let model = @syntax.to_state(document).state.unwrap()
  assert_eq(model.transitions[0].target, "A.X")
  assert_eq(model.transitions[1].source, "A.X")
  assert_eq(@model.validate(model), [])
}

///|
test "compact state arrows retain qualified targets and pinned abbreviated directions" {
  let source = "@startuml\nstate A\nstate B {\nstate C\n}\nA-->B.C : compact\nB.C<--A : reverse compact\n@enduml\n"
  let read = @plantuml.read(source)
  assert_false(read.diagnostics.any(d => d.severity == Error))
  guard read.document is Some(State(document)) else { fail("state") }
  let compact = document.items.filter_map(item => {
    match item.kind {
      Transition(a, arrow, b, label) => Some((a, arrow, b, label))
      _ => None
    }
  })
  assert_eq(compact[0], ("A", "-->", "B.C", "compact"))
  assert_eq(compact[1], ("B.C", "<--", "A", "reverse compact"))
  let converted = @syntax.to_state(document).state.unwrap()
  for edge in converted.transitions {
    assert_eq(edge.source, "A")
    assert_eq(edge.target, "B.C")
  }
  for
    (hint, direction) in [
      ("l", @flowchart.Direction::RL),
      ("le", RL),
      ("left", RL),
      ("r", LR),
      ("ri", LR),
      ("right", LR),
      ("u", BT),
      ("up", BT),
      ("d", TB),
      ("do", TB),
      ("down", TB),
    ] {
    let source = "@startuml\nstate A\nstate B\nA -[#blue,dashed]" +
      hint +
      "-> B\n@enduml\n"
    guard @plantuml.read(source).document is Some(State(document)) else {
      fail(hint)
    }
    let model = @syntax.to_state(document).state.unwrap()
    assert_eq(model.transitions[0].direction_hint, Some(direction), msg=hint)
    assert_eq(model.transitions[0].source, "A", msg=hint)
    assert_eq(model.transitions[0].target, "B", msg=hint)
    assert_eq(model.transitions[0].style, Dotted, msg=hint)
  }
}

///|
test "single-letter state direction is retained without reading color as direction" {
  let read = @plantuml.read(
    "@startuml\nstate A\nstate B\nA -[#red,dashed]u-> B\n@enduml\n",
  )
  guard read.document is Some(State(document)) else { fail("state") }
  let model = @syntax.to_state(document).state.unwrap()
  assert_eq(model.transitions[0].direction_hint, Some(@flowchart.Direction::BT))
}
