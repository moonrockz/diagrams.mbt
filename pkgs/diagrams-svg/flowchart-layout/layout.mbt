///|
/// Flowcharts share vector geometry primitives with the swimlane layout engine.
/// The adapter preserves ordinary groups and introduces no responsibility lanes.
pub struct Limits {
  nodes : Int32
  edges : Int32
  depth : Int32
  work : Int32
  output_units : Int32
  width : Int32
  height : Int32
  minimum_approach : Double
} derive(Eq, Debug)

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
  output_units~ : Int32 = 16777216,
  width~ : Int32 = 1000000,
  height~ : Int32 = 1000000,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, edges, depth, work, output_units, width, height, }
}

///|
pub struct Connection {
  connection : @model.Connection
  index : Int32
  source : String
  target : String
  line : ReadOnlyArray[@geometry.Point]
  label : @geometry.Label?
} derive(Eq, Debug)

///|
pub struct Geometry {
  view : @model.Flowchart
  shapes : ReadOnlyArray[@geometry.Shape]
  connections : ReadOnlyArray[Connection]
  width : Int32
  height : Int32
  priv drawing : @geometry.Geometry
  priv drawing_result : @geometry.Result
  priv prior_diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
  priv intentional : ReadOnlyArray[(String, String)]
  priv hidden_containers : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
pub struct Result {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
fn vector_direction(value : @model.Direction) -> @vector.Direction {
  match value {
    TB => TB
    BT => BT
    LR => LR
    RL => RL
  }
}

///|
fn vector_label(value : @model.LabelKind) -> @vector.LabelKind {
  match value {
    Text => Text
    Markdown => Markdown
    Html => Html
  }
}

///|
fn vector_marker(value : @model.Marker) -> @vector.Marker {
  match value {
    None => None
    Arrow => Arrow
    Circle => Circle
    Cross => Cross
  }
}

///|
fn vector_style(value : @model.LineStyle) -> @vector.LineStyle {
  match value {
    Solid => Solid
    Dotted => Dotted
    Thick => Thick
    Invisible => Invisible
  }
}

///|
pub fn diagnostics(
  values : ArrayView[@diagrams.Diagnostic],
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  ReadOnlyArray::from_array(
    values.map(d => {
      ..d,
      code: d.code.replace_all(old="swimlane/", new="flowchart/"),
      message: d.message
      .replace_all(old="Swimlane", new="Flowchart")
      .replace_all(old="swimlane", new="flowchart"),
    }),
  )
}

///|
pub fn layout(
  view : @model.Flowchart,
  limits~ : Limits = Limits::new(),
  ordered_scopes~ : ArrayView[(String,@model.Direction)] = [],
  region_directions~ : ArrayView[(String,@model.Direction)] = [],
  scope_padding~ : Double = 0.0,
) -> Result {
  fn failed(code : String, message : String) -> Result {
    {
      geometry: None,
      diagnostics: [@diagrams.Diagnostic::error(code, message)],
    }
  }
  if limits.nodes <= 0 ||
    limits.edges <= 0 ||
    limits.depth <= 0 ||
    limits.work <= 0 ||
    limits.output_units <= 0 ||
    limits.width <= 0 ||
    limits.height <= 0 {
    return failed(
      "flowchart/layout-limit", "Flowchart layout limits must be positive",
    )
  }
  let findings = @model.validate(
    view,
    nodes_limit=limits.nodes,
    edges_limit=limits.edges,
    depth_limit=limits.depth,
    work_limit=limits.work,
  )
  if !findings.is_empty() {
    return { geometry: None, diagnostics: findings, }
  }
  let groups : Map[String, @model.Group] = Map([])
  let ownership : Map[String, Array[String?]] = Map([])
  let group_members : Map[String, Array[String]] = Map([])
  let source_groups : Map[String, ReadOnlyArray[String]] = Map([])
  let group_children : Map[String, Array[String]] = Map([])
  for group in view.groups {
    groups[group.id] = group
    ownership[group.id] = []
    group_members[group.id] = []
    group_children[group.id] = []
  }
  for group in view.groups {
    if group.parent is Some(parent) {
      group_children[parent].push(group.id)
    }
  }
  fn register(
    path : ReadOnlyArray[String],
    lane : String?,
    member_id : String,
  ) {
    for id in path {
      let found = ownership[id]
      if found.length() < 2 && !found.contains(lane) {
        found.push(lane)
      }
      group_members[id].push(member_id)
    }
  }
  for node in view.nodes {
    register(node.groups, node.lane, node.id)
    source_groups[node.id] = node.groups
  }
  for note in view.notes {
    register(note.groups, note.lane, note.id)
  }
  let crossing : Map[String, Bool] = Map([])
  for group in view.groups {
    if ownership[group.id].length() > 1 {
      crossing[group.id] = true
    }
  }
  fn collapsed(path : ReadOnlyArray[String]) -> String? {
    for id in path {
      if crossing.contains(id) && !groups[id].expanded {
        return Some(id)
      }
    }
    None
  }
  fn path_for(path : ReadOnlyArray[String]) -> Array[String] {
    let closed = collapsed(path)
    let mut entered = false
    let result = []
    for id in path {
      if Some(id) == closed {
        entered = true
      }
      if !crossing.contains(id) || (entered && Some(id) == closed) {
        result.push(id)
      }
    }
    result
  }
  let path_cache : Map[String, Array[String]] = Map([])
  fn group_path(id : String) -> Array[String] {
    if path_cache.get(id) is Some(path) {
      return path
    }
    let result = []
    let mut cursor = groups[id].parent
    while cursor is Some(parent) {
      result.push(parent)
      cursor = groups[parent].parent
    }
    let ordered = []
    for i = result.length() - 1; i >= 0; i = i - 1 {
      ordered.push(result[i])
    }
    path_cache[id] = ordered
    ordered
  }
  fn group_lane(id : String) -> String? {
    let path = group_path(id)
    if collapsed(ReadOnlyArray::from_array(path)) != None ||
      crossing.contains(id) {
      return None
    }
    let mut cursor = Some(id)
    while cursor is Some(current) {
      if groups[current].lane is Some(lane) {
        return Some(lane)
      }
      let found = ownership[current]
      if found.length() == 1 && found[0] is Some(lane) {
        return Some(lane)
      }
      if crossing.contains(current) {
        return None
      }
      cursor = groups[current].parent
    }
    None
  }
  let intentional : Array[(String, String)] = []
  for node in view.nodes {
    for id in node.groups {
      intentional.push((node.id, id))
      if node.lane is Some(lane) {
        intentional.push((lane, id))
      }
    }
  }
  for note in view.notes {
    for id in note.groups {
      intentional.push((note.id, id))
      if note.lane is Some(lane) {
        intentional.push((lane, id))
      }
    }
  }
  for group in view.groups {
    for parent in group_path(group.id) {
      intentional.push((group.id, parent))
    }
  }
  let nodes : Array[@vector.Node] = view.nodes
    .map(n => {
      @vector.Node::new(
        n.id,
        label=n.label,
        label_kind=vector_label(n.label_kind),
        shape=n.shape,
        metadata=n.metadata[:],
        lane?=if collapsed(n.groups) == None { n.lane } else { None },
        groups=path_for(n.groups)[:],
        properties?=n.properties.map(p => {
          @vector.RenderProperties::new(link?=p.link, metadata=p.metadata[:])
        }),
      )
    })
    .iter()
    .to_array()
  let connections : Array[@model.Connection] = view.connections
    .iter()
    .to_array()
  let used : Map[String, Bool] = Map([])
  for n in view.nodes {
    used[n.id] = true
  }
  for g in view.groups {
    used[g.id] = true
  }
  for l in view.lanes {
    used[l.id] = true
  }
  for e in connections {
    used[e.id] = true
  }
  for n in view.notes {
    used[n.id] = true
  }
  let mut work = 0
  for i, note in view.notes {
    nodes.push(
      @vector.Node::new(
        note.id,
        label=note.text,
        shape="note",
        lane?=if collapsed(note.groups) == None { note.lane } else { None },
        groups=path_for(note.groups)[:],
      ),
    )
    for j, target in note.targets {
      if connections.length() >= limits.edges {
        return failed(
          "flowchart/layout-limit", "Note attachments exceed the connection limit",
        )
      }
      let stem = "~note:" + i.to_string() + ":" + j.to_string()
      let mut id = stem
      let mut suffix = 0
      while used.contains(id) {
        if work >= limits.work {
          return failed(
            "flowchart/layout-limit", "Note identity work limit exceeded",
          )
        }
        work += 1
        suffix += 1
        id = stem + ":" + suffix.to_string()
      }
      used[id] = true
      connections.push(
        @model.Connection::new(
          id,
          target,
          note.id,
          style=Dotted,
          target_marker=None,
          role=NoteAttachment,
        ),
      )
    }
  }
  let vector_groups = view.groups
    .map(g => {
      @vector.Group::new(
        g.id,
        label=g.label,
        parent?=path_for(ReadOnlyArray::from_array(group_path(g.id))).last(),
        lane?=group_lane(g.id),
        direction?=g.direction.map(vector_direction),
        expanded=g.expanded,
      )
    })
    .iter()
    .to_array()
  let group_indices : Map[String, Int32] = Map([])
  for i, group in vector_groups {
    group_indices[group.id] = i
  }
  let node_indices : Map[String, Int32] = Map([])
  let original_paths : Map[String, ReadOnlyArray[String]] = Map([])
  for i, node in nodes {
    node_indices[node.id] = i
    original_paths[node.id] = node.groups
  }
  let wrappers : Map[String, String] = Map([])
  let wrapper_depth : Map[String, Int32] = Map([])
  let wrapped : Map[String, Array[Int32]] = Map([])
  let hidden_containers = []
  fn replace_path(index : Int32, path : ArrayView[String]) {
    let node = nodes[index]
    nodes[index] = @vector.Node::new(
      node.id,
      label=node.label,
      label_kind=node.label_kind,
      shape=node.shape,
      metadata=node.metadata[:],
      lane?=node.lane,
      groups=path,
      properties?=node.properties,
    )
  }
  for i, note in view.notes {
    let anchor = note.targets
      .get(0)
      .map(x => Some(x))
      .unwrap_or_else(() => {
        note.connection_targets
        .get(0)
        .bind(id => view.connections.iter().find_first(c => c.id == id))
        .map(c => c.source)
      })
    if note.placement != "floating" &&
      anchor is Some(anchor) &&
      node_indices.get(anchor) is Some(anchor_index) &&
      node_indices.get(note.id) is Some(note_index) &&
      original_paths[anchor] == original_paths[note.id] &&
      nodes[anchor_index].lane == nodes[note_index].lane {
      let depth = wrapper_depth.get(anchor).unwrap_or(0) + 1
      if depth > limits.depth - original_paths[anchor].length() {
        return failed(
          "flowchart/layout-limit", "Note placement exceeds the nesting limit",
        )
      }
      wrapper_depth[anchor] = depth
      let stem = "~note-layout:" + i.to_string()
      let mut id = stem
      let mut suffix = 0
      while used.contains(id) {
        if work >= limits.work {
          return failed(
            "flowchart/layout-limit", "Note container identity limit exceeded",
          )
        }
        work += 1
        suffix += 1
        id = stem + ":" + suffix.to_string()
      }
      if nodes.length() + vector_groups.length() + view.lanes.length() >=
        limits.nodes {
        return failed(
          "flowchart/layout-limit", "Note placement containers exceed the node limit",
        )
      }
      used[id] = true
      hidden_containers.push(id)
      let original = original_paths[anchor]
      let direction : @vector.Direction = match note.placement {
        "left" => RL
        "top" => BT
        "bottom" => TB
        _ => LR
      }
      let group = @vector.Group::new(
        id,
        label="",
        parent?=original.last(),
        lane?=nodes[anchor_index].lane,
        direction~,
      )
      group_indices[id] = vector_groups.length()
      vector_groups.push(group)
      let members = wrapped.get(anchor).unwrap_or([anchor_index])
      if wrappers.get(anchor) is Some(previous) {
        let index = group_indices[previous]
        let old = vector_groups[index]
        vector_groups[index] = @vector.Group::new(
          old.id,
          label=old.label,
          parent=id,
          lane?=old.lane,
          direction?=old.direction,
          expanded=old.expanded,
        )
      }
      for index in members {
        let units = nodes[index].groups.length() + original.length() + 2
        if units > limits.work - work {
          return failed(
            "flowchart/layout-limit", "Note placement work limit exceeded",
          )
        }
        work += units
        let path = original.iter().concat([id].iter()).to_array()
        for j = original.length(); j < nodes[index].groups.length(); j = j + 1 {
          path.push(nodes[index].groups[j])
        }
        replace_path(index, path[:])
      }
      replace_path(
        note_index,
        original.iter().concat([id].iter()).to_array()[:],
      )
      members.push(note_index)
      wrapped[anchor] = members
      wrappers[anchor] = id
      if source_groups.get(anchor) is Some(path) {
        for parent in path {
          intentional.push((id, parent))
        }
      }
    }
  }
  let vector = @vector.Swimlane::new(
    view.id,
    nodes[:],
    connections.map(e => {
      @vector.Connection::new(
        e.id,
        e.source,
        e.target,
        label=e.label,
        label_kind=vector_label(e.label_kind),
        style=vector_style(e.style),
        source_marker=vector_marker(e.source_marker),
        target_marker=vector_marker(e.target_marker),
        min_length=e.min_length,
      )
    })[:],
    direction=vector_direction(view.direction),
    lanes=view.lanes.map(l => {
        @vector.Lane::new(
          l.id,
          label=l.label,
          direction?=l.direction.map(vector_direction),
          expanded=l.expanded,
        )
      })[:],
    groups=vector_groups[:],
    title?=view.title,
    accessibility_title?=view.accessibility_title,
    accessibility_description?=view.accessibility_description,
  )
  let direction_hints = view.connections
    .iter()
    .filter_map(e => e.direction_hint.map(d => (e.id, vector_direction(d))))
    .to_array()
  let geometry_limits = @geometry.Limits::new(
    minimum_approach=limits.minimum_approach,
    nodes=limits.nodes,
    edges=limits.edges,
    depth=limits.depth,
    work=limits.work,
    output_units=limits.output_units,
  )
  let initial = @geometry.layout(
    vector,
    limits=geometry_limits,
    flowchart=true,
    ordered_scopes=ordered_scopes.map(p => (p.0,vector_direction(p.1))),
    scope_padding~,
    region_directions=region_directions.map(p => (p.0,vector_direction(p.1))),
    direction_hints~,
  )
  let mut overlay_applied = false
  let framed = match initial.geometry {
    Some(drawing) => {
      let overlays = []
      let ordered = view.groups
        .iter()
        .filter(g => crossing.contains(g.id))
        .to_array()
      ordered.sort_by((a, b) => {
        group_path(b.id).length().compare(group_path(a.id).length())
      })
      for group in ordered {
        let members = group_members[group.id]
          .iter()
          .concat(group_children[group.id].iter())
          .to_array()
        overlays.push(
          @geometry.Overlay::new(group.id, members[:], parent?=group.parent),
        )
      }
      if overlays.is_empty() {
        initial
      } else {
        overlay_applied = true
        drawing.overlay(overlays[:], limits=geometry_limits, direction_hints~)
      }
    }
    None => initial
  }
  let annotations = []
  for i, note in view.notes {
    for j, target in note.connection_targets {
      if connections.length() >= limits.edges {
        return failed(
          "flowchart/layout-limit", "Edge note attachments exceed the connection limit",
        )
      }
      let stem = "~edge-note:" + i.to_string() + ":" + j.to_string()
      let mut id = stem
      let mut suffix = 0
      while used.contains(id) {
        if work >= limits.work {
          return failed(
            "flowchart/layout-limit", "Note identity limit exceeded",
          )
        }
        work += 1
        suffix += 1
        id = stem + ":" + suffix.to_string()
      }
      used[id] = true
      annotations.push(@geometry.ConnectionNote::new(id, target, note.id))
      connections.push(
        @model.Connection::new(
          id,
          target,
          note.id,
          style=Dotted,
          target_marker=None,
          role=NoteAttachment,
        ),
      )
    }
  }
  let prior = if overlay_applied {
    initial.diagnostics.iter().to_array()
  } else {
    []
  }
  if !annotations.is_empty() && framed.geometry is Some(_) {
    prior.append(framed.diagnostics)
  }
  let result = if annotations.is_empty() {
    framed
  } else {
    match framed.geometry {
      Some(drawing) => drawing.annotate(annotations[:], limits=geometry_limits)
      None => framed
    }
  }
  let accumulated = diagnostics(
    prior.iter().concat(result.diagnostics.iter()).to_array()[:],
  )
  guard result.geometry is Some(drawing) else {
    return { geometry: None, diagnostics: accumulated, }
  }
  if drawing.width > limits.width || drawing.height > limits.height {
    return failed(
      "flowchart/layout-limit", "Flowchart dimensions exceed the configured bounds",
    )
  }
  let by_id : Map[String, @model.Connection] = Map([])
  for edge in connections {
    by_id[edge.id] = edge
  }
  let routed = drawing.connections.map(e => Connection::{
    connection: by_id[e.connection.id],
    index: e.index,
    source: e.source,
    target: e.target,
    line: e.line,
    label: e.label,
  })
  {
    geometry: Some({
      view,
      shapes: drawing.shapes,
      connections: routed,
      width: drawing.width,
      height: drawing.height,
      drawing,
      drawing_result: result,
      prior_diagnostics: ReadOnlyArray::from_array(prior),
      intentional: ReadOnlyArray::from_array(intentional),
      hidden_containers: ReadOnlyArray::from_array(hidden_containers),
    }),
    diagnostics: accumulated,
  }
}

///|
/// Shared low-level geometry for the vector painter, separate from the model.
pub fn Geometry::drawing(self : Geometry) -> @geometry.Geometry {
  self.drawing
}

///|
pub fn check(
  geometry : Geometry,
  palette : @theme.Palette,
  work_limit~ : Int32 = 1000000,
) -> ReadOnlyArray[@geometry.Finding] {
  @geometry.check(
    geometry.drawing,
    @geometry.palette(palette),
    work_limit~,
    intentional_containment=geometry.intentional[:],
  )
}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Connection with Eq::{equal, not_equal}

///|
pub extend Connection with @debug.Debug::{to_repr}

///|
pub extend Geometry with Eq::{equal, not_equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
pub extend Result with Eq::{equal, not_equal}

///|
pub extend Result with @debug.Debug::{to_repr}

///|
pub fn Geometry::drawing_result(self : Geometry) -> @geometry.Result {
  self.drawing_result
}

///|
pub fn Geometry::intentional_containment(
  self : Geometry,
) -> ReadOnlyArray[(String, String)] {
  self.intentional
}

///|
pub fn Geometry::hidden_containers(self : Geometry) -> ReadOnlyArray[String] {
  self.hidden_containers
}

///|
/// Findings from geometry phases before the final shared drawing phase.
pub fn Geometry::prior_diagnostics(
  self : Geometry,
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  self.prior_diagnostics
}

///|
/// Retain resource limits while selecting the marked terminal reservation.
pub fn Limits::with_minimum_approach(
  self : Limits,
  minimum_approach : Double,
) -> Limits {
  { ..self, minimum_approach, }
}
