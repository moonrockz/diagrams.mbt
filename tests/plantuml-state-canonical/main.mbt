///|
fn main {
  let outputs : Map[String, Json] = Map([])
  for (name, source, _) in @corpus.fixtures {
    if name.has_prefix("canonical/") { continue }
    let read = @plantuml.read(source)
    if read.diagnostics.iter().any(d => d.severity == Error) { continue }
    if read.document is Some(document) && @plantuml.to_diagram(document).diagram != None && @plantuml.print(document).output is Some(source) {
      outputs[name] = Json(source)
    }
  }
  println(Json(outputs).stringify())
}
