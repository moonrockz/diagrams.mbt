///|
fn read_yaml(source : String) -> @yaml.ReadResult {
  @yaml.read(@envelope.scan(source))
}

///|
fn yaml_codes(
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic],
) -> Array[String] {
  diagnostics.iter().map(d => d.code).to_array()
}

///|
fn convert(source : String) -> @yaml.Conversion {
  @yaml.to_data_tree(read_yaml(source).document.unwrap())
}

///|
test "scalars are text and line forms are typed" {
  let source =
    #|@startyaml
    #|enabled: true
    #|- item
    #|-
    #|key:
    #|  text
    #|f: [a, "b,c"]
    #|t: |
    #|  one
    #|g: >
    #|@endyaml
  let document = read_yaml(source).document.unwrap()
  let contents = document.lines.map(line => line.content).iter().collect()
  assert_eq(contents.length(), 8)
  assert_true(
    contents[0]
    is Pair(false, { text: "enabled", .. }, Value({ text: "true", .. })),
  )
  assert_true(contents[1] is Item({ text: "item", .. }))
  assert_true(contents[2] is Dash)
  assert_true(contents[3] is Pair(false, _, Empty))
  assert_true(contents[4] is Text({ text: "text", .. }))
  assert_true(contents[5] is Pair(false, _, Flow(_)))
  guard contents[6] is Pair(false, _, Block(lines)) else { fail("not a block") }
  assert_eq(lines.iter().collect(), ["one"])
  assert_true(contents[7] is Pair(false, _, Folded))
  assert_eq(document.lines[1].native_indent(), 2)
  assert_eq(document.lines[2].native_indent(), 1)
}

///|
test "a scalar that resembles a boolean stays text" {
  let tree = convert("@startyaml\nenabled: true\n@endyaml\n").tree.unwrap()
  assert_eq(tree.nodes[1].value, @data_tree.Value::Text("true"))
}

///|
test "a scalar that resembles a reference creates no relation" {
  let tree = convert("@startyaml\na: &x 1\nb: *x\nc: !!int 2\n@endyaml\n").tree.unwrap()
  assert_eq(tree.nodes.length(), 4)
  assert_eq(tree.nodes[2].value, Text("*x"))
  assert_eq(tree.nodes[3].value, Text("!!int 2"))
}

///|
test "duplicate keys keep every line and warn about the projection" {
  let source = "@startyaml\na: 1\nb: 2\na: 3\n@endyaml\n"
  let document = read_yaml(source).document.unwrap()
  assert_eq(document.lines.length(), 3)
  let conversion = @yaml.to_data_tree(document)
  assert_eq(yaml_codes(conversion.diagnostics), ["yaml/duplicate-key"])
  let tree = conversion.tree.unwrap()
  assert_eq(tree.nodes[0].members().map(m => m.key).iter().collect(), [
    @data_tree.Key::Name("a"),
    Name("b"),
  ])
  assert_eq(tree.nodes[1].value, Text("3"))
  // The member source is the line that gave the kept value.
  assert_eq(tree.nodes[0].members()[0].source.map(s => s.start.line), Some(4))
}

///|
test "refusals name the native reason" {
  let cases = [
    ("just text", "yaml/text-without-key"),
    ("text: >\n  folded", "yaml/unsupported-folded"),
    ("- a: |\n    x", "yaml/unsupported-item-block"),
    ("a: 1\n- b", "yaml/mixed-collection"),
    ("a: 1\n  b: 2\nc: 3", "yaml/indentation"),
    ("-\n  - x", "yaml/missing-value"),
    ("- a:", "yaml/missing-value"),
    ("# only a comment", "yaml/no-data"),
  ]
  for case in cases {
    let (body, code) = case
    let conversion = convert("@startyaml\n" + body + "\n@endyaml\n")
    assert_true(conversion.tree is None, msg=body)
    assert_eq(yaml_codes(conversion.diagnostics), [code], msg=body)
    if body != "# only a comment" {
      assert_true(conversion.diagnostics[0].span is Some(_), msg=body)
    }
  }
}

///|
test "identities follow ownership paths, not names or text" {
  let source =
    #|@startyaml
    #|- x
    #|- x
    #|- a: x
    #|  b: [x, x]
    #|@endyaml
  let tree = convert(source).tree.unwrap()
  assert_eq(tree.nodes.map(n => n.id).iter().collect(), [
    "v", "v/0", "v/1", "v/2", "v/2/0", "v/2/1", "v/2/1/0", "v/2/1/1",
  ])
  assert_eq(tree.nodes[0].members().map(m => m.id).iter().collect(), [
    "m/0", "m/1", "m/2",
  ])
}

///|
test "highlights keep quoted separators and occurrence identities" {
  let source =
    #|@startyaml
    #|#highlight "a/b"
    #|#highlight "l" / "1" <<s1>>
    #|#highlight "**" / "c"
    #|#highlight "nope"
    #|a/b: 1
    #|a:
    #|  b: 2
    #|l:
    #|  - p
    #|  - q
    #|x:
    #|  c: 3
    #|@endyaml
  let conversion = convert(source)
  let tree = conversion.tree.unwrap()
  assert_eq(
    tree.highlights.map(h => h.targets.iter().collect()).iter().collect(),
    [["m/0"], ["m/2/1"], ["m/3/0"]],
  )
  assert_eq(tree.highlights[1].style, Some("s1"))
  assert_eq(yaml_codes(conversion.diagnostics), [
    "yaml/unapplied-highlight-style", "yaml/unresolved-highlight",
  ])
}

///|
test "canonical writing chooses a spelling that reads back" {
  let document = @yaml.Document::new([
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("title"), Value(@yaml.Scalar::new("x"))),
    ),
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("a:b"), Value(@yaml.Scalar::new(" lead"))),
    ),
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("c"), Value(@yaml.Scalar::new("x # y"))),
    ),
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("e"), Value(@yaml.Scalar::new(""))),
    ),
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("f"), Flow(["a,b", "c\"d", ""])),
    ),
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("t"), Block(["one", "# two"])),
    ),
    @yaml.Line::new(0, Pair(false, @yaml.Scalar::new("k"), Empty)),
    @yaml.Line::new(2, Text(@yaml.Scalar::new("x: y"))),
  ])
  let body = @yaml.print_body(document).unwrap()
  assert_eq(
    body,
    (
      #|title: x
      #|"a:b": " lead"
      #|c: "x # y"
      #|e: ""
      #|f: ["a,b", c"d, ""]
      #|t: |
      #|  one
      #|  # two
      #|k:
      #|  "x: y"
      #|
    ),
  )
  let back = read_yaml("@startyaml\n" + body + "@endyaml\n").document.unwrap()
  assert_true(back.logical_equal(document))
  let tree = @yaml.to_data_tree(back).tree.unwrap()
  assert_eq(tree.nodes[1].value, Text("x"))
  assert_eq(tree.nodes[2].value, Text(" lead"))
  assert_eq(tree.nodes[9].value, Text("one\n# two\n"))
  assert_eq(tree.nodes[10].value, Text("x: y"))
}

///|
test "an edited value appears in the output" {
  let document = read_yaml("@startyaml\nname: old\n@endyaml\n").document.unwrap()
  guard document.lines[0].content is Pair(item, key, _) else { fail("no pair") }
  let edited = @yaml.Document::new([
    @yaml.Line::new(0, Pair(item, key, Value(@yaml.Scalar::new("new value")))),
  ])
  let body = @yaml.print_body(edited).unwrap()
  assert_eq(body, "name: new value\n")
  let tree = @yaml.to_data_tree(
    read_yaml("@startyaml\n" + body + "@endyaml\n").document.unwrap(),
  ).tree.unwrap()
  assert_eq(tree.nodes[1].value, Text("new value"))
}

///|
test "values that the native profile cannot express are writer errors" {
  let values = ["two\nlines", "tab\there", "%date()", "carriage\rreturn"]
  for value in values {
    let document = @yaml.Document::new([
      @yaml.Line::new(
        0,
        Pair(false, @yaml.Scalar::new("k"), Value(@yaml.Scalar::new(value))),
      ),
    ])
    guard @yaml.print_body(document) is Err(diagnostics) else {
      fail("'\{value}' is written")
    }
    assert_eq(yaml_codes(diagnostics), ["yaml/unrepresentable-value"])
  }
  let empty_flow = @yaml.Document::new([
    @yaml.Line::new(0, Pair(false, @yaml.Scalar::new("k"), Flow([]))),
  ])
  assert_true(@yaml.print_body(empty_flow) is Err(_))
  let blank_block = @yaml.Document::new([
    @yaml.Line::new(0, Pair(false, @yaml.Scalar::new("k"), Block([""]))),
  ])
  assert_true(@yaml.print_body(blank_block) is Err(_))
}

///|
test "writing limits give errors and no partial output" {
  let lines = Array::makei(100, i => {
    @yaml.Line::new(
      0,
      Pair(false, @yaml.Scalar::new("k\{i}"), Value(@yaml.Scalar::new("v"))),
    )
  })
  let document = @yaml.Document::new(lines)
  guard @yaml.print_body(document, limits=@envelope.Limits::new(output=50))
    is Err(diagnostics) else {
    fail("expected an error")
  }
  assert_eq(yaml_codes(diagnostics), ["yaml/output-limit"])
}

///|
test "reading and conversion limits are explicit" {
  let deep = StringBuilder()
  deep.write_string("@startyaml\n")
  for i in 0..<30 {
    deep.write_string(String::make(i * 2, ' ') + "k:\n")
  }
  deep.write_string(String::make(60, ' ') + "leaf: 1\n@endyaml\n")
  let document = read_yaml(deep.to_string()).document.unwrap()
  let conversion = @yaml.to_data_tree(
    document,
    limits=@envelope.Limits::new(depth=10),
  )
  assert_true(conversion.tree is None)
  assert_eq(yaml_codes(conversion.diagnostics), ["yaml/depth-limit"])
  let ok = @yaml.to_data_tree(document).tree.unwrap()
  assert_eq(ok.nodes.length(), 32)
  let result = @yaml.read(
    @envelope.scan(deep.to_string()),
    limits=@envelope.Limits::new(nodes=5),
  )
  assert_true(result.document is None)
  assert_true(yaml_codes(result.diagnostics).contains("yaml/node-limit"))
  assert_eq(
    @envelope.scan(deep.to_string()).document(result.nodes).text(),
    deep.to_string(),
  )
}

///|
test "diagnostic codes are stable and unique" {
  let seen = Map([])
  for code in @yaml.diagnostic_codes {
    assert_true(code.has_prefix("yaml/"))
    assert_true(!seen.contains(code))
    seen[code] = true
  }
  ignore(@data.value_id([]))
}
