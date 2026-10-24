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
