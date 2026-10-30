///|
/// The C entry points of the spike. They are the only MoonBit functions that
/// the CPython adapter calls, apart from the generated `moonbit_init`.
///
/// On the pinned compiler, an exported function borrows its `Bytes` argument
/// and returns a new reference. The caller releases both with
/// `moonbit_decref`. The MoonBit documentation does not state this convention
/// for exports, so the spike measured it (see the feasibility report).

///|
#export_name("diagrams_py_abi_version")
pub fn abi_version() -> Int {
  @bridge.abi_version()
}

///|
#export_name("diagrams_py_render_svg")
pub fn render_svg(source : Bytes) -> Bytes {
  @bridge.render_svg_utf8(source)
}
