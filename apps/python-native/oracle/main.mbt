///|
/// Writes the direct output of `@mermaid.render_svg` for each `*.mmd` fixture.
///
/// Usage: `oracle <fixtures-dir> <output-dir>`. For each fixture `name.mmd`, it
/// writes `name.svg` when there is output, and `name.result.txt` with the media
/// type, the output state and one line per diagnostic. It does not use the
/// Python boundary code, so the Python tests can compare against it.
async fn main {
  let args = @env.args()
  guard args.length() == 3 else {
    eprintln("Usage: oracle <fixtures-dir> <output-dir>")
    @sys.exit(2)
  }
  let fixtures = args[1]
  let output = args[2]
  try {
    let names = @fs.readdir(fixtures).filter(name => name.has_suffix(".mmd"))
    names.sort()
    for name in names {
      let stem = name.view(end_offset=name.length() - 4).to_owned()
      let source = @utf8.decode(@fs.read_file("\{fixtures}/\{name}").binary())
      let rendered = @mermaid.render_svg(source)
      if rendered.output is Some(svg) {
        @fs.write_file("\{output}/\{stem}.svg", @utf8.encode(svg))
      }
      @fs.write_file(
        "\{output}/\{stem}.result.txt",
        @utf8.encode(result_text(rendered)),
      )
    }
    println("oracle: wrote \{names.length()} results to \{output}")
  } catch {
    error => {
      eprintln("oracle: \{error}")
      @sys.exit(1)
    }
  }
}

///|
/// The media type, the output state and the diagnostics of `rendered`, one
/// field per tab-separated line.
fn result_text(rendered : @render.Rendered) -> String {
  let buf = StringBuilder()
  buf.write_string("media_type\t\{rendered.media_type}\n")
  let state = if rendered.output is Some(_) { "present" } else { "absent" }
  buf.write_string("output\t\{state}\n")
  for d in rendered.diagnostics {
    let severity = match d.severity {
      Error => "error"
      Warning => "warning"
      Info => "info"
    }
    let span = match d.span {
      Some(s) =>
        "\{s.start.line}:\{s.start.column}:\{s.start.offset}-\{s.end.line}:\{s.end.column}:\{s.end.offset}"
      None => "-"
    }
    buf.write_string(
      "diagnostic\t\{severity}\t\{d.code}\t\{span}\t\{escape(d.message)}\n",
    )
  }
  buf.to_string()
}

///|
fn escape(text : String) -> String {
  let buf = StringBuilder()
  for c in text {
    match c {
      '\\' => buf.write_string("\\\\")
      '\t' => buf.write_string("\\t")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      _ => buf.write_char(c)
    }
  }
  buf.to_string()
}
