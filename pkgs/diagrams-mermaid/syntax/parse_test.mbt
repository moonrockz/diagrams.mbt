///|
fn kinds(tree : @cst.Node) -> Array[@cst.NodeKind] {
  tree.nodes().map(n => n.kind)
}

///|
test "the syntax tree text equals the source" {
  let source = "sequenceDiagram\n  participant A\n  actor B as Bob\n  A->>B: hello\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds(result.tree), [Header, Participant, Participant, Message])
}

///|
test "the syntax tree keeps comments, blank lines and CRLF line endings" {
  let source = "%% top\r\nsequenceDiagram\r\n\r\n  %% note\r\n  A ->> B : hi  \r\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds(result.tree), [Comment, Header, Blank, Comment, Message])
}

///|
test "a source without a final newline reproduces exactly" {
  let source = "sequenceDiagram\nA->>B: hi"
  assert_eq(@syntax.parse(source).tree.text(), source)
}

///|
test "an unknown statement gives a diagnostic at its line" {
  let source = "sequenceDiagram\nA->>B: hi\nfrobnicate A\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 1)
  let d = result.diagnostics[0]
  assert_eq(d.code, "mermaid/unknown-statement")
  assert_eq(d.severity, @diagrams.Severity::Error)
  let span = d.span.unwrap()
  assert_eq(span.start, { offset: 26, line: 3, column: 1 })
  assert_eq(span.end, { offset: 38, line: 3, column: 13 })
}

///|
test "statements after a bad statement still parse" {
  let source = "sequenceDiagram\nA->>B: one\n?? bad\nA->>B: two\n!! bad\nA->>B: three\n"
  let result = @syntax.parse(source)
  assert_eq(result.diagnostics.length(), 2)
  assert_eq(kinds(result.tree), [Header, Message, Error, Message, Error, Message])
}

///|
test "a source without the header gives a diagnostic" {
  let result = @syntax.parse("A->>B: hi\n")
  assert_eq(result.diagnostics.map(d => d.code).iter().to_array(), [
    "mermaid/missing-header",
  ])
}

///|
test "a message has its sender, arrow, receiver and text tokens" {
  let tree = @syntax.parse("sequenceDiagram\nA->>B: hello there\n").tree
  let message = tree.nodes()[1]
  let significant = message
    .tokens()
    .filter(t => t.kind != Whitespace && t.kind != Newline)
    .map(t => (t.kind, t.text))
  assert_eq(significant, [
    (Identifier, "A"),
    (Arrow, "->>"),
    (Identifier, "B"),
    (Colon, ":"),
    (Text, "hello there"),
  ])
}

///|
test "an empty or comment-only source gives the missing-header diagnostic at its end" {
  for source in ["", "\n\n", "%% only a comment\n"] {
    let result = @syntax.parse(source)
    assert_eq(result.tree.text(), source)
    let codes = result.diagnostics.map(d => d.code).iter().to_array()
    assert_eq(codes, ["mermaid/missing-header"], msg="source: \{source}")
    assert_eq(result.diagnostics[0].span.unwrap().start.offset, source.length())
  }
}
