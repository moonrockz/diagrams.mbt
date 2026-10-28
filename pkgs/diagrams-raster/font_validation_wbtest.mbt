///|
fn test_cmap4(segments : Int32, wide : Bool) -> Bytes {
  let bytes = Array::make(28 + segments * 8, b'\x00')
  @font.write_be16(bytes, 2, 1)
  @font.write_be16(bytes, 4, 3)
  @font.write_be16(bytes, 6, 1)
  @font.write_be32(bytes, 8, 12)
  @font.write_be16(bytes, 12, 4)
  @font.write_be16(bytes, 14, bytes.length() - 12)
  @font.write_be16(bytes, 18, segments * 2)
  for i in 0..<segments {
    @font.write_be16(bytes, 26 + i * 2, if wide { 65534 } else { 65 })
    @font.write_be16(bytes, 28 + segments * 2 + i * 2, if wide { 0 } else { 65 })
    @font.write_be16(bytes, 28 + segments * 4 + i * 2, if wide { if i == segments - 1 { 1 } else { 0 } } else { 55536 })
  }
  Bytes::from_array(bytes)
}

///|
test "cmap mappings are charged before expanding the next segment" {
  // Eighteen 65,535-scalar ranges fit. The nineteenth exceeds the budget
  // before its otherwise-invalid last glyph can be inspected.
  let code = try {
    ignore(validate_cmap(test_cmap4(19, true), 65535))
    "success"
  } catch {
    error => raster_diagnostic(error).code
  }
  assert_eq(code, "raster/font-limit")
}

///|
test "valid signed-wrapping cmap survives outlining and subsetting" {
  let head = Array::make(54, b'\x00')
  @font.write_be16(head, 18, 1024)
  let hhea = Array::make(36, b'\x00')
  @font.write_be16(hhea, 34, 1)
  let maxp = Array::make(6, b'\x00')
  @font.write_be16(maxp, 4, 60000)
  let original = @font.rebuild_sfnt(65536, [
    ("head", Bytes::from_array(head)),
    ("hhea", Bytes::from_array(hhea)),
    ("maxp", Bytes::from_array(maxp)),
    ("hmtx", Bytes::make(120002, b'\x00')),
    ("loca", Bytes::make(120002, b'\x00')),
    ("glyf", b""),
    ("cmap", test_cmap4(1, false)),
  ])
  let safe = validated_font_bytes(original, RasterLimits::default())
  let parsed = @font.parse_font(safe).unwrap()
  assert_eq(parsed.glyph_index(65), 55601)
  let fonts = FontSet::new([FontFace::new("monospace", original)])
  let source = "<svg width=\"16\" height=\"16\"><text x=\"0\" y=\"12\">A</text></svg>"
  let image = rasterize(source, fonts~)
  assert_eq(image.diagnostics.length(), 0)
  let subset = fonts.subset_for_svg(source)
  assert_eq(subset.diagnostics.length(), 0)
  assert_eq(rasterize(source, fonts=subset.fonts.unwrap()).image.unwrap().bytes, image.image.unwrap().bytes)
}

///|
test "overlapping font table copies share the source budget" {
  let bytes = Array::make(1060, b'\x00')
  @font.write_be32(bytes, 0, 65536)
  @font.write_be16(bytes, 4, 3)
  for i in 0..<3 {
    bytes[12 + i * 16] = (65 + i).to_byte()
    @font.write_be32(bytes, 20 + i * 16, 60)
    @font.write_be32(bytes, 24 + i * 16, 1000)
  }
  let code = try {
    ignore(validated_font_bytes(Bytes::from_array(bytes), {
      ..RasterLimits::default(), max_source_units: 2000,
    }))
    "success"
  } catch {
    error => raster_diagnostic(error).code
  }
  assert_eq(code, "raster/font-limit")
}
