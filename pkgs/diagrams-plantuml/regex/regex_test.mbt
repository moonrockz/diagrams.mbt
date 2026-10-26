///|
fn read_source(source : String) -> @regex.ReadResult {
  @regex.read(@envelope.scan(source))
}

///|
test "read, write and read a pattern with every construct" {
  let source = "@startregex\nab[c-e]*(?<year>\\d{4})(?!x)|^z+?$\n@endregex\n"
  let result = read_source(source)
  assert_eq(result.diagnostics.length(), 0)
  let doc = result.document.unwrap()
  let text = @regex.print_pattern(doc.pattern).unwrap()
  assert_eq(text, "ab[c-e]*(?<year>\\d{4})(?!x)|^z+?$")
  let again = read_source("@startregex\n" + text + "\n@endregex\n").document.unwrap()
  assert_true(again.logical_equal(doc))
}

///|
test "conversion merges adjacent characters and keeps identities" {
  let doc = read_source("@startregex\nab(cd)*\\.e\n@endregex").document.unwrap()
  let model = @regex.to_regex(doc).regex.unwrap()
  let labels = model.nodes.iter().map(n => n.id + "=" + n.label()).collect()
  assert_eq(labels.join(" "), "p.0=ab p.2.0.0=cd p.2.0=group p.2=* p.3=.e p=sequence")
}

///|
test "native refusals and library refusals are errors" {
  for
    pattern in [
      "a{x}", "a|", "(ab", "ab)", "a{2,4}?", "[abc", "[]a]", "(?i)a", "\\x41",
      "a{99999999999}", "a()b", "*a",
    ] {
    let result = read_source("@startregex\n" + pattern + "\n@endregex")
    assert_true(result.document is None, msg=pattern)
    assert_true(
      result.diagnostics.iter().any(d => d.severity == Error),
      msg=pattern,
    )
  }
}

///|
test "two pattern lines are an error" {
  let result = read_source("@startregex\nabc\nxyz\n@endregex")
  assert_true(result.document is None)
  assert_eq(result.diagnostics[0].code, "regex/multiple-patterns")
}

///|
test "large repeats stay symbolic" {
  let doc = read_source("@startregex\na{1000000}\n@endregex").document.unwrap()
  let model = @regex.to_regex(doc).regex.unwrap()
  assert_eq(model.nodes.length(), 2)
}

///|
test "lossless tree with unicode and CRLF" {
  let source = "\u{feff}@startregex\r\n' note\r\nh\u{e9}\u{1F600}+|x\r\n@endregex\r\n"
  let scan = @envelope.scan(source)
  let result = @regex.read(scan)
  assert_eq(scan.document(result.nodes).text(), source)
  assert_eq(result.diagnostics.length(), 0)
  let model = @regex.to_regex(result.document.unwrap()).regex.unwrap()
  assert_true(model.nodes.iter().any(n => n.kind == Literal("\u{1F600}")))
}
