///|
test "PNG and JPEG metadata and complete dimensions" {
  let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 16 8\"><rect x=\"2\" y=\"2\" width=\"10\" height=\"4\" fill=\"red\"/></svg>"
  let before = source
  let png = rasterize(source, options=StillOptions::new(size=Width(32)))
  assert_eq(png.diagnostics.length(), 0)
  assert_true(png.image is Some(_))
  let image = png.image.unwrap()
  assert_eq(image.width, 32)
  assert_eq(image.height, 16)
  assert_eq(image.media_type, "image/png")
  let pixels = @image.decode_png(image.bytes)
  assert_eq(pixels.data[3], b'\x00')
  let jpeg = rasterize(
    source,
    options=StillOptions::new(format=Jpeg(quality=80), background=Rgba::white()),
  )
  assert_eq(jpeg.diagnostics.length(), 0)
  assert_eq(jpeg.image.unwrap().media_type, "image/jpeg")
  assert_eq(source, before)
}

///|
test "invalid options fail before parsing or default fonts" {
  let result = rasterize("not SVG", options=StillOptions::new(size=Scale(0.0)))
  assert_true(result.image is None)
  let quality = rasterize(
    "not SVG",
    options=StillOptions::new(format=Jpeg(quality=0), background=Rgba::white()),
  )
  assert_eq(quality.diagnostics[0].code, "raster/invalid-quality")
  let background = rasterize(
    "not SVG",
    options=StillOptions::new(format=Jpeg(quality=80)),
  )
  assert_eq(background.diagnostics[0].code, "raster/jpeg-background")
}

///|
test "malformed fonts and missing glyphs return no image" {
  let source = "<svg width=\"32\" height=\"32\"><text x=\"1\" y=\"20\">A</text></svg>"
  let corrupt = rasterize(
    source,
    fonts=FontSet::new([FontFace::new("monospace", b"not a font")]),
  )
  assert_true(corrupt.image is None)
  assert_eq(corrupt.diagnostics[0].code, "raster/font-data")
  let absent = rasterize(
    "<svg width=\"32\" height=\"32\"><text x=\"1\" y=\"20\">😀</text></svg>",
  )
  assert_true(absent.image is None)
  assert_eq(absent.diagnostics[0].code, "raster/missing-glyph")
}

///|
test "glyph outlines and per-artifact subsets preserve actual PNG bytes" {
  let source = "<svg width=\"128\" height=\"32\"><text x=\"64\" y=\"22\" text-anchor=\"middle\" font-size=\"16\" font-weight=\"600\">Café ☑ λ</text></svg>"
  let fonts = FontSet::default()
  let subset = fonts.subset_for_svg(source)
  assert_eq(subset.diagnostics.length(), 0)
  let original = rasterize(source, fonts~)
  assert_eq(original.diagnostics.length(), 0)
  let compact = rasterize(source, fonts=subset.fonts.unwrap())
  assert_eq(compact.diagnostics.length(), 0)
  assert_eq(original.image.unwrap().bytes, compact.image.unwrap().bytes)
  assert_true(
    subset.fonts.unwrap().faces[0].data.length() < fonts.faces[0].data.length(),
  )
}

///|
test "bounded work rejects dimensions source and output" {
  let source = "<svg width=\"16\" height=\"8\"><rect width=\"16\" height=\"8\" fill=\"red\"/></svg>"
  let limits = RasterLimits::default()
  let pixels = rasterize(source, limits={ ..limits, max_pixels: 1L, })
  assert_eq(pixels.diagnostics[0].code, "raster/pixel-limit")
  let output = rasterize(source, limits={ ..limits, max_output_bytes: 1, })
  assert_eq(output.diagnostics[0].code, "raster/output-limit")
  let unsupported = rasterize(
    "<svg width=\"16\" height=\"8\"><foreignObject/></svg>",
  )
  assert_true(unsupported.image is None)
}

///|
test "explicit background replaces only the emitted top-level bg rectangle" {
  let source = "<svg width=\"16\" height=\"8\"><rect class=\"bg\" width=\"16\" height=\"8\" fill=\"green\"/><g><rect class=\"bg\" x=\"4\" y=\"2\" width=\"4\" height=\"4\" fill=\"blue\"/></g></svg>"
  let png = rasterize(source).image.unwrap()
  let transparent = @image.decode_png(png.bytes)
  assert_eq(transparent.data[3], b'\x00')
  let nested = (3 * 16 + 5) * 4
  assert_eq(transparent.data[nested + 2], b'\xff')
  assert_eq(transparent.data[nested + 3], b'\xff')
  let composited = rasterize(
    source,
    options=StillOptions::new(background=Rgba::new(255, 0, 0)),
  ).image.unwrap()
  let red = @image.decode_png(composited.bytes)
  assert_eq(red.data[0], b'\xff')
  assert_eq(red.data[3], b'\xff')
  assert_eq(red.data[nested + 2], b'\xff')
}

///|
test "default profile covers every current gallery label scalar" {
  let source = "<svg width=\"1024\" height=\"32\"><text x=\"0\" y=\"20\"> !$&amp;()*+,-./0123456789:;=?ABCDEFGHIJLMNOPQRSTUVWYZ[\\]^_abcdefghijklmnopqrstuvwxyz{}é…␀☐☑</text></svg>"
  let result = rasterize(source)
  assert_eq(result.diagnostics.length(), 0)
  assert_true(result.image is Some(_))
}

///|
test "derived decoration keeps actual parent transforms and source bytes" {
  let source = "<svg width=\"24\" height=\"16\"><g transform=\"translate(4 2)\"><path id=\"p\" d=\"M0 0L8 0\" stroke=\"blue\"/></g></svg>"
  let nodes = parse_svg_xml(source)
  let plain = StringBuilder()
  svg_xml_write(nodes, 0, plain, Map([]), Map([]))
  let serialized = plain.to_string()
  assert_eq(
    rasterize(source).image.unwrap().bytes,
    rasterize(serialized).image.unwrap().bytes,
  )
  let decorated = StringBuilder()
  svg_xml_write(
    nodes,
    0,
    decorated,
    Map([("p", "<rect x=\"0\" y=\"0\" width=\"2\" height=\"2\" fill=\"red\"/>")]),
    Map([]),
  )
  let derived = decorated.to_string()
  let image = @image.decode_png(rasterize(derived).image.unwrap().bytes)
  let at = (2 * 24 + 4) * 4
  assert_eq(image.data[at], b'\xff')
  assert_eq(image.data[at + 3], b'\xff')
  assert_eq(
    source, "<svg width=\"24\" height=\"16\"><g transform=\"translate(4 2)\"><path id=\"p\" d=\"M0 0L8 0\" stroke=\"blue\"/></g></svg>",
  )
}

///|
test "a partial top-level bg rectangle remains ordinary diagram content" {
  let source = "<svg width=\"16\" height=\"8\"><rect class=\"bg\" x=\"4\" y=\"2\" width=\"4\" height=\"4\" fill=\"blue\"/></svg>"
  let image = @image.decode_png(rasterize(source).image.unwrap().bytes)
  let at = (3 * 16 + 5) * 4
  assert_eq(image.data[at + 2], b'\xff')
  assert_eq(image.data[at + 3], b'\xff')
  assert_eq(image.data[3], b'\x00')
}

///|
fn font_test_replace(
  data : Bytes,
  index : Int32,
  value : Int64,
  count : Int32,
) -> Bytes {
  let bytes = FixedArray::make(data.length(), b'\x00')
  bytes.blit_from_bytes(0, data, 0, data.length())
  for n in 0..<count {
    bytes[index + n] = ((value >> ((count - n - 1) * 8)) & 255L)
      .to_int()
      .to_byte()
  }
  Bytes::from_array(bytes)
}

///|
test "malformed font table offsets cmap counts and compound cycles are diagnosed" {
  let original = FontSet::default().faces[0].data
  let variants : Array[Bytes] = [
    font_test_replace(original, 20, 2147483647L, 4),
  ]
  let mut cmap = 0
  let mut head = 0
  let mut loca = 0
  let mut glyf = 0
  let mut maxp = 0
  for i in 0..<font_u16(original, 4) {
    let at = 12 + i * 16
    let name = String::from_array([
      original[at].to_int().unsafe_to_char(),
      original[at + 1].to_int().unsafe_to_char(),
      original[at + 2].to_int().unsafe_to_char(),
      original[at + 3].to_int().unsafe_to_char(),
    ])
    let offset = font_u32(original, at + 8).to_int()
    match name {
      "cmap" => cmap = offset
      "head" => head = offset
      "loca" => loca = offset
      "glyf" => glyf = offset
      "maxp" => maxp = offset
      _ => ()
    }
  }
  assert_true(cmap > 0 && head > 0 && loca > 0 && glyf > 0 && maxp > 0)
  for i in 0..<font_u16(original, cmap + 2) {
    let sub = cmap + font_u32(original, cmap + 4 + i * 8 + 4).to_int()
    if font_u16(original, sub) == 12 {
      variants.push(font_test_replace(original, sub + 12, 2147483647L, 4))
      break
    }
  }
  let unit = if font_u16(original, head + 50) == 0 { 2 } else { 4 }
  let mut compound = false
  for gid in 0..<font_u16(original, maxp + 4) {
    let start = if unit == 2 {
      font_u16(original, loca + gid * 2) * 2
    } else {
      font_u32(original, loca + gid * 4).to_int()
    }
    let end = if unit == 2 {
      font_u16(original, loca + (gid + 1) * 2) * 2
    } else {
      font_u32(original, loca + (gid + 1) * 4).to_int()
    }
    if end - start >= 14 && font_u16(original, glyf + start) >= 32768 {
      variants.push(
        font_test_replace(original, glyf + start + 12, gid.to_int64(), 2),
      )
      compound = true
      break
    }
  }
  assert_true(compound)
  for data in variants {
    let result = rasterize(
      "<svg width=\"32\" height=\"16\"><text x=\"0\" y=\"12\">A</text></svg>",
      fonts=FontSet::new([FontFace::new("monospace", data)]),
    )
    assert_true(result.image is None)
    assert_true(result.diagnostics.length() > 0)
  }
}

///|
test "aggregate glyph budget precedes outlining and missing glyph lookup" {
  let source = "<svg width=\"32\" height=\"32\"><text>A</text><text>😀</text></svg>"
  let limits = { ..RasterLimits::default(), max_glyphs: 1, }
  let result = rasterize(source, limits~)
  assert_true(result.image is None)
  assert_eq(result.diagnostics[0].code, "raster/glyph-limit")
  let fonts = FontSet::default().subset_for_svg(source, limits~)
  assert_true(fonts.fonts is None)
  assert_eq(fonts.diagnostics[0].code, "raster/glyph-limit")
  let long_label = "<svg width=\"32\" height=\"32\"><text>" +
    "A".repeat(1000000) + "</text></svg>"
  let result = rasterize(long_label, limits~)
  assert_eq(result.diagnostics[0].code, "raster/glyph-limit")
}
