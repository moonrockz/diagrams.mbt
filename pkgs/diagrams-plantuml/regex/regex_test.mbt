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
  assert_eq(
    labels.join(" "),
    "p.0=ab p.2.0.0=cd p.2.0=group p.2=* p.3=.e p=sequence",
  )
}

///|
test "native refusals and library refusals are errors" {
  for
    pattern in [
      "a{x}", "a|", "(ab", "ab)", "a{2,4}?", "[abc", "[]a]", "(?i)a", "\\x41", "a{99999999999}",
      "a()b", "*a",
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

///|
test "one read reports the errors of two pattern lines with exact spans" {
  let source = "@startregex\r\n\u{1F600}a{x}\r\nb(c\r\n@endregex\r\n"
  let result = read_source(source)
  assert_true(result.document is None)
  let codes = result.diagnostics.iter().map(d => d.code).collect()
  assert_eq(codes, [
    "regex/multiple-patterns", "regex/bad-quantifier", "regex/unclosed-group",
  ])
  // The quantifier starts after the two UTF-16 units of the emoji and `a`.
  let bad = result.diagnostics[1].span.unwrap()
  assert_eq((bad.start.line, bad.start.column, bad.start.offset), (2, 4, 16))
  assert_eq(bad.end.offset, 19)
  let open = result.diagnostics[2].span.unwrap()
  assert_eq((open.start.line, open.start.column), (3, 2))
}

///|
test "limits stop reading and writing without partial output" {
  let deep = "(".repeat(300) + "a" + ")".repeat(300)
  let read = @regex.read(
    @envelope.scan("@startregex\n" + deep + "\n@endregex"),
    limits=@envelope.Limits::new(depth=64),
  )
  assert_true(read.document is None)
  assert_eq(read.diagnostics[0].code, "regex/limit")
  let doc = read_source("@startregex\nabcdef\n@endregex").document.unwrap()
  let printed = @regex.print_pattern(
    doc.pattern,
    limits=@envelope.Limits::new(output=3),
  )
  assert_eq(printed.unwrap_err()[0].code, "regex/limit")
  let source = @envelope.scan(
    "@startregex\nabc\n@endregex",
    limits=@envelope.Limits::new(source=5),
  )
  assert_eq(source.diagnostics[0].code, "plantuml/source-limit")
}

///|
test "an edited literal is written and reads back" {
  let doc = read_source("@startregex\nab|c\n@endregex").document.unwrap()
  guard doc.pattern is Alt(items) else { fail("alt") }
  let edited = @regex.Document::new(
    Alt([items[0], Char("*", true, None)]),
    name?=doc.name,
  )
  let text = @regex.print_pattern(edited.pattern).unwrap()
  assert_eq(text, "ab|\\*")
  let back = read_source("@startregex\n" + text + "\n@endregex").document.unwrap()
  assert_true(back.logical_equal(edited))
  // A value that the syntax cannot express gives a diagnostic, not stale text.
  let bad = @regex.print_pattern(
    Concat([
      Char("a", false, None),
      Alt([Char("b", false, None), Char("c", false, None)]),
    ]),
  )
  assert_eq(bad.unwrap_err()[0].code, "regex/unrepresentable")
}

///|
test "flat sequences and wide alternations do not count as nesting" {
  let long = "a".repeat(400)
  assert_true(read_source("@startregex\n" + long + "\n@endregex").document is Some(_))
  let wide = Array::makei(400, i => "x\{i}").join("|")
  assert_true(read_source("@startregex\n" + wide + "\n@endregex").document is Some(_))
}
