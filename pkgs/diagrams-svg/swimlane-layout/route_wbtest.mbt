///|
test "planned terminal corridors survive earlier routes and labels in every direction" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    let result = layout(
      example(direction),
      limits=Limits::new(minimum_approach=72.0),
    )
    assert_true(
      result.geometry is Some(_),
      msg=@debug.to_string(result.diagnostics),
    )
    let geometry = result.geometry.unwrap()
    assert_eq(check(geometry, palette(@theme.Theme::classic().light)), [])
    for edge in geometry.connections {
      let first = edge.line[0]
      let next = edge.line[1]
      let last = edge.line[edge.line.length() - 1]
      let before = edge.line[edge.line.length() - 2]
      assert_true(
        (first.x - next.x).abs() + (first.y - next.y).abs() >= 72.0,
        msg=edge.connection.id + " start",
      )
      assert_true(
        (last.x - before.x).abs() + (last.y - before.y).abs() >= 72.0,
        msg=edge.connection.id + " end",
      )
    }
    for i, edge in geometry.connections {
      for other in geometry.connections[:i] {
        for a in 1..<edge.line.length() {
          let p = edge.line[a - 1]
          let q = edge.line[a]
          for b in 1..<other.line.length() {
            let r = other.line[b - 1]
            let s = other.line[b]
            let vertical = p.x == q.x &&
              r.x == s.x &&
              (p.x - r.x).abs() < 0.01 &&
              p.y.min(q.y).max(r.y.min(s.y)) <
              p.y.max(q.y).min(r.y.max(s.y)) - 0.01
            let horizontal = p.y == q.y &&
              r.y == s.y &&
              (p.y - r.y).abs() < 0.01 &&
              p.x.min(q.x).max(r.x.min(s.x)) <
              p.x.max(q.x).min(r.x.max(s.x)) - 0.01
            assert_false(
              vertical || horizontal,
              msg=edge.connection.id + " overlaps " + other.connection.id,
            )
          }
        }
      }
    }
  }
}

///|
fn routed_side(line : ReadOnlyArray[Point], source : Bool) -> Int32 {
  let anchor = if source { line[0] } else { line[line.length() - 1] }
  let outside = if source { line[1] } else { line[line.length() - 2] }
  if outside.x > anchor.x {
    0
  } else if outside.x < anchor.x {
    2
  } else if outside.y > anchor.y {
    1
  } else {
    3
  }
}

///|
fn assert_port_distribution(
  geometry : Geometry,
  id : String,
  source : Bool,
) -> Int32 raise {
  let box = placed(geometry, id).outline_box
  let groups : Map[Int32, Array[Double]] = Map([])
  for edge in geometry.connections {
    if (if source { edge.source } else { edge.target }) != id {
      continue
    }
    let side = routed_side(edge.line, source)
    let point = if source {
      edge.line[0]
    } else {
      edge.line[edge.line.length() - 1]
    }
    assert_true(
      on_shape(point, placed(geometry, id)),
      msg=id + " actual outline",
    )
    let coordinate = if side == 0 || side == 2 { point.y } else { point.x }
    if groups.get(side) is Some(points) {
      points.push(coordinate)
    } else {
      groups[side] = [coordinate]
    }
  }
  let mut side_count = 0
  for (side, points) in groups {
    side_count += 1
    points.sort_by((a, b) => a.compare(b))
    let extent = if side == 0 || side == 2 { box.height } else { box.width }
    let origin = if side == 0 || side == 2 { box.y } else { box.x }
    if points.length() == 1 {
      assert_true(
        (points[0] - origin - extent / 2.0).abs() < 0.001,
        msg="one port is centered",
      )
    } else {
      let padding = 8.0.min(extent / 4.0)
      assert_true(
        (points[0] - origin - padding).abs() < 0.001,
        msg="first port uses the padded side start",
      )
      assert_true(
        (points[points.length() - 1] - origin - extent + padding).abs() < 0.001,
        msg="last port uses the padded side end",
      )
      let spacing = points[1] - points[0]
      assert_true(spacing > 0.0)
      for i in 2..<points.length() {
        assert_true(
          (points[i] - points[i - 1] - spacing).abs() < 0.001,
          msg="ports are evenly spaced on each side",
        )
      }
    }
  }
  side_count
}

///|
test "one two three and dense marked ports use the full side extent in every direction" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    for shape in ["rect", "circle"] {
      for count in [1, 2, 3, 8] {
        let view = @model.Swimlane::new(
          "spread ports",
          [@model.Node::new("A", shape~), @model.Node::new("B")],
          Array::makei(count, i => {
            @model.Connection::new(
              "edge-\{i}",
              "A",
              "B",
              source_marker=Arrow,
              target_marker=Arrow,
            )
          }),
          direction~,
        )
        let geometry = clean(view)
        assert_eq(geometry.connections.length(), count)
        let source_sides = assert_port_distribution(geometry, "A", true)
        let target_sides = assert_port_distribution(geometry, "B", false)
        if count <= 3 {
          assert_eq(source_sides, 1)
          assert_eq(target_sides, 1)
        }
        if count == 8 {
          assert_true(source_sides > 1)
          assert_true(target_sides > 1)
        }
        if shape == "circle" {
          let box = placed(geometry, "A").outline_box
          assert_eq(box.width, box.height)
        }
      }
    }
  }
}

///|
test "feedback uses spare vertical sides and explicit direction hints remain fixed" {
  for direction in [@model.Direction::LR, RL, TB, BT] {
    let view = @model.Swimlane::new(
      "feedback",
      [@model.Node::new("A"), @model.Node::new("B"), @model.Node::new("C")],
      [
        @model.Connection::new("AB", "A", "B"),
        @model.Connection::new("BC", "B", "C"),
        @model.Connection::new("CA", "C", "A"),
      ],
      direction~,
    )
    let result = layout(view, flowchart=true)
    assert_true(
      result.geometry is Some(_),
      msg=@debug.to_string(result.diagnostics),
    )
    let geometry = result.geometry.unwrap()
    let feedback = geometry.connections
      .iter()
      .find_first(e => e.connection.id == "CA")
      .unwrap()
    let chosen = routed_side(feedback.line, true)
    assert_eq(chosen, routed_side(feedback.line, false))
    if horizontal(direction) {
      assert_true(chosen == 1 || chosen == 3)
    } else {
      assert_true(chosen == 0 || chosen == 2)
    }
    let hinted = layout(view, flowchart=true, direction_hints=[
      ("CA", direction),
    ]).geometry.unwrap()
    let feedback = hinted.connections
      .iter()
      .find_first(e => e.connection.id == "CA")
      .unwrap()
    assert_eq(
      (routed_side(feedback.line, true), routed_side(feedback.line, false)),
      match direction {
        LR => (0, 2)
        RL => (2, 0)
        TB => (1, 3)
        BT => (3, 1)
      },
    )
  }
}

///|
test "thin fork ports keep a positive padded span with explicit side choices" {
  let view = @model.Swimlane::new(
    "thin",
    [@model.Node::new("A", shape="fork"), @model.Node::new("B")],
    [
      @model.Connection::new("one", "A", "B"),
      @model.Connection::new("two", "A", "B"),
    ],
    direction=LR,
  )
  let result = layout(view, direction_hints=[("one", TB), ("two", TB)])
  assert_true(
    result.geometry is Some(_),
    msg=@debug.to_string(result.diagnostics),
  )
  let geometry = result.geometry.unwrap()
  assert_eq(assert_port_distribution(geometry, "A", true), 1)
  for edge in geometry.connections {
    assert_eq(routed_side(edge.line, true), 1)
  }
}

///|
test "indexed grid search keeps subpixel collinear clearance" {
  let budget : Budget = {
    limits: Limits::new(),
    diagnostics: [],
    work: 0,
    failed: false,
  }
  let occupied : Array[(Point, Point)] = [
    ({ x: 20.0, y: 0.005, }, { x: 80.0, y: 0.005, }),
  ]
  let obstacles : Array[Rect] = [
    { x: 40.0, y: 40.0, width: 20.0, height: 50.0, },
  ]
  let line = orthogonal(
    { x: 0.0, y: 0.0, },
    { x: 100.0, y: 0.0, },
    obstacles,
    64.0,
    None,
    budget,
    occupied~,
  ).unwrap()
  assert_true(
    line.iter().any(p => p.y.abs() > 0.01),
    msg="A* reused a subpixel occupied channel",
  )
}

///|
test "diagonal forward handoffs use clear spare sides before bundles become crowded" {
  for direction in [@model.Direction::LR, RL, TB, BT] {
    let view = @model.Swimlane::new(
      "diagonal handoffs",
      ["A", "B", "C", "D"].map(id => @model.Node::new(id)),
      [
        @model.Connection::new("AC", "A", "C"),
        @model.Connection::new("BD", "B", "D"),
        @model.Connection::new("AD", "A", "D"),
        @model.Connection::new("BC", "B", "C"),
      ],
      direction~,
    )
    let geometry = clean(view)
    for edge in geometry.connections {
      let pair = (routed_side(edge.line, true), routed_side(edge.line, false))
      if edge.connection.id == "AC" || edge.connection.id == "BD" {
        assert_eq(
          pair,
          match direction {
            LR => (0, 2)
            RL => (2, 0)
            TB => (1, 3)
            BT => (3, 1)
          },
        )
      } else if edge.connection.id == "AD" {
        assert_eq(pair, if horizontal(direction) { (1, 3) } else { (0, 2) })
      } else {
        assert_eq(pair, if horizontal(direction) { (3, 1) } else { (2, 0) })
      }
    }
  }
}
