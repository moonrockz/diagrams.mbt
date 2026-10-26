///|
/// Generated from the pinned PlantUML 1.2026.9 reference run over
/// tests/corpus/plantuml-1.2026.9/fixtures/yaml. Each case is the fixture
/// source and the native data, or `None` for a native refusal.
let profile_cases : Array[(String, String, Json?, String?)] = [
  (
    "yaml/anchors-tags.puml",
    "@startyaml\na: &anc value\nb: *anc\nc: !!str tagged\nd: *customer\n@endyaml\n",
    Some(
      obj([
        ("a", str("&anc value")),
        ("b", str("*anc")),
        ("c", str("!!str tagged")),
        ("d", str("*customer")),
      ]),
    ),
    None,
  ),
  (
    "yaml/basic.puml",
    "@startyaml\nname: test\nenabled: true\ncount: 3\nlist:\n  - a\n  - b\nnested:\n  key: value\n@endyaml\n",
    Some(
      obj([
        ("name", str("test")),
        ("enabled", str("true")),
        ("count", str("3")),
        ("list", arr([str("a"), str("b")])),
        ("nested", obj([("key", str("value"))])),
      ]),
    ),
    None,
  ),
  (
    "yaml/block-at-end.puml",
    "@startyaml\nt: |\n  one\n\ttabbed\tinside\n@endyaml\n",
    Some(obj([("t", str("one\ntabbed\tinside\n"))])),
    None,
  ),
  (
    "yaml/block-blank-comment.puml",
    "@startyaml\nt: |\n  one\n\n  # two\n  three: x\nn: 1\n@endyaml\n",
    Some(obj([("t", str("one\n# two\nthree: x\n")), ("n", str("1"))])),
    None,
  ),
  (
    "yaml/block-dedent-text.puml",
    "@startyaml\nt: |\n  one\nplain\nn: 1\n@endyaml\n",
    Some(obj([("t", str("one\nplain\n")), ("n", str("1"))])),
    None,
  ),
  (
    "yaml/block-literal.puml",
    "@startyaml\ntext: |\n  line one\n  line two\nnext: x\n@endyaml\n",
    Some(obj([("text", str("line one\nline two\n")), ("next", str("x"))])),
    None,
  ),
  (
    "yaml/colons.puml",
    "@startyaml\na: b: c\nurl: http://x.y/z\nk:v\n@endyaml\n",
    Some(
      obj([("a", str("b: c")), ("url", str("http://x.y/z")), ("k", str("v"))]),
    ),
    None,
  ),
  (
    "yaml/comments.puml",
    "@startyaml\n# comment line\na: b #trailing\n  # indented comment\nc: \"#not\" #yes\nd: b#c\ne: #only\n@endyaml\n",
    Some(
      obj([
        ("a", str("b")),
        ("c", str("#not")),
        ("d", str("b#c")),
        ("e", str("")),
      ]),
    ),
    None,
  ),
  (
    "yaml/crlf.puml",
    "@startyaml\na: 1\nb:\n  - x\n@endyaml\n",
    Some(obj([("a", str("1")), ("b", arr([str("x")]))])),
    None,
  ),
  (
    "yaml/dash-empty-refused.puml",
    "@startyaml\na:\n  -\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/dash-map.puml",
    "@startyaml\nitems:\n  -\n    a: 1\n    b: 2\n  -\n    a: 3\n@endyaml\n",
    Some(
      obj([
        (
          "items",
          arr([obj([("a", str("1")), ("b", str("2"))]), obj([("a", str("3"))])]),
        ),
      ]),
    ),
    None,
  ),
  (
    "yaml/dedent-refused.puml",
    "@startyaml\na: 1\n  b: 2\nc: 3\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/duplicate-in-item.puml",
    "@startyaml\n- a: 1\n  a: 2\n@endyaml\n",
    Some(arr([obj([("a", str("2"))])])),
    None,
  ),
  (
    "yaml/duplicate-key.puml",
    "@startyaml\na: 1\nb: 2\na: 3\n@endyaml\n",
    Some(obj([("a", str("3")), ("b", str("2"))])),
    None,
  ),
  (
    "yaml/duplicate-nested.puml",
    "@startyaml\na:\n  x: 1\nb: 2\na: 3\n@endyaml\n",
    Some(obj([("a", str("3")), ("b", str("2"))])),
    None,
  ),
  ("yaml/empty-refused.puml", "@startyaml\n@endyaml\n", None, None),
  (
    "yaml/empty-values.puml",
    "@startyaml\na:\nb:\n  c:\n@endyaml\n",
    Some(obj([("a", str("")), ("b", obj([("c", str(""))]))])),
    None,
  ),
  (
    "yaml/flow-empty.puml",
    "@startyaml\nk: []\n@endyaml\n",
    Some(obj([("k", arr([str("")]))])),
    None,
  ),
  (
    "yaml/flow-escape.puml",
    "@startyaml\nf: [a\\,b, \"c\\\"d\", 'e\\'f', , x ]\n@endyaml\n",
    Some(
      obj([("f", arr([str("a,b"), str("c\"d"), str("e'f"), str(""), str("x")]))]),
    ),
    None,
  ),
  (
    "yaml/flow.puml",
    "@startyaml\nf: [a, \"b,c\", 'd']\ng:\n  - h: [x]\n@endyaml\n",
    Some(
      obj([
        ("f", arr([str("a"), str("b,c"), str("d")])),
        ("g", arr([obj([("h", arr([str("x")]))])])),
      ]),
    ),
    None,
  ),
  (
    "yaml/folded-refused.puml",
    "@startyaml\ntext: >\n  folded\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/highlight-wildcards.puml",
    "@startyaml\n#highlight \"**\" / \"b\"\n#highlight \"a\" / \"*\"\n#highlight \"l\" / \"1\" <<s1>>\na:\n  b: 1\n  c:\n    b: 2\nl:\n  - p\n  - q\n@endyaml\n",
    Some(
      obj([
        ("a", obj([("b", str("1")), ("c", obj([("b", str("2"))]))])),
        ("l", arr([str("p"), str("q")])),
      ]),
    ),
    None,
  ),
  (
    "yaml/highlight.puml",
    "@startyaml\n#highlight \"a\" / \"b\"\na:\n  b: c\n@endyaml\n",
    Some(obj([("a", obj([("b", str("c"))]))])),
    None,
  ),
  (
    "yaml/indent-odd.puml",
    "@startyaml\na:\n   b: 1\n  c: 2\n@endyaml\n",
    Some(obj([("a", obj([("b", str("1"))])), ("c", str("2"))])),
    None,
  ),
  (
    "yaml/item-block-refused.puml",
    "@startyaml\n- a: |\n    x\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/item-flow-text.puml",
    "@startyaml\n- [a, b]\n@endyaml\n",
    Some(arr([str("[a, b]")])),
    None,
  ),
  (
    "yaml/item-key-empty-refused.puml",
    "@startyaml\n- a:\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/item-key-nested.puml",
    "@startyaml\n- a:\n    b: 1\n- c: 2\n@endyaml\n",
    Some(arr([obj([("a", obj([("b", str("1"))]))]), obj([("c", str("2"))])])),
    None,
  ),
  (
    "yaml/item-trailing-space.puml",
    "@startyaml\n- x  #c\n- y\n@endyaml\n",
    Some(arr([str("x "), str("y")])),
    None,
  ),
  (
    "yaml/key-empty.puml",
    "@startyaml\n: v\n@endyaml\n",
    Some(obj([("", str("v"))])),
    None,
  ),
  (
    "yaml/list-in-list-refused.puml",
    "@startyaml\n-\n  - x\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/list-of-maps.puml",
    "@startyaml\n- name: x\n  v: 1\n- name: y\n-\n  z: 2\n@endyaml\n",
    Some(
      arr([
        obj([("name", str("x")), ("v", str("1"))]),
        obj([("name", str("y"))]),
        obj([("z", str("2"))]),
      ]),
    ),
    None,
  ),
  (
    "yaml/list-root.puml",
    "@startyaml\n- a\n- b\n@endyaml\n",
    Some(arr([str("a"), str("b")])),
    None,
  ),
  (
    "yaml/list-same-indent.puml",
    "@startyaml\na:\n- x\n- y\nb: 1\n@endyaml\n",
    Some(obj([("a", arr([str("x"), str("y")])), ("b", str("1"))])),
    None,
  ),
  (
    "yaml/markup.puml",
    "@startyaml\n\"<script>\": \"&amp; <b>bold</b>\"\n@endyaml\n",
    Some(obj([("<script>", str("&amp; <b>bold</b>"))])),
    None,
  ),
  ("yaml/mixed-refused.puml", "@startyaml\na: 1\n- b\n@endyaml\n", None, None),
  (
    "yaml/nested-dash-literal.puml",
    "@startyaml\na:\n  - - x\n@endyaml\n",
    Some(obj([("a", arr([str("- x")]))])),
    None,
  ),
  (
    "yaml/quote-literal.puml",
    "@startyaml\na: 'it''s'\nb: \"say \\\"hi\\\"\"\nc: \"unterminated\nd: x\"\ne: x \"y\" z\nf: \"x\" y\n@endyaml\n",
    Some(
      obj([
        ("a", str("it''s")),
        ("b", str("say \\\"hi\\\"")),
        ("c", str("\"unterminated")),
        ("d", str("x\"")),
        ("e", str("x \"y\" z")),
        ("f", str("\"x\" y")),
      ]),
    ),
    None,
  ),
  (
    "yaml/quoted-key.puml",
    "@startyaml\n\"a:b\": c\n\"x\": \"y\"\n@endyaml\n",
    Some(obj([("a:b", str("c")), ("x", str("y"))])),
    None,
  ),
  (
    "yaml/quotes.puml",
    "@startyaml\nq: \"a: b, c\"\ns: 'x # y'\nc: v # comment\nempty:\nf: [a, \"b,c\", 'd']\n@endyaml\n",
    Some(
      obj([
        ("q", str("a: b, c")),
        ("s", str("x # y")),
        ("c", str("v")),
        ("empty", str("")),
        ("f", arr([str("a"), str("b,c"), str("d")])),
      ]),
    ),
    None,
  ),
  (
    "yaml/scalar-strings.puml",
    "@startyaml\nflag: true\nnothing: null\nnumber: 0012\nfloat: 1.50\n@endyaml\n",
    Some(
      obj([
        ("flag", str("true")),
        ("nothing", str("null")),
        ("number", str("0012")),
        ("float", str("1.50")),
      ]),
    ),
    None,
  ),
  (
    "yaml/style-retained.puml",
    "@startyaml\n<style>\nyamlDiagram { node { BackGroundColor yellow } }\n</style>\nskinparam monochrome true\na: 1\n@endyaml\n",
    Some(obj([("a", str("1"))])),
    None,
  ),
  (
    "yaml/tab-value.puml",
    "@startyaml\na: x\ty\n@endyaml\n",
    Some(obj([("a", str("x    y"))])),
    None,
  ),
  (
    "yaml/tabs.puml",
    "@startyaml\na:\n\tb: c\n@endyaml\n",
    Some(obj([("a", obj([("b", str("c"))]))])),
    None,
  ),
  (
    "yaml/text-deep.puml",
    "@startyaml\na:\n  b:\n    t1\n  c: 2\n@endyaml\n",
    Some(obj([("a", obj([("b", str("t1")), ("c", str("2"))]))])),
    None,
  ),
  (
    "yaml/text-join-blank.puml",
    "@startyaml\na:\n  t1\n\n  t2\nb: 1\n@endyaml\n",
    Some(obj([("a", str("t1 t2")), ("b", str("1"))])),
    None,
  ),
  (
    "yaml/text-join-dedent.puml",
    "@startyaml\na:\n  hello\nworld\n@endyaml\n",
    Some(obj([("a", str("hello world"))])),
    None,
  ),
  (
    "yaml/text-join.puml",
    "@startyaml\nkey:\n  some text\n  more text\n@endyaml\n",
    Some(obj([("key", str("some text more text"))])),
    None,
  ),
  (
    "yaml/text-quoted-refused.puml",
    "@startyaml\n\"just\"\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/text-top-refused.puml",
    "@startyaml\njust text\n@endyaml\n",
    None,
    None,
  ),
  (
    "yaml/title.puml",
    "@startyaml\ntitle My Data\na: 1\n@endyaml\n",
    Some(obj([("a", str("1"))])),
    Some("My Data"),
  ),
  (
    "yaml/unicode.puml",
    "@startyaml\nété: 😀\n名前: 値\n@endyaml\n",
    Some(obj([("été", str("😀")), ("名前", str("値"))])),
    None,
  ),
]
