///|
/// Internal failures become public diagnostics at the API boundary.
priv suberror RasterFailure {
  RasterInvalid(String, String, String?)
}

///|
fn raster_unsupported(message : String) -> RasterFailure {
  RasterInvalid("raster/unsupported-input", message, None)
}

///|
fn raster_diagnostic(error : RasterFailure) -> RasterDiagnostic {
  match error {
    RasterInvalid(code, message, source_id) => { code, message, source_id, }
  }
}
