///|
fn read_source(source : String) -> @ebnf.ReadResult {
  @ebnf.read(@envelope.scan(source))
}

///|
let grammar_source : String =
  #|@startebnf
  #|title Grammar
  #|(* A note *)
  #|expr = term, { ("+" | "-"), term };
  #|term = factor, { ("*" | '/'), factor };
  #|factor = ? digits ? | "(", expr, ")";
  #|r = a | b - c, 3 * x, [ d ], { e }-;
  #|rule (* below *) = "x" (* inner *), y;
  #|empty = ;
  #|long =
  #|  "a",
  #|  "b";
  #|@endebnf

///|
test "read, write and read a grammar" {
  let result = read_source(grammar_source)
  assert_eq(result.diagnostics.length(), 0)
  let doc = result.document.unwrap()
  assert_eq(doc.items.length(), 8)
  let body = @ebnf.print_body(doc).unwrap()
  let again = read_source("@startebnf\n" + body + "@endebnf\n")
  assert_eq(again.diagnostics.length(), 0)
  assert_eq(
    again.document.unwrap().without_spans().items,
    doc.without_spans().items,
  )
  // Writing is stable.
  assert_eq(@ebnf.print_body(again.document.unwrap()).unwrap(), body)
}

///|
test "lossless tree" {
  let scan = @envelope.scan(grammar_source)
  let result = @ebnf.read(scan)
  assert_eq(scan.document(result.nodes).text(), grammar_source)
}

///|
test "conversion keeps references symbolic and exclusions as constraints" {
  let doc = read_source(
    "@startebnf\nr = a | b - c;\nself = self, \"x\";\nu = undefined;\n@endebnf",
  ).document.unwrap()
  let conversion = @ebnf.to_grammar(doc)
  let grammar = conversion.grammar.unwrap()
  assert_true(
    conversion.diagnostics
    .iter()
    .any(d => d.code == "ebnf/unresolved-reference"),
  )
  assert_true(grammar.nodes.iter().any(n => n.kind is Exclusion(_, _)))
  assert_true(grammar.nodes.iter().any(n => n.kind == Reference("self", None)))
}

///|
test "native refusals and syntax errors are errors" {
  for
    rule in [
      "x = [ - a ];", "x = \"a\" \"b\";", "x = a + b;", "x \"a\";", "r = a,\n b",
      "r = \"a", "r = n * x;", "a = \"x\"; b = \"y\";",
    ] {
    let result = read_source("@startebnf\n" + rule + "\n@endebnf")
    assert_true(result.document is None, msg=rule)
  }
}

///|
test "canonical body" {
  let doc = read_source(grammar_source).document.unwrap()
  inspect(
    @ebnf.print_body(doc).unwrap(),
    content=(
      #|(* A note *)
      #|expr = term, { ("+" | "-"), term };
      #|term = factor, { ("*" | '/'), factor };
      #|factor = ? digits ? | "(", expr, ")";
      #|r = a | (b - c, 3 * x, [ d ], { e }-);
      #|rule (* below *) = "x" (* inner *), y;
      #|empty = ;
      #|long = "a", "b";
      #|
    ),
  )
}

///|
test "errors in two separate rules are both reported" {
  let result = read_source(
    "@startebnf\na = [ - x ];\nb = \"ok\";\nc = \"y\" \"z\";\n@endebnf",
  )
  assert_true(result.document is None)
  let errors = result.diagnostics
    .iter()
    .filter(d => d.severity == Error)
    .collect()
  assert_eq(errors.length(), 2)
  assert_eq(errors[0].span.unwrap().start.line, 2)
  assert_eq(errors[1].span.unwrap().start.line, 4)
}

///|
test "an edited terminal is written and reads back" {
  let doc = read_source("@startebnf\nr = \"a\", b;\n@endebnf").document.unwrap()
  guard doc.items[0] is Rule(rule) && rule.body is Some(Concat(items)) else {
    fail("rule")
  }
  let changed : @ebnf.Expr = Terminal("changed", Single, @ebnf.no_note, None)
  let edited = @ebnf.Document::new([
    Rule(@ebnf.Rule::new(rule.name, body=Concat([changed, items[1]]))),
  ])
  let body = @ebnf.print_body(edited).unwrap()
  assert_eq(body, "r = 'changed', b;\n")
  let back = read_source("@startebnf\n" + body + "@endebnf").document.unwrap()
  assert_true(back.logical_equal(edited))
  let bad = @ebnf.print_body(
    @ebnf.Document::new([
      Rule(
        @ebnf.Rule::new("r", body=Terminal("it's", Single, @ebnf.no_note, None)),
      ),
    ]),
  )
  assert_eq(bad.unwrap_err()[0].code, "ebnf/unrepresentable")
}

///|
test "depth, work and output limits fail without a partial result" {
  let deep = "r = " + "(".repeat(300) + "\"a\"" + ")".repeat(300) + ";"
  let read = @ebnf.read(
    @envelope.scan("@startebnf\n" + deep + "\n@endebnf"),
    limits=@envelope.Limits::new(depth=64),
  )
  // Grouping parentheses add no structure, so they add no depth.
  assert_true(read.document is Some(_))
  let nested = "r = " + "[ ".repeat(100) + "\"a\"" + " ]".repeat(100) + ";"
  let limited = @ebnf.read(
    @envelope.scan("@startebnf\n" + nested + "\n@endebnf"),
    limits=@envelope.Limits::new(depth=50),
  )
  assert_true(limited.document is None)
  assert_true(limited.diagnostics.iter().any(d => d.code == "ebnf/limit"))
  let doc = read_source(grammar_source).document.unwrap()
  assert_eq(
    @ebnf.print_body(doc, limits=@envelope.Limits::new(output=20)).unwrap_err()[0].code,
    "ebnf/limit",
  )
  let conversion = @ebnf.to_grammar(doc, limits=@envelope.Limits::new(nodes=3))
  assert_true(conversion.grammar is None)
}

///|
test "an unresolved reference warning locates the reference occurrence" {
  let doc = read_source("@startebnf\nr = a, missing, a;\n@endebnf").document.unwrap()
  let warning = @ebnf.to_grammar(doc).diagnostics
    .iter()
    .find_first(d => d.message.contains("missing"))
    .unwrap()
  let span = warning.span.unwrap()
  assert_eq((span.start.line, span.start.column, span.end.column), (2, 8, 15))
}
