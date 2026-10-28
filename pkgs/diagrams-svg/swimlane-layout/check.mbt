///|
pub(all) enum Rule {
  Overlap
  Fit
  Size
  Contrast
  Containment
  Endpoint
  Limit
} derive(Eq, Debug)

///|
pub struct Finding {
  rule : Rule
  identities : ReadOnlyArray[String]
  message : String
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
fn crosses(a : Point, b : Point, box : Rect) -> Bool {
  let left = box.x + 0.5
  let right = box.x + box.width - 0.5
  let top = box.y + 0.5
  let bottom = box.y + box.height - 0.5
  if left >= right || top >= bottom {
    return false
  }
  let dx = b.x - a.x
  let dy = b.y - a.y
  let mut low = 0.0
  let mut high = 1.0
  for
    (p, q) in [
      (-dx, a.x - left),
      (dx, right - a.x),
      (-dy, a.y - top),
      (dy, bottom - a.y),
    ] {
    if p == 0.0 {
      if q < 0.0 {
        return false
      }
    } else {
      let t = q / p
      if p < 0.0 {
        low = Double::max(low, t)
      } else {
        high = Double::min(high, t)
      }
      if low > high {
        return false
      }
    }
  }
  low < high
}

///|
/// Check measured geometry independently of its painter. Intended nested
/// containment is allowed; ownership, labels, true outline ports and unrelated
/// line intersections are inspected under one explicit work/finding budget.
pub fn check(
  geometry : Geometry,
  palette : @theme.Palette,
  work_limit~ : Int32 = 1000000,
  intentional_containment~ : ArrayView[(String,String)] = [],
) -> ReadOnlyArray[Finding] {
  let findings = []
  let mut work = 0
  let mut exhausted = false
  fn charge(units : Int32) -> Bool {
    if exhausted {
      return false
    }
    if units < 0 || units > work_limit - work {
      findings.push({
        rule: Limit,
        identities: [],
        message: "Legibility search limit exceeded",
      })
      exhausted = true
      return false
    }
    work += units
    true
  }
  fn add(rule : Rule, ids : ArrayView[String], message : String) {
    if exhausted {
      return
    }
    if findings.length() < 255 {
      findings.push({
        rule,
        identities: ReadOnlyArray::from_array(ids),
        message,
      })
    } else {
      findings.push({
        rule: Limit,
        identities: [],
        message: "Legibility finding limit exceeded",
      })
      exhausted = true
    }
  }
  let intended : Map[(String,String),Bool]=Map([])
  for pair in intentional_containment {
    if !charge(pair.0.length()+pair.1.length()+1) { return ReadOnlyArray::from_array(findings) }
    intended[pair]=true
  }
  let by_id : Map[String, Shape] = Map([])
  for shape in geometry.shapes {
    if !charge(shape.id.length() + 1) {
      break
    }
    by_id[shape.id] = shape
  }
  fn ancestor(child : Shape, parent : String) -> Bool {
    if intended.contains((child.id,parent)) { return true }
    let mut current = child.parent
    let seen = Map([])
    while current is Some(id) {
      if !charge(1) || seen.contains(id) {
        return false
      }
      seen[id] = true
      if id == parent {
        return true
      }
      current = by_id.get(id).bind(s => s.parent)
    }
    false
  }
  let labels = []
  for i, shape in geometry.shapes {
    if !charge(1) {
      break
    }
    if !shape.box.contains(shape.outline_box, tolerance=0.1) {
      add(Containment, [shape.id], "Painted outline leaves its layout bounds")
    }
    if shape.parent is Some(parent) {
      if by_id.get(parent) is Some(parent_shape) {
        if !parent_shape.box.contains(shape.box, tolerance=0.1) {
          add(
            Containment,
            [shape.id, parent],
            "Shape \{shape.id} leaves its owner \{parent}",
          )
        }
      } else {
        add(Containment, [shape.id, parent], "Shape owner is absent")
      }
    }
    if shape.label is Some(label) {
      labels.push(label)
      if !shape.box.contains(label.box, tolerance=0.1) {
        add(Fit, [shape.id], "Label overflows \{shape.id}")
      }
      if shape.kind == Node {
        let boundary = outline(shape.shape, shape.outline_box)
        for j, a in boundary {
          if !charge(1) {
            break
          }
          if crosses(a, boundary[(j + 1) % boundary.length()], label.box) {
            add(Fit, [shape.id], "Label intersects its painted outline")
            break
          }
        }
      }
    }
    for j in (i + 1)..<geometry.shapes.length() {
      if !charge(1) {
        break
      }
      let other = geometry.shapes[j]
      if shape.box.overlaps(other.box) &&
        !ancestor(shape, other.id) &&
        !ancestor(other, shape.id) {
        add(
          Overlap,
          [shape.id, other.id],
          "Unintended overlap between \{shape.id} and \{other.id}",
        )
      }
    }
  }
  for edge in geometry.connections {
    if edge.label is Some(label) {
      labels.push(label)
    }
  }
  for i, label in labels {
    if !charge(1) {
      break
    }
    if label.size < 11.0 {
      add(Size, [label.owner], "Label is below 11 px")
    }
    let filled = by_id
      .get(label.owner)
      .map(s => {
        ["f-circ", "sm-circ", "anchor", "fork"].contains(s.shape) &&
        s.outline_box.contains(label.box)
      })
      .unwrap_or(false)
    let ink = if filled {
      palette.bg
    } else {
      label.family.map(f => palette.family(f).ink).unwrap_or(palette.text)
    }
    let bg = if filled {
      label.family.map(f => palette.family(f).ink).unwrap_or(palette.text)
    } else {
      label.family
      .map(f => @theme.over(palette.family(f).fill, palette.bg))
      .unwrap_or(palette.bg)
    }
    if @theme.contrast(ink, bg) < 4.5 {
      add(Contrast, [label.owner], "Text contrast is below 4.5:1")
    }
    if !charge(label.text.length()) {
      break
    }
    let (w, h) = measure(
      label.text,
      size=label.size.ceil().to_int(),
      weight=label.weight,
    )
    if w > label.box.width + 0.1 || h > label.box.height + 0.1 {
      add(Fit, [label.owner], "Measured label exceeds its bounds")
    }
    for j in (i + 1)..<labels.length() {
      if !charge(1) {
        break
      }
      if label.box.overlaps(labels[j].box) {
        add(Overlap, [label.owner, labels[j].owner], "Labels overlap")
      }
    }
    for shape in geometry.shapes {
      if !charge(1) {
        break
      }
      if shape.id == label.owner || shape.kind != Node {
        continue
      }
      if label.box.overlaps(shape.box) {
        add(
          Overlap,
          [label.owner, shape.id],
          "Label overlaps an unrelated node",
        )
      }
    }
  }
  for edge in geometry.connections {
    if !charge(1) {
      break
    }
    if edge.line.length() < 2 {
      add(Endpoint, [edge.connection.id], "Connection has no route")
      continue
    }
    if by_id.get(edge.source) is Some(source) && !on_shape(edge.line[0], source) {
      add(
        Endpoint,
        [edge.connection.id, edge.source],
        "Source port misses its painted outline",
      )
    }
    if by_id.get(edge.target) is Some(target) &&
      !on_shape(edge.line[edge.line.length() - 1], target) {
      add(
        Endpoint,
        [edge.connection.id, edge.target],
        "Target port misses its painted outline",
      )
    }
    for shape in geometry.shapes {
      if !charge(1) {
        break
      }
      if shape.kind != Node ||
        shape.id == edge.source ||
        shape.id == edge.target {
        continue
      }
      for i in 1..<edge.line.length() {
        if !charge(1) {
          break
        }
        if crosses(edge.line[i - 1], edge.line[i], shape.outline_box) {
          add(
            Overlap,
            [edge.connection.id, shape.id],
            "Route crosses an unrelated node",
          )
          break
        }
      }
    }
    if edge.connection.style == Invisible {
      continue
    }
    for label in labels {
      if !charge(1) {
        break
      }
      if label.owner == edge.connection.id {
        continue
      }
      for i in 1..<edge.line.length() {
        if !charge(1) {
          break
        }
        if crosses(edge.line[i - 1], edge.line[i], label.box) {
          add(
            Overlap,
            [edge.connection.id, label.owner],
            "Route crosses unrelated text",
          )
          break
        }
      }
    }
  }
  ReadOnlyArray::from_array(findings)
}
