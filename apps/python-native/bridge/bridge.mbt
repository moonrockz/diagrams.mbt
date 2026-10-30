///|
/// The version of the private C boundary.
///
/// Version 2 has one structured entry point, `call`: an encoded request
/// record in, an encoded response record out (see `record.mbt` and
/// `dispatch.mbt`). Version 1 returned rendering results as JSON text.
///
/// Change it when the exported functions, the record format or the meaning
/// of an operation change. The Python adapter refuses a library with another
/// version. It is independent of the package and query-language versions.
pub fn abi_version() -> Int32 {
  2
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
