///|
/// Public API fixtures decoded independently in Chromium. One shared snapshot
/// also proves exact target bytes, including the integer JPEG path.
test "every implemented family exports complete deterministic PNG and JPEG" {
  let rows : Array[Json] = []
  let defaults = @raster.FontSet::default()
  for (name, source) in still_fixtures {
    let before = source
    let compact = defaults.subset_for_svg(source)
    assert_eq(compact.diagnostics.length(), 0, msg=name)
    let fonts = compact.fonts.unwrap()
    let png = @raster.rasterize(source, fonts~)
    assert_eq(
      png.diagnostics.length(),
      0,
      msg=name +
        Json(png.diagnostics.iter().map(d => Json(d.message)).to_array()).stringify(),
    )
    let jpeg = @raster.rasterize(
      source,
      fonts~,
      options=@raster.StillOptions::new(
        format=Jpeg(quality=80),
        background=@raster.Rgba::new(248, 240, 232),
      ),
    )
    assert_eq(jpeg.diagnostics.length(), 0, msg=name)
    let a = png.image.unwrap()
    let b = jpeg.image.unwrap()
    assert_eq(a.format, Png)
    assert_eq(a.media_type, "image/png")
    assert_eq(b.format, Jpeg)
    assert_eq(b.media_type, "image/jpeg")
    assert_eq(a.width, b.width)
    assert_eq(a.height, b.height)
    assert_eq(source, before)
    rows.push(
      Json({
        "name": Json(name),
        "png": Json(@base64.encode(a.bytes)),
        "jpeg": Json(@base64.encode(b.bytes)),
        "width": Json(a.width),
        "height": Json(a.height),
        "source": Json(source),
      }),
    )
  }
  let source = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 32 16\"><rect class=\"bg\" width=\"32\" height=\"16\" fill=\"green\"/><g><rect class=\"bg\" x=\"8\" y=\"4\" width=\"8\" height=\"8\" fill=\"blue\"/></g></svg>"
  let transparent = @raster.rasterize(source).image.unwrap()
  let composited = @raster.rasterize(
    source,
    options=@raster.StillOptions::new(
      format=Jpeg(quality=100),
      background=@raster.Rgba::new(248, 240, 232),
    ),
  ).image.unwrap()
  rows.push(
    Json({
      "name": Json("explicit-background"),
      "png": Json(@base64.encode(transparent.bytes)),
      "jpeg": Json(@base64.encode(composited.bytes)),
      "width": Json(32),
      "height": Json(16),
      "source": Json(source),
    }),
  )
  let snapshot = @test.Test("portable still exports")
  snapshot.write(Json(rows).stringify())
  snapshot.snapshot(filename="still.json")
}

///|
test "public options limits glyph and font failures have no success payload" {
  let source = "<svg width=\"32\" height=\"16\"><text x=\"0\" y=\"12\">text</text></svg>"
  let limits = @raster.RasterLimits::default()
  let sizes : Array[@raster.RasterSize] = [
    Width(0),
    Height(-1),
    Scale(0.0),
    Scale(1.0 / 0.0),
    Fit(0, 16),
    Width(1000000),
  ]
  for size in sizes {
    let result = @raster.rasterize(
      source,
      options=@raster.StillOptions::new(size~),
    )
    assert_true(result.image is None)
    assert_true(result.diagnostics.length() > 0)
  }
  let exhausted = @raster.rasterize(source, limits={
    ..limits,
    max_output_bytes: 1,
  })
  assert_true(exhausted.image is None)
  let unsupported = @raster.rasterize(
    "<svg width=\"16\" height=\"16\"><foreignObject/></svg>",
  )
  assert_true(unsupported.image is None)
  let invalid = @raster.rasterize(
    source,
    fonts=@raster.FontSet::new([@raster.FontFace::new("monospace", b"invalid")]),
  )
  assert_true(invalid.image is None)
}
