///|
/// Explicit font bytes for an offline worker, deduplicated across face aliases.
pub struct FontDataResult {
  data : Json?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
fn validate_font_metadata(
  fonts : FontSet,
  limits : RasterLimits,
) -> Unit raise RasterFailure {
  let mut units = 0L
  for face in fonts.faces {
    units += face.family.length().to_int64()
  }
  for family in fonts.fallback_families {
    units += family.length().to_int64()
  }
  guard units <= limits.max_source_units.to_int64() else {
    raise raster_fail(
      "raster/font-limit", "Font family metadata exceeds the source budget",
    )
  }
}

///|
pub fn FontSet::export_data(
  self : FontSet,
  limits~ : RasterLimits = RasterLimits::default(),
) -> FontDataResult {
  try {
    validate_raster_limits(limits)
    validate_font_metadata(self, limits)
    ignore(load_font_set(self, limits))
    let resources : Array[Json] = []
    let indices : Map[String, Int32] = Map([])
    let faces : Array[Json] = []
    for face in self.faces {
      let encoded = @base64.encode(face.data)
      let index = match indices.get(encoded) {
        Some(index) => index
        None => {
          let index = resources.length()
          indices[encoded] = index
          resources.push(Json(encoded))
          index
        }
      }
      faces.push(
        Json({
          "family": Json(face.family),
          "weight": Json(face.weight),
          "italic": Json(face.italic),
          "resource": Json(index),
        }),
      )
    }
    {
      data: Some({
        "version": 1,
        "resources": Json(resources),
        "faces": Json(faces),
        "fallbacks": Json(
          self.fallback_families.iter().map(value => Json(value)).to_array(),
        ),
      }),
      diagnostics: [],
    }
  } catch {
    error => { data: None, diagnostics: [raster_diagnostic(error)], }
  }
}

///|
/// Decode the generated worker font protocol with byte and face budgets, then
/// run the same font validation used by ordinary library callers.
pub fn FontSet::from_export_data(
  data : Json,
  limits~ : RasterLimits = RasterLimits::default(),
) -> FontSubsetResult {
  try {
    validate_raster_limits(limits)
    guard gif_number(gif_field(data, "version")) == 1L else {
      raise raster_fail("raster/font-data", "Unsupported font protocol version")
    }
    let resources : Array[Bytes] = []
    let mut used = 0L
    for value in gif_array(gif_field(data, "resources"), 128) {
      let text = gif_string(value)
      used += text.length().to_int64()
      guard used <= limits.max_source_units.to_int64() * 4L / 3L + 512L else {
        raise raster_fail(
          "raster/font-limit", "Worker font data exceeds its byte budget",
        )
      }
      let bytes = @base64.decode_lossy(text)
      guard @base64.encode(bytes) == text else {
        raise raster_fail(
          "raster/font-data", "Worker font resource is not canonical base64",
        )
      }
      resources.push(bytes)
    }
    let faces : Array[FontFace] = []
    for value in gif_array(gif_field(data, "faces"), 128) {
      let family = gif_string(gif_field(value, "family"))
      let weight = gif_number(gif_field(value, "weight"))
      let italic = gif_boolean(gif_field(value, "italic"))
      let resource = gif_number(gif_field(value, "resource"))
      guard family.length() <= limits.max_source_units &&
        weight >= 1L &&
        weight <= 1000L &&
        resource < resources.length().to_int64() else {
        raise raster_fail("raster/font-data", "Worker font face is invalid")
      }
      faces.push(
        FontFace::new(
          family,
          resources[resource.to_int()],
          weight=weight.to_int(),
          italic~,
        ),
      )
    }
    let fallbacks = gif_array(gif_field(data, "fallbacks"), 128).map(value => {
      gif_string(value)
    })
    let fonts = FontSet::new(faces, fallback_families=fallbacks)
    validate_font_metadata(fonts, limits)
    ignore(load_font_set(fonts, limits))
    { fonts: Some(fonts), diagnostics: [], }
  } catch {
    error => { fonts: None, diagnostics: [raster_diagnostic(error)], }
  }
}
