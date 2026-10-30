///|
/// The C entry points of the Python binding. They are the only MoonBit
/// functions that the CPython adapter calls, apart from the generated
/// `moonbit_init`.
///
/// On the pinned compiler, an exported function borrows its `Bytes` argument
/// and returns a new reference. The caller releases both with
/// `moonbit_decref`. The MoonBit documentation does not state this convention
/// for exports, so it was measured (see the feasibility report).
///
/// The adapter calls these functions only while it holds its runtime lock.

///|
#export_name("diagrams_py_abi_version")
pub fn abi_version() -> Int32 {
  @bridge.abi_version()
}

///|
/// The structured boundary: one encoded request record in, one encoded
/// response record out. See `@bridge.call`. Same ownership as above.
#export_name("diagrams_py_call")
pub fn call(request : Bytes) -> Bytes {
  @bridge.call(request)
}
