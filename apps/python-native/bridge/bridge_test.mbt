///|
test "valid source gives versioned JSON with SVG output" {
  let result = @json.parse(
    @python_native_bridge.render_svg_json("flowchart TD\n  A --> B\n"),
  )
  guard result
    is {
      "format": Number(1, ..),
      "media_type": String("image/svg+xml"),
      "output": String(svg),
      "diagnostics": Array([]),
      ..
    } else {
    fail("unexpected result: \{result.stringify()}")
  }
  assert_true(svg.has_prefix("<svg "))
}

///|
test "output equals the direct render_svg output" {
  let source = "flowchart LR\n  A[\"Rocket 🚀\"] --> B[\"𝔘nicode\"]\n"
  let direct = @mermaid.render_svg(source)
  guard @json.parse(@python_native_bridge.render_svg_json(source))
    is { "output": String(svg), .. } else {
    fail("no output")
  }
  assert_eq(Some(svg), direct.output)
}

///|
test "invalid syntax gives a diagnostic with a span" {
  let result = @json.parse(
    @python_native_bridge.render_svg_json("flowchart TD\n  A[Unclosed --> B\n"),
  )
  guard result
    is {
      "output": Null,
      "diagnostics": Array(
        [
          {
            "code": String("flowchart/syntax"),
            "severity": String("error"),
            "span": {
              "start": { "line": Number(2, ..), "column": Number(3, ..), .. },
              ..
            },
            ..
          },
        ]
      ),
      ..
    } else {
    fail("unexpected result: \{result.stringify()}")
  }
}

///|
test "UTF-8 boundary round-trips and refuses invalid bytes" {
  let ok = @utf8.decode(
    @python_native_bridge.render_svg_utf8(
      @utf8.encode("flowchart TD\n  A[\"😀\"] --> B\n"),
    ),
  )
  guard @json.parse(ok) is { "output": String(svg), .. } else {
    fail("no output")
  }
  assert_true(svg.contains("😀"))
  let invalid = @utf8.decode(
    @python_native_bridge.render_svg_utf8(b"flowchart TD\n  A[\xff] --> B\n"),
  )
  guard @json.parse(invalid)
    is {
      "output": Null,
      "diagnostics": Array([{ "code": String("python/invalid-utf8"), .. }]),
      ..
    } else {
    fail("unexpected result: \{invalid}")
  }
}
