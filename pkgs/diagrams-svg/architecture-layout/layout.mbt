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
priv struct PortAttachment {
  key : Int32
  lower : Int32
  upper : Int32
  center : Int32
}

///|
/// Spread all incident connections on an actual outline side. Group-boundary
/// ports also retain the adjacent service's span. Junctions remain real joins.
fn distribute_ports(
  groups : Map[(String, String), Array[PortAttachment]],
  budget : RouteBudget,
) -> Map[Int32, Int32]? {
  let result : Map[Int32, Int32] = Map([])
  for requests in groups.values() {
    if !charge(budget, requests.length()) {
      return None
    }
    if requests.length() == 1 {
      let request = requests[0]
      result[request.key] = request.center.max(request.lower).min(request.upper)
      continue
    }
    let first = requests[0]
    if requests
      .iter()
      .all(r => r.lower == first.lower && r.upper == first.upper) {
      for rank, request in requests {
        result[request.key] = first.lower +
          ((first.upper - first.lower).to_double() *
          rank.to_double() /
          (requests.length() - 1).to_double()).to_int()
      }
      continue
    }
    let mut levels = 0
    let mut size = requests.length()
    while size > 1 {
      levels += 1
      size = (size + 1) / 2
    }
    if !charge(budget, requests.length() * (levels + 1)) {
      return None
    }
    requests.sort_by((a, b) => {
      let order = a.center.compare(b.center)
      if order != 0 {
        order
      } else {
        a.key.compare(b.key)
      }
    })
    let mut left = requests[0].lower
    let mut right = requests[0].upper
    let counts : Map[(Int32, Int32), Int32] = Map([])
    for request in requests {
      left = left.min(request.lower)
      right = right.max(request.upper)
      let span = (request.lower, request.upper)
      counts[span] = counts.get(span).unwrap_or(0) + 1
    }
    fn feasible(distance : Int32) -> Bool {
      let mut previous = left - distance
      for request in requests {
        if !charge(budget, 1) {
          return false
        }
        previous = request.lower.max(previous + distance)
        if previous > request.upper {
          return false
        }
      }
      true
    }
    let mut low = 0
    let mut high = (right - left) / (requests.length() - 1)
    while low < high {
      let middle = low + (high - low + 1) / 2
      if feasible(middle) {
        low = middle
      } else {
        high = middle - 1
      }
      if budget.failed {
        return None
      }
    }
    let latest : Array[Int32] = Array::make(requests.length(), 0)
    for index = requests.length() - 1; index >= 0; index = index - 1 {
      if !charge(budget, 1) {
        return None
      }
      latest[index] = if index == requests.length() - 1 {
        requests[index].upper
      } else {
        requests[index].upper.min(latest[index + 1] - low)
      }
    }
    let ranks : Map[(Int32, Int32), Int32] = Map([])
    let mut previous = left - low
    for index, request in requests {
      if !charge(budget, 1) {
        return None
      }
      let span = (request.lower, request.upper)
      let rank = ranks.get(span).unwrap_or(0)
      ranks[span] = rank + 1
      let count = counts[span]
      let ideal = if count == 1 {
        request.center
      } else {
        request.lower +
        ((request.upper - request.lower).to_double() *
        rank.to_double() /
        (count - 1).to_double()).to_int()
      }
      let position = ideal
        .max(request.lower.max(previous + low))
        .min(latest[index])
      result[request.key] = position
      previous = position
    }
  }
  Some(result)
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
  // Leave the marker approach and curve transition clear of group headers.
  let terminal = limits.minimum_approach.max(14.0).ceil().to_int() + 8
  let group_padding = (terminal + 24).max(40)
  let gap = (100 + max_depth * 100).max(2 * max_depth * group_padding + 64)
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
          x: left - group_padding,
          y: top - header_height - group_padding,
          width: (right - left + 2 * group_padding)
          .max(measure(group.label) + 80)
          .max(group.icon.map(i => measure(i.key) + 80).unwrap_or(0)),
          height: bottom - top + header_height + 2 * group_padding,
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
    min_x = min_x.min(s.box.x - terminal - 24)
    min_y = min_y.min(s.box.y - terminal - 24)
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
  let port_groups : Map[(String, String), Array[PortAttachment]] = Map([])
  let port_budget = RouteBudget::{
    limit: limits.work - work,
    work: 0,
    failed: false,
  }
  for index, edge in model.connections {
    for (end_index, endpoint) in [(0, edge.source), (1, edge.target)] {
      if !charge(port_budget, 1) {
        return failed("work-limit", "Port distribution work budget exhausted")
      }
      let service = by_id[endpoint.id]
      let owner = if endpoint.group {
        by_id[service.parent.unwrap()]
      } else {
        service
      }
      let vertical = endpoint.side is (Left | Right)
      let origin = if vertical { owner.box.y } else { owner.box.x }
      let extent = if vertical { owner.box.height } else { owner.box.width }
      let padding = (extent / 4).min(12)
      let mut lower = origin + padding
      let mut upper = origin + extent - padding
      let mut center = origin + extent / 2
      if owner.kind == Junction {
        lower = center
        upper = center
      } else if endpoint.group {
        if vertical {
          lower = lower.max(owner.box.y + owner.header_height + 12)
        }
        let adjacent_origin = if vertical {
          service.box.y
        } else {
          service.box.x
        }
        let adjacent_extent = if vertical {
          service.box.height
        } else {
          service.box.width
        }
        let adjacent_padding = (adjacent_extent / 4).min(12)
        lower = lower.max(adjacent_origin + adjacent_padding)
        upper = upper.min(adjacent_origin + adjacent_extent - adjacent_padding)
        center = adjacent_origin + adjacent_extent / 2
      }
      let key = (owner.id, endpoint.side.to_string())
      let requests = port_groups.get_or_init(key, () => [])
      requests.push({ key: index * 2 + end_index, lower, upper, center, })
    }
  }
  guard distribute_ports(port_groups, port_budget) is Some(ports) else {
    return failed("work-limit", "Port distribution work budget exhausted")
  }
  work += port_budget.work
  let routes : Array[Connection] = []
  let parallel : Map[(String, String, String, String), Int32] = Map([])
  for edge_index, edge in model.connections {
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
    let start = match edge.source.side {
      Left | Right =>
        { ..port(source_box, edge.source.side, 0), y: ports[edge_index * 2], }
      Top | Bottom =>
        { ..port(source_box, edge.source.side, 0), x: ports[edge_index * 2], }
    }
    let end = match edge.target.side {
      Left | Right =>
        {
          ..port(target_box, edge.target.side, 0),
          y: ports[edge_index * 2 + 1],
        }
      Top | Bottom =>
        {
          ..port(target_box, edge.target.side, 0),
          x: ports[edge_index * 2 + 1],
        }
    }
    let distance = terminal + ordinal % 3 * 2
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
    let occupied : Array[(Point, Point)] = [(start, a), (b, end)]
    for prior in routes {
      if prior.label_box is Some(box) {
        obstacles.push(box)
      }
      // Connections incident on one semantic node may intentionally share a
      // port or trunk. Only independent routes reserve separate channels.
      if [edge.source.id, edge.target.id].contains(prior.connection.source.id) ||
        [edge.source.id, edge.target.id].contains(prior.connection.target.id) {
        continue
      }
      for i in 1..<prior.points.length() {
        occupied.push((prior.points[i - 1], prior.points[i]))
      }
      for i in 1..<(prior.points.length() - 1) {
        let bend = prior.points[i]
        if [start, a, b, end]
          .iter()
          .all(p => (p.x - bend.x).abs() + (p.y - bend.y).abs() > 12) {
          obstacles.push({
            x: bend.x - 8,
            y: bend.y - 8,
            width: 16,
            height: 16,
          })
        }
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
      occupied~,
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
      let first = orthogonal(
        a,
        waypoint,
        obstacles[:],
        waypoint.y,
        budget,
        occupied~,
      )
      let second = orthogonal(
        waypoint,
        b,
        obstacles[:],
        waypoint.y,
        budget,
        occupied~,
      )
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
        let first = orthogonal(
          a,
          waypoint,
          obstacles[:],
          waypoint.y,
          budget,
          occupied~,
        )
        let second = orthogonal(
          waypoint,
          b,
          obstacles[:],
          waypoint.y,
          budget,
          occupied~,
        )
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
