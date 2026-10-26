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
  assert_eq(again.document.unwrap().without_spans().items, doc.without_spans().items)
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
    conversion.diagnostics.iter().any(d => d.code == "ebnf/unresolved-reference"),
  )
  assert_true(
    grammar.nodes.iter().any(n => n.kind is Exclusion(_, _)),
  )
  assert_true(
    grammar.nodes.iter().any(n => n.kind == Reference("self", None)),
  )
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
