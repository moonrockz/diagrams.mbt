///|
test "GIF arclength follows final curved and reversed connectors" {
  let curve = @svg.ConnectorPath::parse("M 0 0 C 0 100 100 100 100 0").unwrap()
  let sampled = gif_path(curve, 8192)
  assert_true((sampled.length - 200.0).abs() < 0.1)
  let middle = sampled.point(0.5)
  assert_true((middle.x - 50.0).abs() < 0.01)
  assert_true((middle.y - 75.0).abs() < 0.01)
  assert_eq(sampled.point(0.0), { x: 0.0, y: 0.0, })
  assert_eq(sampled.point(1.0), { x: 100.0, y: 0.0, })
  let forward = sampled.point(0.25)
  let reversed = sampled.point(1.0 - 0.25)
  assert_true((forward.x + reversed.x - 100.0).abs() < 0.01)
  assert_true((forward.y - reversed.y).abs() < 0.01)
}

///|
test "GIF connector segments never join distinct moves and obey their budget" {
  let path = @svg.ConnectorPath::parse("M0 0 L10 0 M100 0 L110 0").unwrap()
  let sampled = gif_path(path, 2)
  assert_eq(sampled.length, 20.0)
  assert_eq(sampled.point(0.75), { x: 105.0, y: 0.0, })
  let failed = try {
    ignore(gif_path(path, 1))
    false
  } catch {
    GifInvalid(_) => true
  }
  assert_true(failed)
}
