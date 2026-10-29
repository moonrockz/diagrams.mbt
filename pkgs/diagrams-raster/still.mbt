///|
/// Internal RGBA8 exchange between the still encoder and GIF sampler.
priv struct RasterPixels {
  width : Int32
  height : Int32
  data : Bytes
}

///|
fn raster_fail(
  code : String,
  message : String,
  source_id? : String,
) -> RasterFailure {
  RasterInvalid(code, message, source_id)
}

///|
fn validate_raster_limits(limits : RasterLimits) -> Unit raise RasterFailure {
  guard limits.max_source_units > 0 &&
    limits.max_svg_nodes > 0 &&
    limits.max_dimension > 0 &&
    limits.max_pixels > 0L &&
    limits.max_glyphs > 0 &&
    limits.max_output_bytes > 0 &&
    limits.max_frames > 0 &&
    limits.max_cumulative_pixels > 0L else {
    raise raster_fail(
      "raster/invalid-limits", "All raster budgets must be positive",
    )
  }
}

///|
fn validate_background(color : Rgba) -> Unit raise RasterFailure {
  for value in [color.red, color.green, color.blue, color.alpha] {
    guard value >= 0 && value <= 255 else {
      raise raster_fail(
        "raster/invalid-background", "Color components must be integers from 0 to 255",
      )
    }
  }
}

///|
fn checked_pixels(
  width : Int32,
  height : Int32,
  limits : RasterLimits,
) -> Int32 raise RasterFailure {
  guard width > 0 &&
    height > 0 &&
    width <= limits.max_dimension &&
    height <= limits.max_dimension else {
    raise raster_fail(
      "raster/dimension-limit", "Output dimensions exceed the configured dimension budget",
    )
  }
  let pixels = width.to_int64() * height.to_int64()
  guard pixels <= limits.max_pixels && pixels <= 536870911L else {
    raise raster_fail(
      "raster/pixel-limit", "Output pixels exceed the configured pixel budget",
    )
  }
  pixels.to_int()
}

///|
fn still_dimensions(
  source : String,
  size : RasterSize,
  limits : RasterLimits,
) -> (Int32, Int32) raise RasterFailure {
  validate_raster_size(size, limits)
  let nodes = parse_svg_xml(source, max_nodes=limits.max_svg_nodes)
  let roots = nodes[0].children.filter(i => nodes[i].kind == Element)
  let root = nodes[roots[0]]
  let mut width = 0.0
  let mut height = 0.0
  if node_attr(root, "viewBox") is Some(box) {
    let parts = box
      .replace(old=",", new=" ")
      .split(" ")
      .filter(s => s.trim() != "")
      .to_array()
    guard parts.length() == 4 else {
      raise raster_fail(
        "raster/malformed-svg", "Generated viewBox needs four values",
      )
    }
    width = num(parts[2].to_owned())
    height = num(parts[3].to_owned())
  } else {
    width = num(node_attr(root, "width").unwrap_or("0"))
    height = num(node_attr(root, "height").unwrap_or("0"))
  }
  guard width > 0.0 &&
    height > 0.0 &&
    raster_finite(width) &&
    raster_finite(height) else {
    raise raster_fail(
      "raster/malformed-svg", "Generated SVG requires finite positive dimensions",
    )
  }
  let scale = match size {
    Original => 1.0
    Scale(value) => value
    Width(value) => value.to_double() / width
    Height(value) => value.to_double() / height
    Fit(w, h) => {
      guard w > 0 && h > 0 else {
        raise raster_fail(
          "raster/invalid-size", "Fit dimensions must be positive",
        )
      }
      (w.to_double() / width).min(h.to_double() / height)
    }
  }
  guard scale > 0.0 && raster_finite(scale) else {
    raise raster_fail(
      "raster/invalid-scale", "Scale must be finite and positive",
    )
  }
  // Keep explicit axes exact, and derive the other axis without introducing
  // a divide-then-multiply overshoot at an integral aspect result.
  let (w, h) = match size {
    Width(value) => (value.to_double(), ratio_dimension(height, value, width))
    Height(value) => (ratio_dimension(width, value, height), value.to_double())
    Fit(max_w, max_h) => {
      let width_limited = if width <= 2147483647.0 && height <= 2147483647.0 &&
        width.floor() == width && height.floor() == height {
        max_w.to_int64() * height.to_int().to_int64() <=
          max_h.to_int64() * width.to_int().to_int64()
      } else {
        max_w.to_double() / width <= max_h.to_double() / height
      }
      if width_limited {
        (max_w.to_double(), ratio_dimension(height, max_w, width).min(max_h.to_double()))
      } else {
        (ratio_dimension(width, max_h, height).min(max_w.to_double()), max_h.to_double())
      }
    }
    _ => ((width * scale).ceil(), (height * scale).ceil())
  }
  guard raster_finite(w) &&
    raster_finite(h) &&
    w <= limits.max_dimension.to_double() &&
    h <= limits.max_dimension.to_double() else {
    raise raster_fail(
      "raster/dimension-limit", "Scaled output exceeds the dimension budget",
    )
  }
  let result = (w.to_int(), h.to_int())
  ignore(checked_pixels(result.0, result.1, limits))
  result
}

///|
fn encode_png_pixels(
  pixels : RasterPixels,
  limits : RasterLimits,
) -> Bytes raise RasterFailure {
  let encoded = @image.encode_png({
    width: pixels.width,
    height: pixels.height,
    data: pixels.data,
  }) catch {
    _ => raise raster_fail("raster/png-encoding", "PNG encoding failed")
  }
  guard encoded.length() <= limits.max_output_bytes else {
    raise raster_fail(
      "raster/output-limit", "PNG exceeds the encoded byte budget",
    )
  }
  encoded
}

///|
fn encode_jpeg_pixels(
  pixels : RasterPixels,
  quality : Int32,
  limits : RasterLimits,
) -> Bytes raise RasterFailure {
  guard quality >= 1 && quality <= 100 else {
    raise raster_fail(
      "raster/invalid-quality", "JPEG quality must be from 1 to 100",
    )
  }
  let encoded = raster_encode_jpeg_unchecked(
    { width: pixels.width, height: pixels.height, data: pixels.data, },
    quality~,
  ) catch {
    _ => raise raster_fail("raster/jpeg-encoding", "JPEG encoding failed")
  }
  guard encoded.length() <= limits.max_output_bytes else {
    raise raster_fail(
      "raster/output-limit", "JPEG exceeds the encoded byte budget",
    )
  }
  encoded
}

///|
/// Still conversion always receives the complete canonical SVG. Viewport and
/// playback state have no representation in this API.
pub fn rasterize(
  source : String,
  options~ : StillOptions = StillOptions::new(),
  fonts? : FontSet,
  limits~ : RasterLimits = RasterLimits::default(),
) -> RasterResult {
  try {
    validate_raster_limits(limits)
    validate_background(options.background)
    validate_raster_size(options.size, limits)
    guard source.length() <= limits.max_source_units else {
      raise raster_fail(
        "raster/source-limit", "Generated SVG exceeds the source budget",
      )
    }
    if options.format is Jpeg(quality~) {
      guard quality >= 1 && quality <= 100 else {
        raise raster_fail(
          "raster/invalid-quality", "JPEG quality must be from 1 to 100",
        )
      }
      guard options.background.alpha == 255 else {
        raise raster_fail(
          "raster/jpeg-background", "JPEG requires an explicit opaque background",
        )
      }
    }
    ignore(still_dimensions(source, options.size, limits))
    rasterize_explicit(
      source,
      options,
      fonts.unwrap_or_else(FontSet::default),
      limits,
    )
  } catch {
    error => { image: None, diagnostics: [raster_diagnostic(error)], }
  }
}

///|
/// The browser Rasterizer supplies fonts explicitly, keeping default font
/// literals out of its compiled adapter through ordinary dead-code elimination.
fn rasterize_explicit(
  source : String,
  options : StillOptions,
  fonts : FontSet,
  limits : RasterLimits,
) -> RasterResult {
  try {
    validate_raster_limits(limits)
    validate_background(options.background)
    guard source.length() <= limits.max_source_units else {
      raise raster_fail(
        "raster/source-limit", "Generated SVG exceeds the source budget",
      )
    }
    if options.format is Jpeg(quality~) {
      guard quality >= 1 && quality <= 100 else {
        raise raster_fail(
          "raster/invalid-quality", "JPEG quality must be from 1 to 100",
        )
      }
      guard options.background.alpha == 255 else {
        raise raster_fail(
          "raster/jpeg-background", "JPEG requires an explicit opaque background",
        )
      }
    }
    let (width, height) = still_dimensions(source, options.size, limits)
    let pixels = render_rgba(
      source,
      width,
      height,
      options.theme,
      fonts,
      options.background,
      limits,
    )
    let (bytes, media_type, format) = match options.format {
      Png => (encode_png_pixels(pixels, limits), "image/png", RasterFormat::Png)
      Jpeg(quality~) =>
        (
          encode_jpeg_pixels(pixels, quality, limits),
          "image/jpeg",
          RasterFormat::Jpeg,
        )
    }
    {
      image: Some({ bytes, media_type, width, height, format, }),
      diagnostics: [],
    }
  } catch {
    error => { image: None, diagnostics: [raster_diagnostic(error)], }
  }
}

///|
fn render_rgba(
  source : String,
  width : Int32,
  height : Int32,
  theme : ExportTheme,
  fonts : FontSet,
  background : Rgba,
  limits : RasterLimits,
) -> RasterPixels raise RasterFailure {
  validate_raster_limits(limits)
  validate_background(background)
  ignore(checked_pixels(width, height, limits))
  guard source.length() <= limits.max_source_units else {
    raise raster_fail(
      "raster/source-limit", "Generated SVG exceeds the source budget",
    )
  }
  let parsed = load_font_set(fonts, limits)
  let normalized = normalize_generated_svg(
    source,
    match theme {
      Light => "light"
      Dark => "dark"
    },
    parsed,
    limits,
  )
  guard normalized.length() <= limits.max_source_units else {
    raise raster_fail(
      "raster/normalized-limit", "Outlined SVG exceeds the derived source budget",
    )
  }
  render_normalized_rgba(normalized, width, height, theme, background, limits)
}

///|
/// GIF can normalize the canonical scene once, then decorate the outlined
/// derived scene and use this helper for each bounded logical sample.
fn render_normalized_rgba(
  source : String,
  width : Int32,
  height : Int32,
  theme : ExportTheme,
  background : Rgba,
  limits : RasterLimits,
) -> RasterPixels raise RasterFailure {
  let pixels = checked_pixels(width, height, limits)
  guard source.length() <= limits.max_source_units else {
    raise raster_fail(
      "raster/source-limit", "Derived SVG exceeds the source budget",
    )
  }
  let environment = @backend.RenderEnvironment::default()
  let options = {
    ..@backend.RenderOptions::default(),
    environment: {
      ..environment,
      color_scheme: match theme {
        Light => Light
        Dark => Dark
      },
    },
    max_external_depth: 0,
    max_external_resources: 0,
    max_external_bytes: 0,
  }
  let rendered = @backend.render_svg(source, width, height, options)
  guard rendered.diagnostics.length() == 0 else {
    let diagnostic = rendered.diagnostics[0]
    raise raster_fail(
      "raster/backend-resource",
      "Generated SVG has an unresolved, cyclic or unsupported resource",
      source_id=diagnostic.node_id,
    )
  }
  let rgba = FixedArray::make(pixels * 4, b'\x00')
  for y in 0..<height {
    for x in 0..<width {
      let color = rendered.image.get_pixel(x, y)
      let offset = (y * width + x) * 4
      let back_alpha = (background.alpha * (255 - color.a) + 127) / 255
      let alpha = color.a + back_alpha
      if alpha > 0 {
        rgba[offset] = ((
          color.r * color.a + background.red * back_alpha + alpha / 2
        ) /
        alpha).to_byte()
        rgba[offset + 1] = ((
          color.g * color.a + background.green * back_alpha + alpha / 2
        ) /
        alpha).to_byte()
        rgba[offset + 2] = ((
          color.b * color.a + background.blue * back_alpha + alpha / 2
        ) /
        alpha).to_byte()
        rgba[offset + 3] = alpha.to_byte()
      }
    }
  }
  { width, height, data: Bytes::from_array(rgba), }
}

///|
fn raster_finite(value : Double) -> Bool {
  value == value && value.abs() <= 1.7976931348623157e308
}

///|
fn validate_raster_size(
  size : RasterSize,
  limits : RasterLimits,
) -> Unit raise RasterFailure {
  match size {
    Original => ()
    Scale(value) => {
      guard value > 0.0 && raster_finite(value) else {
        raise raster_fail(
          "raster/invalid-scale", "Scale must be finite and positive",
        )
      }
    }
    Width(value) | Height(value) => {
      guard value > 0 && value <= limits.max_dimension else {
        raise raster_fail(
          "raster/invalid-size", "Requested dimension is outside the dimension budget",
        )
      }
    }
    Fit(w, h) => {
      guard w > 0 &&
        h > 0 &&
        w <= limits.max_dimension &&
        h <= limits.max_dimension else {
        raise raster_fail(
          "raster/invalid-size", "Fit dimensions are outside the dimension budget",
        )
      }
    }
  }
}

///|
/// Integral generated dimensions admit an exact, overflow-safe ratio. The
/// largest product of two positive Int32 values fits Int64. Fractional input
/// multiplies before dividing; ratio-first avoids overflow for extreme values.
fn ratio_dimension(axis : Double, requested : Int32, opposite : Double) -> Double {
  if axis <= 2147483647.0 && opposite <= 2147483647.0 &&
    axis.floor() == axis && opposite.floor() == opposite {
    let numerator = axis.to_int().to_int64() * requested.to_int64()
    let denominator = opposite.to_int().to_int64()
    let extra = if numerator % denominator == 0L { 0L } else { 1L }
    let rounded = numerator / denominator + extra
    return rounded.to_double()
  }
  let product = axis * requested.to_double()
  let value = if raster_finite(product) {
    product / opposite
  } else {
    (axis / opposite) * requested.to_double()
  }
  value.ceil().max(1.0)
}
