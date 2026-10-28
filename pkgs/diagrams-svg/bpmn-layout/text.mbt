///|
fn normal_text(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
fn default_font() -> @model.Font {
  @model.Font::new(size=number(13.0))
}

///|
fn font_size(font : @model.Font, budget : Budget) -> Double? {
  match font.size {
    None => Some(13.0)
    Some(value) => {
      if !budget.charge(value.token.length()) {
        return None
      }
      match coordinate(value) {
        Some(n) if n >= 0.0 && n <= 1000000.0 => Some(n)
        _ => {
          budget.error(
            "bpmn/invalid-geometry", "Font size must be nonnegative, finite and bounded",
          )
          None
        }
      }
    }
  }
}

///|
fn measure(
  text : String,
  font : @model.Font,
  budget : Budget,
) -> (Double, Double)? {
  guard font_size(font, budget) is Some(size) else { return None }
  if !budget.charge(text.length()) {
    return None
  }
  let size_int = Double::max(1.0, size.ceil()).to_int()
  if text.length() > 1000000000 / size_int {
    budget.error(
      "bpmn/layout-limit", "Measured text extent exceeded its safe range",
    )
    return None
  }
  let metrics = @metrics.FontMetrics::from_defaults(
    profile=Monospace,
    font_size=size_int,
    font_weight=if font.bold.unwrap_or(false) { 700 } else { 400 },
  )
  let mut width = 0
  for line in normal_text(text).split("\n") {
    width = Int32::max(width, metrics.measure(line.to_owned()).width)
  }
  Some(
    (
      width.to_double(),
      normal_text(text).split("\n").count().to_double() * (size + 4.0),
    ),
  )
}

///|
fn node_label(
  node : @model.Node,
  box : Rect,
  supplied : Bool,
  budget : Budget,
) -> Label? {
  let label = node.geometry.bind(g => g.label)
  let properties = node.properties
  let text = normal_text(
    node.label +
    properties.bind(p => p.sublabel).map(s => "\n" + s).unwrap_or(""),
  )
  if text.is_empty() {
    return None
  }
  let font = if supplied {
    label.bind(l => l.font).unwrap_or_else(default_font)
  } else {
    default_font()
  }
  guard measure(text, font, budget) is Some((width, height)) &&
    font_size(font, budget) is Some(size) else {
    return None
  }
  let bounds = if supplied { label.bind(l => l.bounds) } else { None }
  let horizontal = node.geometry.bind(g => g.horizontal).unwrap_or(true)
  let rotation = if (node.kind == Participant || node.kind == Lane) &&
    horizontal &&
    bounds == None {
    -90
  } else {
    0
  }
  let fallback : Rect = if rotation == -90 {
    {
      x: box.x + 6.0,
      y: box.y + (box.height - width) / 2.0,
      width: height,
      height: width,
    }
  } else if node.kind == Participant || node.kind == Lane {
    { x: box.x + (box.width - width) / 2.0, y: box.y + 8.0, width, height, }
  } else if (
      node.kind == SubProcess ||
      node.kind == AdHocSubProcess ||
      node.kind == Transaction ||
      node.kind == CallActivity
    ) &&
    node.expanded.unwrap_or(false) {
    { x: box.x + (box.width - width) / 2.0, y: box.y + 8.0, width, height, }
  } else if event(node.kind) ||
    gateway(node.kind) ||
    [
      @model.NodeKind::DataObject,
      DataObjectReference,
      DataStore,
      DataStoreReference,
      DataInput,
      DataOutput,
      Message,
    ].contains(node.kind) {
    {
      x: box.x + (box.width - width) / 2.0,
      y: box.y + box.height + 8.0,
      width,
      height,
    }
  } else if node.kind == Group {
    { x: box.x + 12.0, y: box.y - 8.0 - height, width, height, }
  } else {
    {
      x: box.x + (box.width - width) / 2.0,
      y: box.y + (box.height - height) / 2.0,
      width,
      height,
    }
  }
  let actual = match bounds {
    Some(r) =>
      match rectangle(r) {
        Some(r) => r
        None => {
          budget.error(
            "bpmn/invalid-geometry",
            "Invalid label bounds on \{node.id}",
          )
          return None
        }
      }
    None => fallback
  }
  Some({
    text,
    font,
    bounds,
    box: actual,
    size,
    weight: if font.bold.unwrap_or(false) {
      700
    } else {
      400
    },
    rotation,
    mask: bounds != None || !activity(node.kind),
    owner: node.id,
    family: Some(family(node.kind)),
  })
}

///|
fn flow_label(
  flow : @model.Flow,
  line : ArrayView[Point],
  supplied : Bool,
  budget : Budget,
) -> Label? {
  let text = normal_text(
    flow.label +
    flow.properties.bind(p => p.sublabel).map(s => "\n" + s).unwrap_or(""),
  )
  if text.is_empty() {
    return None
  }
  let label = flow.geometry.bind(g => g.label)
  let font = if supplied {
    label.bind(l => l.font).unwrap_or_else(default_font)
  } else {
    default_font()
  }
  guard measure(text, font, budget) is Some((width, height)) &&
    font_size(font, budget) is Some(size) else {
    return None
  }
  let bounds = if supplied { label.bind(l => l.bounds) } else { None }
  let center = midpoint(line).unwrap()
  let box = match bounds {
    Some(r) =>
      match rectangle(r) {
        Some(r) => r
        None => {
          budget.error(
            "bpmn/invalid-geometry",
            "Invalid connection label bounds on \{flow.id}",
          )
          return None
        }
      }
    None =>
      { x: center.x - width / 2.0, y: center.y - height - 8.0, width, height, }
  }
  Some({
    text,
    font,
    bounds,
    box,
    size,
    weight: if font.bold.unwrap_or(false) {
      700
    } else {
      400
    },
    rotation: 0,
    mask: true,
    owner: flow.id,
    family: None,
  })
}
