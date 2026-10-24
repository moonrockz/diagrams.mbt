///|
/// The thin path of add-mermaid-sequence: Mermaid text to a model to SVG.
let source = "sequenceDiagram\n  participant Client\n  actor U as User\n  U->>Client: open the forecast\n  Client->>API: GET /forecast\n"

///|
test "the Mermaid source reproduces, prints canonically and converts" {
  let r = @mermaid.read(source)
  assert_eq(r.tree.text(), source)
  assert_eq(r.diagnostics.length(), 0)
  let ast = r.ast.unwrap()
  assert_eq(@mermaid.print(ast), source)
  let s = @mermaid.to_sequence(ast).sequence
  assert_eq(s.participants.map(p => p.id).iter().to_array(), ["Client", "U", "API"])
}

///|
test "the Mermaid source renders as the same SVG on every target" {
  let r = @mermaid.render_svg(source)
  assert_eq(r.diagnostics.length(), 0)
  let t = @test.Test("tracer")
  t.write(r.output.unwrap())
  t.snapshot(filename="tracer.svg")
}
