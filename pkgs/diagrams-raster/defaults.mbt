///|
pub fn Rgba::new(
  red : Int32,
  green : Int32,
  blue : Int32,
  alpha~ : Int32 = 255,
) -> Rgba {
  { red, green, blue, alpha, }
}

///|
pub fn Rgba::transparent() -> Rgba {
  { red: 0, green: 0, blue: 0, alpha: 0, }
}

///|
pub fn Rgba::white() -> Rgba {
  { red: 255, green: 255, blue: 255, alpha: 255, }
}

///|
pub fn StillOptions::new(
  format~ : StillFormat = Png,
  size~ : RasterSize = Original,
  background~ : Rgba = Rgba::transparent(),
  theme~ : ExportTheme = Light,
) -> StillOptions {
  { format, size, background, theme, }
}

///|
pub fn RasterLimits::default() -> RasterLimits {
  {
    max_source_units: 16777216,
    max_svg_nodes: 200000,
    max_dimension: 16384,
    max_pixels: 16777216L,
    max_glyphs: 100000,
    max_output_bytes: 33554432,
    max_frames: 300,
    max_cumulative_pixels: 67108864L,
  }
}

///|
pub fn FontFace::new(
  family : String,
  data : Bytes,
  weight~ : Int32 = 400,
  italic~ : Bool = false,
) -> FontFace {
  { family, data, weight, italic, }
}

///|
pub fn FontSet::new(
  faces : ArrayView[FontFace],
  fallback_families~ : ArrayView[String] = [],
) -> FontSet {
  {
    faces: ReadOnlyArray::from_array(faces),
    fallback_families: ReadOnlyArray::from_array(fallback_families),
  }
}

///|
/// The licensed default profile maps the writer's documented monospaced stack
/// to Noto Sans Mono, with Noto Sans Symbols 2 for required diagram symbols.
pub fn FontSet::default() -> FontSet {
  let regular = @base64.decode_lossy(
    default_regular_base64,
    ignore_whitespace=true,
  )
  let bold = @base64.decode_lossy(default_bold_base64, ignore_whitespace=true)
  let symbols = @base64.decode_lossy(
    default_symbols_base64,
    ignore_whitespace=true,
  )
  let faces : Array[FontFace] = []
  for
    family in [
      "JetBrains Mono", "Noto Sans Mono", "ui-monospace", "SFMono-Regular", "Menlo",
      "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace",
    ] {
    faces.push(FontFace::new(family, regular))
    faces.push(FontFace::new(family, bold, weight=600))
    faces.push(FontFace::new(family, bold, weight=700))
  }
  faces.push(FontFace::new("Noto Sans Symbols 2", symbols))
  FontSet::new(faces, fallback_families=["Noto Sans Symbols 2"])
}
