///|
test "dispatch keeps a header after a same-line directive" {
  for
    (header, body) in [
      ("sequenceDiagram", "\nA->>B: handoff\n"),
      ("swimlane-beta LR", "\nA --> B\n"),
    ] {
    let source = "%%{init: {\"theme\": \"forest\"}}%% " + header + body
    let result = @mermaid.read_diagram(source)
    assert_eq(result.tree.text(), source)
    assert_eq(result.diagnostics.length(), 0)
    if header == "sequenceDiagram" {
      let legacy = @mermaid.read(source)
      assert_eq(legacy.diagnostics.length(), 0)
      assert_eq(
        result.ast,
        legacy.ast.map(ast => @mermaid.ParsedDiagram::Sequence(ast)),
      )
    } else {
      assert_true(result.ast is Some(@mermaid.ParsedDiagram::Swimlane(_)))
    }
    let rendered = @mermaid.render_svg(source)
    assert_true(
      rendered.diagnostics
      .iter()
      .all(d => d.code == "swimlane/presentation-metadata"),
    )
    assert_true(rendered.output != None)
  }
}

///|
test "dispatch keeps a header on a multiline directive closing line" {
  for
    (header, body) in [
      ("sequenceDiagram", "\nA->>B: handoff\n"),
      ("swimlane-beta LR", "\nA --> B\n"),
    ] {
    let source = "%%{init: {\r\n\"theme\": \"forest\"\r\n}}%%\t" + header + body
    let result = @mermaid.read_diagram(source)
    assert_eq(result.tree.text(), source)
    assert_eq(result.diagnostics.length(), 0)
    if header == "sequenceDiagram" {
      let legacy = @mermaid.read(source)
      assert_eq(legacy.diagnostics.length(), 0)
      assert_eq(
        result.ast,
        legacy.ast.map(ast => @mermaid.ParsedDiagram::Sequence(ast)),
      )
    } else {
      assert_true(result.ast is Some(@mermaid.ParsedDiagram::Swimlane(_)))
    }
    let rendered = @mermaid.render_svg(source)
    assert_true(
      rendered.diagnostics
      .iter()
      .all(d => d.code == "swimlane/presentation-metadata"),
    )
    assert_true(rendered.output != None)
  }
}

///|
test "dispatch resumes trivia scanning after consecutive directives" {
  let source = "---\nconfig:\n  theme: forest\n---\n%% a comment mentioning swimlane-beta\n%%{init: {}}%%%%{init: {}}%%\u{a0}swimlane-beta LR\nA --> B\n"
  let result = @mermaid.read_diagram(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.ast is Some(@mermaid.ParsedDiagram::Swimlane(_)))
}
