///|
test "each Mermaid 12.2.0 example reproduces exactly and has no syntax diagnostics" {
  for e in @corpus.mermaid_12_2_0 {
    let r = @mermaid.read(e.source)
    assert_eq(r.tree.text(), e.source, msg="example \{e.name}")
    let found = r.diagnostics.map(d => "\{d.code} at line \{d.span.unwrap().start.line}")
    assert_eq(found.iter().to_array(), [], msg="example \{e.name}")
  }
}

///|
test "each example also reproduces with CRLF line endings" {
  for e in @corpus.mermaid_12_2_0 {
    let source = e.source.replace_all(old="\n", new="\r\n")
    let r = @mermaid.read(source)
    assert_eq(r.tree.text(), source, msg="example \{e.name}")
    assert_eq(r.diagnostics.length(), 0, msg="example \{e.name}")
  }
}
