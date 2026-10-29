///|
/// Size-only reductions of actual generated SVGs from the refresh-site gallery.
/// Root dimensions and background rectangles are retained verbatim; unrelated
/// geometry/text is omitted to isolate sizing and avoid filesystem-dependent
/// portable tests. These are deliberately the non-power-of-two dimensions that
/// exposed a one-ULP constrained-axis overshoot.
///
/// _gallery/state-plantuml-history-dark.svg, viewBox 0 0 1275 2454
/// SHA-256 fbbfc214f57a0c7720146b4c13f3d3815c6f55b1455a90e4c32ff830e7a25e08
let sizing_state_svg : String = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1275 2454\" width=\"1275\" height=\"2454\"><rect class=\"bg\" x=\"0\" y=\"0\" width=\"1275\" height=\"2454\" fill=\"#020617\"/></svg>"

///|
/// _gallery/flowchart-mermaid-dispatch-light.svg, viewBox 0 0 1912 424
/// SHA-256 e39c7bfcd1ce523e88fd3aa32aed881025270c82e7e628469f4845d12fff97d4
let sizing_flowchart_svg : String = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1912 424\" width=\"1912\" height=\"424\"><rect class=\"bg\" x=\"0\" y=\"0\" width=\"1912\" height=\"424\" fill=\"#f4f5f7\"/></svg>"

///|
/// _gallery/yaml-service-light.svg, viewBox 0 0 616 382
/// SHA-256 9daa3011f1957d3b73fa86dfbbbdcda34b973b0b671ee19664691794611ed650
let sizing_yaml_svg : String = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 616 382\" width=\"616\" height=\"382\"><rect class=\"bg\" x=\"0\" y=\"0\" width=\"616\" height=\"382\" fill=\"#f4f5f7\"/></svg>"

///|
/// _gallery/sequence-parallel-checkout-light.svg, viewBox 0 0 624 756
/// SHA-256 09f708630716c8f9e53dc1ae82052e5576dd325dfdba3f8baa849d951175a8ee
let sizing_sequence_svg : String = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 624 756\" width=\"624\" height=\"756\"><rect class=\"bg\" x=\"0\" y=\"0\" width=\"624\" height=\"756\" rx=\"0\" fill=\"#f4f5f7\"/></svg>"

///|
test "generated viewBoxes retain exact integer Width Height and Fit axes" {
  // Expected secondary axes are independently rounded from the exact rational
  // dimensions, not computed through the production floating-point expression.
  let cases = [
    (sizing_state_svg, 165, 318, 15, 8),
    (sizing_flowchart_svg, 63, 14, 107, 483),
    (sizing_yaml_svg, 63, 40, 27, 44),
    (sizing_sequence_svg, 25, 31, 191, 158),
  ]
  for (source, width, scaled_height, height, scaled_width) in cases {
    assert_eq(
      still_dimensions(source, Width(width), RasterLimits::default()),
      (width, scaled_height),
    )
    assert_eq(
      still_dimensions(source, Height(height), RasterLimits::default()),
      (scaled_width, height),
    )
    assert_eq(
      still_dimensions(
        source,
        Fit(width, scaled_height),
        RasterLimits::default(),
      ),
      (width, scaled_height),
    )
    assert_eq(
      still_dimensions(
        source,
        Fit(scaled_width, height),
        RasterLimits::default(),
      ),
      (scaled_width, height),
    )
  }
}

///|
test "public PNG JPEG dimensions honor generated sizing and exact limit boundaries" {
  let fonts = FontSet::new([FontSet::default().faces[0]])
  let cases : Array[(String, RasterSize, Int32, Int32)] = [
    (sizing_state_svg, Width(165), 165, 318),
    // Previously Height(15) became16 and incorrectly exceeded max_dimension15.
    (sizing_state_svg, Height(15), 8, 15),
    (sizing_state_svg, Fit(8, 15), 8, 15),
    // Previously Width(63) became64 and incorrectly exceeded max_dimension63.
    (sizing_flowchart_svg, Width(63), 63, 14),
    (sizing_flowchart_svg, Fit(63, 14), 63, 14),
    (sizing_yaml_svg, Fit(63, 40), 63, 40),
    (sizing_sequence_svg, Width(25), 25, 31),
    (sizing_sequence_svg, Height(191), 158, 191),
  ]
  for (source, size, width, height) in cases {
    let limits = {
      ..RasterLimits::default(),
      max_dimension: width.max(height),
    }
    for format in [StillFormat::Png, Jpeg(quality=80)] {
      let result = rasterize(
        source,
        options=StillOptions::new(size~, format~, background=Rgba::white()),
        fonts~,
        limits~,
      )
      assert_eq(result.diagnostics.length(), 0)
      let image = result.image.unwrap()
      assert_eq((image.width, image.height), (width, height))
      let decoded = match format {
        Png => @image.decode_png(image.bytes)
        Jpeg(..) => @image.decode_jpeg(image.bytes)
      }
      assert_eq((decoded.width, decoded.height), (width, height))
    }
  }
}

///|
test "exact requested axes do not suppress real dimension limit failures" {
  let height_limit = rasterize(
    sizing_state_svg,
    options=StillOptions::new(size=Width(165)),
    limits={ ..RasterLimits::default(), max_dimension: 317, },
  )
  assert_true(height_limit.image is None)
  assert_eq(height_limit.diagnostics[0].code, "raster/dimension-limit")
  let width_limit = rasterize(
    sizing_flowchart_svg,
    options=StillOptions::new(size=Width(64)),
    limits={ ..RasterLimits::default(), max_dimension: 63, },
  )
  assert_true(width_limit.image is None)
  assert_eq(width_limit.diagnostics[0].code, "raster/invalid-size")
}

///|
test "exact integral aspect ratios do not gain a derived pixel" {
  // Actual emitted architecture-group-boundary and swimlane-escalation bounds.
  let architecture = "<svg viewBox=\"0 0 715 420\"/>"
  let swimlane = "<svg viewBox=\"0 0 608 741\"/>"
  let limits = RasterLimits::default()
  assert_eq(still_dimensions(architecture, Width(1573), limits), (1573, 924))
  assert_eq(still_dimensions(architecture, Height(924), limits), (1573, 924))
  assert_eq(still_dimensions(architecture, Fit(1573, 924), limits), (1573, 924))
  assert_eq(still_dimensions(swimlane, Width(672), limits), (672, 819))
  assert_eq(still_dimensions(swimlane, Height(819), limits), (672, 819))
  assert_eq(still_dimensions(swimlane, Fit(672, 819), limits), (672, 819))
  // The integral path's largest allowed intermediate product remains in Int64.
  assert_eq(ratio_dimension(2147483647.0, 2147483647, 2147483647.0), 2147483647.0)
  // Fractional input and an overflowing floating product retain a finite ratio.
  assert_eq(still_dimensions("<svg viewBox=\"0 0 10.5 21\"/>", Width(165), limits), (165, 330))
  assert_eq(still_dimensions("<svg viewBox=\"0 0 1e308 1e308\"/>", Width(165), limits), (165, 165))
}
