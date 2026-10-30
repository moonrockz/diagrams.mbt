///|
test "every fixture and the deep tree equal their checked-in normalized text" {
  let actual = @corpus.outputs()
  assert_eq(
    actual.map(p => p.0),
    @corpus.expected.iter().map(f => f.name).to_array(),
  )
  for i, pair in actual {
    let (name, text) = pair
    let want = @corpus.expected[i].text
    if text != want {
      fail(
        "normalized traversal differs for \{name}; run mise run traversal-corpus:expected",
      )
    }
  }
}

///|
test "the corpus covers each required document family" {
  let names = @corpus.fixture_names()
  for
    required in [
      "process.bpmn", "choreography.bpmn", "vendor.bpmn", "duplicates.bpmn", "crlf-nonbmp.bpmn",
      "import-root.bpmn", "broken.bpmn",
    ] {
    assert_true(names.contains(required))
  }
  let crlf = @corpus.file("crlf-nonbmp.bpmn").unwrap()
  assert_true(crlf.contains("\r\n"))
  assert_true(crlf.contains("\u{1D518}"))
}
