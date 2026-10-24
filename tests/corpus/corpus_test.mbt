///|
test "the corpus has every Mermaid 12.2.0 sequence example" {
  assert_eq(@corpus.mermaid_12_2_0.length(), 38)
  assert_eq(@corpus.mermaid_12_2_0[0].name, "01")
  assert_eq(@corpus.mermaid_12_2_0[37].name, "38")
}

///|
test "each embedded example has the digest of its frozen file" {
  for e in @corpus.mermaid_12_2_0 {
    let actual = @crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(e.source)))
    assert_eq(actual, e.sha256, msg="example \{e.name}")
  }
}
