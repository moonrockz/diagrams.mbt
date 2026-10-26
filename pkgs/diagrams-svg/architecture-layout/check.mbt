///|
fn boundary(point : Point, box : Rect, side : @model.Side) -> Bool {
  match side {
    Left =>
      point.x == box.x && point.y >= box.y && point.y <= box.y + box.height
    Right =>
      point.x == box.x + box.width &&
      point.y >= box.y &&
      point.y <= box.y + box.height
    Top => point.y == box.y && point.x >= box.x && point.x <= box.x + box.width
    Bottom =>
      point.y == box.y + box.height &&
      point.x >= box.x &&
      point.x <= box.x + box.width
  }
}

///|
pub fn check(
  geometry : Geometry,
  palette~ : @theme.Palette = @theme.Theme::classic().light,
  work_limit~ : Int32 = 1000000,
) -> ReadOnlyArray[Finding] {
  let out : Array[Finding] = []
  let mut work = 0
  let shapes : Map[String, Shape] = Map([])
  fn finding(code : String, message : String, element : String) {
    out.push({ code, message, element, })
  }
  for shape in geometry.shapes {
    work += 1 + shape.label.length()
    if work > work_limit {
      finding("limit", "Legibility work budget exhausted", geometry.model.id)
      return ReadOnlyArray::from_array(out[:])
    }
    shapes[shape.id] = shape
    if shape.font_size < 11 {
      finding("small-text", "Text size is below 11 px", shape.id)
    }
    if shape.label != "" &&
      measure(shape.label, size=shape.font_size) > shape.box.width - 24 {
      finding("label-overflow", "Label exceeds measured shape bounds", shape.id)
    }
    if shape.box.width < 0 ||
      shape.box.height < 0 ||
      shape.box.x < 0 ||
      shape.box.y < 0 ||
      shape.box.x + shape.box.width > geometry.width ||
      shape.box.y + shape.box.height > geometry.height {
      finding("overflow", "Shape exceeds viewport", shape.id)
    }
  }
  for shape in geometry.shapes {
    if shape.parent is Some(parent) {
      match shapes.get(parent) {
        Some(group) =>
          if !group.box.contains(shape.box) {
            finding(
              "containment",
              "Shape is outside its parent group",
              shape.id,
            )
          }
        None => finding("containment", "Parent group has no geometry", shape.id)
      }
    }
  }
  fn ancestor(group : String, shape : Shape) -> Bool {
    let mut parent = shape.parent
    let mut depth = 0
    while parent is Some(p) {
      work += 1
      if work > work_limit || depth >= geometry.shapes.length() {
        return false
      }
      if p == group {
        return true
      }
      parent = shapes.get(p).bind(s => s.parent)
      depth += 1
    }
    false
  }
  for i, a in geometry.shapes {
    for j = i + 1; j < geometry.shapes.length(); j = j + 1 {
      work += 1
      if work > work_limit {
        finding("limit", "Legibility work budget exhausted", geometry.model.id)
        return ReadOnlyArray::from_array(out[:])
      }
      let b = geometry.shapes[j]
      if a.box.overlaps(b.box) && !ancestor(a.id, b) && !ancestor(b.id, a) {
        finding("overlap", "Unrelated shape boxes overlap", a.id + "," + b.id)
      }
    }
  }
  for route in geometry.connections {
    if route.points.length() < 2 {
      finding("endpoint", "Connection has no path", route.connection.id)
      continue
    }
    for shape in geometry.shapes {
      let source = shapes.get(route.connection.source.id)
      let target = shapes.get(route.connection.target.id)
      let box = if shape.kind == Group &&
        (
          source.map(s => ancestor(shape.id, s)).unwrap_or(false) ||
          target.map(s => ancestor(shape.id, s)).unwrap_or(false)
        ) {
        { ..shape.box, height: shape.header_height, }
      } else {
        shape.box
      }
      for i in 1..<route.points.length() {
        work += 1
        if work > work_limit {
          finding(
            "limit",
            "Legibility work budget exhausted",
            geometry.model.id,
          )
          return ReadOnlyArray::from_array(out[:])
        }
        if crosses(route.points[i - 1], route.points[i], box) {
          finding(
            "overlap",
            "Connection crosses an unrelated shape or group title",
            route.connection.id + "," + shape.id,
          )
          break
        }
      }
      if route.label_box is Some(label) &&
        label.overlaps(
          if shape.kind == Group {
            { ..shape.box, height: shape.header_height, }
          } else {
            shape.box
          },
        ) {
        finding(
          "label-overflow",
          "Connection label overlaps a node",
          route.connection.id,
        )
      }
    }

    for
      (endpoint, point) in [
        (route.connection.source, route.points[0]),
        (route.connection.target, route.points[route.points.length() - 1]),
      ] {
      match shapes.get(endpoint.id) {
        Some(shape) => {
          let box = if endpoint.group {
            shape.parent
            .bind(p => shapes.get(p))
            .map(g => g.box)
            .unwrap_or(shape.box)
          } else {
            shape.box
          }
          if !boundary(point, box, endpoint.side) {
            finding(
              "endpoint",
              "Connection misses authored endpoint port",
              route.connection.id,
            )
          }
        }
        None =>
          finding(
            "endpoint",
            "Connection endpoint is absent",
            route.connection.id,
          )
      }
    }
  }
  if @theme.contrast(palette.text, palette.bg) < 4.5 {
    finding("contrast", "Text contrast is below 4.5:1", geometry.model.id)
  }
  ReadOnlyArray::from_array(out[:])
}
