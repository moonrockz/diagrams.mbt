///|
let font_size : Int32 = 13

///|
let title_size : Int32 = 16

///|
let line_height : Double = 17.0

///|
let title_line_height : Double = 21.0

///|
let pad_x : Double = 8.0

///|
let pad_y : Double = 5.0

///|
let column_gap : Double = 56.0

///|
let box_gap : Double = 16.0

///|
let margin : Double = 20.0

///|
let min_value_width : Double = 16.0

///|
priv struct Budget {
  limit : Int32
  diagnostics : Array[@diagrams.Diagnostic]
  mut used : Int32
  mut failed : Bool
}

///|
fn Budget::charge(self : Budget, units : Int32) -> Bool {
  if self.failed {
    return false
  }
  if units < 0 || units > self.limit - self.used {
    self.failed = true
    self.diagnostics.push(
      @diagrams.Diagnostic::error(
        "data-tree/layout-limit", "Data-tree layout exceeds its work limit",
      ),
    )
    return false
  }
  self.used += units
  true
}

///|
fn metrics(size : Int32, weight : Int32) -> @metrics.FontMetrics {
  @metrics.FontMetrics::from_defaults(
    profile=Monospace,
    font_size=size,
    font_weight=weight,
  )
}

///|
/// The measured width of one line of text.
pub fn text_width(
  line : String,
  size~ : Int32 = 13,
  weight~ : Int32 = 400,
) -> Double {
  metrics(size, weight).measure(line).width.to_double()
}

///|
/// The line breaks of the text: LF, CR LF and CR.
fn split_breaks(text : String) -> Array[String] {
  let out = []
  let mut start = 0
  let mut i = 0
  let n = text.length()
  while i < n {
    let c = text.code_unit_at(i).to_int()
    if c == 10 || c == 13 {
      out.push(text.view(start_offset=start, end_offset=i).to_owned())
      i += if c == 13 && i + 1 < n && text.code_unit_at(i + 1).to_int() == 10 {
        2
      } else {
        1
      }
      start = i
    } else {
      i += 1
    }
  }
  out.push(text.view(start_offset=start, end_offset=n).to_owned())
  out
}

///|
/// Wrap text into lines no wider than `max_width`. A line breaks after its
/// last space when it has one, else between code points. Every code unit of
/// the text stays in the result; only line breaks become separate lines.
fn wrap(
  text : String,
  font : @metrics.FontMetrics,
  max_width : Double,
  budget : Budget,
) -> Array[String] {
  let lines = []
  for segment in split_breaks(text) {
    let n = segment.length()
    if n == 0 {
      lines.push("")
      continue
    }
    let mut start = 0
    while start < n {
      let mut end = start
      let mut after_space = -1
      while end < n {
        let c = segment.code_unit_at(end).to_int()
        let next = end +
          (if c >= 0xd800 && c <= 0xdbff && end + 1 < n { 2 } else { 1 })
        if !budget.charge(next - start) {
          return lines
        }
        let candidate = segment
          .view(start_offset=start, end_offset=next)
          .to_owned()
        if end > start && font.measure(candidate).width.to_double() > max_width {
          break
        }
        if c == 32 {
          after_space = next
        }
        end = next
      }
      if end < n && after_space > start {
        end = after_space
      }
      lines.push(segment.view(start_offset=start, end_offset=end).to_owned())
      start = end
    }
  }
  lines
}

///|
priv struct Text {
  lines : Array[String]
  width : Double
  height : Double
  size : Int32
  weight : Int32
  ink : Ink
}

///|
fn measure_text(
  text : String,
  font : @metrics.FontMetrics,
  size : Int32,
  weight : Int32,
  ink : Ink,
  max_width : Double,
  budget : Budget,
) -> Text {
  let lines = wrap(text, font, max_width, budget)
  let mut width = 0.0
  for line in lines {
    if !budget.charge(line.length() + 1) {
      break
    }
    let w = font.measure(line).width.to_double()
    if w > width {
      width = w
    }
  }
  let height = lines.length().to_double() *
    (if size == title_size { title_line_height } else { line_height })
  { lines, width, height, size, weight, ink, }
}

///|
fn Text::place(self : Text, x : Double, y : Double) -> Label {
  {
    lines: ReadOnlyArray::from_array(self.lines),
    box: { x, y, width: self.width, height: self.height, },
    size: self.size.to_double(),
    weight: self.weight,
    ink: self.ink,
  }
}

///|
priv struct MeasuredRow {
  entry : @model.Member
  kind : Kind
  key : Text
  value : Text?
  offset : Double
  height : Double
}

///|
priv struct Measured {
  kind : Kind
  depth : Int32
  width : Double
  height : Double
  key_width : Double
  rows : Array[MeasuredRow]
  label : Text?
}

///|
fn failure(diagnostics : ArrayView[@diagrams.Diagnostic]) -> Result {
  { geometry: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
}

///|
/// Measured data geometry. Each container is a box with ordered rows;
/// arrays show the position of each row. A nested container is a separate
/// box in the next column, joined by a connector from its row. Inline
/// scalars stay in their row, with no connector. Empty containers and a
/// scalar root are visible boxes. Layout is iterative and every bound is
/// explicit; exhaustion gives a diagnostic and no geometry.
pub fn layout(
  tree : @model.DataTree,
  limits~ : Limits = Limits::new(),
) -> Result {
  let diagnostics : Array[@diagrams.Diagnostic] = []
  if limits.nodes <= 0 ||
    limits.depth <= 0 ||
    limits.work <= 0 ||
    limits.width <= 0 ||
    limits.output_units <= 0 {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "data-tree/invalid-limits", "Data-tree layout limits must be positive",
      ),
    )
    return failure(diagnostics)
  }
  let indexed = @model.Index::build(
    tree,
    limits=@model.Limits::new(
      nodes=limits.nodes,
      depth=limits.depth,
      work=limits.work,
    ),
  )
  guard indexed.index is Some(index) else {
    return failure(indexed.diagnostics.iter().to_array())
  }
  let budget : Budget = {
    limit: limits.work,
    diagnostics,
    used: 0,
    failed: false,
  }
  let max_width = limits.width.to_double()
  let regular = metrics(font_size, 400)
  let bold = metrics(font_size, 700)
  let heading = metrics(title_size, 700)
  let row_offset : Map[String, Double] = Map([])
  let marked_members : Map[String, Bool] = Map([])
  let marked_nodes : Map[String, Bool] = Map([])
  for highlight in tree.highlights {
    for target in highlight.targets {
      if index.find_member(target) is Some(_) {
        marked_members[target] = true
      } else {
        marked_nodes[target] = true
      }
    }
  }
  // A highlighted inline scalar marks its row.
  for id, _ in marked_nodes {
    if index.node(id) is Some(node) &&
      !node.is_container() &&
      index.owner(id) is Some(owner) {
      marked_members[owner.id] = true
    }
  }
  let measured : Map[String, Measured] = Map([])
  let order : Array[String] = []
  for id in index.order {
    if !budget.charge(1) {
      return failure(diagnostics)
    }
    let node = index.node(id).unwrap()
    if !node.is_container() && id != tree.root {
      continue
    }
    order.push(id)
    let kind = kind_of(node.value)
    let depth = index.depth(id).unwrap_or(0)
    let members = node.members()
    if members.is_empty() {
      let text = match node.value {
        Object(_) => "{}"
        Array(_) => "[]"
        value => display_text(value)
      }
      let label = measure_text(
        text,
        regular,
        font_size,
        400,
        ink_of(kind),
        max_width,
        budget,
      )
      measured[id] = {
        kind,
        depth,
        width: (label.width + 2.0 * pad_x).max(32.0),
        height: label.height + 2.0 * pad_y,
        key_width: 0.0,
        rows: [],
        label: Some(label),
      }
      continue
    }
    let rows = []
    let mut key_width = 0.0
    let mut value_width = min_value_width
    let mut offset = 0.0
    for entry in members {
      let value = index.node(entry.value).unwrap()
      let value_kind = kind_of(value.value)
      let key = match entry.key {
        Name(name) =>
          measure_text(name, bold, font_size, 700, Key, max_width, budget)
        Index(i) =>
          measure_text(
            "[\{i}]",
            regular,
            font_size,
            400,
            Index,
            max_width,
            budget,
          )
      }
      let text = display_text(value.value)
      let value_text = if text.is_empty() {
        None
      } else {
        Some(
          measure_text(
            text,
            regular,
            font_size,
            400,
            ink_of(value_kind),
            max_width,
            budget,
          ),
        )
      }
      if budget.failed {
        return failure(diagnostics)
      }
      key_width = key_width.max(key.width)
      let value_height = match value_text {
        Some(t) => {
          value_width = value_width.max(t.width)
          t.height
        }
        None => line_height
      }
      let height = key.height.max(value_height) + 2.0 * pad_y
      rows.push({
        entry,
        kind: value_kind,
        key,
        value: value_text,
        offset,
        height,
      })
      row_offset[entry.id] = offset
      offset += height
    }
    measured[id] = {
      kind,
      depth,
      width: key_width + value_width + 4.0 * pad_x,
      height: offset,
      key_width,
      rows,
      label: None,
    }
  }
  // Column positions from the widest box of each depth.
  let columns : Array[Double] = []
  for id in order {
    let m = measured[id]
    while columns.length() <= m.depth {
      columns.push(0.0)
    }
    columns[m.depth] = columns[m.depth].max(m.width)
  }
  let column_x : Array[Double] = []
  let mut x = margin
  for width in columns {
    column_x.push(x)
    x += width + column_gap
  }
  let title = tree.title.map(text => {
    measure_text(text, heading, title_size, 700, Title, max_width * 2.0, budget).place(
      margin, margin,
    )
  })
  if budget.failed {
    return failure(diagnostics)
  }
  let top = margin + title.map(t => t.box.height + 12.0).unwrap_or(0.0)
  let free : Array[Double] = Array::make(columns.length(), top)
  let placed_y : Map[String, Double] = Map([])
  for id in order {
    if !budget.charge(1) {
      return failure(diagnostics)
    }
    let m = measured[id]
    let wanted = match index.owner(id) {
      None => top
      Some(owner) => {
        let parent = index.container(owner.id).unwrap()
        placed_y[parent] + row_offset[owner.id]
      }
    }
    let y = wanted.max(free[m.depth])
    placed_y[id] = y
    free[m.depth] = y + m.height + box_gap
  }
  let boxes : Array[Box] = []
  let connectors : Array[Connector] = []
  let mut height = top
  let mut width = margin
  for id in order {
    if !budget.charge(1) {
      return failure(diagnostics)
    }
    let m = measured[id]
    let bx = column_x[m.depth]
    let by = placed_y[id]
    let frame : Rect = { x: bx, y: by, width: m.width, height: m.height, }
    height = height.max(frame.bottom())
    width = width.max(frame.right())
    let divider = bx + m.key_width + 2.0 * pad_x
    let rows = []
    for row in m.rows {
      let ry = by + row.offset
      let row_box : Rect = { x: bx, y: ry, width: m.width, height: row.height, }
      let child = measured.get(row.entry.value)
      let port : Point? = child.map(_ => {
        x: frame.right(),
        y: ry + row.height / 2.0,
      })
      rows.push({
        entry: row.entry.id,
        node: row.entry.value,
        kind: row.kind,
        box: row_box,
        key: Some(row.key.place(bx + pad_x, ry + pad_y)),
        value: row.value.map(t => t.place(divider + pad_x, ry + pad_y)),
        highlighted: marked_members.contains(row.entry.id),
        port,
      })
      if child is Some(c) && port is Some(start) {
        let cy = placed_y[row.entry.value]
        let anchor = cy +
          c.rows.get(0).map(r => r.height).unwrap_or(c.height) / 2.0
        let column_right = column_x[m.depth] + columns[m.depth]
        let target_x = column_x[c.depth]
        let bend = (target_x - column_right) / 2.0
        connectors.push({
          entry: row.entry.id,
          source: id,
          target: row.entry.value,
          points: [
            start,
            { x: column_right, y: start.y, },
            { x: column_right + bend, y: start.y, },
            { x: target_x - bend, y: anchor, },
            { x: target_x, y: anchor, },
          ],
        })
      }
    }
    boxes.push({
      node: id,
      kind: m.kind,
      box: frame,
      divider: if m.rows.is_empty() {
        None
      } else {
        Some(divider)
      },
      rows: ReadOnlyArray::from_array(rows),
      label: m.label.map(t => t.place(bx + pad_x, by + pad_y)),
      highlighted: marked_nodes.contains(id),
      depth: m.depth,
    })
  }
  if title is Some(t) {
    width = width.max(t.box.right())
  }
  let total_width = (width + margin).ceil()
  let total_height = (height + margin).ceil()
  if total_width > 16777216.0 || total_height > 16777216.0 {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "data-tree/layout-limit", "Data-tree geometry exceeds its safe numeric bound",
      ),
    )
    return failure(diagnostics)
  }
  {
    geometry: Some({
      tree,
      width: total_width.to_int(),
      height: total_height.to_int(),
      title,
      boxes: ReadOnlyArray::from_array(boxes),
      connectors: ReadOnlyArray::from_array(connectors),
    }),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
