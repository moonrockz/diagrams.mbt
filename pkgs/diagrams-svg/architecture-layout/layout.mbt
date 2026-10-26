///|
fn root(parents : Array[Int32], index : Int32) -> Int32 {
  let mut i = index
  while parents[i] != i {
    i = parents[i]
  }
  i
}

///|
fn union(parents : Array[Int32], a : Int32, b : Int32) -> Unit {
  let a = root(parents, a)
  let b = root(parents, b)
  if a != b {
    parents[b] = a
  }
}

///|
fn port(box : Rect, side : @model.Side, offset : Int32) -> Point {
  match side {
    Left => { x: box.x, y: box.y + box.height / 2 + offset, }
    Right => { x: box.x + box.width, y: box.y + box.height / 2 + offset, }
    Top => { x: box.x + box.width / 2 + offset, y: box.y, }
    Bottom => { x: box.x + box.width / 2 + offset, y: box.y + box.height, }
  }
}

///|
fn outward(p : Point, side : @model.Side, distance : Int32) -> Point {
  match side {
    Left => { x: p.x - distance, y: p.y, }
    Right => { x: p.x + distance, y: p.y, }
    Top => { x: p.x, y: p.y - distance, }
    Bottom => { x: p.x, y: p.y + distance, }
  }
}

///|
pub fn layout(
  model : @model.Architecture,
  limits~ : Limits = Limits::new(),
) -> LayoutResult {
  let diagnostics = @model.validate(
      model,
      nodes_limit=limits.nodes,
      edges_limit=limits.edges,
      depth_limit=limits.depth,
      work_limit=limits.work,
    )
    .iter()
    .to_array()
  fn failed(code : String, message : String) -> LayoutResult {
    diagnostics.push(
      @diagrams.Diagnostic::error("architecture/" + code, message),
    )
    { geometry: None, diagnostics: ReadOnlyArray::from_array(diagnostics[:]), }
  }
  if !diagnostics.is_empty() {
    return {
      geometry: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    }
  }
  let ids = []
  let labels = []
  let parents = []
  let kinds = []
  let widths = []
  let heights = []
  let indices : Map[String, Int32] = Map([])
  for n in model.services {
    indices[n.id] = ids.length()
    ids.push(n.id)
    labels.push(n.label)
    parents.push(n.parent)
    kinds.push(Kind::Service)
    widths.push(
      (measure(n.label) + 32)
      .max(n.icon_text.map(v => measure(v) + 32).unwrap_or(0))
      .max(n.icon.map(v => measure(v.key) + 32).unwrap_or(0))
      .max(120),
    )
    heights.push(
      50 +
      n.icon_text.map(v => v.split("\n").count() * 18).unwrap_or(40).max(40) +
      n.label.split("\n").count() * 18,
    )
  }
  for n in model.junctions {
    indices[n.id] = ids.length()
    ids.push(n.id)
    labels.push("")
    parents.push(n.parent)
    kinds.push(Kind::Junction)
    widths.push(16)
    heights.push(16)
  }
  let count = ids.length()
  let xs = Array::makei(count, i => i)
  let ys = Array::makei(count, i => i)
  let mut work = 0
  for alignment in model.alignments {
    let a = indices[alignment.members[0]]
    for element in alignment.members {
      let b = indices[element]
      if alignment.axis == Row {
        union(ys, a, b)
      } else {
        union(xs, a, b)
      }
      work += 1
    }
  }
  let xedges : Array[(Int32, Int32)] = []
  let yedges : Array[(Int32, Int32)] = []
  for alignment in model.alignments {
    for i = 1; i < alignment.members.length(); i = i + 1 {
      let a = indices[alignment.members[i - 1]]
      let b = indices[alignment.members[i]]
      if alignment.axis == Row {
        xedges.push((root(xs, a), root(xs, b)))
      } else {
        yedges.push((root(ys, a), root(ys, b)))
      }
      work += 1
    }
  }
  if work > limits.work {
    return failed("work-limit", "Placement work budget exhausted")
  }
  let group_indices : Map[String, Int32] = Map([])
  let group_parents : Map[String, String?] = Map([])
  for i, g in model.groups {
    group_indices[g.id] = i
    group_parents[g.id] = g.parent
  }
  let priorities : Array[Array[Int32]] = []
  for i, parent in parents {
    let path = []
    let mut parent = parent
    while parent is Some(p) {
      path.push(group_indices[p])
      parent = group_parents[p]
    }
    let ordered = Array::makei(path.length(), i => path[path.length() - 1 - i])
    ordered.push(model.groups.length() + i)
    priorities.push(ordered)
  }
  let order = Array::makei(count, i => i)
  order.sort_by((a, b) => {
    let left = priorities[a]
    let right = priorities[b]
    for i in 0..<left.length().min(right.length()) {
      if left[i] != right[i] {
        return left[i].compare(right[i])
      }
    }
    left.length().compare(right.length())
  })
  let xrank = Array::make(count, 0)
  let yrank = Array::make(count, 0)
  // Stable topological ordering chooses declaration order between unconstrained columns.
  for
    (roots, edges, ranks, unique) in [
      (xs, xedges, xrank, true),
      (ys, yedges, yrank, false),
    ] {
    let active = Array::make(count, false)
    let indegree = Array::make(count, 0)
    let outgoing : Array[Array[Int32]] = Array::makei(count, _ => [])
    for i in 0..<count {
      active[root(roots, i)] = true
    }
    for (a, b) in edges {
      if a == b {
        return failed(
          "constraint-conflict", "An alignment requires the same axis member before itself",
        )
      }
      outgoing[a].push(b)
      indegree[b] += 1
    }
    let done = Array::make(count, false)
    let mut rank = 0
    let total = active.iter().filter(v => v).count()
    for _ in 0..<total {
      let mut selected = None
      for index in order {
        let i = root(roots, index)
        work += 1
        if active[i] && !done[i] && indegree[i] == 0 {
          selected = Some(i)
          break
        }
      }
      guard selected is Some(i) else {
        return failed("constraint-conflict", "Conflicting ordered alignments")
      }
      if unique {
        ranks[i] = rank
        rank += 1
      }
      done[i] = true
      for target in outgoing[i] {
        if !unique {
          ranks[target] = ranks[target].max(ranks[i] + 1)
        }
        indegree[target] -= 1
      }
      if work > limits.work {
        return failed("work-limit", "Constraint work budget exhausted")
      }
    }
  }
  let mut max_width = 120
  let mut max_height = 108
  for w in widths {
    max_width = max_width.max(w)
  }
  for h in heights {
    max_height = max_height.max(h)
  }
  for group in model.groups {
    max_width = max_width
      .max(measure(group.label) + 80)
      .max(group.icon.map(i => measure(i.key) + 80).unwrap_or(0))
  }
  let mut max_depth = 0
  let group_map : Map[String, @model.Group] = Map([])
  for g in model.groups {
    group_map[g.id] = g
  }
  for parent in parents {
    let mut parent = parent
    let mut depth = 0
    while parent is Some(p) {
      depth += 1
      parent = group_map[p].parent
    }
    max_depth = max_depth.max(depth)
  }
  let gap = 100 + max_depth * 100
  let step_x = max_width + gap
  let step_y = max_height + gap
  if count + 1 > limits.coordinate / step_x.max(step_y).max(1) {
    return failed("coordinate-limit", "Architecture coordinates exceed budget")
  }
  let shapes : Array[Shape] = []
  for i in 0..<count {
    let box : Rect = {
      x: 100 + xrank[root(xs, i)] * step_x + (max_width - widths[i]) / 2,
      y: 100 + yrank[root(ys, i)] * step_y + (max_height - heights[i]) / 2,
      width: widths[i],
      height: heights[i],
    }
    shapes.push({
      id: ids[i],
      kind: kinds[i],
      box,
      label: labels[i],
      parent: parents[i],
      font_size: 13,
      header_height: 0,
    })
  }
  for a in 0..<count {
    for b = a + 1; b < count; b = b + 1 {
      work += 1
      if shapes[a].box.overlaps(shapes[b].box) {
        return failed(
          "constraint-conflict", "Alignments place nodes at the same point",
        )
      }
      if work > limits.work {
        return failed("work-limit", "Overlap work budget exhausted")
      }
    }
  }
  // Place a group after its children. Empty groups retain declaration order.
  let pending = model.groups.iter().to_array()
  let mut rounds = 0
  while !pending.is_empty() {
    let mut progress = false
    let mut i = 0
    while i < pending.length() {
      let group = pending[i]
      let ready = !pending.iter().any(g => g.parent == Some(group.id))
      if !ready {
        i += 1
        continue
      }
      let children = shapes
        .iter()
        .filter(s => s.parent == Some(group.id))
        .to_array()
      let header_height = (28 +
      group.label.split("\n").count() * 18 +
      group.icon.map(i => i.key.split("\n").count() * 18).unwrap_or(0)).max(64)
      let box = if children.is_empty() {
        {
          x: 100 + shapes.length() * step_x,
          y: 100,
          width: (measure(group.label) + 80)
          .max(group.icon.map(i => measure(i.key) + 80).unwrap_or(0))
          .max(140),
          height: 120,
        }
      } else {
        let mut left = children[0].box.x
        let mut right = left + children[0].box.width
        let mut top = children[0].box.y
        let mut bottom = top + children[0].box.height
        for child in children {
          left = left.min(child.box.x)
          right = right.max(child.box.x + child.box.width)
          top = top.min(child.box.y)
          bottom = bottom.max(child.box.y + child.box.height)
        }
        {
          x: left - 40,
          y: top - header_height - 32,
          width: (right - left + 80)
          .max(measure(group.label) + 80)
          .max(group.icon.map(i => measure(i.key) + 80).unwrap_or(0)),
          height: bottom - top + header_height + 72,
        }
      }
      shapes.push({
        id: group.id,
        kind: Group,
        box,
        label: group.label,
        parent: group.parent,
        font_size: 13,
        header_height,
      })
      ignore(pending.remove(i))
      progress = true
      work += 1
    }
    rounds += 1
    if !progress || rounds > limits.depth + 1 {
      return failed(
        "depth-limit", "Cannot resolve group ownership within budget",
      )
    }
    if work > limits.work {
      return failed("work-limit", "Group work budget exhausted")
    }
  }
  // Translate padded nested groups into the positive viewport.
  let mut min_x = 0
  let mut min_y = 0
  for s in shapes {
    min_x = min_x.min(s.box.x - 24)
    min_y = min_y.min(s.box.y - 24)
  }
  if min_x < 0 || min_y < 0 {
    for i, s in shapes {
      shapes[i] = {
        ..s,
        box: { ..s.box, x: s.box.x - min_x, y: s.box.y - min_y, },
      }
    }
  }
  let by_id : Map[String, Shape] = Map([])
  let mut width = 240
  let mut height = 180
  for s in shapes {
    by_id[s.id] = s
    width = width.max(s.box.x + s.box.width + 80)
    height = height.max(s.box.y + s.box.height + 80)
  }
  fn ancestor(group : String, shape : Shape) -> Bool {
    let mut parent = shape.parent
    while parent is Some(p) {
      work += 1
      if work > limits.work {
        return false
      }
      if p == group {
        return true
      }
      parent = by_id[p].parent
    }
    false
  }
  for i, a in shapes {
    for j = i + 1; j < shapes.length(); j = j + 1 {
      work += 1
      let b = shapes[j]
      if a.box.overlaps(b.box) && !ancestor(a.id, b) && !ancestor(b.id, a) {
        return failed(
          "constraint-conflict", "Ownership bounds overlap under the authored alignments",
        )
      }
      if work > limits.work {
        return failed("work-limit", "Containment work budget exhausted")
      }
    }
  }
  let routes : Array[Connection] = []
  let parallel : Map[(String, String, String, String), Int32] = Map([])
  for edge in model.connections {
    work += shapes.length() + 8
    if work > limits.work {
      return failed("work-limit", "Routing work budget exhausted")
    }
    let source = by_id[edge.source.id]
    let target = by_id[edge.target.id]
    let source_box = if edge.source.group {
      by_id[source.parent.unwrap()].box
    } else {
      source.box
    }
    let target_box = if edge.target.group {
      by_id[target.parent.unwrap()].box
    } else {
      target.box
    }
    let key = (
      edge.source.id,
      edge.target.id,
      edge.source.side.to_string(),
      edge.target.side.to_string(),
    )
    let ordinal = parallel.get(key).unwrap_or(0)
    parallel[key] = ordinal + 1
    let offset = ordinal * 8
    let port_offset = offset %
      (source_box.width
      .min(source_box.height)
      .min(target_box.width)
      .min(target_box.height) /
      3).max(1)
    let mut start = port(source_box, edge.source.side, port_offset)
    let mut end = port(target_box, edge.target.side, port_offset)
    if edge.source.group {
      start = match edge.source.side {
        Left | Right =>
          {
            ..start,
            y: (source.box.y + source.box.height / 2 + port_offset)
            .min(source_box.y + source_box.height - 12)
            .max(source_box.y + 40),
          }
        Top | Bottom =>
          {
            ..start,
            x: (source.box.x + source.box.width / 2 + port_offset)
            .min(source_box.x + source_box.width - 12)
            .max(source_box.x + 12),
          }
      }
    }
    if edge.target.group {
      end = match edge.target.side {
        Left | Right =>
          {
            ..end,
            y: (target.box.y + target.box.height / 2 + port_offset)
            .min(target_box.y + target_box.height - 12)
            .max(target_box.y + 40),
          }
        Top | Bottom =>
          {
            ..end,
            x: (target.box.x + target.box.width / 2 + port_offset)
            .min(target_box.x + target_box.width - 12)
            .max(target_box.x + 12),
          }
      }
    }
    let distance = 16 + ordinal % 3 * 2
    let a = outward(start, edge.source.side, distance)
    let b = outward(end, edge.target.side, distance)
    let ancestors : Map[String, Bool] = Map([])
    for node in [source, target] {
      let mut parent = node.parent
      while parent is Some(id) {
        ancestors[id] = true
        parent = by_id[id].parent
      }
    }
    let obstacles = []
    for shape in shapes {
      let box = if shape.kind == Group && ancestors.contains(shape.id) {
        { ..shape.box, height: shape.header_height, }
      } else {
        shape.box
      }
      obstacles.push({
        x: box.x - 8,
        y: box.y - 8,
        width: box.width + 16,
        height: box.height + 16,
      })
    }
    for prior in routes {
      if prior.label_box is Some(box) {
        obstacles.push(box)
      }
    }
    let budget = RouteBudget::{
      limit: limits.work - work,
      work: 0,
      failed: false,
    }
    let inner = orthogonal(
      a,
      b,
      obstacles[:],
      height - 24 + ordinal * 16,
      budget,
    )
    guard inner is Some(inner) else {
      return failed(
        if budget.failed {
          "work-limit"
        } else {
          "routing-conflict"
        },
        "Cannot route authored ports within the routing budget: " + edge.id,
      )
    }
    let points = [start]
    points.append(inner)
    points.push(end)
    if routes
      .iter()
      .any(route => route.points == ReadOnlyArray::from_array(points[:])) {
      let waypoint : Point = {
        x: width + 48 + ordinal * 24,
        y: height + 48 + ordinal * 24,
      }
      let first = orthogonal(a, waypoint, obstacles[:], waypoint.y, budget)
      let second = orthogonal(waypoint, b, obstacles[:], waypoint.y, budget)
      guard first is Some(first) && second is Some(second) else {
        return failed(
          if budget.failed {
            "work-limit"
          } else {
            "routing-conflict"
          },
          "Cannot separate parallel routes within budget",
        )
      }
      points.clear()
      points.push(start)
      points.append(first)
      points.append(second)
      points.push(end)
    }
    let mut label_box = None
    if edge.label is Some(label) {
      let label_width = measure(label) + 12
      let candidates = []
      for i in 1..<points.length() {
        let a = points[i - 1]
        let b = points[i]
        candidates.push({
          x: (a.x + b.x) / 2 - label_width / 2,
          y: (a.y + b.y) / 2 - 22,
          width: label_width,
          height: 20,
        })
      }
      for box in candidates {
        if !charge(budget, shapes.length() + routes.length()) {
          break
        }
        if box.x < 12 ||
          box.y < 12 ||
          shapes
          .iter()
          .any(shape => {
            let obstacle = if shape.kind == Group {
              { ..shape.box, height: shape.header_height, }
            } else {
              {
                x: shape.box.x - 24,
                y: shape.box.y - 24,
                width: shape.box.width + 48,
                height: shape.box.height + 48,
              }
            }
            obstacle.overlaps(box)
          }) ||
          routes
          .iter()
          .any(route => {
            route.label_box.map(prior => prior.overlaps(box)).unwrap_or(false)
          }) {
          continue
        }
        label_box = Some(box)
        break
      }
      if label_box == None && !budget.failed {
        let waypoint : Point = {
          x: width + label_width / 2 + 60,
          y: height + 60,
        }
        let first = orthogonal(a, waypoint, obstacles[:], waypoint.y, budget)
        let second = orthogonal(waypoint, b, obstacles[:], waypoint.y, budget)
        guard first is Some(first) && second is Some(second) else {
          return failed(
            if budget.failed {
              "work-limit"
            } else {
              "routing-conflict"
            },
            "Cannot reserve connection label space",
          )
        }
        points.clear()
        points.push(start)
        points.append(first)
        points.append(second)
        points.push(end)
        label_box = Some({
          x: waypoint.x - label_width / 2,
          y: waypoint.y - 22,
          width: label_width,
          height: 20,
        })
      }
      if budget.failed {
        return failed("work-limit", "Connection label work budget exhausted")
      }
    }
    work += budget.work
    if label_box is Some(box) {
      width = width.max(box.x + box.width + 80)
      height = height.max(box.y + box.height + 80)
    }
    for p in points {
      width = width.max(p.x + 80)
      height = height.max(p.y + 80)
      if p.x < 0 ||
        p.y < 0 ||
        p.x > limits.coordinate ||
        p.y > limits.coordinate {
        return failed("coordinate-limit", "Route coordinates exceed budget")
      }
    }
    routes.push({
      connection: edge,
      points: ReadOnlyArray::from_array(points[:]),
      label_box,
    })
  }
  if width > limits.coordinate || height > limits.coordinate {
    return failed("coordinate-limit", "Viewport exceeds coordinate budget")
  }
  {
    geometry: Some({
      model,
      shapes: ReadOnlyArray::from_array(shapes[:]),
      connections: ReadOnlyArray::from_array(routes[:]),
      width,
      height,
    }),
    diagnostics: [],
  }
}
