///|
fn polygon(box : Rect, values : ArrayView[(Double, Double)]) -> Array[Point] {
  values.map(p => Point::{
    x: box.x + p.0 * box.width,
    y: box.y + p.1 * box.height,
  })
}

///|
fn arc(
  points : Array[Point],
  x : Double,
  y : Double,
  rx : Double,
  ry : Double,
  start : Double,
  end : Double,
  steps : Int32,
) -> Unit {
  for i in 0..<=steps {
    let t = start + (end - start) * i.to_double() / steps.to_double()
    points.push({ x: x + rx * @math.cos(t), y: y + ry * @math.sin(t), })
  }
}

///|
/// Each painted outer boundary and its edge attachment use this same vector.
/// Curves use fixed sampled segments, so path bytes and clipping agree on all targets.
pub fn outline(shape : String, box : Rect) -> ReadOnlyArray[Point] {
  let r = box
  let x = r.x
  let y = r.y
  let w = r.width
  let h = r.height
  let circle = [
    "circle", "doublecircle", "sm-circ", "fr-circ", "f-circ", "cross-circ", "anchor",
  ].contains(shape)
  let points : Array[Point] = []
  if circle || shape == "ellipse" {
    arc(
      points,
      x + w / 2.0,
      y + h / 2.0,
      w / 2.0,
      h / 2.0,
      0.0,
      2.0 * @math.PI,
      64,
    )
    return ReadOnlyArray::from_array(points)
  }
  if shape == "stadium" ||
    shape == "rounded" ||
    shape == "state" ||
    shape == "composite" {
    let rx = if shape == "stadium" {
      Double::min(h / 2.0, w / 2.0)
    } else {
      Double::min(12.0, w / 4.0)
    }
    let ry = Double::min(rx, h / 2.0)
    arc(points, x + w - rx, y + ry, rx, ry, -@math.PI / 2.0, 0.0, 8)
    arc(points, x + w - rx, y + h - ry, rx, ry, 0.0, @math.PI / 2.0, 8)
    arc(points, x + rx, y + h - ry, rx, ry, @math.PI / 2.0, @math.PI, 8)
    arc(points, x + rx, y + ry, rx, ry, @math.PI, 1.5 * @math.PI, 8)
    return ReadOnlyArray::from_array(points)
  }
  if shape == "cylinder" || shape == "lin-cyl" {
    arc(
      points,
      x + w / 2.0,
      y + h * 0.15,
      w / 2.0,
      h * 0.15,
      @math.PI,
      2.0 * @math.PI,
      24,
    )
    arc(points, x + w / 2.0, y + h * 0.85, w / 2.0, h * 0.15, 0.0, @math.PI, 24)
    return ReadOnlyArray::from_array(points)
  }
  if shape == "h-cyl" {
    arc(
      points,
      x + w * 0.12,
      y + h / 2.0,
      w * 0.12,
      h / 2.0,
      @math.PI / 2.0,
      1.5 * @math.PI,
      24,
    )
    arc(
      points,
      x + w * 0.88,
      y + h / 2.0,
      w * 0.12,
      h / 2.0,
      -@math.PI / 2.0,
      @math.PI / 2.0,
      24,
    )
    return ReadOnlyArray::from_array(points)
  }
  if shape == "delay" {
    points.push({ x, y, })
    arc(
      points,
      x + w - h / 2.0,
      y + h / 2.0,
      h / 2.0,
      h / 2.0,
      -@math.PI / 2.0,
      @math.PI / 2.0,
      24,
    )
    points.push({ x, y: y + h, })
    return ReadOnlyArray::from_array(points)
  }
  if ["doc", "docs", "lin-doc", "tag-doc"].contains(shape) {
    points.push({ x, y, })
    points.push({ x: x + w, y, })
    points.push({ x: x + w, y: y + h * 0.88, })
    for i in 0..<=32 {
      let t = i.to_double() / 32.0
      points.push({
        x: x + w * (1.0 - t),
        y: y + h * (0.88 - 0.12 * @math.sin(t * 2.0 * @math.PI)),
      })
    }
    return ReadOnlyArray::from_array(points)
  }
  if shape == "flag" {
    for i in 0..<=32 {
      let t = i.to_double() / 32.0
      points.push({
        x: x + w * t,
        y: y + h * (0.12 + 0.1 * @math.sin(t * 2.0 * @math.PI)),
      })
    }
    for i in 0..<=32 {
      let t = i.to_double() / 32.0
      points.push({
        x: x + w * (1.0 - t),
        y: y + h * (0.88 - 0.1 * @math.sin(t * 2.0 * @math.PI)),
      })
    }
    return ReadOnlyArray::from_array(points)
  }
  if shape == "bow-rect" {
    points.push({ x, y, })
    points.push({ x: x + w, y, })
    for i in 0..<=24 {
      let t = i.to_double() / 24.0
      points.push({
        x: x + w - w * 0.12 * @math.sin(t * @math.PI),
        y: y + h * t,
      })
    }
    points.push({ x, y: y + h, })
    for i in 0..<=24 {
      let t = i.to_double() / 24.0
      points.push({
        x: x + w * 0.12 * @math.sin(t * @math.PI),
        y: y + h * (1.0 - t),
      })
    }
    return ReadOnlyArray::from_array(points)
  }
  if shape == "cloud" {
    for i in 0..<96 {
      let t = 2.0 * @math.PI * i.to_double() / 96.0
      let ripple = 0.87 + 0.13 * @math.cos(8.0 * t)
      points.push({
        x: x + w / 2.0 + w / 2.0 * ripple * @math.cos(t),
        y: y + h / 2.0 + h / 2.0 * ripple * @math.sin(t),
      })
    }
    return ReadOnlyArray::from_array(points)
  }
  if shape == "bang" {
    for i in 0..<24 {
      let t = 2.0 * @math.PI * i.to_double() / 24.0
      let scale = if i % 2 == 0 { 1.0 } else { 0.72 }
      points.push({
        x: x + w / 2.0 + w / 2.0 * scale * @math.cos(t),
        y: y + h / 2.0 + h / 2.0 * scale * @math.sin(t),
      })
    }
    return ReadOnlyArray::from_array(points)
  }
  if shape == "person" {
    return outline("rounded", {
      x,
      y: y + h * 0.34,
      width: w,
      height: h * 0.66,
    })
  }
  if shape == "curv-trap" {
    points.push({ x: x + w * 0.15, y, })
    points.push({ x: x + w * 0.85, y, })
    arc(
      points,
      x + w * 0.85,
      y + h / 2.0,
      w * 0.15,
      h / 2.0,
      -@math.PI / 2.0,
      @math.PI / 2.0,
      16,
    )
    points.push({ x: x + w * 0.15, y: y + h, })
    points.push({ x, y: y + h / 2.0, })
    return ReadOnlyArray::from_array(points)
  }
  if shape == "braces" {
    let both = outline("brace", box).iter().to_array()
    both.append(outline("brace-r", box))
    return ReadOnlyArray::from_array(both)
  }
  let values : Array[(Double, Double)] = match shape {
    "choice" | "diamond" => [(0.5, 0.0), (1.0, 0.5), (0.5, 1.0), (0.0, 0.5)]
    "hexagon" =>
      [(0.2, 0.0), (0.8, 0.0), (1.0, 0.5), (0.8, 1.0), (0.2, 1.0), (0.0, 0.5)]
    "lean-r" => [(0.15, 0.0), (1.0, 0.0), (0.85, 1.0), (0.0, 1.0)]
    "lean-l" => [(0.0, 0.0), (0.85, 0.0), (1.0, 1.0), (0.15, 1.0)]
    "trap-b" => [(0.2, 0.0), (0.8, 0.0), (1.0, 1.0), (0.0, 1.0)]
    "trap-t" | "bucket" => [(0.0, 0.0), (1.0, 0.0), (0.8, 1.0), (0.2, 1.0)]
    "folder" =>
      [
        (0.0, 0.0),
        (0.35, 0.0),
        (0.45, 0.15),
        (1.0, 0.15),
        (1.0, 1.0),
        (0.0, 1.0),
      ]
    "note" => [(0.0, 0.0), (0.85, 0.0), (1.0, 0.2), (1.0, 1.0), (0.0, 1.0)]
    "brace" =>
      [
        (0.18, 0.0),
        (0.08, 0.05),
        (0.07, 0.38),
        (0.0, 0.5),
        (0.07, 0.62),
        (0.08, 0.95),
        (0.18, 1.0),
        (0.18, 0.97),
        (0.1, 0.93),
        (0.1, 0.6),
        (0.03, 0.5),
        (0.1, 0.4),
        (0.1, 0.07),
        (0.18, 0.03),
      ]
    "brace-r" =>
      [
        (0.82, 0.0),
        (0.92, 0.05),
        (0.93, 0.38),
        (1.0, 0.5),
        (0.93, 0.62),
        (0.92, 0.95),
        (0.82, 1.0),
        (0.82, 0.97),
        (0.9, 0.93),
        (0.9, 0.6),
        (0.97, 0.5),
        (0.9, 0.4),
        (0.9, 0.07),
        (0.82, 0.03),
      ]
    "braces" =>
      [
        (0.0, 0.5),
        (0.06, 0.4),
        (0.06, 0.06),
        (0.16, 0.0),
        (0.84, 0.0),
        (0.94, 0.06),
        (0.94, 0.4),
        (1.0, 0.5),
        (0.94, 0.6),
        (0.94, 0.94),
        (0.84, 1.0),
        (0.16, 1.0),
        (0.06, 0.94),
        (0.06, 0.6),
      ]
    "odd" => [(0.2, 0.0), (1.0, 0.0), (1.0, 1.0), (0.2, 1.0), (0.0, 0.5)]
    "notch-rect" =>
      [(0.16, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0), (0.0, 0.2)]
    "hourglass" =>
      [(0.0, 0.0), (1.0, 0.0), (0.55, 0.5), (1.0, 1.0), (0.0, 1.0), (0.45, 0.5)]
    "sl-rect" => [(0.0, 0.2), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
    "flip-tri" => [(0.0, 0.0), (1.0, 0.0), (0.5, 1.0)]
    "tri" => [(0.5, 0.0), (1.0, 1.0), (0.0, 1.0)]
    "notch-pent" =>
      [(0.1, 0.0), (0.9, 0.0), (1.0, 0.2), (1.0, 1.0), (0.0, 1.0), (0.0, 0.2)]
    "bolt" =>
      [
        (0.55, 0.0),
        (0.0, 0.6),
        (0.4, 0.6),
        (0.3, 1.0),
        (1.0, 0.35),
        (0.6, 0.35),
      ]
    _ => [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)]
  }
  ReadOnlyArray::from_array(polygon(box, values))
}

///|
fn segment_distance(p : Point, a : Point, b : Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let length = dx * dx + dy * dy
  let t = if length == 0.0 {
    0.0
  } else {
    Double::max(
      0.0,
      Double::min(1.0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length),
    )
  }
  let x = p.x - a.x - t * dx
  let y = p.y - a.y - t * dy
  (x * x + y * y).sqrt()
}

///|
fn on_shape(p : Point, shape : Shape) -> Bool {
  if shape.shape == "datastore" {
    let r = shape.outline_box
    return segment_distance(p, { x: r.x, y: r.y, }, {
        x: r.x + r.width,
        y: r.y,
      }) <=
      0.1 ||
      segment_distance(p, { x: r.x, y: r.y + r.height, }, {
        x: r.x + r.width,
        y: r.y + r.height,
      }) <=
      0.1
  }

  if shape.shape == "braces" {
    return on_shape(p, { ..shape, shape: "brace", }) ||
      on_shape(p, { ..shape, shape: "brace-r", })
  }

  let boundary = outline(shape.shape, shape.outline_box)
  for i, a in boundary {
    if segment_distance(p, a, boundary[(i + 1) % boundary.length()]) <= 0.1 {
      return true
    }
  }
  false
}

///|
fn port(shape : Shape, side : Int32, fraction : Double) -> Point {
  let box = shape.outline_box
  if shape.shape == "datastore" {
    match side {
      0 => return { x: box.x + box.width * (0.55 + 0.4 * fraction), y: box.y, }
      2 =>
        return {
          x: box.x + box.width * (0.05 + 0.4 * fraction),
          y: box.y + box.height,
        }
      _ => ()
    }
  }
  let boundary = outline(shape.shape, box)
  let horizontal = side == 0 || side == 2
  let coordinate = if horizontal {
    box.y + box.height * fraction
  } else {
    box.x + box.width * fraction
  }
  let hits : Array[Double] = []
  for i, a in boundary {
    let b = boundary[(i + 1) % boundary.length()]
    let aa = if horizontal { a.y } else { a.x }
    let bb = if horizontal { b.y } else { b.x }
    if aa == bb {
      if (coordinate - aa).abs() < 0.0001 {
        hits.push(if horizontal { a.x } else { a.y })
        hits.push(if horizontal { b.x } else { b.y })
      }
      continue
    }
    let t = (coordinate - aa) / (bb - aa)
    if t >= 0.0 && t <= 1.0 {
      hits.push(
        if horizontal {
          a.x + (b.x - a.x) * t
        } else {
          a.y + (b.y - a.y) * t
        },
      )
    }
  }
  hits.sort_by((a, b) => a.compare(b))
  let v = if side == 0 || side == 1 { hits.last() } else { hits.get(0) }
  if v == None {
    let desired : Point = match side {
      0 => { x: box.x + box.width, y: coordinate, }
      1 => { x: coordinate, y: box.y + box.height, }
      2 => { x: box.x, y: coordinate, }
      _ => { x: coordinate, y: box.y, }
    }
    let mut closest = boundary[0]
    let mut distance = 1000000000000000000.0
    for p in boundary {
      let d = (p.x - desired.x) * (p.x - desired.x) +
        (p.y - desired.y) * (p.y - desired.y)
      if d < distance {
        closest = p
        distance = d
      }
    }
    return closest
  }
  let v = v.unwrap()
  if horizontal {
    { x: v, y: coordinate, }
  } else {
    { x: coordinate, y: v, }
  }
}
