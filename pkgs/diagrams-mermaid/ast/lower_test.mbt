///|
fn ast_of(source : String) -> @ast.Diagram? {
  @ast.lower(@syntax.parse(source).tree)
}

///|
/// The kind of the first statement of `body`.
fn one(body : String) -> @ast.StatementKind {
  ast_of("sequenceDiagram\n\{body}\n").unwrap().statements[0].kind
}

///|
test "participant statements keep their keyword, id, configuration and label" {
  guard one("participant A") is Participant(a) else { fail("participant") }
  assert_eq((a.created, a.keyword, a.id, a.config, a.label), (false, Participant, "A", None, None))
  guard one("actor B as Bob the builder") is Participant(b) else { fail("actor") }
  assert_eq((b.keyword, b.id, b.label), (Actor, "B", Some("Bob the builder")))
  guard one("participant API@{ \"type\": \"boundary\" } as Public API") is Participant(c) else {
    fail("config")
  }
  assert_eq((c.id, c.config, c.label), ("API", Some("\"type\": \"boundary\""), Some("Public API")))
  guard one("create actor D as Donald") is Participant(d) else { fail("create") }
  assert_eq((d.created, d.keyword, d.id), (true, Actor, "D"))
}

///|
test "destroy, activate and deactivate keep their participant" {
  assert_eq(one("destroy Carl"), Destroy("Carl"))
  assert_eq(one("activate John"), Activate("John"))
  assert_eq(one("deactivate John"), Deactivate("John"))
}

///|
test "a message keeps its sender, arrow, modifiers, receiver and text" {
  let d = ast_of("sequenceDiagram\n  A ->> B :  hello there  \n").unwrap()
  guard d.statements[0].kind is Message(m) else { fail("message") }
  assert_eq((m.sender, m.arrow, m.receiver, m.text), ("A", "->>", "B", "hello there"))
  assert_eq(d.statements[0].span.start.line, 2)
  assert_eq(d.statements[0].span.start.column, 3)
  guard one("A->>+B: x") is Message(p) else { fail("+") }
  assert_eq(p.activation, Some(@ast.Activation::Activate))
  guard one("B-->>-A: x") is Message(q) else { fail("-") }
  assert_eq((q.arrow, q.activation), ("-->>", Some(@ast.Activation::Deactivate)))
  guard one("John()->>()Alice: Great!") is Message(r) else { fail("()") }
  assert_eq((r.central_before, r.central_after, r.activation), (true, true, None))
  guard one("A-)B:") is Message(s) else { fail("empty") }
  assert_eq((s.arrow, s.text), ("-)", ""))
}

///|
test "notes keep their placement, participants and text" {
  assert_eq(
    one("Note right of John: Text in note"),
    Note({ placement: RightOf, participants: ["John"], text: "Text in note" }),
  )
  assert_eq(
    one("note over Alice,John: A typical interaction"),
    Note({ placement: Over, participants: ["Alice", "John"], text: "A typical interaction" }),
  )
  guard one("NOTE LEFT OF A: x") is Note(n) else { fail("left of") }
  assert_eq(n.placement, LeftOf)
}

///|
test "link statements keep their kind, participant and text" {
  assert_eq(
    one("link Alice: Dashboard @ https://dashboard.contoso.com/alice"),
    Link({ kind: Link, participant: "Alice", text: "Dashboard @ https://dashboard.contoso.com/alice" }),
  )
  guard one("links John: {\"Wiki\": \"https://wiki\"}") is Link(l) else { fail("links") }
  assert_eq((l.kind, l.text), (Links, "{\"Wiki\": \"https://wiki\"}"))
  guard one("properties A: {}") is Link(p) else { fail("properties") }
  assert_eq(p.kind, Properties)
  guard one("details A: {}") is Link(q) else { fail("details") }
  assert_eq(q.kind, Details)
}

///|
test "titles, accessibility text and autonumber" {
  assert_eq(one("title Login flow"), Title("Login flow"))
  assert_eq(one("title: Login flow"), Title("Login flow"))
  assert_eq(one("accTitle: The login"), AccTitle("The login"))
  assert_eq(one("accDescr: One line"), AccDescr("One line"))
  assert_eq(one("accDescr {\n  Line one\n  Line two\n}"), AccDescr("Line one\n  Line two"))
  assert_eq(one("autonumber"), Autonumber(On(start=None, step=None)))
  assert_eq(one("autonumber 10 5"), Autonumber(On(start=Some("10"), step=Some("5"))))
  assert_eq(one("autonumber off"), Autonumber(Off))
}

///|
test "frames keep their kind, sections and nested statements" {
  let source = "sequenceDiagram\nalt is sick\n  B->>A: no\nelse is well\n  loop daily\n    B->>A: yes\n  end\nend\n"
  guard ast_of(source).unwrap().statements[0].kind is Frame(alt) else { fail("alt") }
  assert_eq(alt.kind, Alt)
  assert_eq(alt.sections.map(s => s.label).iter().to_array(), ["is sick", "is well"])
  assert_eq(alt.sections[0].statements.length(), 1)
  guard alt.sections[1].statements[0].kind is Frame(lp) else { fail("loop") }
  assert_eq((lp.kind, lp.sections.length(), lp.sections[0].label), (Loop, 1, "daily"))
  for pair in [
    ("rect rgb(0, 0, 255)", @ast.FrameKind::Rect),
    ("opt x", Opt),
    ("par x", Par),
    ("par_over x", ParOver),
    ("critical x", Critical),
    ("break x", Break),
  ] {
    guard one("\{pair.0}\nA->>B: m\nend") is Frame(f) else { fail(pair.0) }
    assert_eq(f.kind, pair.1, msg=pair.0)
  }
}

///|
test "a frame without an end keeps the statements that follow it" {
  let d = ast_of("sequenceDiagram\nloop every minute\nA->>B: ping\nB->>A: pong\n").unwrap()
  assert_eq(d.statements.length(), 1)
  guard d.statements[0].kind is Frame(f) else { fail("loop") }
  assert_eq(f.sections[0].statements.length(), 2)
}

///|
test "a box keeps its label and participants" {
  guard one("box Purple Alice & John\nparticipant A\nparticipant J\nend") is Box(b) else {
    fail("box")
  }
  assert_eq(b.label, "Purple Alice & John")
  assert_eq(b.statements.length(), 2)
}

///|
test "front matter and directives are in the AST, comments are not" {
  let d = ast_of(
    "---\nconfig:\n  theme: dark\n---\n%%{init: {\"wrap\": true}}%%\nsequenceDiagram\n%% a comment\nA->>B: hi\n",
  ).unwrap()
  assert_eq(d.front_matter, Some("---\nconfig:\n  theme: dark\n---"))
  assert_eq(d.directives.iter().to_array(), ["%%{init: {\"wrap\": true}}%%"])
  assert_eq(d.statements.length(), 1)
}

///|
test "statements with errors are not in the AST" {
  let d = ast_of("sequenceDiagram\nA->>B: one\n?? bad\nA->>B: two\n").unwrap()
  assert_eq(d.statements.length(), 2)
}

///|
test "a source without the header has no AST" {
  assert_eq(ast_of("A->>B: hi\n"), None)
}

///|
test "AST equality does not compare source positions" {
  let a = ast_of("sequenceDiagram\nA->>B: hi\n")
  let b = ast_of("%% a comment\n\nsequenceDiagram\n    A->>B:hi\n")
  assert_eq(a, b)
}
