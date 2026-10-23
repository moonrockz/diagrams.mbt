///|
fn ast_of(source : String) -> @ast.Diagram? {
  @ast.lower(@syntax.parse(source).tree)
}

///|
test "participant statements keep their keyword, id and label" {
  let d = ast_of("sequenceDiagram\nparticipant A\nactor B as Bob the builder\n").unwrap()
  guard d.statements[0] is Participant(a) else { fail("expected a participant") }
  assert_eq(a.keyword, @ast.ParticipantKeyword::Participant)
  assert_eq(a.id, "A")
  assert_eq(a.label, None)
  guard d.statements[1] is Participant(b) else { fail("expected a participant") }
  assert_eq(b.keyword, @ast.ParticipantKeyword::Actor)
  assert_eq(b.id, "B")
  assert_eq(b.label, Some("Bob the builder"))
}

///|
test "a message keeps its sender, arrow, receiver and text" {
  let d = ast_of("sequenceDiagram\n  A ->> B :  hello there  \n").unwrap()
  guard d.statements[0] is Message(m) else { fail("expected a message") }
  assert_eq((m.sender, m.arrow, m.receiver, m.text), ("A", "->>", "B", "hello there"))
  assert_eq(m.span.start.line, 2)
  assert_eq(m.span.start.column, 3)
}

///|
test "lines with errors are not in the AST" {
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
