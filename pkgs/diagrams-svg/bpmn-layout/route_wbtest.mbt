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
    occupied,
    64.0,
    None,
    budget,
  ).unwrap()
  assert_true(
    line.iter().any(p => p.y.abs() > 0.01),
    msg="A* reused a subpixel occupied channel",
  )
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
fn manual_port_routes(
  target_box : Rect,
  count : Int32,
) -> (Array[Shape], Array[Connection]) raise {
  let nodes = [@model.Node::new("A", Task), @model.Node::new("B", Task)]
  let view = @model.Bpmn::new(
    "port routes",
    nodes,
    Array::makei(count, i => @model.Flow::new("flow-\{i}", "A", "B")),
  )
  let boxes = [
    Rect::{ x: 400.0, y: 400.0, width: 140.0, height: 100.0, },
    target_box,
  ]
  let shapes = Array::makei(2, i => Shape::{
    node: nodes[i],
    index: i,
    box: boxes[i],
    bounds: exact_bounds(boxes[i]),
    label: None,
  })
  let budget : Budget = {
    limits: Limits::new(),
    diagnostics: [],
    work: 0,
    failed: false,
  }
  let connections = route_connections(
    view,
    Array::makei(count, i => (i, 0, 1)),
    shapes,
    [-1, -1],
    budget,
  )
  assert_false(budget.failed, msg=@debug.to_string(budget.diagnostics))
  assert_eq(connections.length(), count)
  (shapes, connections)
}

///|
test "BPMN spreads ports per side and uses spare sides for feedback and dense bundles" {
  for
    target_box in [
      Rect::{ x: 800.0, y: 400.0, width: 140.0, height: 100.0, },
      { x: 64.0, y: 400.0, width: 140.0, height: 100.0, },
      { x: 400.0, y: 800.0, width: 140.0, height: 100.0, },
      { x: 400.0, y: 64.0, width: 140.0, height: 100.0, },
    ] {
    for count in [1, 2, 3, 8] {
      let (shapes, connections) = manual_port_routes(target_box, count)
      for (source, index) in [(true, 0), (false, 1)] {
        let groups : Map[Int32, Array[Double]] = Map([])
        for edge in connections {
          let side = routed_side(edge.line, source)
          let point = if source {
            edge.line[0]
          } else {
            edge.line[edge.line.length() - 1]
          }
          assert_true(
            on_shape(point, shapes[index]),
            msg="spread port attaches to the activity's rounded outline",
          )
          let coordinate = if side == 0 || side == 2 {
            point.y
          } else {
            point.x
          }
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
          let box = shapes[index].box
          let extent = if side == 0 || side == 2 {
            box.height
          } else {
            box.width
          }
          let origin = if side == 0 || side == 2 { box.y } else { box.x }
          if points.length() == 1 {
            assert_true((points[0] - origin - extent / 2.0).abs() < 0.001)
          } else {
            assert_true(
              (points[0] -
              origin -
              shape_profile(shapes[index], side, Budget::{
                limits: Limits::new(),
                diagnostics: [],
                work: 0,
                failed: false,
              }).padding).abs() <
              0.001,
              msg="first port near the usable side start",
            )
            assert_true(
              (points[points.length() - 1] -
              origin -
              extent +
              shape_profile(shapes[index], side, Budget::{
                limits: Limits::new(),
                diagnostics: [],
                work: 0,
                failed: false,
              }).padding).abs() <
              0.001,
              msg="last port near the usable side end",
            )
            let spacing = points[1] - points[0]
            assert_true(spacing > 0.0)
            for i in 2..<points.length() {
              assert_true(
                (points[i] - points[i - 1] - spacing).abs() < 0.001,
                msg="even side distribution",
              )
            }
          }
        }
        if count == 8 {
          assert_true(side_count > 1, msg="dense bundle uses a spare side")
        }
      }
    }
  }
  let (_, connections) = manual_port_routes(
    { x: 64.0, y: 400.0, width: 140.0, height: 100.0, },
    1,
  )
  let from = routed_side(connections[0].line, true)
  assert_eq(from, routed_side(connections[0].line, false))
  assert_true(
    from == 1 || from == 3,
    msg="a horizontal return uses top or bottom approaches",
  )
}

///|
test "BPMN diagonal forward flows use clear bottom and top opportunities" {
  let nodes = ["A", "B", "C", "D"].map(id => @model.Node::new(id, Task))
  let view = @model.Bpmn::new("diagonal flows", nodes, [
    @model.Flow::new("AC", "A", "C"),
    @model.Flow::new("BD", "B", "D"),
    @model.Flow::new("AD", "A", "D"),
    @model.Flow::new("BC", "B", "C"),
  ])
  let boxes = [
    Rect::{ x: 400.0, y: 400.0, width: 140.0, height: 100.0, },
    { x: 400.0, y: 700.0, width: 140.0, height: 100.0, },
    { x: 800.0, y: 400.0, width: 140.0, height: 100.0, },
    { x: 800.0, y: 700.0, width: 140.0, height: 100.0, },
  ]
  let shapes = Array::makei(4, i => Shape::{
    node: nodes[i],
    index: i,
    box: boxes[i],
    bounds: exact_bounds(boxes[i]),
    label: None,
  })
  let budget : Budget = {
    limits: Limits::new(),
    diagnostics: [],
    work: 0,
    failed: false,
  }
  let connections = route_connections(
    view,
    [(0, 0, 2), (1, 1, 3), (2, 0, 3), (3, 1, 2)],
    shapes,
    [-1, -1, -1, -1],
    budget,
  )
  assert_false(budget.failed, msg=@debug.to_string(budget.diagnostics))
  assert_eq(connections.length(), 4)
  assert_eq(
    (
      routed_side(connections[0].line, true),
      routed_side(connections[0].line, false),
    ),
    (0, 2),
  )
  assert_eq(
    (
      routed_side(connections[1].line, true),
      routed_side(connections[1].line, false),
    ),
    (0, 2),
  )
  assert_eq(
    (
      routed_side(connections[2].line, true),
      routed_side(connections[2].line, false),
    ),
    (1, 3),
  )
  assert_eq(
    (
      routed_side(connections[3].line, true),
      routed_side(connections[3].line, false),
    ),
    (3, 1),
  )
}

///|
test "spread ports near rounded and folded corners retain actual outline attachment" {
  for
    (kind, box) in [
      (
        @model.NodeKind::Task,
        Rect::{ x: 100.0, y: 100.0, width: 140.0, height: 100.0, },
      ),
      (Group, { x: 100.0, y: 100.0, width: 140.0, height: 100.0, }),
      (DataObject, { x: 100.0, y: 100.0, width: 48.0, height: 64.0, }),
    ] {
    let shape : Shape = {
      node: @model.Node::new("shape", kind),
      index: 0,
      box,
      bounds: exact_bounds(box),
      label: None,
    }
    for side in 0..<4 {
      for count in [2, 3] {
        for rank in 0..<count {
          assert_true(
            on_shape(
              port(
                shape,
                side,
                @attachment.attachment_profile(
                  if activity(kind) {
                    "bpmn-activity"
                  } else {
                    "rect"
                  },
                  box.width,
                  box.height,
                  side,
                  0.0,
                ).fraction(rank, count),
              ),
              shape,
            ),
            msg="spread corner port attaches to its drawn outline",
          )
        }
      }
    }
  }
}

///|
test "automatic gateway profiles use measured cardinal points and separate crowded terminals" {
  for
    (dx, dy, expected) in [
      (400.0, 0.0, 0),
      (0.0, 400.0, 1),
      (-400.0, 0.0, 2),
      (0.0, -400.0, 3),
    ] {
    for count in [1, 2, 4, 8] {
      let nodes = [
        @model.Node::new("A", ExclusiveGateway),
        @model.Node::new("B", Task),
      ]
      let view = @model.Bpmn::new(
        "gateway",
        nodes,
        Array::makei(count, i => @model.Flow::new("f-\{i}", "A", "B")),
      )
      let boxes = [
        Rect::{ x: 500.0, y: 500.0, width: 160.0, height: 80.0, },
        { x: 500.0 + dx, y: 500.0 + dy, width: 160.0, height: 80.0, },
      ]
      let shapes = Array::makei(2, i => Shape::{
        node: nodes[i],
        index: i,
        box: boxes[i],
        bounds: exact_bounds(boxes[i]),
        label: None,
      })
      let budget : Budget = {
        limits: Limits::new(),
        diagnostics: [],
        work: 0,
        failed: false,
      }
      let edges = route_connections(
        view,
        Array::makei(count, i => (i, 0, 1)),
        shapes,
        [-1, -1],
        budget,
      )
      assert_false(budget.failed, msg=@debug.to_string(budget.diagnostics))
      assert_eq(edges.length(), count)
      let endpoints = []
      for edge in edges {
        let start = edge.line[0]
        assert_true(on_shape(start, shapes[0]))
        assert_false(endpoints.contains(start))
        endpoints.push(start)
        assert_eq(edge.flow, view.flows[edge.index])
        if count == 1 {
          // The established feedback policy can choose a transverse free point.
          if expected == 0 || expected == 1 {
            assert_eq(routed_side(edge.line, true), expected)
          }
          assert_eq(start, port(shapes[0], routed_side(edge.line, true), 0.5))
        }
        let next = edge.line[1]
        assert_true((next.x - start.x).abs() + (next.y - start.y).abs() >= 24.0)
      }
    }
  }
}
