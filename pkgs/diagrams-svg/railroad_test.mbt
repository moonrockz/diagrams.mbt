///|
fn literal_model(text : String) -> @regex.Regex {
  @regex.Regex::new("r", "p", [@regex.Node::new("p", Literal(text))])
}

///|
test "railroad output limits and forbidden characters give no partial SVG" {
  let small = @svg.render_regex(
    literal_model("abc"),
    limits=@railroad_layout.Limits::new(output_units=200),
  )
  assert_true(small.output is None)
  assert_eq(small.diagnostics[0].code, "railroad/render-limit")
  let control = @svg.render_regex(literal_model("a\u{1}b"))
  assert_true(control.output is None)
  assert_eq(control.diagnostics[0].code, "railroad/invalid-xml-character")
}

///|
test "hostile labels stay text" {
  let svg = @svg.render_regex(literal_model("<script>alert(1)</script>&")).output.unwrap()
  assert_false(svg.contains("<script>"))
  assert_true(svg.contains("&lt;script&gt;"))
}

///|
test "adaptive and fixed railroads share geometry" {
  let model = literal_model("abc")
  let adaptive = @svg.render_regex(model, id_prefix="p").output.unwrap()
  let dark = @svg.render_regex(model, mode=Fixed(Dark), id_prefix="p").output.unwrap()
  let d = (svg : String) => {
    svg
    .split("d=\"")
    .drop(1)
    .map(s => s.split("\"").next().unwrap().to_owned())
    .collect()
  }
  assert_eq(d(adaptive), d(dark))
  assert_true(adaptive.contains("prefers-color-scheme"))
  assert_false(dark.contains("<style"))
}
