///|
priv struct ParsedFontFace {
  face : FontFace
  font : @font.TTFont
}

///|
priv struct ParsedFontSet {
  faces : Array[ParsedFontFace]
  fallbacks : ReadOnlyArray[String]
}

///|
fn load_font_set(
  fonts : FontSet,
  limits : RasterLimits,
) -> ParsedFontSet raise RasterFailure {
  guard fonts.faces.length() > 0 && fonts.faces.length() <= 128 else {
    raise raster_fail(
      "raster/font-limit", "Supply from 1 to 128 explicit font faces",
    )
  }
  let parsed : Array[ParsedFontFace] = []
  let cache : Array[(Bytes, @font.TTFont)] = []
  let mut units = 0L
  for face in fonts.faces {
    guard face.family != "" && face.weight >= 1 && face.weight <= 1000 else {
      raise raster_fail(
        "raster/font-options", "Invalid explicit font family or weight",
      )
    }
    let mut found : @font.TTFont? = None
    for (data, font) in cache {
      if data == face.data {
        found = Some(font)
        break
      }
    }
    let font = match found {
      Some(font) => font
      None => {
        units += face.data.length().to_int64()
        guard units <= limits.max_source_units.to_int64() else {
          raise raster_fail(
            "raster/font-limit", "Total unique font bytes exceed the source budget",
          )
        }
        let safe = validated_font_bytes(face.data, limits)
        guard @font.parse_font(safe) is Some(font) else {
          raise raster_fail(
            "raster/font-data", "TrueType outline parser rejected the validated font",
          )
        }
        cache.push((face.data, font))
        font
      }
    }
    parsed.push({ face, font, })
  }
  { faces: parsed, fallbacks: fonts.fallback_families, }
}

///|
fn font_for_text(
  fonts : ParsedFontSet,
  family : String,
  weight : String,
  style : String,
  source_id : String,
) -> ParsedFontFace raise RasterFailure {
  let weight = match weight {
    "normal" => 400
    "bold" => 700
    _ =>
      @string.parse_int(weight) catch {
        _ =>
          raise raster_fail(
            "raster/font-style",
            "Unsupported font weight",
            source_id~,
          )
      }
  }
  let italic = match style {
    "normal" => false
    "italic" | "oblique" => true
    _ =>
      raise raster_fail(
        "raster/font-style",
        "Unsupported font style",
        source_id~,
      )
  }
  for part in family.split(",") {
    let name = part
      .trim()
      .to_owned()
      .replace(old="'", new="")
      .replace(old="\"", new="")
    for parsed in fonts.faces {
      if parsed.face.family == name &&
        parsed.face.weight == weight &&
        parsed.face.italic == italic {
        return parsed
      }
    }
  }
  raise raster_fail(
    "raster/font-style",
    "No supplied face matches the required family, weight and style",
    source_id~,
  )
}

///|
fn glyph_face(
  fonts : ParsedFontSet,
  preferred : ParsedFontFace,
  codepoint : Int32,
  source_id : String,
) -> ParsedFontFace raise RasterFailure {
  if preferred.font.glyph_index(codepoint) != 0 {
    return preferred
  }
  for family in fonts.fallbacks {
    for face in fonts.faces {
      if face.face.family == family && face.font.glyph_index(codepoint) != 0 {
        return face
      }
    }
  }
  raise raster_fail(
    "raster/missing-glyph",
    "No supplied font contains required Unicode scalar " + codepoint.to_string(),
    source_id~,
  )
}

///|
pub fn FontSet::subset_for_svg(
  self : FontSet,
  source : String,
  limits~ : RasterLimits = RasterLimits::default(),
) -> FontSubsetResult {
  try {
    validate_raster_limits(limits)
    guard source.length() <= limits.max_source_units else {
      raise raster_fail(
        "raster/source-limit", "Generated SVG exceeds the source budget",
      )
    }
    let nodes = parse_svg_xml(source, max_nodes=limits.max_svg_nodes)
    let parsed = load_font_set(self, limits)
    ignore(normalize_generated_svg(source, "light", parsed, limits))
    let cps : Map[Int32, Bool] = Map([])
    for node in nodes {
      if node.raw_name == "text" || node.raw_name == "tspan" {
        for child in node.children {
          let content = nodes[child]
          if content.kind == Text && content.value.trim() != "" {
            // Portable scalar iteration includes surrogate pairs.
            for scalar in content.value.iter() {
              cps[scalar.to_int()] = true
              guard cps.length() <= limits.max_glyphs else {
                raise raster_fail(
                  "raster/glyph-limit", "Font subset codepoint budget exceeded",
                )
              }
            }
          }
        }
      }
    }
    let coverage = cps.keys().to_array()
    coverage.sort()
    let faces : Array[FontFace] = []
    let cache : Array[(Bytes, Bytes)] = []
    for face in self.faces {
      let mut subset : Bytes? = None
      for (original, data) in cache {
        if original == face.data {
          subset = Some(data)
          break
        }
      }
      let data = match subset {
        Some(data) => data
        None => {
          let safe = validated_font_bytes(face.data, limits)
          guard @font.subset_font(safe, coverage) is Some(data) else {
            raise raster_fail(
              "raster/font-subset", "Unable to subset the supplied static TrueType font",
            )
          }
          cache.push((face.data, data))
          data
        }
      }
      faces.push({ ..face, data, })
    }
    {
      fonts: Some(FontSet::new(faces, fallback_families=self.fallback_families)),
      diagnostics: [],
    }
  } catch {
    error => { fonts: None, diagnostics: [raster_diagnostic(error)], }
  }
}
