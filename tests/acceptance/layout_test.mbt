///|
test "all 38 corpus layouts pass every legibility rule in both classic palettes" {
  let theme = @theme.Theme::classic()
  for example in @corpus.mermaid_12_2_0 {
    let model = @mermaid.to_sequence(@mermaid.read(example.source).ast.unwrap()).sequence
    let geometry = @layout.layout(model)
    for (name, palette) in [("dark", theme.dark), ("light", theme.light)] {
      let findings = @layout.check(geometry, palette)
      assert_eq(findings, [], msg="example \{example.name} \{name}: \{findings.map(f => f.message).join("; ")}")
    }
  }
}

///|
test "destruction stays on a reply row across activation shorthand" {
  let read = @mermaid.read("sequenceDiagram\nparticipant A\nparticipant B\nactivate B\ndestroy B\nB-->>-A: done\nA->>A: after\n")
  assert_eq(read.diagnostics.length(), 0)
  let converted = @mermaid.to_sequence(read.ast.unwrap())
  assert_eq(converted.diagnostics.length(), 0)
  let g = @layout.layout(converted.sequence)
  let b = g.participants[1]
  assert_true(b.destroyed)
  assert_eq(b.lifeline_bottom, g.messages[0].y)
  assert_eq(g.activations[0].box.y + g.activations[0].box.height, g.messages[0].y)
  assert_true(b.lifeline_bottom < g.messages[1].y)
  let theme = @theme.Theme::classic()
  assert_eq(@layout.check(g, theme.dark), [])
  assert_eq(@layout.check(g, theme.light), [])
}
