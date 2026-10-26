///|
test "per-kind dispatch limits are independent of legacy swimlane limits" {
  let empty_legacy = @swimlane_syntax.Limits::new(source=0)
  for
    source in [
      "zenuml\nA->B: notify\n", "architecture-beta\nservice node(server)[Node]\n",
    ] {
    let result = @mermaid.read_diagram(source, limits=empty_legacy)
    assert_true(result.ast is Some(_))
    assert_false(result.diagnostics.iter().any(d => d.severity == Error))
  }
  let result = @mermaid.read_diagram(
    "zenuml\nA->B: notify\n",
    zenuml_limits=@zenuml_syntax.Limits::new(source=4),
  )
  assert_eq(result.ast, None)
  assert_true(
    result.diagnostics.iter().any(d => d.code == "zenuml/source-limit"),
  )
  let result = @mermaid.read_diagram(
    "architecture-beta\nservice node(server)[Node]\n",
    architecture_limits=@architecture_syntax.Limits::new(source=4),
  )
  assert_eq(result.ast, None)
  assert_true(
    result.diagnostics.iter().any(d => d.code == "architecture/source-limit"),
  )
}
