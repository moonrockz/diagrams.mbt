///|
/// Sends `op` with `args` through the structured boundary and returns the
/// decoded response record.
fn call_op(
  op : String,
  args : Array[@python_native_bridge.Rec],
) -> @python_native_bridge.Rec raise @python_native_bridge.BridgeError {
  let request = [@python_native_bridge.Rec::Str(op), ..args]
  @python_native_bridge.decode_record(
    @python_native_bridge.call(
      @python_native_bridge.encode_record(
        @python_native_bridge.Rec::list(request),
      ),
    ),
  )
}

///|
test "the boundary version is 2" {
  assert_eq(@python_native_bridge.abi_version(), 2)
  assert_true(call_op("abi_version", []) is List([Int(0L), Int(2L)]))
}

///|
test "valid source gives a rendered record with SVG output" {
  let response = call_op("render_svg", [
    Bin(@utf8.encode("flowchart TD\n  A --> B\n")),
  ])
  guard response
    is List([Int(0L), List([Str("image/svg+xml"), Str(svg), List([])])]) else {
    fail("unexpected response")
  }
  assert_true(svg.has_prefix("<svg "))
}

///|
test "output equals the direct render_svg output" {
  let source = "flowchart LR\n  A[\"Rocket 🚀\"] --> B[\"𝔘nicode\"]\n"
  let direct = @mermaid.render_svg(source)
  guard call_op("render_svg", [Bin(@utf8.encode(source))])
    is List([Int(0L), List([_, Str(svg), _])]) else {
    fail("no output")
  }
  assert_eq(Some(svg), direct.output)
}

///|
test "invalid syntax gives a diagnostic record with a span" {
  let response = call_op("render_svg", [
    Bin(@utf8.encode("flowchart TD\n  A[Unclosed --> B\n")),
  ])
  guard response
    is List(
      [
        Int(0L),
        List(
          [
            Str("image/svg+xml"),
            Null,
            List(
              [
                List(
                  [
                    Str("flowchart/syntax"),
                    Str("error"),
                    Str(_),
                    List(
                      [
                        List([Int(2L), Int(3L), Int(_)]),
                        List([Int(_), Int(_), Int(_)]),
                      ]
                    ),
                  ]
                ),
              ]
            ),
          ]
        ),
      ]
    ) else {
    fail("unexpected response")
  }
}

///|
test "invalid UTF-8 gives a diagnostic and no output" {
  let rendered = @python_native_bridge.render_svg_bytes(
    b"flowchart TD\n  A[\xff] --> B\n",
  )
  assert_eq(rendered.output, None)
  assert_eq(rendered.diagnostics.map(d => d.code), ["python/invalid-utf8"])
  let response = call_op("render_svg", [Bin(b"\xff")])
  assert_true(
    response
    is List(
      [Int(0L), List([_, Null, List([List([Str("python/invalid-utf8"), ..])])])]
    ),
  )
}

///|
test "render_svg refuses arguments that are not bytes" {
  for args in [[], [@python_native_bridge.Rec::Str("flowchart TD")]] {
    assert_true(
      call_op("render_svg", args)
      is List([Int(1L), Str("invalid-argument"), Str(_)]),
    )
  }
}

///|
test "live_objects lists open-object counts" {
  guard call_op("live_objects", []) is List([Int(0L), List(counts)]) else {
    fail("unexpected live_objects response")
  }
  for entry in counts {
    assert_true(entry is List([Str(_), Int(_)]))
  }
}

///|
test "severity names are lowercase" {
  assert_eq(@python_native_bridge.severity_name(Error), "error")
  assert_eq(@python_native_bridge.severity_name(Warning), "warning")
  assert_eq(@python_native_bridge.severity_name(Info), "info")
}

///|
test "echo returns its arguments" {
  let args : Array[@python_native_bridge.Rec] = [
    Null,
    Int(-9223372036854775808L),
    Str("𝔘"),
    Bin(b"\x00"),
  ]
  guard call_op("echo", args) is List([Int(0L), List(echoed)]) else {
    fail("unexpected echo response")
  }
  assert_eq(
    @python_native_bridge.Rec::List(echoed),
    @python_native_bridge.Rec::list(args),
  )
}
