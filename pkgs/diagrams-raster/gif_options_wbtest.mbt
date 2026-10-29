///|
fn gif_test_limits() -> RasterLimits {
  {
    max_source_units: 16777216,
    max_svg_nodes: 100000,
    max_dimension: 16384,
    max_pixels: 16777216L,
    max_glyphs: 100000,
    max_output_bytes: 33554432,
    max_frames: 300,
    max_cumulative_pixels: 67108864L,
  }
}

///|
test "GIF intervals include exact endpoints and bounded centisecond holds" {
  let times = gif_times(250L, GifOptions::new(frame_rate=10), gif_test_limits())
  assert_eq(times, [(0L, 10), (100L, 10), (200L, 5), (250L, 5)])
  let interval = GifOptions::new(
    interval=Interval(start_ms=101L, end_ms=145L),
    frame_rate=30,
  )
  assert_eq(gif_times(1000L, interval, gif_test_limits()), [
    (101L, 3),
    (134L, 1),
    (145L, 1),
  ])
}

///|
test "GIF rejects frame work and invalid options before sampling" {
  let limits = gif_test_limits()
  for
    options in [
      GifOptions::new(frame_rate=0),
      GifOptions::new(frame_rate=101),
      GifOptions::new(loop_behavior=Repeat(0)),
      GifOptions::new(interval=Interval(start_ms=20L, end_ms=10L)),
      GifOptions::new(
        interval=Interval(start_ms=0L, end_ms=9223372036854775807L),
      ),
    ] {
    let failed = try {
      ignore(gif_times(100L, options, limits))
      false
    } catch {
      GifInvalid(_) => true
      _ => false
    }
    assert_true(failed)
  }
  let failed = try {
    ignore(gif_times(100L, GifOptions::new(), { ..limits, max_frames: 1, }))
    false
  } catch {
    GifInvalid(_) => true
    _ => false
  }
  assert_true(failed)
}

///|
test "tiny pixel and byte budgets reject enormous schedules before timing allocation" {
  let options = GifOptions::new(
    frame_rate=100,
    interval=Interval(start_ms=0L, end_ms=21474836460L),
  )
  let limits = { ..gif_test_limits(), max_frames: 2147483647, }
  for (bounded, expected) in [
    ({ ..limits, max_cumulative_pixels: 1L, }, "raster/cumulative-pixel-limit"),
    ({ ..limits, max_cumulative_pixels: 9223372036854775807L, max_output_bytes: 1, }, "raster/output-limit"),
  ] {
    let code = try {
      ignore(gif_times(1L, options, bounded, pixels=1L))
      "success"
    } catch {
      RasterInvalid(code, _, _) => code
      error => error.to_string()
    }
    assert_eq(code, expected)
  }
}
