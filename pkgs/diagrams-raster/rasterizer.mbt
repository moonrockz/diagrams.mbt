///|
/// An explicit font/limit profile for hosts and offline workers. This path
/// carries no bundled font fallback; callers supply their chosen font bytes.
pub struct Rasterizer {
  fonts : FontSet
  limits : RasterLimits
}

///|
pub fn Rasterizer::new(
  fonts : FontSet,
  limits~ : RasterLimits = RasterLimits::default(),
) -> Rasterizer {
  { fonts, limits, }
}

///|
pub fn Rasterizer::rasterize(
  self : Rasterizer,
  source : String,
  options~ : StillOptions = StillOptions::new(),
) -> RasterResult {
  rasterize_explicit(source, options, self.fonts, self.limits)
}

///|
pub fn Rasterizer::export_gif_data(
  self : Rasterizer,
  data : Json,
  plan? : Json,
  options~ : GifOptions = GifOptions::new(),
) -> RasterResult {
  export_gif_data_explicit(data, plan, options, () => self.fonts, self.limits)
}
