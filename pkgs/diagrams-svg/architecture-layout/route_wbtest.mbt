///|
test "nested groups reserve marker approaches below headers and outside viewport borders" {
  let model = @model.Architecture::new(
    "nested-approach",
    [
      @model.Service::new("a", parent="inner"),
      @model.Service::new("b", parent="outer"),
    ],
    [
      @model.Connection::new(
        "headers",
        @model.Endpoint::new("a", Top),
        @model.Endpoint::new("b", Top),
        source_head=true,
        target_head=true,
      ),
      @model.Connection::new(
        "outer-port",
        @model.Endpoint::new("a", Right, group=true),
        @model.Endpoint::new("b", Left, group=true),
        target_head=true,
      ),
    ],
    groups=[
      @model.Group::new("outer"),
      @model.Group::new("inner", parent="outer"),
    ],
  )
  for minimum in [24.0, 64.0] {
    let result = layout(model, limits=Limits::new(minimum_approach=minimum))
    assert_true(
      result.geometry is Some(_),
      msg=result.diagnostics.iter().map(d => d.message).to_array().join("; "),
    )
    let geometry = result.geometry.unwrap()
    assert_eq(check(geometry), [])
    for route in geometry.connections {
      let start = route.points[0]
      let first = route.points[1]
      let last = route.points[route.points.length() - 1]
      let before = route.points[route.points.length() - 2]
      assert_true(
        (start.x - first.x).abs() + (start.y - first.y).abs() >=
        minimum.to_int(),
      )
      assert_true(
        (last.x - before.x).abs() + (last.y - before.y).abs() >=
        minimum.to_int(),
      )
      assert_true(route.points.iter().all(p => p.x >= 0 && p.y >= 0))
    }
  }
}

///|
test "independent architecture connections receive separate collinear channels" {
  let model = @model.Architecture::new(
    "channels",
    [
      @model.Service::new("a"),
      @model.Service::new("b"),
      @model.Service::new("c"),
      @model.Service::new("d"),
    ],
    [
      @model.Connection::new(
        "ac",
        @model.Endpoint::new("a", Right),
        @model.Endpoint::new("c", Left),
      ),
      @model.Connection::new(
        "bd",
        @model.Endpoint::new("b", Right),
        @model.Endpoint::new("d", Left),
      ),
    ],
  )
  let geometry = layout(model).geometry.unwrap()
  assert_eq(check(geometry), [])
  let a = geometry.connections[0].points
  let b = geometry.connections[1].points
  for i in 1..<a.length() {
    for j in 1..<b.length() {
      let p = a[i - 1]
      let q = a[i]
      let r = b[j - 1]
      let s = b[j]
      let horizontal = p.y == q.y && r.y == s.y && p.y == r.y
      let vertical = p.x == q.x && r.x == s.x && p.x == r.x
      assert_false(
        (
          horizontal &&
          p.x.min(q.x).max(r.x.min(s.x)) < p.x.max(q.x).min(r.x.max(s.x))
        ) ||
        (
          vertical &&
          p.y.min(q.y).max(r.y.min(s.y)) < p.y.max(q.y).min(r.y.max(s.y))
        ),
      )
    }
  }
}

///|
test "architecture channel reservations allow transverse crossings within the work budget" {
  let budget = RouteBudget::{ limit: 1000, work: 0, failed: false, }
  assert_true(
    clear([{ x: 20, y: 50, }, { x: 80, y: 50, }], [], budget, occupied=[
      ({ x: 50, y: 20, }, { x: 50, y: 80, }),
    ]),
  )
  assert_false(
    clear([{ x: 20, y: 50, }, { x: 80, y: 50, }], [], budget, occupied=[
      ({ x: 40, y: 50, }, { x: 100, y: 50, }),
    ]),
  )
  let bounded = RouteBudget::{ limit: 0, work: 0, failed: false, }
  assert_false(
    clear([{ x: 20, y: 50, }, { x: 80, y: 50, }], [], bounded, occupied=[
      ({ x: 50, y: 20, }, { x: 50, y: 80, }),
    ]),
  )
  assert_true(bounded.failed)
}

///|
test "incident architecture ports fill the usable side evenly and keep a single port centered" {
  let edges = Array::makei(4, index => {
    @model.Connection::new(
      "edge-\{index}",
      @model.Endpoint::new("a", Right),
      @model.Endpoint::new("b", Left),
      source_head=true,
      target_head=true,
    )
  })
  let model = @model.Architecture::new(
    "spread",
    [@model.Service::new("a"), @model.Service::new("b")],
    edges[:],
  )
  let geometry = layout(model).geometry.unwrap()
  assert_eq(check(geometry), [])
  let a = geometry.shapes.iter().find_first(s => s.id == "a").unwrap()
  let b = geometry.shapes.iter().find_first(s => s.id == "b").unwrap()
  let source_y = geometry.connections.map(c => c.points[0].y).iter().to_array()
  let target_y = geometry.connections
    .map(c => c.points[c.points.length() - 1].y)
    .iter()
    .to_array()
  source_y.sort()
  target_y.sort()
  assert_eq(source_y[0], a.box.y + 12)
  assert_eq(source_y[3], a.box.y + a.box.height - 12)
  assert_eq(target_y[0], b.box.y + 12)
  assert_eq(target_y[3], b.box.y + b.box.height - 12)
  for positions in [source_y, target_y] {
    let gaps = Array::makei(positions.length() - 1, index => {
      positions[index + 1] - positions[index]
    })
    assert_true(gaps.iter().all(gap => (gap - gaps[0]).abs() <= 1))
  }
  for c in geometry.connections {
    assert_eq(c.points[0].x, a.box.x + a.box.width)
    assert_eq(c.points[c.points.length() - 1].x, b.box.x)
  }
  let single = layout(
    @model.Architecture::new("single", model.services[:], [edges[0]]),
  ).geometry.unwrap()
  let a = single.shapes.iter().find_first(s => s.id == "a").unwrap()
  let b = single.shapes.iter().find_first(s => s.id == "b").unwrap()
  assert_eq(single.connections[0].points[0].y, a.box.y + a.box.height / 2)
  assert_eq(
    single.connections[0].points.last().unwrap().y,
    b.box.y + b.box.height / 2,
  )
}

///|
test "spread group-boundary ports stay adjacent to the authored service" {
  let edges = Array::makei(4, index => {
    @model.Connection::new(
      "edge-\{index}",
      @model.Endpoint::new("a", Right, group=true),
      @model.Endpoint::new("b", Left),
      target_head=true,
    )
  })
  let model = @model.Architecture::new(
    "group-spread",
    [@model.Service::new("a", parent="g"), @model.Service::new("b")],
    edges[:],
    groups=[@model.Group::new("g")],
  )
  let geometry = layout(model).geometry.unwrap()
  assert_eq(check(geometry), [])
  let group = geometry.shapes.iter().find_first(s => s.id == "g").unwrap()
  let service = geometry.shapes.iter().find_first(s => s.id == "a").unwrap()
  let ys = geometry.connections.map(c => c.points[0].y).iter().to_array()
  ys.sort()
  assert_eq(ys[0], service.box.y + 12)
  assert_eq(ys[3], service.box.y + service.box.height - 12)
  for c in geometry.connections {
    let p = c.points[0]
    assert_eq(p.x, group.box.x + group.box.width)
    assert_true(
      p.y >= service.box.y + 12 &&
      p.y <= service.box.y + service.box.height - 12,
    )
    assert_true(p.y > group.box.y + group.header_height)
  }
}

///|
test "ports in different adjacent service spans stay separated within their bounds" {
  let requests = [
    PortAttachment::{ key: 0, lower: 12, upper: 96, center: 54, },
    PortAttachment::{ key: 1, lower: 212, upper: 296, center: 254, },
    PortAttachment::{ key: 2, lower: 12, upper: 96, center: 54, },
    PortAttachment::{ key: 3, lower: 212, upper: 296, center: 254, },
  ]
  let budget = RouteBudget::{ limit: 1000, work: 0, failed: false, }
  let result = distribute_ports(Map([(("group", "R"), requests)]), budget).unwrap()
  assert_eq([result[0], result[2]], [12, 96])
  assert_eq([result[1], result[3]], [212, 296])
  let limited = RouteBudget::{ limit: 0, work: 0, failed: false, }
  assert_true(
    distribute_ports(Map([(("group", "R"), requests)]), limited) is None,
  )
  assert_true(limited.failed)
}

///|
test "shared junction ports retain their actual cardinal outline point" {
  let view = @model.Architecture::new(
    "join",
    [@model.Service::new("a"), @model.Service::new("b")],
    [
      @model.Connection::new(
        "ja",
        @model.Endpoint::new("j", Right),
        @model.Endpoint::new("a", Left),
      ),
      @model.Connection::new(
        "jb",
        @model.Endpoint::new("j", Right),
        @model.Endpoint::new("b", Left),
      ),
    ],
    junctions=[@model.Junction::new("j")],
  )
  let geometry = layout(view).geometry.unwrap()
  let junction = geometry.shapes.iter().find_first(s => s.id == "j").unwrap()
  let cardinal = Point::{
    x: junction.box.x + junction.box.width,
    y: junction.box.y + junction.box.height / 2,
  }
  for c in geometry.connections {
    assert_eq(c.points[0], cardinal)
  }
  assert_eq(check(geometry), [])
}

///|
test "incoming and outgoing connections share one outline-side distribution" {
  let view = @model.Architecture::new(
    "mixed-ports",
    [
      @model.Service::new("a"),
      @model.Service::new("b"),
      @model.Service::new("c"),
    ],
    [
      @model.Connection::new(
        "out",
        @model.Endpoint::new("a", Right),
        @model.Endpoint::new("b", Left),
        target_head=true,
      ),
      @model.Connection::new(
        "in",
        @model.Endpoint::new("c", Left),
        @model.Endpoint::new("a", Right),
        target_head=true,
      ),
    ],
  )
  let geometry = layout(view).geometry.unwrap()
  assert_eq(check(geometry), [])
  let box = geometry.shapes.iter().find_first(s => s.id == "a").unwrap().box
  let out = geometry.connections[0].points[0]
  let incoming = geometry.connections[1].points.last().unwrap()
  assert_eq(out, { x: box.x + box.width, y: box.y + 12, })
  assert_eq(incoming, { x: box.x + box.width, y: box.y + box.height - 12, })
}
