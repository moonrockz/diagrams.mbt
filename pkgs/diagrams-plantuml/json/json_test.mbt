///|
fn read_source(source : String) -> @json.ReadResult {
  @json.read(@envelope.scan(source))
}

///|
fn codes(diagnostics : ReadOnlyArray[@diagrams.Diagnostic]) -> Array[String] {
  diagnostics.iter().map(d => d.code).to_array()
}

///|
fn reproduce(source : String) -> String {
  let scan = @envelope.scan(source)
  let result = @json.read(scan)
  scan.document(result.nodes).text()
}

///|
fn round_trip(source : String) -> (@json.Document, @json.Document, String) {
  let first = read_source(source).document.unwrap()
  let body = @json.print_body(first).unwrap()
  let second = read_source("@startjson\n" + body + "@endjson\n").document.unwrap()
  (first, second, body)
}

///|
test "duplicate members, exact numbers and order are kept" {
  let source =
    #|@startjson
    #|{"a": 1, "b": [true, false, null], "c": {"d": "e"}, "a": 12345678901234567890123, "z": -0.0, "e": 1e400}
    #|@endjson
    #|
  let document = read_source(source).document.unwrap()
  guard document.value.kind is Object(members) else { fail("not an object") }
  assert_eq(members.map(m => m.name.text).iter().collect(), [
    "a", "b", "c", "a", "z", "e",
  ])
  assert_true(members[3].value.kind is Number("12345678901234567890123"))
  assert_true(members[4].value.kind is Number("-0.0"))
  assert_true(members[5].value.kind is Number("1e400"))
  let (first, second, _) = round_trip(source)
  assert_true(first.logical_equal(second))
}

///|
test "the syntax tree reproduces every source code unit" {
  let sources = [
    "@startjson\r\n{ \"é\": \"😀\", // note\r\n  \"x\": [1,\t2] }\r\n@endjson\r\n",
    "@startjson\n{\"a\": 01, \"b\": \"\\q\"}\n@endjson", "' head\n@startjson\ntitle T\n#highlight \"a\"\n{\"a\":\n#c\n1}\n@endjson\n",
    "@startjson\n\"unterminated\n@endjson\n",
  ]
  for source in sources {
    assert_eq(reproduce(source), source)
  }
}

///|
test "malformed data is refused, never coerced" {
  let cases = [
    ("{\"a\": 01}", "json/invalid-number"),
    ("{\"a\": \"\\q\"}", "json/invalid-escape"),
    ("{\"a\": \"x\ty\"}", "json/invalid-string"),
    ("{\"a\": True}", "json/invalid-literal"),
    ("{'a': 1}", "json/unexpected-character"),
    ("{\"a\":1,}", "json/unexpected-token"),
    ("[1, // c\n 2]", "json/unexpected-comment"),
    ("{ // c\n}", "json/unexpected-token"),
    ("1 2", "json/trailing-content"),
    ("[1.]", "json/invalid-number"),
    ("[-]", "json/invalid-number"),
    ("[+1]", "json/unexpected-character"),
    ("{\"a\": 1}\u{3}x", "json/unexpected-character"),
    ("", "json/missing-value"),
  ]
  for case in cases {
    let (body, code) = case
    let result = read_source("@startjson\n" + body + "\n@endjson\n")
    assert_true(result.document is None)
    assert_true(
      codes(result.diagnostics).contains(code),
      msg="\{body}: \{codes(result.diagnostics).join(",")}",
    )
  }
}

///|
test "comments stand before a name or after a member value" {
  let result = read_source(
    "@startjson\n{ // c\n  \"a\": 1 // d\n  , \"b\": 2\n}\n@endjson\n",
  )
  assert_eq(codes(result.diagnostics), [])
  guard result.document.unwrap().value.kind is Object(members) else {
    fail("not an object")
  }
  assert_eq(members.length(), 2)
}

///|
test "escapes decode and canonical writing escapes again" {
  let source =
    #|@startjson
    #|{"a":"\u0000x","b":"\ud800","c":"\u00E9\/\b\f\n\r\t","d":"\u0025date()","e":"😀"}
    #|@endjson
  let (first, second, body) = round_trip(source)
  assert_true(first.logical_equal(second))
  guard first.value.kind is Object(members) else { fail("not an object") }
  guard members[1].value.kind is String(lone) else { fail("not a string") }
  assert_eq(lone.text.length(), 1)
  assert_eq(lone.text.code_unit_at(0).to_int(), 0xd800)
  assert_eq(lone.raw, Some("\"\\ud800\""))
  assert_true(body.contains("\\u0025date()"))
  assert_true(body.contains("😀"))
  assert_true(!body.contains("%date"))
}

///|
test "canonical writing is stable and reflects edits" {
  let document = @json.Document::new(
    @json.Value::object([
      @json.Member::new("name", @json.Value::string("old")),
      @json.Member::new(
        "list",
        @json.Value::array([
          @json.Value::number("1"),
          @json.Value::object([]),
          @json.Value::array([]),
        ]),
      ),
    ]),
    highlights=[@data.Selector::new([Name("a/b"), Occurrence("item", 2)])],
  )
  let body = @json.print_body(document).unwrap()
  assert_eq(
    body,
    (
      #|#highlight "a/b" / "item"#2
      #|{
      #|  "name": "old",
      #|  "list": [
      #|    1,
      #|    {},
      #|    []
      #|  ]
      #|}
      #|
    ),
  )
  let reread = read_source("@startjson\n" + body + "@endjson\n").document.unwrap()
  assert_true(reread.logical_equal(document))
  assert_eq(@json.print_body(reread).unwrap(), body)
  let edited = @json.Document::new(
    @json.Value::object([
      @json.Member::new("name", @json.Value::string("new \"value\"")),
    ]),
  )
  let text = @json.print_body(edited).unwrap()
  assert_true(text.contains("\"new \\\"value\\\"\""))
  let back = read_source("@startjson\n" + text + "@endjson\n").document.unwrap()
  assert_true(back.logical_equal(edited))
}

///|
test "an invalid number in a constructed model is a writer error" {
  let document = @json.Document::new(@json.Value::number("01"))
  let result = @json.print_body(document)
  guard result is Err(diagnostics) else { fail("expected an error") }
  assert_eq(codes(diagnostics), ["json/invalid-model"])
}

///|
test "limits give errors and no partial output" {
  let deep = StringBuilder()
  for _ in 0..<40 {
    deep.write_string("[")
  }
  for _ in 0..<40 {
    deep.write_string("]")
  }
  let limits = @envelope.Limits::new(depth=10)
  let result = @json.read(
    @envelope.scan("@startjson\n" + deep.to_string() + "\n@endjson\n"),
    limits~,
  )
  assert_true(result.document is None)
  assert_true(codes(result.diagnostics).contains("json/depth-limit"))
  let big = @json.Document::new(
    @json.Value::array(Array::make(50, @json.Value::string("abcdef"))),
  )
  let output = @json.print_body(big, limits=@envelope.Limits::new(output=100))
  guard output is Err(diagnostics) else { fail("expected an error") }
  assert_eq(codes(diagnostics), ["json/output-limit"])
  // Deep data within its limit uses no recursion.
  let ok = StringBuilder()
  for _ in 0..<200 {
    ok.write_string("{\"a\":")
  }
  ok.write_string("1")
  for _ in 0..<200 {
    ok.write_string("}")
  }
  let source = "@startjson\n" + ok.to_string() + "\n@endjson\n"
  let document = read_source(source).document.unwrap()
  let tree = @json.to_data_tree(document).tree.unwrap()
  assert_eq(tree.nodes.length(), 201)
}

///|
test "conversion keeps scalar roots, empty containers and identities" {
  let scalar = read_source("@startjson\n\"hello\"\n@endjson\n").document.unwrap()
  let tree = @json.to_data_tree(scalar, id="s").tree.unwrap()
  assert_eq(tree.root, "v")
  assert_eq(tree.nodes.map(n => n.value).iter().collect(), [
    @data_tree.Value::Text("hello"),
  ])
  let source =
    #|@startjson
    #|title First
    #|title Data
    #|{"o": {}, "a": [], "x": [7, 7], "t": "true", "b": true}
    #|@endjson
  let document = read_source(source).document.unwrap()
  let conversion = @json.to_data_tree(document)
  let tree = conversion.tree.unwrap()
  assert_eq(tree.id, "json")
  assert_eq(tree.title, Some("Data"))
  let ids = tree.nodes.map(n => n.id).iter().collect()
  assert_eq(ids, ["v", "v/0", "v/1", "v/2", "v/2/0", "v/2/1", "v/3", "v/4"])
  let root = tree.nodes[0]
  assert_eq(root.members().map(m => m.id).iter().collect(), [
    "m/0", "m/1", "m/2", "m/3", "m/4",
  ])
  assert_eq(tree.nodes[6].value, Text("true"))
  assert_eq(tree.nodes[7].value, Boolean(true))
  assert_eq(tree.nodes[1].value, Object([]))
  assert_eq(@data_tree.validate(tree).length(), 0)
}

///|
test "highlights resolve to member occurrences" {
  let source =
    #|@startjson
    #|#highlight "a/b" / "c"
    #|#highlight lst / 0
    #|#highlight "x" <<bold>>
    #|#highlight "**" / "c"
    #|#highlight "item"
    #|#highlight "item"#2
    #|#highlight "missing"
    #|#highlight "o" / *
    #|{"a/b": {"c": 1}, "lst": [1,2], "x": 3, "item": 1, "item": 2, "o": {"p": 1, "q": {"c": 2}}}
    #|@endjson
  let document = read_source(source).document.unwrap()
  assert_eq(document.highlights.length(), 8)
  let conversion = @json.to_data_tree(document)
  let tree = conversion.tree.unwrap()
  let targets = tree.highlights
    .map(h => h.targets.iter().collect())
    .iter()
    .collect()
  assert_eq(targets, [
    ["m/0/0"],
    ["m/1/0"],
    ["m/2"],
    ["m/0/0", "m/5/1/0"],
    ["m/3", "m/4"],
    ["m/4"],
    ["m/5/0", "m/5/1"],
  ])
  assert_eq(tree.highlights[2].style, Some("bold"))
  let warnings = codes(conversion.diagnostics)
  assert_eq(warnings, [
    "json/unapplied-highlight-style", "json/ambiguous-highlight", "json/unresolved-highlight",
  ])
}

///|
test "invalid highlight lines are errors" {
  for
    line in [
      "#highlight a<b", "#highlight \"a", "#highlight a //b", "#highlight \"a\"#0",
      "#highlight \"a\" <<s",
    ] {
    let result = read_source("@startjson\n" + line + "\n{\"a\": 1}\n@endjson\n")
    assert_true(result.document is None, msg=line)
    assert_true(
      codes(result.diagnostics).contains("json/invalid-highlight"),
      msg=line,
    )
  }
  let quoted = read_source(
    "@startjson\n#highlight \"a<b\" / \"c\\\"d\"\n{\"a<b\": {\"c\\\"d\": 1}}\n@endjson\n",
  )
  let tree = @json.to_data_tree(quoted.document.unwrap()).tree.unwrap()
  assert_eq(tree.highlights[0].targets.iter().collect(), ["m/0/0"])
}

///|
test "diagnostic codes are stable and unique" {
  let seen = Map([])
  for code in @json.diagnostic_codes {
    assert_true(code.has_prefix("json/"))
    assert_true(!seen.contains(code))
    seen[code] = true
  }
}
