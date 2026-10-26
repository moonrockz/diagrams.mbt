///|
/// Generated from the pinned PlantUML 1.2026.9 reference run over
/// tests/corpus/plantuml-1.2026.9/fixtures/json. Each case is the fixture
/// source and the native data, or `None` for a native refusal.
let profile_cases : Array[(String, String, Json?, String?)] = [
  (
    "json/basic.puml",
    "@startjson\n{\"a\": 1, \"b\": [true, false, null], \"c\": {\"d\": \"e\"}, \"a\": 12345678901234567890123, \"z\": -0.0, \"e\": 1e400}\n@endjson\n",
    Some(
      obj([
        ("a", num("1")),
        ("b", arr([boolean(true), boolean(false), null()])),
        ("c", obj([("d", str("e"))])),
        ("a", num("12345678901234567890123")),
        ("z", num("-0.0")),
        ("e", num("1e400")),
      ]),
    ),
    None,
  ),
  (
    "json/comments.puml",
    "@startjson\n{ // c\n  \"a\": 1 // d\n  , \"b\": 2\n}\n@endjson\n",
    Some(obj([("a", num("1")), ("b", num("2"))])),
    None,
  ),
  (
    "json/deep.puml",
    "@startjson\n[[[[[[[[[[[[[[[[[[[[{\"deep\": true}]]]]]]]]]]]]]]]]]]]]\n@endjson\n",
    Some(
      arr([
        arr([
          arr([
            arr([
              arr([
                arr([
                  arr([
                    arr([
                      arr([
                        arr([
                          arr([
                            arr([
                              arr([
                                arr([
                                  arr([
                                    arr([
                                      arr([
                                        arr([
                                          arr([
                                            arr([obj([("deep", boolean(true))])]),
                                          ]),
                                        ]),
                                      ]),
                                    ]),
                                  ]),
                                ]),
                              ]),
                            ]),
                          ]),
                        ]),
                      ]),
                    ]),
                  ]),
                ]),
              ]),
            ]),
          ]),
        ]),
      ]),
    ),
    None,
  ),
  (
    "json/divergence-empty-array-root.puml",
    "@startjson\n[]\n@endjson\n",
    Some(arr([str("")])),
    None,
  ),
  (
    "json/divergence-empty-object-root.puml",
    "@startjson\n{}\n@endjson\n",
    Some(arr([str("")])),
    None,
  ),
  (
    "json/divergence-highlight-slash.puml",
    "@startjson\n#highlight \"a/b\" / \"c\"\n{\"a/b\": {\"c\": 1}, \"a\": {\"b\": {\"c\": 2}}}\n@endjson\n",
    Some(
      obj([
        ("a/b", obj([("c", num("1"))])),
        ("a", obj([("b", obj([("c", num("2"))]))])),
      ]),
    ),
    None,
  ),
  (
    "json/divergence-null-root.puml",
    "@startjson\nnull\n@endjson\n",
    Some(arr([null()])),
    None,
  ),
  (
    "json/divergence-number-root.puml",
    "@startjson\n42\n@endjson\n",
    Some(arr([num("42")])),
    None,
  ),
  (
    "json/divergence-scalar-root.puml",
    "@startjson\n\"hello\"\n@endjson\n",
    Some(arr([str("hello")])),
    None,
  ),
  (
    "json/divergence-true-root.puml",
    "@startjson\ntrue\n@endjson\n",
    Some(arr([boolean(true)])),
    None,
  ),
  (
    "json/duplicate-members.puml",
    "@startjson\n{\"item\": 1, \"item\": 1, \"item\": {\"x\": [7, 7]}}\n@endjson\n",
    Some(
      obj([
        ("item", num("1")),
        ("item", num("1")),
        ("item", obj([("x", arr([num("7"), num("7")]))])),
      ]),
    ),
    None,
  ),
  (
    "json/empty-nested.puml",
    "@startjson\n{\"o\": {}, \"a\": [], \"n\": [[], {}]}\n@endjson\n",
    Some(obj([("o", obj([])), ("a", arr([])), ("n", arr([arr([]), obj([])]))])),
    None,
  ),
  (
    "json/hash-and-quote-lines.puml",
    "@startjson\n' plantuml comment\n{\"a\":\n#hash comment\n1}\n@endjson\n",
    Some(obj([("a", num("1"))])),
    None,
  ),
  (
    "json/highlight-duplicate.puml",
    "@startjson\n#highlight \"item\"\n{\"item\":1,\"item\":2}\n@endjson\n",
    Some(obj([("item", num("1")), ("item", num("2"))])),
    None,
  ),
  (
    "json/highlight-wildcards.puml",
    "@startjson\n#highlight \"**\" / \"x\"\n#highlight \"o\" / \"*\"\n#highlight \"*\" / \"y\"\n{\"o\":{\"x\":1,\"y\":{\"x\":2}},\"a\":{\"b\":3},\"x\":4}\n@endjson\n",
    Some(
      obj([
        ("o", obj([("x", num("1")), ("y", obj([("x", num("2"))]))])),
        ("a", obj([("b", num("3"))])),
        ("x", num("4")),
      ]),
    ),
    None,
  ),
  (
    "json/highlight.puml",
    "@startjson\n#highlight \"lst\" / \"0\"\n#highlight \"x\" <<bold>>\n#highlight c / d\n{\"lst\": [1,2], \"x\": 3, \"c\": {\"d\": 4}}\n@endjson\n",
    Some(
      obj([
        ("lst", arr([num("1"), num("2")])),
        ("x", num("3")),
        ("c", obj([("d", num("4"))])),
      ]),
    ),
    None,
  ),
  (
    "json/multiline.puml",
    "@startjson\n{\n  \"a\": [\n    1,\n    {\"b\": null}\n  ],\n  \"c\": \"d\"\n}\n@endjson\n",
    Some(obj([("a", arr([num("1"), obj([("b", null())])])), ("c", str("d"))])),
    None,
  ),
  (
    "json/numbers.puml",
    "@startjson\n[0, -0, 1.5e-7, 2E+3, 10, 0.000, -12345678901234567890.5e-30]\n@endjson\n",
    Some(
      arr([
        num("0"),
        num("-0"),
        num("1.5e-7"),
        num("2E+3"),
        num("10"),
        num("0.000"),
        num("-12345678901234567890.5e-30"),
      ]),
    ),
    None,
  ),
  (
    "json/refused-array-comment.puml",
    "@startjson\n[1, // c\n 2]\n@endjson\n",
    None,
    None,
  ),
  (
    "json/refused-bad-escape.puml",
    "@startjson\n{\"a\": \"\\q\"}\n@endjson\n",
    None,
    None,
  ),
  (
    "json/refused-bare-word.puml",
    "@startjson\n{\"a\": True}\n@endjson\n",
    None,
    None,
  ),
  (
    "json/refused-comment-only-object.puml",
    "@startjson\n{ // c\n}\n@endjson\n",
    None,
    None,
  ),
  ("json/refused-dot.puml", "@startjson\n[.5]\n@endjson\n", None, None),
  ("json/refused-empty.puml", "@startjson\n@endjson\n", None, None),
  ("json/refused-exponent.puml", "@startjson\n[1e]\n@endjson\n", None, None),
  ("json/refused-fraction.puml", "@startjson\n[1.]\n@endjson\n", None, None),
  (
    "json/refused-leading-zero.puml",
    "@startjson\n{\"a\": 01}\n@endjson\n",
    None,
    None,
  ),
  ("json/refused-minus.puml", "@startjson\n[-]\n@endjson\n", None, None),
  ("json/refused-plus.puml", "@startjson\n[+1]\n@endjson\n", None, None),
  (
    "json/refused-single-quote.puml",
    "@startjson\n{'a': 1}\n@endjson\n",
    None,
    None,
  ),
  ("json/refused-slash.puml", "@startjson\n{/ \"a\":1}\n@endjson\n", None, None),
  (
    "json/refused-tab-in-string.puml",
    "@startjson\n{\"a\":\"x\ty\"}\n@endjson\n",
    None,
    None,
  ),
  (
    "json/refused-trailing-comma.puml",
    "@startjson\n{\"a\":1,}\n@endjson\n",
    None,
    None,
  ),
  ("json/refused-two-values.puml", "@startjson\n1 2\n@endjson\n", None, None),
  (
    "json/refused-unclosed.puml",
    "@startjson\n{\"a\": [1, 2}\n@endjson\n",
    None,
    None,
  ),
  (
    "json/strings.puml",
    "@startjson\n{\"a\":\"\\u0000x\",\"b\":\"\\ud800\",\"c\":\"\\u00E9\\/\\b\\f\\n\\r\\t\",\"d\":\"true\",\"e\":\"\\ud83d\\ude00\"}\n@endjson\n",
    Some(
      obj([
        ("a", str("\u{0}x")),
        ("b", str(u([0xd800]))),
        ("c", str("é/\u{8}\u{c}\n\r\t")),
        ("d", str("true")),
        ("e", str("😀")),
      ]),
    ),
    None,
  ),
  (
    "json/style-retained.puml",
    "@startjson\n<style>\njsonDiagram { node { BackGroundColor yellow } }\n</style>\n{\"a\": 1}\n@endjson\n",
    Some(obj([("a", num("1"))])),
    None,
  ),
  (
    "json/title.puml",
    "@startjson\ntitle Data\n{\"k\": \"v\"}\n@endjson\n",
    Some(obj([("k", str("v"))])),
    Some("Data"),
  ),
  (
    "json/unicode.puml",
    "@startjson\n{\"é\": \"😀\", \"x\": \"<script>alert(1)</script>\", \"amp\": \"a & b \\\" c\"}\n@endjson\n",
    Some(
      obj([
        ("é", str("😀")),
        ("x", str("<script>alert(1)</script>")),
        ("amp", str("a & b \" c")),
      ]),
    ),
    None,
  ),
]
