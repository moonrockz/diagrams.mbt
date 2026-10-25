///|
fn layout_failure(diagnostics : ArrayView[@diagrams.Diagnostic]) -> Result {
  { geometry: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
}

///|
fn horizontal(direction : @model.Direction) -> Bool {
  direction == LR || direction == RL
}

///|
fn reversed(direction : @model.Direction) -> Bool {
  direction == BT || direction == RL
}

///|
/// Measured responsibility bands, built bottom-up without recursive ownership walks.
pub fn layout(
  view : @model.Swimlane,
  limits~ : Limits = Limits::new(),
) -> Result {
  let diagnostics = []
  let budget = Budget::{ limits, diagnostics, work: 0, failed: false, }
  let real_count = view.lanes.length() +
    view.groups.length() +
    view.nodes.length()
  let count = real_count + 1
  let unowned = real_count
  if limits.nodes < 0 ||
    limits.edges < 0 ||
    limits.depth < 0 ||
    limits.work <= 0 ||
    limits.output_units <= 0 ||
    real_count > limits.nodes ||
    view.connections.length() > limits.edges {
    budget.error(
      "swimlane/layout-limit", "Swimlane geometry input exceeds its explicit limits",
    )
    return layout_failure(diagnostics)
  }
  fn text(value : String) -> Bool {
    if value.length() > 50000000 {
      budget.error(
        "swimlane/layout-limit", "A text extent exceeds its safe numeric bound",
      )
      return false
    }
    budget.charge(value.length() + 1)
  }
  for
    value in view.title
    .iter()
    .concat(view.accessibility_title.iter())
    .concat(view.accessibility_description.iter()) {
    if !text(value) {
      return layout_failure(diagnostics)
    }
  }
  if !text(view.id) {
    return layout_failure(diagnostics)
  }
  for lane in view.lanes {
    if !text(lane.id) || !text(lane.label) {
      return layout_failure(diagnostics)
    }
  }
  for group in view.groups {
    if !text(group.id) || !text(group.label) {
      return layout_failure(diagnostics)
    }
    for id in group.parent.iter().concat(group.lane.iter()) {
      if !text(id) {
        return layout_failure(diagnostics)
      }
    }
  }
  for node in view.nodes {
    if !text(node.id) || !text(node.label) || !text(node.shape) {
      return layout_failure(diagnostics)
    }
    for id in node.lane.iter().concat(node.groups.iter()) {
      if !text(id) {
        return layout_failure(diagnostics)
      }
    }
  }
  for edge in view.connections {
    for value in [edge.id, edge.source, edge.target, edge.label] {
      if !text(value) {
        return layout_failure(diagnostics)
      }
    }
  }
  let parents = Array::make(count, -1)
  let visible = Array::make(count, true)
  let ids : Map[String, Int32] = Map([])
  let kinds : Array[Kind] = []
  let texts = []
  let shapes = []
  let expanded = []
  let directions : Array[@model.Direction] = []
  let lanes : Array[String?] = []
  let explicit_direction : Array[Bool] = []
  fn add(
    id : String,
    kind : Kind,
    text : String,
    shape : String,
    open : Bool,
    lane : String?,
    direction : @model.Direction?,
  ) {
    ids[id] = kinds.length()
    kinds.push(kind)
    texts.push(text)
    shapes.push(shape)
    expanded.push(open)
    lanes.push(lane)
    directions.push(direction.unwrap_or(view.direction))
    explicit_direction.push(direction != None)
  }
  for lane in view.lanes {
    add(
      lane.id,
      Lane,
      lane.label,
      "rect",
      lane.expanded,
      Some(lane.id),
      lane.direction,
    )
  }
  for group in view.groups {
    add(
      group.id,
      Group,
      group.label,
      "rect",
      group.expanded,
      group.lane,
      group.direction,
    )
  }
  for node in view.nodes {
    if !@model.built_in_shapes.contains(node.shape) {
      budget.error(
        "swimlane/unsupported-shape",
        "Unsupported vector or asset shape \{node.shape} on \{node.id}",
      )
      return layout_failure(diagnostics)
    }
    for (key, value) in node.metadata {
      if !budget.charge(key.length() + value.length() + 1) {
        return layout_failure(diagnostics)
      }
    }
    if node.properties is Some(properties) {
      if !budget.charge(properties.link.map(s => s.length()).unwrap_or(0)) {
        return layout_failure(diagnostics)
      }
      for (key, value) in properties.metadata {
        if !budget.charge(key.length() + value.length() + 1) {
          return layout_failure(diagnostics)
        }
      }
    }
    add(
      node.id,
      Node,
      project_label(node.label, node.label_kind),
      node.shape,
      true,
      node.lane,
      None,
    )
    if node.label_kind != Text {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "swimlane/plain-text-label",
          "Label on \{node.id} uses a safe plain-text projection",
        ),
      )
    }
  }
  add("", Group, "", "rect", true, None, None)
  let group_start = view.lanes.length()
  let node_start = group_start + view.groups.length()
  for i, group in view.groups {
    parents[group_start + i] = group.parent
      .map(id => Some(id))
      .unwrap_or(group.lane)
      .bind(id => ids.get(id))
      .unwrap_or(-1)
  }
  for i, node in view.nodes {
    parents[node_start + i] = node.groups
      .last()
      .map(id => Some(id))
      .unwrap_or(node.lane)
      .bind(id => ids.get(id))
      .unwrap_or(-1)
  }
  let mut has_unowned = false
  for i in 0..<real_count {
    if kinds[i] != Lane && parents[i] == -1 {
      parents[i] = unowned
      has_unowned = true
    }
  }
  visible[unowned] = has_unowned
  for i in 0..<count {
    let mut cursor = parents[i]
    let mut depth = 0
    let seen = Map([])
    let mut direction_found = explicit_direction[i]
    while cursor >= 0 {
      if !budget.charge(1) {
        return layout_failure(diagnostics)
      }
      if cursor != unowned {
        depth += 1
      }
      if cursor == i || seen.contains(cursor) || depth > limits.depth {
        budget.error(
          if depth > limits.depth {
            "swimlane/layout-limit"
          } else {
            "swimlane/ownership-cycle"
          },
          "Invalid or excessive ownership at \{i}",
        )
        return layout_failure(diagnostics)
      }
      seen[cursor] = true
      if !expanded[cursor] {
        visible[i] = false
      }
      if !direction_found && explicit_direction[cursor] {
        directions[i] = directions[cursor]
        direction_found = true
      }
      cursor = parents[cursor]
    }
  }
  let validation = @model.validate(view)
  if validation.iter().any(d => d.severity == @diagrams.Severity::Error) {
    diagnostics.append(validation)
    return layout_failure(diagnostics)
  }
  let children : Map[Int32, Array[Int32]] = Map([])
  for i in 0..<count {
    if visible[i] {
      match children.get(parents[i]) {
        Some(values) => values.push(i)
        None => children[parents[i]] = [i]
      }
    }
  }
  let selected : Array[(Int32, Int32, Int32)] = []
  let graph_links = []
  fn anchor(id : String) -> Int32 {
    let mut i = ids[id]
    while !visible[i] && parents[i] >= 0 {
      if !budget.charge(1) {
        return i
      }
      i = parents[i]
    }
    i
  }
  for i, edge in view.connections {
    if edge.label_kind != Text {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "swimlane/plain-text-label",
          "Connection label on \{edge.id} uses a safe plain-text projection",
        ),
      )
    }
    if !budget.charge(1) {
      return layout_failure(diagnostics)
    }
    let a = anchor(edge.source)
    let b = anchor(edge.target)
    // A hidden internal edge has no visible occurrence. Boundary handoffs retain
    // their logical endpoints in the connection, with a separate display anchor.
    if !visible[a] || !visible[b] || (a == b && edge.source != edge.target) {
      continue
    }
    selected.push((i, a, b))
    graph_links.push((a, b, edge.min_length))
  }
  let members = Array::makei(count, i => i).filter(i => visible[i])
  let global_ranks = weighted_ranks(members, graph_links, budget)
  let subtree_rank = Array::make(count, 0)
  for i in members {
    subtree_rank[i] = global_ranks.get(i).unwrap_or(0)
  }
  let sizes : Array[(Double, Double)] = Array::make(count, (0.0, 0.0))
  let offsets : Array[Point] = Array::make(count, { x: 0.0, y: 0.0, })
  let mut gap = 80.0
  for edge in view.connections {
    let (w, h) = measure(project_label(edge.label, edge.label_kind))
    gap = Double::max(gap, Double::max(w, h) + 56.0)
  }
  for i in members {
    let (w, h) = measure(
      plain_text(texts[i]),
      weight=if kinds[i] == Node { 400 } else { 700 },
    )
    if kinds[i] == Node {
      let inset = ![
        "rect", "rounded", "stadium", "subroutine", "lin-rect", "div-rect", "win-pane",
        "browser", "console", "state", "composite", "text", "tag-rect", "person",
      ].contains(shapes[i])
      let factor = if shapes[i] == "tri" || shapes[i] == "flip-tri" {
        3.0
      } else if inset {
        2.0
      } else {
        1.0
      }
      let mut width = Double::max(112.0, w * factor + 48.0)
      let mut height = Double::max(64.0, h * factor + 40.0)
      if ["circle", "doublecircle", "fr-circ"].contains(shapes[i]) {
        width = Double::max(64.0, (w * w + h * h).sqrt() + 48.0)
        height = width
      }
      if shapes[i] == "bang" {
        height = Double::max(height, 88.0)
      }
      if shapes[i] == "person" {
        height = Double::max(112.0, (h + 40.0) / 0.66)
      }
      if [
          "hourglass", "bolt", "sm-circ", "f-circ", "fr-circ", "cross-circ", "anchor",
          "fork",
        ].contains(shapes[i]) {
        let (gw, gh) = glyph_size(shapes[i], directions[i])
        if shapes[i] == "fork" && horizontal(directions[i]) {
          width = gw + w + 32.0
          height = Double::max(gh, h + 16.0)
        } else {
          width = Double::max(gw, w + 16.0)
          height = gh + h + 32.0
        }
      }
      sizes[i] = (width, height)
    } else {
      sizes[i] = (Double::max(160.0, w + 40.0), Double::max(96.0, h + 56.0))
    }
  }
  let stack = [(-1, false)]
  while stack.pop() is Some((scope, leave)) {
    if !budget.charge(1) {
      return layout_failure(diagnostics)
    }
    let items = children.get(scope).unwrap_or([])
    if !leave {
      stack.push((scope, true))
      for item in items {
        if kinds[item] != Node {
          stack.push((item, false))
        }
      }
      continue
    }
    if scope == -1 {
      // Top-level responsibility bands keep declaration order across the flow.
      let mut cross = 32.0
      let mut length = 0.0
      for item in items {
        length = Double::max(
          length,
          if horizontal(view.direction) {
            sizes[item].0
          } else {
            sizes[item].1
          },
        )
      }
      for item in items {
        if kinds[item] == Lane || item == unowned {
          sizes[item] = if horizontal(view.direction) {
            (length, sizes[item].1)
          } else {
            (sizes[item].0, length)
          }
        }
        offsets[item] = if horizontal(view.direction) {
          { x: 32.0, y: cross, }
        } else {
          { x: cross, y: 32.0, }
        }
        cross += (if horizontal(view.direction) {
            sizes[item].1
          } else {
            sizes[item].0
          }) +
          32.0
      }
      continue
    }
    if items.is_empty() || !expanded[scope] {
      continue
    }
    let dir = directions[scope]
    let axis = horizontal(dir)
    let projected = []
    fn child(index : Int32) -> Int32? {
      let mut cursor = index
      while parents[cursor] != scope {
        if !budget.charge(1) || parents[cursor] < 0 {
          return None
        }
        cursor = parents[cursor]
      }
      Some(cursor)
    }
    for (edge, a, b) in selected {
      if child(a) is Some(a) && child(b) is Some(b) && a != b {
        projected.push((a, b, view.connections[edge].min_length))
      }
    }
    let ranks = weighted_ranks(items, projected, budget)
    let rows : Map[Int32, Array[Int32]] = Map([])
    let row_order = []
    for item in items {
      let rank = ranks.get(item).unwrap_or(0)
      // A scope with its own direction has a explicit_direction rank system. Other lane
      // scopes align cross-lane handoffs to the global structural ranks.
      let rank = if kinds[scope] == Lane && !explicit_direction[scope] {
        Int32::max(rank, subtree_rank[item])
      } else {
        rank
      }
      if !rows.contains(rank) {
        rows[rank] = []
        row_order.push(rank)
      }
      rows[rank].push(item)
    }
    row_order.sort()
    let (header_w, header_h) = if scope == unowned {
      (0.0, 0.0)
    } else {
      measure(plain_text(texts[scope]), weight=700)
    }
    let mut flow = 0.0
    let mut extent = 0.0
    let mut previous_rank = 0
    for rank in row_order {
      if rank > previous_rank + 1 {
        flow += (rank - previous_rank - 1).to_double() * gap
      }
      previous_rank = rank
      let row = rows[rank]
      let mut cross = 0.0
      let mut length = 0.0
      for item in row {
        length = Double::max(
          length,
          if axis {
            sizes[item].0
          } else {
            sizes[item].1
          },
        )
      }
      for item in row {
        offsets[item] = if axis {
          { x: flow, y: cross, }
        } else {
          { x: cross, y: flow, }
        }
        cross += (if axis { sizes[item].1 } else { sizes[item].0 }) + gap
      }
      extent = Double::max(extent, Double::max(0.0, cross - gap))
      flow += length + gap
    }
    flow = Double::max(0.0, flow - gap)
    let pad_x = 32.0
    let pad_y = if scope == unowned { 32.0 } else { header_h + 40.0 }
    let body_w = if axis { flow } else { extent }
    let body_h = if axis { extent } else { flow }
    sizes[scope] = (
      Double::max(header_w + 40.0, body_w + 64.0),
      body_h + pad_y + 32.0,
    )
    for item in items {
      let p = offsets[item]
      let x = if axis && reversed(dir) {
        body_w - p.x - sizes[item].0
      } else {
        p.x
      }
      let y = if !axis && reversed(dir) {
        body_h - p.y - sizes[item].1
      } else {
        p.y
      }
      offsets[item] = { x: x + pad_x, y: y + pad_y, }
    }
    let mut first = true
    for item in items {
      if first || subtree_rank[item] < subtree_rank[scope] {
        subtree_rank[scope] = subtree_rank[item]
        first = false
      }
    }
  }
  if budget.failed {
    return layout_failure(diagnostics)
  }
  let positions = Array::make(count, { x: 0.0, y: 0.0, })
  let stack = children.get(-1).unwrap_or([]).copy()
  while stack.pop() is Some(i) {
    if !budget.charge(1) {
      return layout_failure(diagnostics)
    }
    let parent = if parents[i] >= 0 {
      positions[parents[i]]
    } else {
      Point::{ x: 0.0, y: 0.0, }
    }
    positions[i] = { x: parent.x + offsets[i].x, y: parent.y + offsets[i].y, }
    stack.append(children.get(i).unwrap_or([]))
  }
  let result_shapes : Array[Shape] = []
  let index_ids = Array::make(count, "")
  for (id, i) in ids {
    index_ids[i] = id
  }
  let mut width = 64.0
  let mut height = 64.0
  for i in members {
    if i == unowned {
      continue
    }
    let box : Rect = {
      x: positions[i].x,
      y: positions[i].y,
      width: sizes[i].0,
      height: sizes[i].1,
    }
    let id = index_ids[i]
    let kind = kinds[i]
    let parent = if parents[i] >= 0 && parents[i] != unowned {
      Some(index_ids[parents[i]])
    } else {
      None
    }
    let external = [
      "hourglass", "bolt", "sm-circ", "f-circ", "fr-circ", "cross-circ", "anchor",
      "fork",
    ].contains(shapes[i])
    let (tw, th) = measure(plain_text(texts[i]))
    let (gw, gh) = glyph_size(shapes[i], directions[i])
    let outline_box = if external {
      if shapes[i] == "fork" && horizontal(directions[i]) {
        Rect::{
          x: box.x,
          y: box.y + (box.height - gh) / 2.0,
          width: gw,
          height: gh,
        }
      } else {
        Rect::{
          x: box.x + (box.width - gw) / 2.0,
          y: box.y,
          width: gw,
          height: gh,
        }
      }
    } else {
      box
    }
    let label_box = if external {
      if shapes[i] == "fork" && horizontal(directions[i]) {
        Rect::{
          x: box.x + gw + 24.0,
          y: box.y + (box.height - th) / 2.0,
          width: tw,
          height: th,
        }
      } else {
        Rect::{
          x: box.x + (box.width - tw) / 2.0,
          y: box.y + gh + 24.0,
          width: tw,
          height: th,
        }
      }
    } else if shapes[i] == "cylinder" || shapes[i] == "lin-cyl" {
      let top = if shapes[i] == "lin-cyl" { 0.36 } else { 0.3 }
      Rect::{
        x: box.x,
        y: box.y + box.height * top,
        width: box.width,
        height: box.height * (1.0 - top),
      }
    } else if shapes[i] == "person" {
      Rect::{
        x: box.x,
        y: box.y + box.height * 0.34,
        width: box.width,
        height: box.height * 0.66,
      }
    } else {
      box
    }
    let label = make_label(
      texts[i],
      id,
      label_box,
      kind != Node,
      if kind == Node {
        Some(family(shapes[i]))
      } else {
        None
      },
    )
    result_shapes.push({
      id,
      index: i,
      kind,
      shape: shapes[i],
      box,
      outline_box,
      label,
      parent,
      lane: lanes[i],
      expanded: expanded[i],
    })
    width = Double::max(width, box.x + box.width + 32.0)
    height = Double::max(height, box.y + box.height + 32.0)
  }
  let connections = route_connections(
    view, selected, result_shapes, parents, budget,
  )
  if budget.failed {
    return layout_failure(diagnostics)
  }
  for edge in connections {
    for p in edge.line {
      width = Double::max(width, p.x + 32.0)
      height = Double::max(height, p.y + 32.0)
    }
    if edge.label is Some(label) {
      width = Double::max(width, label.box.x + label.box.width + 32.0)
      height = Double::max(height, label.box.y + label.box.height + 32.0)
    }
  }
  if width > 1000000000.0 || height > 1000000000.0 {
    budget.error(
      "swimlane/layout-limit", "Measured diagram exceeds the coordinate bound",
    )
    return layout_failure(diagnostics)
  }
  {
    geometry: Some({
      view,
      shapes: ReadOnlyArray::from_array(result_shapes),
      connections: ReadOnlyArray::from_array(connections),
      width: width.ceil().to_int(),
      height: height.ceil().to_int(),
    }),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
fn glyph_size(shape : String, direction : @model.Direction) -> (Double, Double) {
  match shape {
    "hourglass" => (96.0, 64.0)
    "bolt" => (64.0, 80.0)
    "sm-circ" => (18.0, 18.0)
    "f-circ" => (24.0, 24.0)
    "fr-circ" => (32.0, 32.0)
    "cross-circ" => (64.0, 64.0)
    "anchor" => (12.0, 12.0)
    "fork" => if horizontal(direction) { (12.0, 84.0) } else { (84.0, 12.0) }
    _ => (0.0, 0.0)
  }
}
