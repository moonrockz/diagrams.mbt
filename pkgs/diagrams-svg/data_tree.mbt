///|
fn paint_data_tree(
  _view : @data_tree.DataTree,
  _theme : @theme.Theme,
  _mode : Mode,
  _id_prefix : String?,
  _limits : @data_tree_layout.Limits,
) -> @render.Rendered {
  @render.Rendered::failed("image/svg+xml", [
    @diagrams.Diagnostic::error(
      "data-tree/render-unavailable", "Data-tree rendering is not available",
    ),
  ])
}

///|
/// Scene geometry for a data tree: the canonical render, the connector paths
/// and the box/row bindings, all from one measured layout.
fn data_tree_scene(
  _renderer : SvgRenderer,
  _view : @data_tree.DataTree,
  _catalog : @animation.Catalog,
  _output_units : Int,
) -> Result[
  (@render.Rendered, Array[(@animation.Occurrence, String)], Array[NodeBinding]),
  ReadOnlyArray[@diagrams.Diagnostic],
] {
  Err([
    @diagrams.Diagnostic::error(
      "data-tree/render-unavailable", "Data-tree rendering is not available",
    ),
  ])
}
