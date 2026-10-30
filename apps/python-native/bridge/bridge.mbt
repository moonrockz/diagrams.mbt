///|
/// The version of the bytes-in, bytes-out boundary and of its JSON result.
///
/// Change it when the exported functions or the result format change. The
/// Python adapter refuses a library with another version.
pub fn abi_version() -> Int32 {
  1
}

///|
/// Renders Mermaid `source` with the default SVG renderer and returns the
/// boundary result as JSON text.
///
/// The result has `format`, `media_type`, `output` (a string or `null`) and
/// `diagnostics`. Span positions are the values of `@diagrams.Position`, so
/// lines and columns are 1-based. Offsets and columns count UTF-16 code units.
pub fn render_svg_json(source : String) -> String {
  result_json(@mermaid.render_svg(source)).stringify()
}

///|
/// Decodes UTF-8 `source`, renders it and returns the JSON result as UTF-8.
///
/// Source that is not valid UTF-8 gives a result with the error diagnostic
/// `python/invalid-utf8` and no output. The renderer is not called.
pub fn render_svg_utf8(source : BytesView) -> Bytes {
  let json = try @utf8.decode(source) catch {
    _ => {
      let invalid = @diagrams.Diagnostic::error(
        "python/invalid-utf8", "The source is not valid UTF-8.",
      )
      result_json(@render.Rendered::failed("image/svg+xml", [invalid])).stringify()
    }
  } noraise {
    text => render_svg_json(text)
  }
  @utf8.encode(json)
}

///|
fn result_json(rendered : @render.Rendered) -> Json {
  {
    "format": Json(abi_version()),
    "media_type": Json(rendered.media_type),
    "output": match rendered.output {
      Some(text) => Json(text)
      None => Json(null)
    },
    "diagnostics": Json(
      rendered.diagnostics.iter().map(diagnostic_json).to_array(),
    ),
  }
}

///|
fn diagnostic_json(d : @diagrams.Diagnostic) -> Json {
  {
    "code": Json(d.code),
    "severity": Json(severity_name(d.severity)),
    "message": Json(d.message),
    "span": match d.span {
      Some(span) =>
        { "start": position_json(span.start), "end": position_json(span.end) }
      None => Json(null)
    },
  }
}

///|
fn position_json(p : @diagrams.Position) -> Json {
  { "line": Json(p.line), "column": Json(p.column), "offset": Json(p.offset) }
}

///|
/// The lowercase name of `severity`, as the boundary result writes it.
pub fn severity_name(severity : @diagrams.Severity) -> String {
  match severity {
    Error => "error"
    Warning => "warning"
    Info => "info"
  }
}
