///|
/// Binary format metadata. Still options exclude GIF; animation has its own
/// bounded interval and sampling options.
pub(all) enum RasterFormat {
  Png
  Jpeg
  Gif
} derive(Eq, Debug)

///|
pub(all) enum ExportTheme {
  Light
  Dark
} derive(Eq, Debug)

///|
pub(all) struct Rgba {
  red : Int32
  green : Int32
  blue : Int32
  alpha : Int32
} derive(Eq, Debug)

///|
pub(all) enum RasterSize {
  Original
  Scale(Double)
  Width(Int32)
  Height(Int32)
  Fit(Int32, Int32)
} derive(Eq, Debug)

///|
/// PNG permits transparent backgrounds. JPEG requires an opaque background
/// and quality between 1 and 100, checked before rendering.
pub(all) enum StillFormat {
  Png
  Jpeg(quality~ : Int32)
} derive(Eq, Debug)

///|
/// Values are checked before source parsing, font parsing or allocation.
pub(all) struct StillOptions {
  format : StillFormat
  size : RasterSize
  background : Rgba
  theme : ExportTheme
} derive(Eq, Debug)

///|
/// A supplied face is selected by family, weight and italic style. The default
/// profile is an explicit licensed set, never a host-font lookup.
pub(all) struct FontFace {
  family : String
  weight : Int32
  italic : Bool
  data : Bytes
}

///|
pub(all) struct FontSet {
  faces : ReadOnlyArray[FontFace]
  fallback_families : ReadOnlyArray[String]
}

///|
/// Limits bound work before unsafe arithmetic and allocation.
pub(all) struct RasterLimits {
  max_source_units : Int32
  max_svg_nodes : Int32
  max_dimension : Int32
  max_pixels : Int64
  max_glyphs : Int32
  max_output_bytes : Int32
  max_frames : Int32
  max_cumulative_pixels : Int64
} derive(Eq, Debug)

///|
pub(all) struct RasterDiagnostic {
  code : String
  message : String
  source_id : String?
} derive(Eq, Debug)

///|
pub(all) struct RasterImage {
  bytes : Bytes
  media_type : String
  width : Int32
  height : Int32
  format : RasterFormat
}

///|
/// Failure has no partial image payload.
pub(all) struct RasterResult {
  image : RasterImage?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
/// Font subsetting reports errors without returning a partial font set.
pub(all) struct FontSubsetResult {
  fonts : FontSet?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
pub extend RasterFormat with Eq::{equal, not_equal}

///|
pub extend RasterFormat with @debug.Debug::{to_repr}

///|
pub extend ExportTheme with Eq::{equal, not_equal}

///|
pub extend ExportTheme with @debug.Debug::{to_repr}

///|
pub extend Rgba with Eq::{equal, not_equal}

///|
pub extend Rgba with @debug.Debug::{to_repr}

///|
pub extend RasterSize with Eq::{equal, not_equal}

///|
pub extend RasterSize with @debug.Debug::{to_repr}

///|
pub extend StillFormat with Eq::{equal, not_equal}

///|
pub extend StillFormat with @debug.Debug::{to_repr}

///|
pub extend StillOptions with Eq::{equal, not_equal}

///|
pub extend StillOptions with @debug.Debug::{to_repr}

///|
pub extend RasterLimits with Eq::{equal, not_equal}

///|
pub extend RasterLimits with @debug.Debug::{to_repr}

///|
pub extend RasterDiagnostic with Eq::{equal, not_equal}

///|
pub extend RasterDiagnostic with @debug.Debug::{to_repr}
