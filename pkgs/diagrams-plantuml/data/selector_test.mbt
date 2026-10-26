///|
test "selectors keep quoted separators, wildcards and occurrences" {
  let selector = @data.parse_selector(
    "  #highlight \"a/b\" / * / ** / \"x\\\"y\"#2 / plain name <<warn>>",
  ).unwrap()
  assert_eq(selector.segments.iter().collect(), [
    @data.Segment::Name("a/b"),
    Any,
    Deep,
    Occurrence("x\"y", 2),
    Name("plain name"),
  ])
  assert_eq(selector.stereotype, Some("warn"))
  let line = selector.to_line()
  assert_eq(
    line, "#highlight \"a/b\" / * / ** / \"x\\\"y\"#2 / \"plain name\" <<warn>>",
  )
  assert_true(@data.parse_selector(line).unwrap().logical_equal(selector))
}

///|
test "quoted stars are wildcards unless escaped" {
  let wild = @data.parse_selector("#highlight \"*\" / \"**\"").unwrap()
  assert_eq(wild.segments.iter().collect(), [@data.Segment::Any, Deep])
  let literal = @data.parse_selector("#highlight \"\\*\" / \"\\*\\*\"").unwrap()
  assert_eq(literal.segments.iter().collect(), [
    @data.Segment::Name("*"),
    Name("**"),
  ])
  assert_true(
    @data.parse_selector(literal.to_line()).unwrap().logical_equal(literal),
  )
}

///|
test "malformed selectors are errors" {
  for
    text in [
      "#highlight ", "#highlight a <b", "#highlight \"a", "#highlight a / / b", "#highlight <<s>>",
      "#highlight \"a\" x", "#highlight \"a\"#0",
    ] {
    assert_true(@data.parse_selector(text) is Err(_), msg=text)
  }
}

///|
test "path identities do not use names" {
  assert_eq(@data.value_id([]), "v")
  assert_eq(@data.value_id([0, 2]), "v/0/2")
  assert_eq(@data.member_id([0, 2]), "m/0/2")
}
