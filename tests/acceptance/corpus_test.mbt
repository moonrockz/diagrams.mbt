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

///|
test "each example lowers to an AST without diagnostics" {
  for e in @corpus.mermaid_12_2_0 {
    let r = @mermaid.read(e.source)
    assert_true(r.ast is Some(_), msg="example \{e.name}")
    assert_true(r.ast.unwrap().statements.length() > 0, msg="example \{e.name}")
  }
}

///|
test "each example obeys the read-print-read law, and printing is stable" {
  for e in @corpus.mermaid_12_2_0 {
    let ast = @mermaid.read(e.source).ast.unwrap()
    let text = @mermaid.print(ast)
    let again = @mermaid.read(text)
    assert_eq(again.diagnostics.length(), 0, msg="example \{e.name}: \{text}")
    assert_eq(again.ast, Some(ast), msg="example \{e.name}")
    assert_eq(@mermaid.print(again.ast.unwrap()), text, msg="example \{e.name}")
  }
}
