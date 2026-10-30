///|
test "records round trip through the wire format" {
  let value = @python_native_bridge.Rec::list([
    Null,
    Bool(true),
    Bool(false),
    Int(-1L),
    Int(9223372036854775807L),
    Str("Rocket 🚀 𝔘"),
    Bin(b"\x00\xff"),
    @python_native_bridge.Rec::list([]),
    @python_native_bridge.Rec::list([
      Str(""),
      @python_native_bridge.Rec::list([Null]),
    ]),
  ])
  let bytes = @python_native_bridge.encode_record(value)
  assert_eq(@python_native_bridge.decode_record(bytes), value)
}

///|
test "malformed records are refused" {
  for
    bytes in [
      b"", b"\x07", b"\x03\x00", b"\x04\x02\x00\x00\x00\xff\xfe", b"\x00\x00", b"\x06\x05\x00\x00\x00\x00",
    ] {
    let refused = try {
      @python_native_bridge.decode_record(bytes) |> ignore
      false
    } catch {
      BridgeError("invalid-record", _) => true
      _ => false
    }
    assert_true(refused)
  }
}

///|
test "nesting deeper than the limit is refused without host recursion" {
  let bytes = Bytes::makei(100000, i => {
    if i < 99999 {
      b'\x06'
    } else {
      b'\x00'
    }
  })
  // Every list header claims one item, which the input cannot hold, or the
  // depth limit applies first.
  let deep = Bytes::makei(5 * 70 + 1, i => {
    let k = i % 5
    if i == 5 * 70 {
      b'\x00'
    } else if k == 0 {
      b'\x06'
    } else if k == 1 {
      b'\x01'
    } else {
      b'\x00'
    }
  })
  for input in [bytes, deep] {
    let refused = try {
      @python_native_bridge.decode_record(input) |> ignore
      false
    } catch {
      BridgeError("invalid-record", _) => true
      _ => false
    }
    assert_true(refused)
  }
}

///|
test "call reports unknown operations and malformed requests as failures" {
  let unknown = @python_native_bridge.decode_record(
    @python_native_bridge.call(
      @python_native_bridge.encode_record(
        @python_native_bridge.Rec::list([Str("nope")]),
      ),
    ),
  )
  assert_true(unknown is List([Int(1L), Str("unknown-op"), Str(_)]))
  let malformed = @python_native_bridge.decode_record(
    @python_native_bridge.call(b"\x07"),
  )
  assert_true(malformed is List([Int(1L), Str("invalid-record"), Str(_)]))
}

///|
test "registry tokens are generation checked" {
  let registry : @python_native_bridge.Registry[String] = @python_native_bridge.Registry::new(
    9,
  )
  let other : @python_native_bridge.Registry[String] = @python_native_bridge.Registry::new(
    10,
  )
  let a = registry.add("a")
  assert_eq(registry.get(a), "a")
  assert_true(registry.remove(a))
  assert_false(registry.remove(a))
  let b = registry.add("b")
  assert_eq(registry.get(b), "b")
  let code = fn(
    f : () -> Unit raise @python_native_bridge.BridgeError,
  ) -> String {
    try {
      f()
      ""
    } catch {
      BridgeError(code, _) => code
    }
  }
  assert_eq(code(() => registry.get(a) |> ignore), "closed-token")
  assert_eq(code(() => other.get(b) |> ignore), "wrong-token")
  assert_eq(
    code(() => registry.get((9L << 48) | (1L << 24) | 77L) |> ignore),
    "invalid-token",
  )
  assert_eq(code(() => registry.get(-1L) |> ignore), "wrong-token")
  assert_eq(registry.live(), 1)
}
