///|
test "worker font metadata has a cumulative source bound" {
  let family = "a-family-name-with-many-characters"
  let fonts = FontSet::new([FontFace::new(family, b""), FontFace::new(family, b"")])
  let limits = { ..RasterLimits::default(), max_source_units: family.length() }
  let result = fonts.export_data(limits~)
  assert_true(result.data is None)
  assert_eq(result.diagnostics[0].code, "raster/font-limit")
  let data : Json = { "version": 1, "resources": [""], "fallbacks": [], "faces": [
    { "family": Json(family), "weight": 400, "italic": false, "resource": 0 },
    { "family": Json(family), "weight": 400, "italic": false, "resource": 0 },
  ] }
  let decoded = FontSet::from_export_data(data, limits~)
  assert_true(decoded.fonts is None)
  assert_eq(decoded.diagnostics[0].code, "raster/font-limit")
}

///|
test "worker fonts deduplicate aliases and preserve explicit binary inputs" {
  let fonts = FontSet::default().subset_for_svg("<svg width=\"32\" height=\"16\"><text x=\"0\" y=\"12\">text</text></svg>").fonts.unwrap()
  let data = fonts.export_data().data.unwrap()
  guard data is Object(fields) && fields["resources"] is Array(resources) else { fail("Missing font resources") }
  assert_true(resources.length() < fonts.faces.length())
  let restored = FontSet::from_export_data(data).fonts.unwrap()
  assert_eq(restored.faces.length(), fonts.faces.length())
  for i in 0..<fonts.faces.length() {
    assert_eq(restored.faces[i].family, fonts.faces[i].family)
    assert_eq(restored.faces[i].data, fonts.faces[i].data)
  }
}
