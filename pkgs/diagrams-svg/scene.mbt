///|
pub struct PathBinding {
  occurrence : @animation.Occurrence
  id : String
  path : String
}

///|
pub(all) enum NodeBindingKind {
  Bpmn(String)
  Message(Int32)
  Frame(Int32)
  Swimlane(String)
} derive(Eq, Debug)

///|
pub extend NodeBindingKind with Eq::{equal, not_equal}

///|
pub extend NodeBindingKind with @debug.Debug::{to_repr}

///|
pub struct NodeBinding {
  endpoint : String
  kind : NodeBindingKind
}

///|
pub struct Scene {
  canonical_svg : String
  display_svg : String
  catalog : @animation.Catalog
  paths : ReadOnlyArray[PathBinding]
  nodes : ReadOnlyArray[NodeBinding]
}

///|
pub struct SceneResult {
  scene : Scene?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn scene_prefix(canonical : String) -> String {
  let mut hash : UInt64 = 14695981039346656037
  for i in 0..<canonical.length() {
    hash = (hash ^ canonical.code_unit_at(i).to_int().to_uint64()) *
      1099511628211
  }
  "motion-\{hash.to_string(radix=16)}-"
}

///|
fn sequence_scene_input(
  sequence : @sequence.Sequence,
  limits : @animation.Limits,
) -> Bool {
  if sequence.participants.length() > limits.nodes {
    return false
  }
  let mut used = 0
  fn text(value : String) -> Bool {
    if value.length() > limits.work - used {
      return false
    }
    used += value.length()
    true
  }
  for
    value in sequence.title
    .iter()
    .concat(sequence.accessibility_title.iter())
    .concat(sequence.accessibility_description.iter()) {
    if !text(value) {
      return false
    }
  }
  for participant in sequence.participants {
    if !text(participant.id) || !text(participant.label) {
      return false
    }
    if participant.link is Some(link) && !text(link.target) {
      return false
    }
    if participant.group is Some(group) &&
      (
        !text(group.id) ||
        !text(group.label) ||
        !text(group.colour.unwrap_or(""))
      ) {
      return false
    }
    if participant.properties is Some(properties) &&
      (
        !text(properties.sublabel.unwrap_or("")) ||
        !text(properties.description.unwrap_or(""))
      ) {
      return false
    }
  }
  let stack = sequence.events.iter().to_array()
  while stack.pop() is Some(event) {
    if used >= limits.work {
      return false
    }
    used += 1
    match event {
      Message(message) => {
        if !text(message.sender) ||
          !text(message.receiver) ||
          !text(message.label) {
          return false
        }
        if message.link is Some(link) && !text(link.target) {
          return false
        }
        if message.properties is Some(properties) &&
          (
            !text(properties.sublabel.unwrap_or("")) ||
            !text(properties.description.unwrap_or(""))
          ) {
          return false
        }
      }
      Note(note) => {
        if !text(note.text) {
          return false
        }
        for id in note.participants {
          if !text(id) {
            return false
          }
        }
      }
      Activate(id) | Deactivate(id) | Create(id) | Destroy(id) =>
        if !text(id) {
          return false
        }
      Frame(frame) => {
        if !text(frame.colour.unwrap_or("")) {
          return false
        }
        for section in frame.sections {
          if !text(section.label.unwrap_or("")) ||
            section.events.length() > limits.work - used {
            return false
          }
          stack.append(section.events)
        }
      }
      Autonumber(_) => ()
    }
  }
  true
}

///|
fn sequence_path(message : @layout.MessageLine, limit : Int32) -> String? {
  let result = StringBuilder()
  let mut used = 0
  for i, segment in message.path {
    let part = if i == 0 {
      "M\{segment.x1} \{segment.y1} L\{segment.x2} \{segment.y2}"
    } else {
      " L\{segment.x2} \{segment.y2}"
    }
    if part.length() > limit - used {
      return None
    }
    used += part.length()
    result.write_string(part)
  }
  Some(result.to_string())
}

///|
/// Both copies and their motion bindings use one measured geometry. Ordinary
/// render output remains the canonical artifact; only the display copy gains
/// invisible, scoped numeric paths. No scripts or active references are added.
pub fn SvgRenderer::scene(
  self : SvgRenderer,
  diagram : @render.Diagram,
  sequence_view_id~ : String = "sequence",
  limits~ : @animation.Limits = @animation.Limits::new(),
  output_units~ : Int32 = 33554432,
) -> SceneResult {
  fn failed(code : String, message : String) -> SceneResult {
    { scene: None, diagnostics: [@diagrams.Diagnostic::error(code, message)], }
  }
  if output_units <= 0 {
    return failed(
      "animation/scene-limit", "Scene output limit must be positive",
    )
  }
  let catalog_result = match diagram {
    Swimlane(view) => @animation.Catalog::swimlane(view, limits~)
    Bpmn(view) => @animation.Catalog::bpmn(view, limits~)
    Sequence(sequence) =>
      @animation.Catalog::sequence(sequence, view_id=sequence_view_id, limits~)
  }
  guard catalog_result.catalog is Some(catalog) else {
    return { scene: None, diagnostics: catalog_result.diagnostics, }
  }
  let paths : Array[(@animation.Occurrence, String)] = []
  let nodes : Array[NodeBinding] = []
  let (rendered, bpmn) = match diagram {
    Swimlane(view) => {
      let geometry = @swimlane_layout.layout(view, limits=self.swimlane_limits)
      let rendered = paint_swimlane(
        view,
        self.theme,
        self.mode,
        self.id_prefix,
        self.swimlane_limits,
        precomputed=geometry,
      )
      guard geometry.geometry is Some(geometry) && rendered.output is Some(_) else {
        return { scene: None, diagnostics: rendered.diagnostics, }
      }
      let edges = Map([])
      for edge in geometry.connections {
        edges[edge.connection.id] = edge
      }
      for occurrence in catalog.occurrences {
        guard occurrence.swimlane_connection is Some(connection) &&
          edges.get(connection.id) is Some(edge) else {
          return failed(
            "animation/binding-mismatch", "A swimlane connection has no visible rendered path",
          )
        }
        let path = swimlane_path(edge)
        if path.length() > output_units {
          return failed(
            "animation/scene-limit", "Swimlane scene path exceeds its output limit",
          )
        }
        paths.push((occurrence, path))
      }
      for node in catalog.graph.nodes {
        nodes.push({ endpoint: node.id, kind: Swimlane(node.id), })
      }
      (rendered, false)
    }
    Bpmn(view) => {
      let geometry = @bpmn_layout.layout(
        view,
        policy=self.bpmn_policy,
        limits=self.bpmn_limits,
      )
      let rendered = paint_bpmn(
        view,
        self.theme,
        self.mode,
        self.id_prefix,
        self.bpmn_policy,
        self.bpmn_limits,
        precomputed=geometry,
      )
      guard geometry.geometry is Some(geometry) && rendered.output is Some(_) else {
        return { scene: None, diagnostics: rendered.diagnostics, }
      }
      let edges = Map([])
      for edge in geometry.connections {
        edges[edge.flow.id] = edge
      }
      for occurrence in catalog.occurrences {
        guard occurrence.flow is Some(flow) && edges.get(flow.id) is Some(edge) else {
          return failed(
            "animation/binding-mismatch", "A catalog connection has no visible rendered path",
          )
        }
        guard bpmn_geometry_path(edge, max_units=output_units) is Some(path) else {
          return failed(
            "animation/scene-limit", "Scene path exceeds its output limit",
          )
        }
        paths.push((occurrence, path))
      }
      for node in catalog.graph.nodes {
        if node.source_node is Some(source) {
          nodes.push({ endpoint: node.id, kind: Bpmn(source.id), })
        }
      }
      (rendered, true)
    }
    Sequence(sequence) => {
      if !sequence_scene_input(sequence, limits) {
        return failed(
          "animation/scene-limit", "Sequence scene input exceeds its node/text work bound",
        )
      }
      let geometry = @layout.layout(sequence)
      let (svg, diagnostics) = paint(
        sequence,
        self.theme,
        self.mode,
        self.id_prefix,
        geometry~,
      )
      let messages = Map([])
      for message in geometry.messages {
        messages[message.index] = message
      }
      for occurrence in catalog.occurrences {
        guard messages.get(occurrence.index) is Some(message) &&
          sequence_path(message, output_units) is Some(path) else {
          return failed(
            "animation/binding-mismatch", "A message occurrence has no rendered path",
          )
        }
        paths.push((occurrence, path))
        nodes.push({
          endpoint: occurrence.key,
          kind: Message(occurrence.index),
        })
      }
      for i, frame in catalog.frames {
        nodes.push({ endpoint: frame.key + ":in", kind: Frame(i), })
        nodes.push({ endpoint: frame.key + ":out", kind: Frame(i), })
      }
      (@render.Rendered::ok(svg, "image/svg+xml", diagnostics~), false)
    }
  }
  let canonical = rendered.output.unwrap()
  let prefix = scene_prefix(canonical)
  let bindings : Array[PathBinding] = []
  let elements = []
  let mut units = canonical.length()
  for i, (occurrence, path) in paths {
    let id = prefix + i.to_string()
    let element = @writer.element("path", attrs=[
      ("id", id),
      ("d", path),
      ("fill", "none"),
      ("stroke", "none"),
      ("pointer-events", "none"),
      ("aria-hidden", "true"),
    ])
    let size = path.length() + id.length() + 256
    if size > output_units - units {
      return failed(
        "animation/scene-limit", "Scene bindings exceed their output limit",
      )
    }
    units += size
    elements.push(element)
    bindings.push({ occurrence, id, path, })
  }
  let extra = @writer.to_string(
    @writer.element(
      "g",
      attrs=[("data-motion-paths", "true"), ("aria-hidden", "true")],
      children=elements,
    ),
  )
  if canonical.length() > output_units - canonical.length() - extra.length() {
    return failed(
      "animation/scene-limit", "Canonical and display copies exceed the scene output limit",
    )
  }
  let closing = if bpmn { "</g>" } else { "</svg>" }
  guard canonical.rev_find(closing) is Some(cut) else {
    return failed(
      "animation/binding-mismatch", "Rendered SVG is missing its scene container",
    )
  }
  let display = canonical[:cut].to_owned() + extra + canonical[cut:].to_owned()
  {
    scene: Some({
      canonical_svg: canonical,
      display_svg: display,
      catalog,
      paths: ReadOnlyArray::from_array(bindings),
      nodes: ReadOnlyArray::from_array(nodes),
    }),
    diagnostics: rendered.diagnostics,
  }
}
