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

///|
test "review decision uses available distinct diamond points before sloping edges" {
  let geometry = clean(example(TB))
  let diamond = placed(geometry, "B")
  let box = diamond.outline_box
  let points = [
    Point::{ x: box.x + box.width, y: box.y + box.height / 2.0, },
    { x: box.x + box.width / 2.0, y: box.y + box.height, },
    { x: box.x, y: box.y + box.height / 2.0, },
    { x: box.x + box.width / 2.0, y: box.y, },
  ]
  let endpoints = []
  for edge in geometry.connections {
    if edge.source == "B" {
      endpoints.push(edge.line[0])
    }
    if edge.target == "B" {
      endpoints.push(edge.line[edge.line.length() - 1])
    }
  }
  // This example has five incidents, so at least two must use a safe fallback.
  // Uncrowded sides must still use their exact measured point.
  assert_true(endpoints.iter().filter(p => points.contains(p)).count() >= 2)
}

///|
test "minimal decision fan uses three distinct natural points" {
  let view = @model.Swimlane::new(
    "decision",
    [
      @model.Node::new("A"),
      @model.Node::new("B", shape="diamond"),
      @model.Node::new("C"),
      @model.Node::new("D"),
    ],
    [
      @model.Connection::new("AB", "A", "B"),
      @model.Connection::new("BC", "B", "C"),
      @model.Connection::new("BD", "B", "D"),
    ],
  )
  let geometry = clean(view)
  let box = placed(geometry, "B").outline_box
  for edge in geometry.connections {
    let p = if edge.source == "B" {
      edge.line[0]
    } else {
      edge.line[edge.line.length() - 1]
    }
    assert_true(
      (
        (p.x - box.x - box.width / 2.0).abs() < 0.001 &&
        (p.y == box.y || p.y == box.y + box.height)
      ) ||
      (
        (p.y - box.y - box.height / 2.0).abs() < 0.001 &&
        (p.x == box.x || p.x == box.x + box.width)
      ),
      msg=@debug.to_string(p),
    )
  }
}

///|
test "measured diamond points and marked approaches follow all four directions" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    for shape in ["diamond", "choice"] {
      let view = @model.Swimlane::new(
        "measured decision",
        [
          @model.Node::new(
            "A",
            shape~,
            label="a deliberately wide decision label",
          ),
          @model.Node::new("B", shape="rounded"),
        ],
        [@model.Connection::new("AB", "A", "B", source_marker=Arrow)],
        direction~,
      )
      let original = @debug.to_string(view)
      let geometry = clean(view)
      assert_eq(@debug.to_string(view), original)
      assert_eq(layout(view).geometry, Some(geometry))
      let source = placed(geometry, "A")
      assert_true(source.outline_box.width != source.outline_box.height)
      let edge = geometry.connections[0]
      let chosen = match direction {
        TB => 1
        BT => 3
        LR => 0
        RL => 2
      }
      assert_eq(
        routed_side(edge.line, true),
        chosen,
        msg=@debug.to_string((direction, shape, geometry)),
      )
      assert_eq(edge.line[0], port(source, chosen, 0.5))
      assert_true(
        (edge.line[0].x - edge.line[1].x).abs() +
        (edge.line[0].y - edge.line[1].y).abs() >=
        24.0,
      )
      assert_eq(edge.connection, view.connections[0])
    }
  }
}

///|
test "diamond parallel reciprocal and self terminals remain distinct with safe constrained fallback" {
  for direction in [@model.Direction::TB, BT, LR, RL] {
    for count in [2, 4, 8] {
      let view = @model.Swimlane::new(
        "crowded diamond",
        [@model.Node::new("A", shape="diamond"), @model.Node::new("B")],
        Array::makei(count, i => {
          @model.Connection::new("edge-\{i}", "A", "B", source_marker=Arrow)
        }),
        direction~,
      )
      for constrained in [false, true] {
        let hints = if constrained {
          view.connections.iter().map(e => (e.id, direction)).to_array()
        } else {
          []
        }
        let result = layout(view, direction_hints=hints)
        assert_true(
          result.geometry != None,
          msg=@debug.to_string(result.diagnostics),
        )
        let geometry = result.geometry.unwrap()
        assert_eq(check(geometry, palette(@theme.Theme::classic().light)), [])
        let source = placed(geometry, "A")
        let endpoints = []
        for edge in geometry.connections {
          assert_true(on_shape(edge.line[0], source))
          assert_false(
            endpoints.contains(edge.line[0]),
            msg="independent connections do not share a point",
          )
          endpoints.push(edge.line[0])
          if constrained {
            assert_eq(
              routed_side(edge.line, true),
              match direction {
                LR => 0
                RL => 2
                TB => 1
                BT => 3
              },
            )
          }
          assert_eq(edge.connection, view.connections[edge.index])
        }
      }
    }
    let geometry = clean(example(direction))
    let self_edge = geometry.connections
      .iter()
      .find_first(e => e.source == e.target)
      .unwrap()
    assert_true(
      self_edge.line[0] != self_edge.line[self_edge.line.length() - 1],
    )
  }
}

///|
test "attachment profiles keep rounded and box spans usable and bounded" {
  for side in 0..<4 {
    for shape in ["rect", "rounded", "stadium", "circle", "diamond"] {
      let profile = attachment_profile(shape, 160.0, 80.0, side, 8.0)
      assert_true(
        profile.padding >= 8.0 && profile.padding <= profile.extent / 4.0,
      )
      assert_eq(profile.fraction(0, 1), 0.5)
      assert_eq(profile.sides(side, true), [side])
      assert_true(profile.sides(side, false).length() <= 4)
      for count in [2, 3, 8] {
        let first = profile.fraction(0, count)
        let last = profile.fraction(count - 1, count)
        assert_true(first > 0.0 && last < 1.0)
        assert_true((first + last - 1.0).abs() < 0.001)
      }
    }
  }
  let result = layout(example(TB), limits=Limits::new(work=100))
  assert_eq(result.geometry, None)
  assert_true(
    result.diagnostics.iter().any(d => d.code == "swimlane/layout-limit"),
  )
}

///|
test "blocked preferred point selects a complete clear alternative route" {
  let nodes = [
    @model.Node::new("A", shape="diamond"),
    @model.Node::new("B"),
    @model.Node::new("blocked"),
  ]
  let boxes = [
    Rect::{ x: 100.0, y: 100.0, width: 160.0, height: 80.0, },
    { x: 500.0, y: 100.0, width: 112.0, height: 64.0, },
    { x: 270.0, y: 110.0, width: 40.0, height: 60.0, },
  ]
  let shapes = Array::makei(3, i => Shape::{
    id: nodes[i].id,
    index: i,
    kind: Node,
    shape: nodes[i].shape,
    box: boxes[i],
    outline_box: boxes[i],
    label: None,
    parent: None,
    lane: None,
    expanded: true,
  })
  let view = @model.Swimlane::new(
    "blocked",
    nodes,
    [@model.Connection::new("AB", "A", "B")],
    direction=LR,
  )
  let budget : Budget = {
    limits: Limits::new(),
    diagnostics: [],
    work: 0,
    failed: false,
  }
  let edges = route_connections(view, [(0, 0, 1)], shapes, [-1, -1, -1], budget)
  assert_false(budget.failed, msg=@debug.to_string(budget.diagnostics))
  assert_eq(edges.length(), 1)
  let exhausted : Budget = {
    limits: Limits::new(work=1),
    diagnostics: [],
    work: 0,
    failed: false,
  }
  assert_eq(
    route_connections(view, [(0, 0, 1)], shapes, [-1, -1, -1], exhausted),
    [],
  )
  assert_true(exhausted.failed)
  assert_eq(exhausted.diagnostics[0].code, "swimlane/layout-limit")
  assert_true(routed_side(edges[0].line, true) != 0)
  for i in 1..<edges[0].line.length() {
    assert_false(crosses(edges[0].line[i - 1], edges[0].line[i], boxes[2]))
  }
  let geometry : Geometry = {
    view,
    shapes: ReadOnlyArray::from_array(shapes),
    connections: ReadOnlyArray::from_array(edges),
    width: 800,
    height: 400,
  }
  assert_eq(check(geometry, palette(@theme.Theme::classic().light)), [])
  let broken = {
    ..edges[0],
    line: ReadOnlyArray::from_array([
      Point::{ x: 260.0, y: 140.0, },
      { x: 500.0, y: 140.0, },
    ]),
  }
  let findings = check(
    { ..geometry, connections: [broken], },
    palette(@theme.Theme::classic().light),
  )
  assert_true(
    findings
    .iter()
    .any(f => f.rule == Overlap && f.identities.contains("blocked")),
  )
}
