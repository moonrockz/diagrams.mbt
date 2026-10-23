///|
fn ast_of(source : String) -> @ast.Diagram {
  @ast.lower(@syntax.parse(source).tree).unwrap()
}

///|
test "the printer writes canonical Mermaid" {
  let d = ast_of("%% c\nsequenceDiagram\nparticipant  A\n actor B   as Bob\nA  ->>  B :hi there\n")
  assert_eq(
    @printer.print(d),
    "sequenceDiagram\n  participant A\n  actor B as Bob\n  A->>B: hi there\n",
  )
}

///|
test "reading the printed text gives the same AST, and printing again gives the same text" {
  let d = ast_of("sequenceDiagram\nactor C as Client\nC->>API: GET /forecast\nAPI->>C: 200\n")
  let text = @printer.print(d)
  let again = ast_of(text)
  assert_eq(again, d)
  assert_eq(@printer.print(again), text)
}
