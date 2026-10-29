///|
fn inflated(box : Rect, padding : Double) -> Rect {
  {
    x: box.x - padding,
    y: box.y - padding,
    width: box.width + 2.0 * padding,
    height: box.height + 2.0 * padding,
  }
}

///|
fn compact(line : ArrayView[Point]) -> Array[Point] {
  let result : Array[Point] = []
  for point in line {
    if result.last() == Some(point) {
      continue
    }
    if result.length() >= 2 {
      let a = result[result.length() - 2]
      let b = result[result.length() - 1]
      if (a.x == b.x && b.x == point.x && (b.y - a.y) * (point.y - b.y) >= 0.0) ||
        (a.y == b.y && b.y == point.y && (b.x - a.x) * (point.x - b.x) >= 0.0) {
        ignore(result.pop())
      }
    }
    result.push(point)
  }
  result
}

///|
fn clear_line(
  line : ArrayView[Point],
  obstacles : ArrayView[Rect],
  budget : Budget,
  occupied~ : ArrayView[(Point, Point)] = [],
) -> Bool {
  for i in 1..<line.length() {
    let a = line[i - 1]
    let b = line[i]
    for (p, q) in occupied {
      if !budget.charge(1) {
        return false
      }
      let horizontal = a.y == b.y && p.y == q.y && (a.y - p.y).abs() < 0.01
      let vertical = a.x == b.x && p.x == q.x && (a.x - p.x).abs() < 0.01
      if (
          horizontal &&
          a.x.min(b.x).max(p.x.min(q.x)) < a.x.max(b.x).min(p.x.max(q.x)) - 0.01
        ) ||
        (
          vertical &&
          a.y.min(b.y).max(p.y.min(q.y)) < a.y.max(b.y).min(p.y.max(q.y)) - 0.01
        ) {
        return false
      }
    }

    for box in obstacles {
      if !budget.charge(1) {
        return false
      }
      if crosses(line[i - 1], line[i], box) {
        return false
      }
    }
  }
  true
}

///|
fn sorted_axis(values : Array[Double]) -> Array[Double] {
  values.sort_by((a, b) => a.compare(b))
  let result = []
  for value in values {
    if result.last() != Some(value) {
      result.push(value)
    }
  }
  result
}

///|
fn axis_index(values : ArrayView[Double], target : Double) -> Int32 {
  for i, value in values {
    if value == target {
      return i
    }
  }
  abort("route endpoint absent from coordinate axis")
}

///|
fn axis_lower(
  values : ArrayView[Double],
  target : Double,
  budget : Budget,
) -> Int32 {
  let mut lo = 0
  let mut hi = values.length()
  while lo < hi {
    if !budget.charge(1) {
      return lo
    }
    let mid = lo + (hi - lo) / 2
    if values[mid] < target {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  lo
}

///|
fn clear_channels(
  values : Array[Double],
  occupied : ArrayView[(Point, Point)],
  horizontal : Bool,
  start : Double,
  end : Double,
  budget : Budget,
) -> Array[Double] {
  let barriers = []
  for (p, q) in occupied {
    if !budget.charge(1) {
      return []
    }
    if horizontal && p.x == q.x {
      barriers.push(p.x)
    }
    if !horizontal && p.y == q.y {
      barriers.push(p.y)
    }
  }
  let barriers = sorted_axis(barriers)
  values.filter(value => {
    if value == start || value == end {
      return true
    }
    let at = axis_lower(barriers, value, budget)
    (at == barriers.length() || (barriers[at] - value).abs() >= 8.0) &&
    (at == 0 || (value - barriers[at - 1]).abs() >= 8.0)
  })
}

///|
fn orthogonal(
  start : Point,
  end : Point,
  obstacles : ArrayView[Rect],
  channel : Double,
  area : Rect?,
  budget : Budget,
  occupied~ : ArrayView[(Point, Point)] = [],
) -> Array[Point]? {
  let mid_x = (start.x + end.x) / 2.0
  let mid_y = (start.y + end.y) / 2.0
  let candidates : Array[Array[Point]] = [
    [start, { x: end.x, y: start.y, }, end],
    [start, { x: start.x, y: end.y, }, end],
    [start, { x: mid_x, y: start.y, }, { x: mid_x, y: end.y, }, end],
    [start, { x: start.x, y: mid_y, }, { x: end.x, y: mid_y, }, end],
    [start, { x: start.x, y: channel, }, { x: end.x, y: channel, }, end],
  ]
  for line in candidates {
    let line = compact(line)
    if line.length() >= 2 &&
      line
      .iter()
      .all(p => {
        area
        .map(r => r.contains({ x: p.x, y: p.y, width: 0.0, height: 0.0, }))
        .unwrap_or(true)
      }) &&
      clear_line(line, obstacles, budget, occupied~) {
      return Some(line)
    }
    if budget.failed {
      return None
    }
  }
  let xs = [start.x, end.x]
  let ys = [start.y, end.y, channel]
  if area is Some(area) {
    xs.push(area.x)
    xs.push(area.x + area.width)
    ys.push(area.y)
    ys.push(area.y + area.height)
  }
  for box in obstacles {
    if !budget.charge(1) {
      return None
    }
    xs.push(box.x)
    xs.push(box.x + box.width)
    ys.push(box.y)
    ys.push(box.y + box.height)
  }
  for (a, b) in occupied {
    for p in [a, b] {
      xs.push(p.x - 12.0)
      xs.push(p.x + 12.0)
      ys.push(p.y - 12.0)
      ys.push(p.y + 12.0)
    }
  }
  let xs = clear_channels(
    sorted_axis(xs),
    occupied,
    true,
    start.x,
    end.x,
    budget,
  )
  let ys = clear_channels(
    sorted_axis(ys),
    occupied,
    false,
    start.y,
    end.y,
    budget,
  )
  if budget.failed {
    return None
  }
  // Index obstacle strips once. The grid search then checks only rectangles
  // intersecting its current row/column and exact collinear occupied spans.
  // Every insertion and lookup remains part of the bounded routing work.
  let horizontal_rects : Map[Int32, Array[Rect]] = Map([])
  let vertical_rects : Map[Int32, Array[Rect]] = Map([])
  for box in obstacles {
    for
      (values, index, low, high) in [
        (xs, vertical_rects, box.x + 0.5, box.x + box.width - 0.5),
        (ys, horizontal_rects, box.y + 0.5, box.y + box.height - 0.5),
      ] {
      let first = axis_lower(values, low, budget)
      let mut at = first
      while at < values.length() && values[at] <= high {
        if !budget.charge(1) {
          return None
        }
        if index.get(at) is Some(items) {
          items.push(box)
        } else {
          index[at] = [box]
        }
        at += 1
      }
    }
  }
  let horizontal_spans : Map[Int32, Array[(Point, Point)]] = Map([])
  let vertical_spans : Map[Int32, Array[(Point, Point)]] = Map([])
  for (p, q) in occupied {
    if !budget.charge(1) {
      return None
    }
    let horizontal = p.y == q.y
    let values = if horizontal { ys } else { xs }
    let index = if horizontal { horizontal_spans } else { vertical_spans }
    let coordinate = if horizontal { p.y } else { p.x }
    // Match clear_line's subpixel tolerance instead of requiring exact float
    // equality. Index each span into every nearby candidate grid row/column.
    let mut at = axis_lower(values, coordinate - 0.01, budget)
    while at < values.length() && values[at] <= coordinate + 0.01 {
      if !budget.charge(1) {
        return None
      }
      if index.get(at) is Some(items) {
        items.push((p, q))
      } else {
        index[at] = [(p, q)]
      }
      at += 1
    }
  }
  if budget.failed {
    return None
  }
  let passable : Map[(Int32, Int32, Int32), Bool] = Map([])
  let sx = axis_index(xs, start.x)
  let sy = axis_index(ys, start.y)
  let tx = axis_index(xs, end.x)
  let ty = axis_index(ys, end.y)
  let initial = (sx, sy, 2)
  let distance = Map([(initial, 0.0)])
  let previous : Map[(Int32, Int32, Int32), (Int32, Int32, Int32)] = Map([])
  let queue : @priority_queue.PriorityQueue[
    (Double, Double, Int32, Int32, Int32),
  ] = @priority_queue.PriorityQueue([])
  queue.push(
    (-(start.x - end.x).abs() - (start.y - end.y).abs(), 0.0, sx, sy, 2),
  )
  while queue.pop() is Some((_, negative, x, y, direction)) {
    if !budget.charge(1) {
      return None
    }
    let key = (x, y, direction)
    let cost = -negative
    if distance.get(key) != Some(cost) {
      continue
    }
    if x == tx && y == ty {
      let reverse : Array[Point] = [{ x: xs[x], y: ys[y], }]
      let mut cursor = key
      while previous.get(cursor) is Some(parent) {
        if !budget.charge(1) {
          return None
        }
        reverse.push({ x: xs[parent.0], y: ys[parent.1], })
        cursor = parent
      }
      return Some(
        compact(
          Array::makei(reverse.length(), i => reverse[reverse.length() - 1 - i]),
        ),
      )
    }
    let a : Point = { x: xs[x], y: ys[y], }
    for
      (nx, ny, nd) in [
        (x + 1, y, 0),
        (x, y + 1, 1),
        (x - 1, y, 0),
        (x, y - 1, 1),
      ] {
      if nx < 0 || nx >= xs.length() || ny < 0 || ny >= ys.length() {
        continue
      }
      let b : Point = { x: xs[nx], y: ys[ny], }
      if area
        .map(r => !r.contains({ x: b.x, y: b.y, width: 0.0, height: 0.0, }))
        .unwrap_or(false) {
        continue
      }
      let next_cost = cost +
        (a.x - b.x).abs() +
        (a.y - b.y).abs() +
        (if direction != 2 && direction != nd { 24.0 } else { 0.0 })
      let next = (nx, ny, nd)
      if distance.get(next).map(old => old <= next_cost).unwrap_or(false) {
        continue
      }
      let segment_key = (x.min(nx), y.min(ny), nd)
      if !budget.charge(1) {
        return None
      }
      let clear = match passable.get(segment_key) {
        Some(clear) => clear
        None => {
          let local_rects = (if nd == 0 {
            horizontal_rects.get(y)
          } else {
            vertical_rects.get(x)
          }).unwrap_or([])
          let local_spans = (if nd == 0 {
            horizontal_spans.get(y)
          } else {
            vertical_spans.get(x)
          }).unwrap_or([])
          let clear = clear_line(
            [a, b],
            local_rects,
            budget,
            occupied=local_spans,
          )
          passable[segment_key] = clear
          clear
        }
      }
      if !clear {
        if budget.failed {
          return None
        }
        continue
      }
      distance[next] = next_cost
      previous[next] = key
      let estimate = next_cost + (b.x - end.x).abs() + (b.y - end.y).abs()
      queue.push((-estimate, -next_cost, nx, ny, nd))
    }
  }
  None
}

///|
fn side(shape : Shape, other : Shape, source : Bool) -> Int32 {
  if shape.shape == "braces" {
    if other.box.x + other.box.width / 2.0 > shape.box.x + shape.box.width / 2.0 ||
      source {
      return 0
    } else {
      return 2
    }
  }

  if shape.shape == "brace" {
    return 2
  }
  if shape.shape == "brace-r" {
    return 0
  }
  let dx = other.outline_box.x +
    other.outline_box.width / 2.0 -
    shape.outline_box.x -
    shape.outline_box.width / 2.0
  let dy = other.outline_box.y +
    other.outline_box.height / 2.0 -
    shape.outline_box.y -
    shape.outline_box.height / 2.0
  let point_profile = ["diamond", "choice"].contains(shape.shape) ||
    ["diamond", "choice"].contains(other.shape)
  let horizontal_distance = if point_profile {
    dx.abs() / (shape.outline_box.width + other.outline_box.width).max(1.0)
  } else {
    dx.abs()
  }
  let vertical_distance = if point_profile {
    dy.abs() / (shape.outline_box.height + other.outline_box.height).max(1.0)
  } else {
    dy.abs()
  }
  if horizontal_distance >= vertical_distance {
    if dx > 0.0 || (dx == 0.0 && source) {
      0
    } else {
      2
    }
  } else if dy > 0.0 {
    1
  } else {
    3
  }
}

///|
fn label_safe_side(shape : Shape, other : Shape, preferred : Int32) -> Int32 {
  guard shape.label is Some(label) && !shape.outline_box.contains(label.box) else {
    return preferred
  }
  let box = shape.outline_box
  let cx = box.x + box.width / 2.0
  let cy = box.y + box.height / 2.0
  let dx = other.outline_box.x + other.outline_box.width / 2.0 - cx
  let dy = other.outline_box.y + other.outline_box.height / 2.0 - cy
  let horizontal = label.box.y < cy + box.height * 0.3 &&
    label.box.y + label.box.height > cy - box.height * 0.3
  let vertical = label.box.x < cx + box.width * 0.3 &&
    label.box.x + label.box.width > cx - box.width * 0.3
  if (
      (preferred == 0 && label.box.x >= cx) ||
      (preferred == 2 && label.box.x + label.box.width <= cx)
    ) &&
    horizontal {
    return if dy >= 0.0 { 1 } else { 3 }
  }
  if (
      (preferred == 1 && label.box.y >= cy) ||
      (preferred == 3 && label.box.y + label.box.height <= cy)
    ) &&
    vertical {
    return if dx >= 0.0 { 0 } else { 2 }
  }
  preferred
}

///|
fn outside_port(
  shape : Shape,
  anchor : Point,
  side : Int32,
  distance : Double,
) -> Point {
  let box = shape.outline_box
  match side {
    0 => { x: (anchor.x + distance).max(box.x + box.width + 8.0), y: anchor.y, }
    1 =>
      { x: anchor.x, y: (anchor.y + distance).max(box.y + box.height + 8.0), }
    2 => { x: (anchor.x - distance).min(box.x - 8.0), y: anchor.y, }
    _ => { x: anchor.x, y: (anchor.y - distance).min(box.y - 8.0), }
  }
}

///|
fn bounded_exit_distance(
  anchor : Point,
  side : Int32,
  other : Rect,
  requested : Double,
  minimum : Double,
) -> Double {
  let aligned = if side == 0 || side == 2 {
    anchor.y >= other.y && anchor.y <= other.y + other.height
  } else {
    anchor.x >= other.x && anchor.x <= other.x + other.width
  }
  let gap = match side {
    0 => other.x - anchor.x
    1 => other.y - anchor.y
    2 => anchor.x - other.x - other.width
    _ => anchor.y - other.y - other.height
  }
  if aligned && gap > minimum * 2.0 + 16.0 {
    requested.min((gap - 16.0) / 2.0)
  } else {
    requested
  }
}

///|
fn shape_profile(
  shape : Shape,
  side : Int32,
  budget : Budget,
) -> AttachmentProfile {
  attachment_profile(
    shape.shape,
    shape.outline_box.width,
    shape.outline_box.height,
    side,
    (budget.limits.minimum_approach - 24.0).max(0.0) / 4.0,
  )
}

///|
fn route_connections(
  view : @model.Swimlane,
  selected : ArrayView[(Int32, Int32, Int32)],
  shapes : ArrayView[Shape],
  parents : ArrayView[Int32],
  budget : Budget,
  direction_hints~ : ArrayView[(String, @model.Direction)] = [],
  fixed_ports~ : ArrayView[(String, Int32)] = [],
) -> Array[Connection] {
  let by_index = Map([])
  for shape in shapes {
    by_index[shape.index] = shape
  }
  let hints : Map[String, @model.Direction] = Map(direction_hints)
  let fixed = Map(fixed_ports)
  fn ancestor(child : Int32, container : Int32) -> Bool {
    let mut i = parents[child]
    while i >= 0 {
      if !budget.charge(1) {
        return false
      }
      if i == container {
        return true
      }
      i = parents[i]
    }
    false
  }
  let counts : Map[(Int32, Int32), Int32] = Map([])
  fn clear_side_at(
    shape : Shape,
    other : Shape,
    chosen : Int32,
    fraction : Double,
    distance : Double,
  ) -> Bool {
    if label_safe_side(shape, other, chosen) != chosen {
      return false
    }
    let anchor = port(shape, chosen, fraction)
    let minimum = budget.limits.minimum_approach.max(14.0) + 8.0
    let exit = outside_port(
      shape,
      anchor,
      chosen,
      bounded_exit_distance(
        anchor,
        chosen,
        other.outline_box,
        distance,
        minimum,
      ),
    )
    for obstacle in shapes {
      if !budget.charge(1) {
        return false
      }
      if obstacle.index != shape.index &&
        obstacle.kind == Node &&
        !ancestor(shape.index, obstacle.index) &&
        crosses(anchor, exit, inflated(obstacle.outline_box, 4.0)) {
        return false
      }
      if obstacle.label is Some(label) &&
        !(obstacle.index == shape.index && shape.outline_box.contains(label.box)) &&
        crosses(anchor, exit, inflated(label.box, 4.0)) {
        return false
      }
    }
    let mut container = parents[shape.index]
    while container >= 0 {
      if !budget.charge(1) {
        return false
      }
      if ancestor(other.index, container) || other.index == container {
        if by_index.get(container) is Some(parent) {
          return inflated(parent.box, -8.0).contains({
            x: exit.x,
            y: exit.y,
            width: 0.0,
            height: 0.0,
          })
        }
      }
      container = parents[container]
    }
    !budget.failed
  }
  fn clear_side(
    shape : Shape,
    other : Shape,
    chosen : Int32,
    distance : Double,
  ) -> Bool {
    let count = counts.get((shape.index, chosen)).unwrap_or(0) + 1
    let reserved = distance.max(
      budget.limits.minimum_approach.max(14.0) +
      8.0 +
      (count - 1).to_double() * 8.0,
    )
    for rank in 0..<count {
      if !clear_side_at(
          shape,
          other,
          chosen,
          shape_profile(shape, chosen, budget).fraction(rank, count),
          reserved,
        ) {
        return false
      }
    }
    true
  }
  let sides = []
  for (edge_index, a, b) in selected {
    let source = by_index[a]
    let target = by_index[b]
    let explicit = hints.get(view.connections[edge_index].id)
    let (from, to) = if a != b && explicit is Some(dir) {
      match dir {
        LR => (0, 2)
        RL => (2, 0)
        TB => (1, 3)
        BT => (3, 1)
      }
    } else {
      (
        if a == b {
          0
        } else {
          side(source, target, true)
        },
        if a == b {
          3
        } else {
          side(target, source, false)
        },
      )
    }
    let mut from = if explicit is Some(_) {
      from
    } else {
      label_safe_side(source, target, from)
    }
    let mut to = if explicit is Some(_) {
      to
    } else {
      label_safe_side(target, source, to)
    }
    from = fixed.get(source.id).unwrap_or(from)
    to = fixed.get(target.id).unwrap_or(to)
    let connection = view.connections[edge_index]
    let special = ["brace", "brace-r", "braces"].contains(source.shape) ||
      ["brace", "brace-r", "braces"].contains(target.shape)
    if explicit is None &&
      a != b &&
      !special &&
      !fixed.contains(source.id) &&
      !fixed.contains(target.id) &&
      connection.style != Invisible {
      let source_box = source.outline_box
      let target_box = target.outline_box
      let dx = target_box.x +
        target_box.width / 2.0 -
        source_box.x -
        source_box.width / 2.0
      let dy = target_box.y +
        target_box.height / 2.0 -
        source_box.y -
        source_box.height / 2.0
      let horizontal_axis = from == 0 || from == 2
      let advance = match view.direction {
        LR => dx
        RL => -dx
        TB => dy
        BT => -dy
      }
      let aligned = if horizontal(view.direction) {
        dy.abs() <= source_box.height.max(target_box.height) / 2.0
      } else {
        dx.abs() <= source_box.width.max(target_box.width) / 2.0
      }
      let feedback = aligned &&
        advance * (if connection.direction == Backward { -1.0 } else { 1.0 }) <
        -0.5
      let current = counts.get((a, from)).unwrap_or(0) +
        counts.get((b, to)).unwrap_or(0)
      let crowded = counts.get((a, from)).unwrap_or(0) >= 3 ||
        counts.get((b, to)).unwrap_or(0) >= 3
      let distance = budget.limits.minimum_approach.max(14.0) + 8.0
      let transverse_gap = if horizontal_axis {
        dy.abs() - (source_box.height + target_box.height) / 2.0
      } else {
        dx.abs() - (source_box.width + target_box.width) / 2.0
      }
      let diagonal = current > 0 && transverse_gap > distance * 2.0 + 8.0
      if feedback || crowded || diagonal {
        let candidates : Array[(Int32, Int32)] = []
        if diagonal && !feedback {
          candidates.push(
            if horizontal_axis {
              if dy > 0.0 {
                (1, 3)
              } else {
                (3, 1)
              }
            } else if dx > 0.0 {
              (0, 2)
            } else {
              (2, 0)
            },
          )
        }
        if feedback || crowded {
          candidates.append(
            if horizontal_axis {
              [(3, 3), (1, 1)]
            } else {
              [(2, 2), (0, 0)]
            },
          )
        }
        let mut best : (Int32, Int32)? = None
        let mut best_cost = 2147483647
        for (candidate_from, candidate_to) in candidates {
          let cost = counts.get((a, candidate_from)).unwrap_or(0) +
            counts.get((b, candidate_to)).unwrap_or(0)
          if cost >= best_cost || (!feedback && cost >= current) {
            continue
          }
          if clear_side(source, target, candidate_from, distance) &&
            clear_side(target, source, candidate_to, distance) {
            best = Some((candidate_from, candidate_to))
            best_cost = cost
          }
        }
        if best is Some((chosen_from, chosen_to)) {
          from = chosen_from
          to = chosen_to
        }
      }
    }
    let source_profile = shape_profile(source, from, budget)
    let target_profile = shape_profile(target, to, budget)
    if (source_profile.point_preferred || target_profile.point_preferred) &&
      connection.style != Invisible &&
      !special {
      let preferred_from = from
      let preferred_to = to
      let mut best_cost = 1.0e30
      let mut best = None
      let obstacles = []
      for shape in shapes {
        if !budget.charge(1) {
          return []
        }
        if shape.kind == Node &&
          !ancestor(a, shape.index) &&
          !ancestor(b, shape.index) {
          obstacles.push(
            inflated(
              shape.outline_box,
              if shape.index == a || shape.index == b {
                0.0
              } else {
                8.0
              },
            ),
          )
        }
        if shape.label is Some(label) {
          obstacles.push(inflated(label.box, 6.0))
        }
      }
      let mut area : Rect? = None
      let mut parent = parents[a]
      while parent >= 0 {
        if !budget.charge(1) {
          return []
        }
        if ancestor(b, parent) && by_index.get(parent) is Some(container) {
          area = Some(inflated(container.box, -8.0))
          break
        }
        parent = parents[parent]
      }
      let distance = budget.limits.minimum_approach.max(14.0) + 8.0
      for
        candidate_from in source_profile.sides(
          from,
          explicit != None || fixed.contains(source.id),
        ) {
        for
          candidate_to in target_profile.sides(
            to,
            explicit != None || fixed.contains(target.id),
          ) {
          if !budget.charge(1) {
            return []
          }
          if a == b && candidate_from == candidate_to {
            continue
          }
          if !clear_side(source, target, candidate_from, distance) ||
            !clear_side(target, source, candidate_to, distance) {
            continue
          }
          let source_count = counts.get((a, candidate_from)).unwrap_or(0)
          let target_count = counts.get((b, candidate_to)).unwrap_or(0)
          let start = port(
            source,
            candidate_from,
            shape_profile(source, candidate_from, budget).fraction(
              source_count,
              source_count + 1,
            ),
          )
          let end = port(
            target,
            candidate_to,
            shape_profile(target, candidate_to, budget).fraction(
              target_count,
              target_count + 1,
            ),
          )
          let exit = outside_port(source, start, candidate_from, distance)
          let entry = outside_port(target, end, candidate_to, distance)
          if orthogonal(
              exit,
              entry,
              obstacles,
              source.box.y.max(target.box.y) +
              source.box.height.max(target.box.height) +
              64.0,
              area,
              budget,
            )
            is Some(route) {
            let mut length = 2.0 * distance
            for i in 1..<route.length() {
              length += (route[i].x - route[i - 1].x).abs() +
                (route[i].y - route[i - 1].y).abs()
            }
            let congestion = (if source_profile.point_preferred {
                counts.get((a, candidate_from)).unwrap_or(0)
              } else {
                0
              }) +
              (if target_profile.point_preferred {
                counts.get((b, candidate_to)).unwrap_or(0)
              } else {
                0
              })
            let cost = attachment_cost(
              candidate_from,
              candidate_to,
              preferred_from,
              preferred_to,
              congestion,
              route.length() - 2,
              length,
              source.outline_box.width
              .max(source.outline_box.height)
              .max(target.outline_box.width)
              .max(target.outline_box.height),
            )
            if cost < best_cost {
              best_cost = cost
              best = Some((candidate_from, candidate_to))
            }
          }
          if budget.failed {
            return []
          }
        }
      }
      if best is Some((chosen_from, chosen_to)) {
        from = chosen_from
        to = chosen_to
      }
    }
    sides.push((from, to))
    counts[(a, from)] = counts.get((a, from)).unwrap_or(0) + 1
    counts[(b, to)] = counts.get((b, to)).unwrap_or(0) + 1
  }
  // Order each side's fan by the other endpoint's cross-axis position.
  // Source declaration order still breaks ties for parallel identities, while
  // routes to different rows/columns do not braid inside their marker stubs.
  let fans : Map[(Int32, Int32), Array[(Double, Int32, Bool)]] = Map([])
  for occurrence, (_, a, b) in selected {
    let (from, to) = sides[occurrence]
    for
      (endpoint, other, side, source) in [(a, b, from, true), (b, a, to, false)] {
      if !budget.charge(1) {
        return []
      }
      let box = by_index[other].outline_box
      let coordinate = if side == 0 || side == 2 {
        box.y + box.height / 2.0
      } else {
        box.x + box.width / 2.0
      }
      let key = (endpoint, side)
      if fans.get(key) is Some(items) {
        items.push((coordinate, occurrence, source))
      } else {
        fans[key] = [(coordinate, occurrence, source)]
      }
    }
  }
  let port_order : Map[(Int32, Bool), Int32] = Map([])
  for (_, items) in fans {
    items.sort_by((a, b) => {
      let order = a.0.compare(b.0)
      if order == 0 {
        a.1.compare(b.1)
      } else {
        order
      }
    })
    for n, (_, occurrence, source) in items {
      if !budget.charge(1) {
        return []
      }
      port_order[(occurrence, source)] = n
    }
  }
  let connections : Array[Connection] = []
  let labels : Array[Label] = []
  for shape in shapes {
    if shape.label is Some(label) {
      labels.push(label)
    }
  }
  let mut lower = 0.0
  for shape in shapes {
    lower = Double::max(lower, shape.box.y + shape.box.height)
  }

  // Reserve every terminal corridor before the first middle route or label
  // is placed. Otherwise an earlier edge can occupy a later marker approach.
  let planned : Array[(Point, Point, Point, Point)] = []
  for occurrence, (_, a, b) in selected {
    if budget.failed {
      break
    }
    let source = by_index[a]
    let target = by_index[b]
    let (from, to) = sides[occurrence]
    fn next_port(shape : Shape, side : Int32, source : Bool) -> Point {
      let n = port_order[(occurrence, source)]
      port(
        shape,
        side,
        shape_profile(shape, side, budget).fraction(
          n,
          counts[(shape.index, side)],
        ),
      )
    }
    let start = next_port(source, from, true)
    let end = next_port(target, to, false)
    fn outside(
      shape : Shape,
      other : Shape,
      anchor : Point,
      side : Int32,
      source_end : Bool,
    ) -> Point {
      let minimum = budget.limits.minimum_approach.max(14.0) + 8.0
      let requested = minimum +
        port_order[(occurrence, source_end)].to_double() * 8.0
      outside_port(
        shape,
        anchor,
        side,
        bounded_exit_distance(
          anchor,
          side,
          other.outline_box,
          requested,
          minimum,
        ),
      )
    }
    let exit = outside(source, target, start, from, true)
    let entry = outside(target, source, end, to, false)
    planned.push((start, exit, entry, end))
  }
  for occurrence, (i, a, b) in selected {
    if budget.failed {
      break
    }
    let connection = view.connections[i]
    let source = by_index[a]
    let target = by_index[b]
    let (start, exit, entry, end) = planned[occurrence]
    let obstacles = []
    for shape in shapes {
      if !budget.charge(1) {
        break
      }
      if shape.kind != Node ||
        ancestor(a, shape.index) ||
        ancestor(b, shape.index) {
        continue
      }
      obstacles.push(
        inflated(
          shape.outline_box,
          if shape.index == a || shape.index == b {
            0.0
          } else {
            8.0
          },
        ),
      )
    }
    for label in labels {
      // Endpoint node labels sit inside their outline and are protected by it.
      obstacles.push(inflated(label.box, 6.0))
    }
    for previous in connections {
      for j in 1..<(previous.line.length() - 1) {
        let bend = previous.line[j]
        if [start, exit, entry, end]
          .iter()
          .all(p => (p.x - bend.x).abs() + (p.y - bend.y).abs() > 12.0) {
          obstacles.push({
            x: bend.x - 8.0,
            y: bend.y - 8.0,
            width: 16.0,
            height: 16.0,
          })
        }
      }
    }
    let source_ancestors = Map([])
    let mut current = parents[a]
    while current >= 0 {
      if !budget.charge(1) {
        break
      }
      source_ancestors[current] = true
      current = parents[current]
    }
    let mut area : Rect? = None
    current = parents[b]
    while current >= 0 {
      if !budget.charge(1) {
        break
      }
      if source_ancestors.contains(current) &&
        by_index.get(current) is Some(container) {
        area = Some(inflated(container.box, -8.0))
        break
      }
      current = parents[current]
    }
    let occupied : Array[(Point, Point)] = []
    for j, (anchor, outer, inner, finish) in planned {
      occupied.push((anchor, outer))
      occupied.push((inner, finish))
      if j != occurrence {
        let (_, pa, pb) = selected[j]
        for (endpoint, p, q) in [(pa, anchor, outer), (pb, finish, inner)] {
          let padding = if endpoint == a || endpoint == b { 1.0 } else { 3.0 }
          let length = (q.x - p.x).abs() + (q.y - p.y).abs()
          let q = if length > 0.0 {
            Point::{
              x: q.x + (q.x - p.x) / length * 8.0,
              y: q.y + (q.y - p.y) / length * 8.0,
            }
          } else {
            q
          }
          let reserved : Rect = {
            x: p.x.min(q.x) - padding,
            y: p.y.min(q.y) - padding,
            width: (p.x - q.x).abs() + padding * 2.0,
            height: (p.y - q.y).abs() + padding * 2.0,
          }
          if !reserved.contains({
              x: exit.x,
              y: exit.y,
              width: 0.0,
              height: 0.0,
            }) &&
            !reserved.contains({
              x: entry.x,
              y: entry.y,
              width: 0.0,
              height: 0.0,
            }) {
            obstacles.push(reserved)
          }
        }
      }
    }
    for previous in connections {
      for j in 1..<previous.line.length() {
        occupied.push((previous.line[j - 1], previous.line[j]))
      }
    }
    guard orthogonal(
        exit,
        entry,
        obstacles,
        lower + 64.0 + occurrence.to_double() * 32.0,
        area,
        budget,
        occupied~,
      )
      is Some(middle) else {
      if !budget.failed {
        budget.error(
          "swimlane/layout-limit",
          "No bounded orthogonal route for \{connection.id}",
        )
      }
      break
    }
    let line = compact(
      [start].iter().concat(middle.iter()).concat([end].iter()).to_array(),
    )
    let text = project_label(connection.label, connection.label_kind)
    let mut chosen : Label? = None
    if !text.is_empty() && connection.style != Invisible {
      let (width, height) = measure(text)
      let candidates = []
      let segments : Array[(Double, Int32)] = []
      for segment in 1..<line.length() {
        let p = line[segment - 1]
        let q = line[segment]
        segments.push(((p.x - q.x).abs() + (p.y - q.y).abs(), segment))
      }
      segments.sort_by((a, b) => {
        let length = b.0.compare(a.0)
        if length == 0 {
          a.1.compare(b.1)
        } else {
          length
        }
      })
      for (_, segment) in segments {
        let p = line[segment - 1]
        let q = line[segment]
        let cx = (p.x + q.x) / 2.0
        let cy = (p.y + q.y) / 2.0
        for
          offset in [
            10.0, 34.0, 58.0, 82.0, 106.0, 130.0, 162.0, 194.0, 258.0, 386.0, 514.0,
          ] {
          for
            box in [
              Rect::{
                x: cx - width / 2.0,
                y: cy - height - offset,
                width,
                height,
              },
              { x: cx - width / 2.0, y: cy + offset, width, height, },
              { x: cx + offset, y: cy - height / 2.0, width, height, },
              { x: cx - width - offset, y: cy - height / 2.0, width, height, },
            ] {
            candidates.push(box)
          }
        }
      }
      for box in candidates {
        let mut clear = area.map(r => r.contains(box)).unwrap_or(true)
        if !clear || box.x < 8.0 || box.y < 8.0 {
          continue
        }
        for shape in shapes {
          if !budget.charge(1) {
            clear = false
            break
          }
          if shape.kind != Node {
            continue
          }
          if box.overlaps(inflated(shape.box, 12.0)) {
            clear = false
            break
          }
        }
        if !clear {
          continue
        }
        for obstacle in obstacles {
          if !budget.charge(1) {
            clear = false
            break
          }
          if box.overlaps(obstacle) {
            clear = false
            break
          }
        }
        if clear {
          for (anchor, outer, inner, finish) in planned {
            if !budget.charge(2) ||
              crosses(anchor, outer, inflated(box, 4.0)) ||
              crosses(inner, finish, inflated(box, 4.0)) {
              clear = false
              break
            }
          }
        }
        if clear {
          for previous in connections {
            for j in 1..<previous.line.length() {
              if !budget.charge(1) ||
                crosses(
                  previous.line[j - 1],
                  previous.line[j],
                  inflated(box, 4.0),
                ) {
                clear = false
                break
              }
            }
            if !clear {
              break
            }
          }
        }
        if clear {
          chosen = Some({
            text,
            box,
            size: 13.0,
            weight: 400,
            owner: connection.id,
            family: None,
          })
          break
        }
      }
      if chosen == None {
        budget.error(
          "swimlane/layout-limit",
          "No bounded label placement for \{connection.id}",
        )
        break
      }
    }
    if chosen is Some(label) {
      labels.push(label)
    }
    if line
      .iter()
      .any(p => p.x.abs() > 1000000000.0 || p.y.abs() > 1000000000.0) {
      budget.error(
        "swimlane/layout-limit", "Automatic route extent exceeded its safe range",
      )
      break
    }
    connections.push({
      connection,
      index: i,
      source: source.id,
      target: target.id,
      line: ReadOnlyArray::from_array(line),
      label: chosen,
    })
  }
  connections
}
