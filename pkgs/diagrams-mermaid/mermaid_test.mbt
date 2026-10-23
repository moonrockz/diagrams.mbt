///|
let source = "sequenceDiagram\n  participant Client\n  Client->>API: GET /forecast\n"

///|
test "read gives the syntax tree, the AST and no diagnostics" {
  let r = @mermaid.read(source)
  assert_eq(r.tree.text(), source)
  assert_true(r.ast is Some(_))
  assert_eq(r.diagnostics.length(), 0)
}

///|
test "read reports syntax errors and keeps the good statements" {
  let r = @mermaid.read("sequenceDiagram\nA->>B: one\n?? bad\n")
  assert_eq(r.diagnostics.length(), 1)
  assert_eq(r.ast.unwrap().statements.length(), 1)
}

///|
test "print and read give the same AST" {
  let ast = @mermaid.read(source).ast.unwrap()
  assert_eq(@mermaid.read(@mermaid.print(ast)).ast, Some(ast))
}

///|
test "to_sequence gives the model" {
  let c = @mermaid.to_sequence(@mermaid.read(source).ast.unwrap())
  assert_eq(c.sequence.participants.length(), 2)
  assert_eq(c.sequence.events.length(), 1)
}

///|
test "render_svg renders a source as SVG" {
  let r = @mermaid.render_svg(source)
  assert_eq(r.media_type, "image/svg+xml")
  assert_eq(r.diagnostics.length(), 0)
  assert_true(r.output.unwrap().contains("GET /forecast"))
}

///|
test "render_svg gives the reader diagnostics and no output for a source without a header" {
  let r = @mermaid.render_svg("A->>B: hi\n")
  assert_eq(r.output, None)
  assert_eq(r.diagnostics.map(d => d.code).iter().to_array(), [
    "mermaid/missing-header",
  ])
}

///|
test "render_svg of an empty source says why it has no output" {
  let r = @mermaid.render_svg("")
  assert_eq(r.output, None)
  assert_eq(r.diagnostics.map(d => d.code).iter().to_array(), [
    "mermaid/missing-header",
  ])
}
