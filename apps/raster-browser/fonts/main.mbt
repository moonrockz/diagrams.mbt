///|
fn escape(text : String) -> String {
  text.replace_all(old="&", new="&amp;").replace_all(old="<", new="&lt;").replace_all(old=">", new="&gt;")
}

///|
async fn collect(root : String, output : StringBuilder, seen : Map[String, Bool]) -> Unit {
  let entries = @fs.readdir(root)
  entries.sort()
  for entry in entries {
    let path = root + "/" + entry
    if @fs.kind(path) is Directory { collect(path, output, seen); continue }
    if !entry.has_suffix(".svg") { continue }
    let reader = @xml.Reader::from_string(@fs.read_file(path).text())
    while true {
      let event = reader.read_event()
      match event.kind {
        Eof => break
        Text(value) | CData(value) => {
          let mut i = 0
          while i < value.length() {
            let code = value.code_unit_at(i).to_int()
            let end = if code >= 0xd800 && code <= 0xdbff && i + 1 < value.length() { i + 2 } else { i + 1 }
            let scalar = value[i:end].to_owned()
            if code != 9 && code != 10 && code != 13 && !seen.contains(scalar) { seen[scalar] = true; output.write_string(escape(scalar)) }
            i = end
          }
        }
        _ => ()
      }
    }
  }
}

///|
async fn main {
  try {
    let args = @env.args()
    guard args.length() == 3 else { raise Failure("Usage: raster-browser/fonts OUTPUT_JSON SVG_DIRECTORY") }
    let fonts = if args[2] == "--default" { @raster.FontSet::default() } else {
      let text = StringBuilder()
      collect(args[2], text, Map([]))
      let source = "<svg width=\"1\" height=\"1\"><text x=\"0\" y=\"0\">" + text.to_string() + "</text></svg>"
      let subset = @raster.FontSet::default().subset_for_svg(source)
      guard subset.fonts is Some(fonts) else { raise Failure(subset.diagnostics.iter().map(d => d.message).to_array().join("; ")) }
      fonts
    }
    let encoded = fonts.export_data()
    guard encoded.data is Some(data) else { raise Failure(encoded.diagnostics.iter().map(d => d.message).to_array().join("; ")) }
    @fs.write_file(args[1], data.stringify())
  } catch { error => { eprintln(error.to_string()); @sys.exit(1) } }
}
