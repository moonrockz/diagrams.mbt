///|
test "all six exact corpus inputs have the recorded SHA-256" {
  assert_eq(@corpus.inputs.length(), 6)
  for input in @corpus.inputs {
    assert_eq(@crypto.bytes_to_hex_string(@crypto.sha256(@utf8.encode(input.source))), input.sha256, msg=input.name)
  }
}
