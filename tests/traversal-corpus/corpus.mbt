///|
/// A corpus file and its exact text.
pub struct CorpusFile {
  name : String
  text : String
}

///|
/// The content of the corpus file `name`, from `fixtures/`.
pub fn file(name : String) -> String? {
  files.iter().find_first(f => f.name == name).map(f => f.text)
}

///|
/// The names of the `.bpmn` fixtures, in file-name order.
pub fn fixture_names() -> Array[String] {
  files
  .iter()
  .filter(f => f.name.has_suffix(".bpmn"))
  .map(f => f.name)
  .to_array()
}

///|
/// The normalized text of each fixture and of the deep tree, keyed by the
/// name of its file in `expected/`, in name order.
pub fn outputs() -> Array[(String, String)] {
  let out = fixture_names().map(name => {
    let stem = name.view(end_offset=name.length() - 5).to_owned()
    (stem + ".txt", normalize(name, file))
  })
  out.push(("deep.txt", normalize_deep()))
  out.sort_by((a, b) => a.0.compare(b.0))
  out
}
