///|
fn project(sequence : @model.Sequence) -> Json {
  let messages = []
  fn walk(events : ReadOnlyArray[@model.Event]) {
    for event in events {
      match event {
        Message(message) =>
          messages.push({
            "from": Json(message.sender),
            "to": Json(message.receiver),
            "label": Json(message.label),
          })
        Frame(frame) =>
          for section in frame.sections {
            walk(section.events)
          }
        _ => ()
      }
    }
  }
  walk(sequence.events)
  {
    "participants": Json(
      sequence.participants.map(p => Json(p.id)).iter().to_array(),
    ),
    "messages": Json(messages),
  }
}

///|
test "every frozen documentation source reads converts and canonicalizes" {
  let canonical = []
  for (id, source, _) in oracle {
    let read = @syntax.read(source)
    assert_eq(read.tree.text(), source)
    assert_eq(read.diagnostics.length(), 0, msg=id)
    let ast = read.ast.unwrap()
    let result = convert(ast)
    assert_eq(result.diagnostics.length(), 0, msg=id + ": conversion")
    assert_true(result.sequence is Some(_), msg=id)
    let printed = @printer.print(ast).output.unwrap()
    let reread = @syntax.read(printed)
    assert_eq(reread.diagnostics.length(), 0, msg=id + ": reparse")
    assert_eq(reread.ast.unwrap(), ast, msg=id + ": equivalent AST")
    assert_eq(
      @printer.print(reread.ast.unwrap()).output,
      Some(printed),
      msg=id + ": stable print",
    )
    canonical.push(Json([Json(id), Json(printed)]))
  }
  let snapshot = @test.Test("canonical ZenUML corpus")
  snapshot.write(Json(canonical).stringify())
  snapshot.snapshot(filename="canonical.json")
}

///|
test "native conversion agrees with independent upstream participants and ordered messages" {
  for (_, source, expected) in oracle {
    let sequence = convert(@syntax.read(source).ast.unwrap()).sequence.unwrap()
    assert_eq(project(sequence), @json.parse(expected))
  }
}

///|
test "recover malformed UTF16 source and enforce depth budgets" {
  let source = "zenuml\r\n// 😀\r\nunsupported syntax here\r\nA->B: later\r\nA.call() {\r\n B->C: inner"
  let result = @syntax.read(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 2)
  assert_eq(result.diagnostics[0].span.unwrap().start.line, 3)
  assert_eq(result.diagnostics[1].code, "zenuml/missing-brace")
  assert_eq(result.ast.unwrap().statements.length(), 4)
  assert_eq(
    @syntax.read(
      "zenuml\nA.call() {\nB.call() {\n}\n}",
      limits=@syntax.Limits::new(depth=1),
    ).ast,
    None,
  )
  assert_eq(
    @syntax.read("zenuml\nA->B: text", limits=@syntax.Limits::new(source=2)).ast,
    None,
  )
  assert_eq(
    convert(@syntax.read("zenuml\nreturn value").ast.unwrap()).sequence,
    None,
  )
}

///|
test "typed edits expressions multiline metadata and explicit starters" {
  let source = "---\ntitle: metadata\n---\n%%{init: {\"theme\":\"forest\"}}%% zenuml\n@Starter(User)\n@Actor User as Person\nA.call(key=1,\n [1,2], \"a:b\") {\n return done\n}"
  let read = @syntax.read(source)
  assert_eq(read.diagnostics, [])
  assert_eq(read.tree.text(), source)
  let ast = read.ast.unwrap()
  let printed = @printer.print(ast).output.unwrap()
  assert_eq(@syntax.read(printed).ast, Some(ast))
  let conversion = convert(ast)
  assert_true(conversion.sequence is Some(_))
  assert_true(
    conversion.diagnostics
    .iter()
    .all(d => d.code == "zenuml/presentation-metadata"),
  )
  assert_eq(conversion.sequence.unwrap().participants[0].id, "User")
  assert_eq(
    conversion.sequence.unwrap().participants[0].kind,
    @model.ParticipantKind::Actor,
  )
  let statements = ast.statements.iter().to_array()
  for i, statement in statements {
    match statement.kind {
      Participant(id~, annotator~, ..) =>
        statements[i] = {
          ..statement,
          kind: Participant(id~, annotator~, label=Some("Edited person")),
        }
      Call(sender~, receiver~, assignment~, creation~, scope~, ..) =>
        statements[i] = {
          ..statement,
          kind: Call(
            sender~,
            receiver~,
            assignment~,
            creation~,
            scope~,
            operation="edited(42)",
          ),
        }
      _ => ()
    }
  }
  let edited = @ast.Diagram::new(statements)
  let text = @printer.print(edited).output.unwrap()
  assert_true(text.contains("Edited person"))
  assert_true(text.contains("edited(42)"))
  assert_eq(@syntax.read(text).ast, Some(edited))
}

///|
test "unknown annotators retain identity and bounded diagnostic failures suppress models" {
  let read = @syntax.read("zenuml\n@CustomThing A\nA->B: hello")
  let result = convert(read.ast.unwrap())
  assert_eq(result.diagnostics[0].code, "zenuml/unknown-annotator")
  assert_eq(
    result.sequence.unwrap().participants[0].icon,
    Some(@icons.Reference::new("zenuml", "customthing")),
  )
  assert_eq(
    @syntax.read("zenuml\nA\nB", limits=@syntax.Limits::new(participants=1)).ast,
    None,
  )
  assert_eq(
    @printer.print(read.ast.unwrap(), limits=@syntax.Limits::new(output=3)).output,
    None,
  )
  assert_eq(
    convert(read.ast.unwrap(), limits=@syntax.Limits::new(events=0)).sequence,
    None,
  )
}

///|
test "CRLF diagnostics use exact UTF16 token boundaries" {
  let source = "zenuml\r\n// 😀\r\n  broken tokens\r\nA->B: later\r\nA.call() {\r\nB->C: body"
  let result = @syntax.read(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics[0].span.unwrap().start.offset, 17)
  assert_eq(result.diagnostics[0].span.unwrap().start.line, 3)
  assert_eq(result.diagnostics[0].span.unwrap().start.column, 3)
  assert_eq(result.diagnostics[1].code, "zenuml/missing-brace")
  let limited = @syntax.read(
    "zenuml\nbad tokens\nmore tokens\nA->B: later",
    limits=@syntax.Limits::new(diagnostics=1),
  )
  assert_eq(limited.ast, None)
  assert_eq(limited.diagnostics[0].code, "zenuml/diagnostic-limit")
}

///|
test "parallel branches retain entire authored call scopes and attached comments" {
  let source = "zenuml\npar {\n// first branch\nA.method() {\n B.nested()\n return done\n}\nC.method() {\n if(ok) {\n C->D: yes\n }\n // section comment\n else {\n C->D: no\n }\n}\n}"
  let sequence = convert(@syntax.read(source).ast.unwrap()).sequence.unwrap()
  guard sequence.events[0] is Frame(frame) else {
    fail("parallel frame expected")
  }
  assert_eq(frame.kind, @model.FrameKind::Par)
  assert_eq(frame.sections.length(), 2)
  assert_true(frame.sections[0].events[0] is Note(_))
  assert_true(frame.sections[0].events[1] is Message(_))
  assert_true(frame.sections[0].events[2] is Activate("A"))
  assert_true(frame.sections[0].events.last() is Some(Deactivate("A")))
  assert_true(frame.sections[1].events[2] is Frame(_))
  assert_true(frame.sections[1].events.last() is Some(Deactivate("C")))
}

///|
test "malformed open expression recovers before later async statements" {
  let source = "zenuml\r\nA.broken(\r\nB->C: later\r\nC->D: after"
  let result = @syntax.read(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics[0].code, "zenuml/unclosed-expression")
  let statements = result.ast.unwrap().statements
  assert_true(
    statements.iter().any(s => s.kind is Async(sender="B", receiver="C", ..)),
  )
  assert_true(
    statements.iter().any(s => s.kind is Async(sender="C", receiver="D", ..)),
  )
}

///|
test "dangling annotators diagnose and annotation prefixes stay independent identities" {
  assert_true(
    @syntax.read("zenuml\n@Actor").diagnostics
    .iter()
    .any(d => d.code == "zenuml/identifier"),
  )
  assert_true(
    @syntax.read("zenuml\n@return").diagnostics
    .iter()
    .any(d => d.code == "zenuml/unsupported-statement"),
  )
  let source = "zenuml\n@ReturnService A\nA->B: hello"
  let parsed = @syntax.read(source)
  assert_eq(parsed.diagnostics, [])
  assert_eq(
    convert(parsed.ast.unwrap()).sequence.unwrap().participants[0].icon,
    Some(@icons.Reference::new("zenuml", "returnservice")),
  )
}

///|
test "BOM front matter and same-line Mermaid metadata preserve header dispatch" {
  let source = "\uFEFF---\r\ntitle: test\r\n---\r\n%%{init: {\"theme\":\"forest\"}}%% zenuml %% header comment\r\nA->B: text"
  let read = @syntax.read(source)
  assert_eq(read.tree.text(), source)
  assert_eq(read.diagnostics, [])
  assert_true(convert(read.ast.unwrap()).sequence is Some(_))
}
