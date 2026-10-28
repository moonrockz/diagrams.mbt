///|
priv struct RouteBudget {
  limit : Int32
  mut work : Int32
  mut failed : Bool
}

///|
fn charge(budget : RouteBudget, units : Int32) -> Bool {
  if budget.failed {
    return false
  }
  if units > budget.limit - budget.work {
    budget.failed = true
    false
  } else {
    budget.work += units
    true
  }
}

///|
fn crosses(a : Point, b : Point, box : Rect) -> Bool {
  if a.x == b.x {
    a.x > box.x &&
    a.x < box.x + box.width &&
    a.y.min(b.y) < box.y + box.height &&
    a.y.max(b.y) > box.y
  } else if a.y == b.y {
    a.y > box.y &&
    a.y < box.y + box.height &&
    a.x.min(b.x) < box.x + box.width &&
    a.x.max(b.x) > box.x
  } else {
    true
  }
}

///|
fn clear(
  line : ArrayView[Point],
  obstacles : ArrayView[Rect],
  budget : RouteBudget,
  occupied~ : ArrayView[(Point, Point)] = [],
) -> Bool {
  for i in 1..<line.length() {
    let a = line[i - 1]
    let b = line[i]
    for (p, q) in occupied {
      if !charge(budget, 1) {
        return false
      }
      let horizontal = a.y == b.y && p.y == q.y && a.y == p.y
      let vertical = a.x == b.x && p.x == q.x && a.x == p.x
      if (
          horizontal &&
          a.x.min(b.x).max(p.x.min(q.x)) < a.x.max(b.x).min(p.x.max(q.x))
        ) ||
        (
          vertical &&
          a.y.min(b.y).max(p.y.min(q.y)) < a.y.max(b.y).min(p.y.max(q.y))
        ) {
        return false
      }
    }
    for box in obstacles {
      if !charge(budget, 1) || crosses(line[i - 1], line[i], box) {
        return false
      }
    }
  }
  true
}

///|
fn compact(points : ArrayView[Point]) -> Array[Point] {
  let out : Array[Point] = []
  for p in points {
    if out.last() == Some(p) {
      continue
    }
    if out.length() >= 2 {
      let a = out[out.length() - 2]
      let b = out[out.length() - 1]
      if (a.x == b.x && b.x == p.x && (b.y >= a.y) == (p.y >= b.y)) ||
        (a.y == b.y && b.y == p.y && (b.x >= a.x) == (p.x >= b.x)) {
        ignore(out.pop())
      }
    }
    out.push(p)
  }
  out
}

///|
fn axis(values : Array[Int32]) -> Array[Int32] {
  values.sort()
  let out = []
  for value in values {
    if out.last() != Some(value) {
      out.push(value)
    }
  }
  out
}

///|
fn orthogonal(
  start : Point,
  end : Point,
  obstacles : ArrayView[Rect],
  channel : Int32,
  budget : RouteBudget,
  occupied~ : ArrayView[(Point, Point)] = [],
) -> Array[Point]? {
  let middle_x = (start.x + end.x) / 2
  let middle_y = (start.y + end.y) / 2
  for
    points in [
      [start, { x: end.x, y: start.y, }, end],
      [start, { x: start.x, y: end.y, }, end],
      [start, { x: middle_x, y: start.y, }, { x: middle_x, y: end.y, }, end],
      [start, { x: start.x, y: middle_y, }, { x: end.x, y: middle_y, }, end],
      [start, { x: start.x, y: channel, }, { x: end.x, y: channel, }, end],
    ] {
    let points = compact(points[:])
    if clear(points[:], obstacles, budget, occupied~) {
      return Some(points)
    }
    if budget.failed {
      return None
    }
  }
  let xs = [start.x, end.x, 24]
  let ys = [start.y, end.y, 24, channel]
  for box in obstacles {
    if !charge(budget, 1) {
      return None
    }
    xs.push((box.x - 12).max(12))
    xs.push(box.x + box.width + 12)
    ys.push((box.y - 12).max(12))
    ys.push(box.y + box.height + 12)
  }
  for (a, b) in occupied {
    if !charge(budget, 1) {
      return None
    }
    for p in [a, b] {
      xs.push((p.x - 12).max(12))
      xs.push(p.x + 12)
      ys.push((p.y - 12).max(12))
      ys.push(p.y + 12)
    }
  }
  let xs = axis(xs)
  let ys = axis(ys)
  let sx = xs.iter().to_array().search(start.x).unwrap()
  let sy = ys.iter().to_array().search(start.y).unwrap()
  let tx = xs.iter().to_array().search(end.x).unwrap()
  let ty = ys.iter().to_array().search(end.y).unwrap()
  let queue = [(sx, sy)]
  let seen : Map[(Int32, Int32), Bool] = Map([((sx, sy), true)])
  let previous : Map[(Int32, Int32), (Int32, Int32)] = Map([])
  let mut cursor = 0
  while cursor < queue.length() {
    if !charge(budget, 1) {
      return None
    }
    let (x, y) = queue[cursor]
    cursor += 1
    if x == tx && y == ty {
      let reversed = [end]
      let mut current = (x, y)
      while previous.get(current) is Some(parent) {
        if !charge(budget, 1) {
          return None
        }
        reversed.push({ x: xs[parent.0], y: ys[parent.1], })
        current = parent
      }
      return Some(
        compact(
          Array::makei(reversed.length(), i => {
            reversed[reversed.length() - 1 - i]
          })[:],
        ),
      )
    }
    for (nx, ny) in [(x + 1, y), (x, y + 1), (x - 1, y), (x, y - 1)] {
      if nx < 0 ||
        ny < 0 ||
        nx >= xs.length() ||
        ny >= ys.length() ||
        seen.contains((nx, ny)) {
        continue
      }
      if clear(
          [{ x: xs[x], y: ys[y], }, { x: xs[nx], y: ys[ny], }],
          obstacles,
          budget,
          occupied~,
        ) {
        seen[(nx, ny)] = true
        previous[(nx, ny)] = (x, y)
        queue.push((nx, ny))
      }
      if budget.failed {
        return None
      }
    }
  }
  None
}
