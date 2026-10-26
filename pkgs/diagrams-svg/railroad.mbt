///|
priv struct RailroadPaint {
  rendered : @render.Rendered
}

///|
fn paint_railroad(
  _diagram : @render.Diagram,
  _renderer : SvgRenderer,
) -> RailroadPaint {
  {
    rendered: @render.Rendered::failed("image/svg+xml", [
      @diagrams.Diagnostic::error(
        "railroad/render-unavailable", "Railroad rendering is not available",
      ),
    ]),
  }
}

///|
fn railroad_scene(
  _renderer : SvgRenderer,
  _diagram : @render.Diagram,
  _catalog : @animation.Catalog,
  _output_units : Int,
) -> Result[
  (@render.Rendered, Array[(@animation.Occurrence, String)], Array[NodeBinding]),
  ReadOnlyArray[@diagrams.Diagnostic],
] {
  Err([
    @diagrams.Diagnostic::error(
      "railroad/render-unavailable", "Railroad rendering is not available",
    ),
  ])
}
