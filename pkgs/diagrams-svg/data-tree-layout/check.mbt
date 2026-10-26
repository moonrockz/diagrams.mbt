///|
/// The rule that a legibility finding breaks.
pub(all) enum Rule {
  /// Boxes, rows or labels overlap, or a connector crosses an unrelated box.
  Overlap
  /// A label does not fit its bounds or has too little clearance.
  Fit
  /// Text is smaller than 11 px.
  Size
  /// Text contrast is below 4.5:1.
  Contrast
  /// A row leaves its box, or a box leaves the canvas.
  Containment
  /// A connector does not attach to its row or to its target box.
  Endpoint
  /// The check stopped at its work limit.
  Limit
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub struct Finding {
  rule : Rule
  identities : ReadOnlyArray[String]
  message : String
} derive(Eq, Debug)

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
/// The smallest space between a label and the edge of its row.
pub let label_clearance : Double = 2.0

///|
fn segment_crosses(a : Point, b : Point, box : Rect) -> Bool {
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
    pair in [
      (-dx, a.x - left),
      (dx, right - a.x),
      (-dy, a.y - top),
      (dy, bottom - a.y),
    ] {
    let (p, q) = pair
    if p == 0.0 {
      if q < 0.0 {
        return false
      }
    } else {
      let r = q / p
      if p < 0.0 {
        if r > high {
          return false
        }
        if r > low {
          low = r
        }
      } else {
        if r < low {
          return false
        }
        if r < high {
          high = r
        }
      }
    }
  }
  low < high
}

///|
/// Check measured data geometry independently of its painter: row bounds,
/// label clearance and fit, overlaps, connector attachment and crossings,
/// text size and the contrast of every label on its background, including
/// highlighted rows. The check is bounded by `work_limit`.
pub fn check(
  geometry : Geometry,
  palette : @theme.Palette,
  work_limit~ : Int32 = 1000000,
) -> ReadOnlyArray[Finding] {
  let findings : Array[Finding] = []
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
        message: "Legibility check work limit exceeded",
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
  let canvas : Rect = {
    x: 0.0,
    y: 0.0,
    width: geometry.width.to_double(),
    height: geometry.height.to_double(),
  }
  let highlight = highlight_background(palette)
  let fonts : Map[String, @metrics.FontMetrics] = Map([])
  fn label(
    owner : String,
    l : Label,
    bounds : Rect,
    background : @theme.Color,
  ) {
    if !charge(l.lines.length() + 1) {
      return
    }
    if l.size < 11.0 {
      add(Size, [owner], "Label of \{owner} is below 11 px")
    }
    if @theme.contrast(l.ink.color(palette), background) < 4.5 {
      add(Contrast, [owner], "Text of \{owner} has contrast below 4.5:1")
    }
    let inner : Rect = {
      x: bounds.x + label_clearance,
      y: bounds.y + label_clearance,
      width: bounds.width - 2.0 * label_clearance,
      height: bounds.height - 2.0 * label_clearance,
    }
    if !inner.contains(l.box, tolerance=0.01) {
      add(
        Fit,
        [owner],
        "Label of \{owner} leaves its bounds or has too little clearance",
      )
    }
    let key = "\{l.size}:\{l.weight}"
    let font = match fonts.get(key) {
      Some(font) => font
      None => {
        let font = metrics(l.size.to_int(), l.weight)
        fonts[key] = font
        font
      }
    }
    let line_step = if l.size.to_int() == title_size {
      title_line_height
    } else {
      line_height
    }
    if l.lines.length().to_double() * line_step > l.box.height + 0.01 {
      add(Fit, [owner], "Label lines of \{owner} exceed the label height")
    }
    for line in l.lines {
      if !charge(line.length() + 1) {
        return
      }
      if font.measure(line).width.to_double() > l.box.width + 0.01 {
        add(Fit, [owner], "Measured text of \{owner} exceeds its label width")
        break
      }
    }
  }
  let by_node : Map[String, Box] = Map([])
  let rows : Map[String, Row] = Map([])
  for box in geometry.boxes {
    if !charge(1) {
      break
    }
    by_node[box.node] = box
    for row in box.rows {
      rows[row.entry] = row
    }
  }
  if geometry.title is Some(t) {
    label("title", t, canvas, palette.bg)
  }
  for box in geometry.boxes {
    if !charge(1) {
      break
    }
    if !canvas.contains(box.box, tolerance=0.01) {
      add(Containment, [box.node], "Box \{box.node} leaves the canvas")
    }
    if box.box.width <= 0.0 || box.box.height <= 0.0 {
      add(Containment, [box.node], "Box \{box.node} has no area")
    }
    if box.label is Some(l) {
      label(box.node, l, box.box, palette.mask)
    }
    let mut previous : Rect? = None
    for row in box.rows {
      if !charge(1) {
        break
      }
      if !box.box.contains(row.box, tolerance=0.01) {
        add(
          Containment,
          [row.entry, box.node],
          "Row \{row.entry} leaves its box",
        )
      }
      if row.box.height <= 0.0 {
        add(Containment, [row.entry], "Row \{row.entry} has no height")
      }
      if previous is Some(p) && p.overlaps(row.box) {
        add(Overlap, [row.entry], "Row \{row.entry} overlaps the row before it")
      }
      previous = Some(row.box)
      let background = if row.highlighted { highlight } else { palette.mask }
      if row.key is Some(l) {
        label(row.entry, l, row.box, background)
      }
      if row.value is Some(l) {
        label(row.entry, l, row.box, background)
      }
      if row.key is Some(k) && row.value is Some(v) && k.box.overlaps(v.box) {
        add(Overlap, [row.entry], "Key and value of \{row.entry} overlap")
      }
      if box.divider is Some(divider) {
        if row.key is Some(k) && k.box.right() > divider + 0.01 {
          add(Fit, [row.entry], "Key of \{row.entry} crosses the column line")
        }
        if row.value is Some(v) && v.box.x < divider - 0.01 {
          add(Fit, [row.entry], "Value of \{row.entry} crosses the column line")
        }
      }
    }
  }
  // Boxes in vertical bands, so overlap and crossing checks stay near linear.
  let band = 128.0
  let bands : Map[Int32, Array[Int32]] = Map([])
  fn band_range(top : Double, bottom : Double) -> (Int32, Int32) {
    let a = (top / band).floor().to_int()
    let b = (bottom / band).floor().to_int()
    (a, if b - a > 4096 { a + 4096 } else { b })
  }
  for i, box in geometry.boxes {
    let (a, b) = band_range(box.box.y, box.box.bottom())
    for k in a..<=b {
      if !charge(1) {
        break
      }
      match bands.get(k) {
        Some(list) => list.push(i)
        None => bands[k] = [i]
      }
    }
  }
  fn near(top : Double, bottom : Double) -> Array[Int32] {
    let seen : Map[Int32, Bool] = Map([])
    let out = []
    let (a, b) = band_range(top, bottom)
    for k in a..<=b {
      if bands.get(k) is Some(list) {
        for i in list {
          if !charge(1) {
            return out
          }
          if !seen.contains(i) {
            seen[i] = true
            out.push(i)
          }
        }
      }
    }
    out.sort()
    out
  }
  for i, box in geometry.boxes {
    for j in near(box.box.y, box.box.bottom()) {
      if j <= i {
        continue
      }
      let other = geometry.boxes[j]
      if box.box.overlaps(other.box) {
        add(
          Overlap,
          [box.node, other.node],
          "Boxes \{box.node} and \{other.node} overlap",
        )
      }
    }
  }
  for connector in geometry.connectors {
    if !charge(1) {
      break
    }
    let points = connector.points
    if points.length() < 2 {
      add(
        Endpoint,
        [connector.entry],
        "Connector \{connector.entry} has no route",
      )
      continue
    }
    let start = points[0]
    let end = points[points.length() - 1]
    if (end.x - start.x).abs() + (end.y - start.y).abs() < 1.0 {
      add(
        Endpoint,
        [connector.entry],
        "Connector \{connector.entry} has no length",
      )
    }
    match (rows.get(connector.entry), by_node.get(connector.source)) {
      (Some(row), Some(source)) =>
        if (start.x - source.box.right()).abs() > 0.5 ||
          start.y < row.box.y ||
          start.y > row.box.bottom() {
          add(
            Endpoint,
            [connector.entry],
            "Connector \{connector.entry} does not start at the right edge of its row",
          )
        }
      _ =>
        add(
          Endpoint,
          [connector.entry],
          "Connector \{connector.entry} has no source row",
        )
    }
    match by_node.get(connector.target) {
      Some(target) =>
        if (end.x - target.box.x).abs() > 0.5 ||
          end.y < target.box.y ||
          end.y > target.box.bottom() {
          add(
            Endpoint,
            [connector.entry, connector.target],
            "Connector \{connector.entry} does not end at the left edge of its box",
          )
        }
      None =>
        add(
          Endpoint,
          [connector.entry, connector.target],
          "Connector \{connector.entry} has no target box",
        )
    }
    let samples = connector.samples()
    let top = samples.fold(init=samples[0].y, (m, p) => m.min(p.y))
    let bottom = samples.fold(init=samples[0].y, (m, p) => m.max(p.y))
    for index in near(top, bottom) {
      let box = geometry.boxes[index]
      if !charge(samples.length()) {
        break
      }
      if box.node == connector.source || box.node == connector.target {
        continue
      }
      for k in 1..<samples.length() {
        if segment_crosses(samples[k - 1], samples[k], box.box) {
          add(
            Overlap,
            [connector.entry, box.node],
            "Connector \{connector.entry} crosses box \{box.node}",
          )
          break
        }
      }
    }
  }
  ReadOnlyArray::from_array(findings)
}
