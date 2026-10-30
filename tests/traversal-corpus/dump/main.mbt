///|
/// Prints the MoonBit oracle text of every corpus fixture. Each file starts
/// with a line `=== <name>`. `mise run traversal-corpus:expected` writes them
/// to `tests/traversal-corpus/expected/`.
fn main {
  for pair in @corpus.outputs() {
    // Each text ends with one line break, which println restores.
    let text = pair.1
    println("=== " + pair.0 + "\n" + text[0:text.length() - 1].to_owned())
  }
}
