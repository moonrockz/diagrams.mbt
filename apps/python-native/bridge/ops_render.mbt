///|
/// Rendering operations. `render_svg(source : bytes)` returns
/// `(media_type, output, diagnostics)`. `output` is the SVG text or `None`.
/// Each diagnostic is `(code, severity, message, span)` and a span is
/// `((line, column, offset), (line, column, offset))` or `None`.
///
/// `echo(args...)` returns its arguments as one list. It runs no domain code;
/// the adapter tests use it to check the record codec in both directions.
/// The measurement operations of `ops_measure.mbt` are reached from here.
fn render_op(op : String, args : ArrayView[Rec]) -> Rec? raise BridgeError {
  match op {
    "echo" => Some(List(ReadOnlyArray::from_array(args.to_owned())))
    "render_svg" =>
      match args.get(0) {
        Some(Bin(source)) => Some(rendered_record(render_svg_bytes(source)))
        _ => raise BridgeError("invalid-argument", "Argument 0 must be bytes.")
      }
    _ => measure_op(op, args)
  }
}

///|
/// Decodes UTF-8 `source` and renders it. Source that is not valid UTF-8 gives
/// the error diagnostic `python/invalid-utf8` and no output; the renderer is
/// not called.
pub fn render_svg_bytes(source : BytesView) -> @render.Rendered {
  let text = @utf8.decode(source) catch {
    _ => {
      let invalid = @diagrams.Diagnostic::error(
        "python/invalid-utf8", "The source is not valid UTF-8.",
      )
      return @render.Rendered::failed("image/svg+xml", [invalid])
    }
  }
  @mermaid.render_svg(text)
}

///|
fn rendered_record(rendered : @render.Rendered) -> Rec {
  Rec::list([
    Str(rendered.media_type),
    Rec::str_opt(rendered.output),
    Rec::list(rendered.diagnostics.iter().map(diagnostic_record).to_array()),
  ])
}

///|
fn diagnostic_record(d : @diagrams.Diagnostic) -> Rec {
  Rec::list([
    Str(d.code),
    Str(severity_name(d.severity)),
    Str(d.message),
    match d.span {
      Some(span) =>
        Rec::list([position_record(span.start), position_record(span.end)])
      None => Null
    },
  ])
}

///|
fn position_record(p : @diagrams.Position) -> Rec {
  Rec::list([Rec::int(p.line), Rec::int(p.column), Rec::int(p.offset)])
}
