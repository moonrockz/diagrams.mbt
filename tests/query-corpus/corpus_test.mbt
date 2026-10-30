///|
test "the shared query corpus gives the expected normalized output" {
  let actual = @corpus.run_corpus()
  if actual != @corpus.expected_text {
    // Print the actual text so a reviewer can compare it with the file.
    println("<<<ACTUAL")
    println(actual)
    println("ACTUAL>>>")
  }
  assert_eq(actual, @corpus.expected_text)
}
