///|
fn sample() -> @model.DataTree {
  let m = (id : String, name : String, value : String) => {
    @model.Member::named(id, name, value)
  }
  @model.DataTree::new(
    "sample",
    "v",
    [
      @model.Node::object("v", [
        m("m/0", "name", "v/0"),
        m("m/1", "list", "v/1"),
        m("m/2", "other", "v/2"),
      ]),
      @model.Node::new("v/0", Text("value")),
      @model.Node::array("v/1", [@model.Member::index("m/1/0", 0, "v/1/0")]),
      @model.Node::new("v/1/0", Number("1")),
      @model.Node::object("v/2", [m("m/2/0", "x", "v/2/0")]),
      @model.Node::new("v/2/0", Null),
    ],
    highlights=[@model.Highlight::new(["m/0"])],
  )
}

///|
fn rules(geometry : Geometry, palette : @theme.Palette) -> Array[Rule] {
  check(geometry, palette).map(f => f.rule).iter().collect()
}

///|
fn with_box(geometry : Geometry, index : Int32, box : Box) -> Geometry {
  let boxes = geometry.boxes.iter().collect()
  boxes[index] = box
  { ..geometry, boxes: ReadOnlyArray::from_array(boxes), }
}

///|
fn with_row(box : Box, index : Int32, row : Row) -> Box {
  let rows = box.rows.iter().collect()
  rows[index] = row
  { ..box, rows: ReadOnlyArray::from_array(rows), }
}

///|
test "valid geometry has no findings" {
  let geometry = layout(sample()).geometry.unwrap()
  let theme = @theme.Theme::classic()
  assert_eq(rules(geometry, palette(theme.dark)), [])
  assert_eq(rules(geometry, palette(theme.light)), [])
}

///|
test "a row that leaves its box breaks containment" {
  let geometry = layout(sample()).geometry.unwrap()
  let root = geometry.boxes[0]
  let row = root.rows[0]
  let broken = with_box(
    geometry,
    0,
    with_row(root, 0, { ..row, box: { ..row.box, x: row.box.x - 30.0, }, }),
  )
  assert_true(
    rules(broken, palette(@theme.Theme::classic().dark)).contains(Containment),
  )
}

///|
test "a label without clearance breaks fit" {
  let geometry = layout(sample()).geometry.unwrap()
  let root = geometry.boxes[0]
  let row = root.rows[0]
  let key = row.key.unwrap()
  let broken = with_box(
    geometry,
    0,
    with_row(root, 0, {
      ..row,
      key: Some({ ..key, box: { ..key.box, x: row.box.x, }, }),
    }),
  )
  assert_true(
    rules(broken, palette(@theme.Theme::classic().dark)).contains(Fit),
  )
  let narrow = with_box(
    geometry,
    0,
    with_row(root, 0, {
      ..row,
      key: Some({ ..key, box: { ..key.box, width: 2.0, }, }),
    }),
  )
  assert_true(
    rules(narrow, palette(@theme.Theme::classic().dark)).contains(Fit),
  )
}

///|
test "a connector that misses its box breaks attachment" {
  let geometry = layout(sample()).geometry.unwrap()
  let connector = geometry.connectors[0]
  let points = connector.points.iter().collect()
  points[4] = { x: points[4].x + 40.0, y: points[4].y, }
  let connectors = geometry.connectors.iter().collect()
  connectors[0] = { ..connector, points: ReadOnlyArray::from_array(points), }
  let broken = {
    ..geometry,
    connectors: ReadOnlyArray::from_array(connectors),
  }
  assert_true(
    rules(broken, palette(@theme.Theme::classic().dark)).contains(Endpoint),
  )
  let start = connector.points.iter().collect()
  start[0] = { x: start[0].x - 50.0, y: start[0].y, }
  connectors[0] = { ..connector, points: ReadOnlyArray::from_array(start), }
  let detached = {
    ..geometry,
    connectors: ReadOnlyArray::from_array(connectors),
  }
  assert_true(
    rules(detached, palette(@theme.Theme::classic().dark)).contains(Endpoint),
  )
}

///|
test "overlapping boxes and crossing connectors are found" {
  let geometry = layout(sample()).geometry.unwrap()
  let root = geometry.boxes[0]
  let moved = with_box(geometry, 1, { ..geometry.boxes[1], box: root.box, })
  assert_true(
    rules(moved, palette(@theme.Theme::classic().dark)).contains(Overlap),
  )
  // Put the third box across the route of the first connector.
  let connector = geometry.connectors[0]
  let p = connector.points
  let blocker = {
    ..geometry.boxes[2],
    box: { x: p[2].x - 5.0, y: p[0].y - 5.0, width: 10.0, height: 10.0, },
  }
  let crossed = with_box(geometry, 2, blocker)
  assert_true(
    rules(crossed, palette(@theme.Theme::classic().dark)).contains(Overlap),
  )
}

///|
test "highlight colours without contrast are found" {
  let geometry = layout(sample()).geometry.unwrap()
  let p = palette(@theme.Theme::classic().dark)
  let flat = { ..p, cloud: { ..p.cloud, fill: p.text, }, }
  assert_true(rules(geometry, flat).contains(Contrast))
  let small = with_box(
    geometry,
    0,
    with_row(geometry.boxes[0], 0, {
      ..geometry.boxes[0].rows[0],
      value: geometry.boxes[0].rows[0].value.map(l => { ..l, size: 8.0, }),
    }),
  )
  assert_true(rules(small, p).contains(Size))
}

///|
test "the check stops at its work limit" {
  let geometry = layout(sample()).geometry.unwrap()
  let findings = check(
    geometry,
    palette(@theme.Theme::classic().dark),
    work_limit=3,
  )
  assert_true(findings.iter().any(f => f.rule == Limit))
}
