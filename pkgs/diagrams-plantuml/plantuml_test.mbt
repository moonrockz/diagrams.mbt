///|
test "render a regex" (t : @test.Test) {
  let regex = @plantuml.render_svg(
    "@startregex\ntitle Year\nab[c-e]*(?<year>\\d{4})(?!x)|^z+?$\n@endregex\n",
    renderer=@svg.SvgRenderer::new(mode=Fixed(Light)),
  )
  assert_eq(regex.diagnostics.length(), 0)
  t.write(regex.output.unwrap())
  t.snapshot(filename="regex-light.svg")
}

///|
test "render a grammar" (t : @test.Test) {
  let grammar = @plantuml.render_svg(
    "@startebnf\nexpr = term, { (\"+\" | \"-\"), term };\nterm = 3 * \"x\" | [ y ] | a - b;\n@endebnf\n",
    renderer=@svg.SvgRenderer::new(mode=Fixed(Dark)),
  )
  assert_true(grammar.diagnostics.iter().all(d => d.severity == Warning))
  t.write(grammar.output.unwrap())
  t.snapshot(filename="ebnf-dark.svg")
}
