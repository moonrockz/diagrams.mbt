///|
pub struct Conversion {
  diagram : @render.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub extend Conversion with Eq::{equal, not_equal}

///|
pub extend Conversion with @debug.Debug::{to_repr}

///|
priv struct Instance {
  resource : Int32
  root : Int32
  tag : String
  pool : String?
  container : String?
  members : Map[Int32, Bool]
}

///|
priv struct Projection {
  converter : Converter
  instances : Array[Instance]
  nodes : Array[@model.Node]
  flows : Array[@model.Flow]
  visuals : Map[(Int32, Int32, String), Int32]
  selected : Map[(Int32, Int32), Bool]
  di : Map[(Int32, Int32), Array[Int32]]
  di_order : Array[(Int32, Int32)]
  used_di : Map[Int32, Bool]
  shapes : Map[Int32, Array[Int32]]
  visual_order : Array[(Int32, Int32, String)]
}

///|
fn Projection::include_scope(
  self : Projection,
  resource : Int32,
  root : Int32,
  tag : String,
  pool : String?,
  container? : String,
) -> Unit {
  let c = self.converter
  let index = c.sources[resource].index
  let members = Map([(root, true)])
  if !c.charge(index.nodes.length()) {
    return
  }
  for n in index.nodes {
    if n.parent.map(p => members.contains(p)).unwrap_or(false) {
      members[n.ordinal] = true
    }
  }
  self.instances.push({ resource, root, tag, pool, container, members, })
  for ordinal in members.keys() {
    self.selected[(resource, ordinal)] = true
  }
}

///|
fn Projection::selected_di(self : Projection, selected : Selected) -> Unit {
  let c = self.converter
  if selected.plane is Some(plane) {
    self.selected[(0, plane)] = true
    let index = c.sources[0].index
    let members = Map([(plane, true)])
    for n in index.nodes {
      if n.parent.map(p => members.contains(p)).unwrap_or(false) {
        members[n.ordinal] = true
        self.selected[(0, n.ordinal)] = true
      }
    }
    for ordinal in index.nodes[plane].children {
      let e = index.nodes[ordinal].element
      if actual(e) != Some(BpmnBPMNShape) && actual(e) != Some(BpmnBPMNEdge) {
        c.add(
          "bpmn/unsupported-element",
          "Selected plane contains an unsupported graphical element",
          e~,
        )
        continue
      }
      let targets = c.resolve_field(0, ordinal, "bpmnElement")
      if targets.length() != 1 {
        c.add(
          "bpmn/invalid-reference",
          "Selected DI must identify one graphical element",
          e~,
        )
        continue
      }
      let key = targets[0]
      if !self.di.contains(key) {
        self.di_order.push(key)
      }
      match self.di.get(key) {
        Some(values) => values.push(ordinal)
        None => self.di[key] = [ordinal]
      }
    }
  }
}

///|
fn Projection::geometry_for(
  self : Projection,
  key : (Int32, Int32),
  shape : Bool,
) -> Int32? {
  let candidates = self.di.get(key).unwrap_or([])
  let expected = if shape { @bpmn.TypeId::BpmnBPMNShape } else { BpmnBPMNEdge }
  let values = candidates.filter(i => {
    actual(self.converter.sources[0].index.nodes[i].element) == Some(expected)
  })
  if values.length() > 1 {
    self.converter.add(
      "bpmn/ambiguous-di",
      "Multiple DI elements depict one source identity; select an unambiguous plane",
      e=self.converter.sources[key.0].index.nodes[key.1].element,
    )
    return None
  }
  values.get(0)
}

///|
fn Projection::add_node(
  self : Projection,
  instance : Instance,
  ordinal : Int32,
  kind : @model.NodeKind,
) -> Unit {
  let c = self.converter
  let e = c.sources[instance.resource].index.nodes[ordinal].element
  let id = c.render_id(instance.resource, ordinal, instance.tag)
  let geometry_ordinal = self.geometry_for((instance.resource, ordinal), true)
  let geometry = geometry_ordinal.map(i => c.shape(i))
  let ownership = @model.Ownership::new(pool?=instance.pool)
  let mut label = if kind == TextAnnotation {
    e.children
    .iter()
    .find_first(c => actual(c) == Some(Text))
    .map(c => c.content)
    .unwrap_or("")
  } else {
    e.attribute("name").unwrap_or("")
  }
  let label_ref = if kind == Group {
    "categoryValueRef"
  } else if kind == DataObjectReference {
    "dataObjectRef"
  } else if kind == DataStoreReference {
    "dataStoreRef"
  } else {
    ""
  }
  if label_ref != "" && label.is_empty() {
    for key in c.resolve_field(instance.resource, ordinal, label_ref) {
      let element = c.sources[key.0].index.nodes[key.1].element
      label = element
        .attribute(if kind == Group { "value" } else { "name" })
        .unwrap_or("")
    }
  }
  let markers = c.markers(instance.resource, ordinal)
  self.visuals[(instance.resource, ordinal, instance.tag)] = self.nodes.length()
  self.visual_order.push((instance.resource, ordinal, instance.tag))
  if geometry_ordinal is Some(i) {
    self.used_di[i] = true
    match self.shapes.get(i) {
      Some(values) => values.push(self.nodes.length())
      None => self.shapes[i] = [self.nodes.length()]
    }
  }
  self.nodes.push(
    @model.Node::new(
      id,
      kind,
      bounds=integer_bounds(geometry),
      source=c.identity(instance.resource, ordinal),
      label~,
      geometry?,
      ownership~,
      markers~,
      expanded?=geometry.bind(g => g.expanded),
      black_box=kind == Participant && e.attribute("processRef") == None,
    ),
  )
}

///|
fn Projection::collect(self : Projection, instance : Instance) -> Unit {
  let c = self.converter
  let index = c.sources[instance.resource].index
  let referenced_data = Map([])
  for n in index.nodes {
    if !instance.members.contains(n.ordinal) {
      continue
    }
    if actual(n.element) == Some(DataObjectReference) {
      for key in c.resolve_field(instance.resource, n.ordinal, "dataObjectRef") {
        referenced_data[key] = true
      }
    }
  }
  for n in index.nodes {
    if !instance.members.contains(n.ordinal) ||
      (
        n.ordinal == instance.root &&
        !(is_type(n.element, SubProcess) &&
        self.di.contains((instance.resource, n.ordinal)))
      ) {
      continue
    }
    let e = n.element
    if e.kind is Unknown(_) {
      c.add(
        "bpmn/unsupported-element",
        "Selected standard element is unknown",
        e~,
      )
      continue
    }
    if n.payload {
      continue
    }
    if actual(e) == Some(ImplicitThrowEvent) {
      if self.di.contains((instance.resource, n.ordinal)) {
        c.add(
          "bpmn/unsupported-element",
          "Implicit throw events are non-graphical",
          e~,
        )
      }
      continue
    }
    if is_type(e, ChoreographyActivity) ||
      is_type(e, ConversationNode) ||
      actual(e) == Some(ConversationLink) ||
      actual(e) == Some(ConversationAssociation) {
      c.add(
        "bpmn/unsupported-view",
        "Choreography and conversation rendering is deferred; the document remains intact",
        e~,
      )
      continue
    }
    if node_kind(e) is Some(kind) {
      let has_shape = self.di.contains((instance.resource, n.ordinal))
      // Data definitions can have explicit depictions; references carry the usual
      // data symbol. Activity-local IO stays a semantic endpoint, never a shape.
      if kind == DataObject &&
        referenced_data.contains((instance.resource, n.ordinal)) &&
        !has_shape {
        continue
      }
      if kind == DataInput || kind == DataOutput {
        let parent = n.parent.map(p => index.nodes[p])
        let process_io = parent
          .bind(p => p.parent)
          .map(p => {
            p == instance.root &&
            actual(index.nodes[p].element) == Some(Process)
          })
          .unwrap_or(false)
        if !process_io {
          if has_shape {
            c.add(
              "bpmn/unsupported-element",
              "Only process data inputs and outputs have graphical depictions",
              e~,
            )
          }
          continue
        }
      }
      self.add_node(instance, n.ordinal, kind)
    } else if connection_kind(e) == None &&
      (e.kind is Unknown(_) || is_type(e, FlowNode) || is_type(e, Artifact)) {
      c.add(
        "bpmn/unsupported-element",
        "Selected graphical kind \{e.kind.local_name()} has no conversion",
        e~,
      )
    }
  }
}

///|
fn Projection::visual(
  self : Projection,
  key : (Int32, Int32),
  instance : String,
  owner : @bpmn.Element,
) -> Int32? {
  if self.visuals.get((key.0, key.1, instance)) is Some(i) {
    return Some(i)
  }
  let candidates = []
  for ((resource, ordinal, _), i) in self.visuals {
    if resource == key.0 && ordinal == key.1 {
      candidates.push(i)
    }
  }
  if candidates.length() == 1 {
    return Some(candidates[0])
  }
  if candidates.length() > 1 {
    self.converter.add(
      "bpmn/ambiguous-endpoint",
      "Endpoint has multiple visible participant instances; supply an explicit DI endpoint",
      e=owner,
    )
    return None
  }
  let index = self.converter.sources[key.0].index
  let mut parent = index.nodes[key.1].parent
  while parent is Some(ordinal) {
    if self.visuals.get((key.0, ordinal, instance)) is Some(i) {
      return Some(i)
    }
    parent = index.nodes[ordinal].parent
  }
  self.converter.add(
    "bpmn/invalid-reference",
    "Selected endpoint has no graphical owner",
    e=owner,
  )
  None
}

///|
fn Projection::display_endpoint(
  self : Projection,
  semantic : (Int32, Int32),
  tag : String,
  di : Int32?,
  field : String,
  owner : @bpmn.Element,
) -> Int32? {
  if di is Some(di) {
    let refs = self.converter.resolve_field(0, di, field)
    if refs.length() == 1 {
      let key = refs[0]
      if key.0 != 0 {
        self.converter.add(
          "bpmn/invalid-reference",
          "DI endpoint must belong to the selected plane",
          e=owner,
        )
        return None
      }
      let candidates = self.shapes.get(key.1).unwrap_or([])
      if candidates.length() != 1 {
        self.converter.add(
          "bpmn/ambiguous-endpoint",
          "DI endpoint does not identify one selected shape",
          e=owner,
        )
        return None
      }
      return Some(candidates[0])
    }
  }
  let visual = self.visual(semantic, tag, owner)
  if actual(owner) == Some(MessageFlow) &&
    visual is Some(i) &&
    self.nodes[i].ownership.pool is Some(pool) {
    if !self.converter.charge(self.nodes.length()) {
      return None
    }
    for index, node in self.nodes {
      if node.id == pool && node.black_box {
        return Some(index)
      }
    }
  }
  visual
}

///|
fn Projection::ownership(self : Projection) -> Unit {
  let c = self.converter
  for instance in self.instances {
    let index = c.sources[instance.resource].index
    let lane_members : Map[Int32, Array[String]] = Map([])
    let category_groups : Map[(Int32, Int32), Array[String]] = Map([])
    for (resource, ordinal, tag) in self.visual_order {
      let node = self.nodes[self.visuals[(resource, ordinal, tag)]]
      if resource != instance.resource ||
        tag != instance.tag ||
        node.kind != Group {
        continue
      }
      for key in c.resolve_field(resource, ordinal, "categoryValueRef") {
        match category_groups.get(key) {
          Some(groups) => groups.push(node.id)
          None => category_groups[key] = [node.id]
        }
      }
    }
    for n in index.nodes {
      if !instance.members.contains(n.ordinal) ||
        actual(n.element) != Some(Lane) {
        continue
      }
      let mut lanes = [c.render_id(instance.resource, n.ordinal, instance.tag)]
      let mut parent = n.parent
      while parent is Some(p) {
        if actual(index.nodes[p].element) == Some(Lane) {
          lanes.insert(0, c.render_id(instance.resource, p, instance.tag))
        }
        parent = index.nodes[p].parent
      }
      for key in c.resolve_field(instance.resource, n.ordinal, "flowNodeRef") {
        if key.0 != instance.resource || !instance.members.contains(key.1) {
          c.add(
            "bpmn/invalid-reference",
            "Lane member is outside its participant process",
            e=n.element,
          )
          continue
        }
        match lane_members.get(key.1) {
          Some(existing) =>
            for lane in lanes {
              if !existing.contains(lane) {
                existing.push(lane)
              }
            }
          None => lane_members[key.1] = lanes.copy()
        }
      }
      lanes = []
    }
    for (resource, ordinal, tag) in self.visual_order {
      let i = self.visuals[(resource, ordinal, tag)]
      if resource != instance.resource ||
        tag != instance.tag ||
        !instance.members.contains(ordinal) {
        continue
      }
      let n = index.nodes[ordinal]
      let node = self.nodes[i]
      let mut subprocess = None
      let mut parent = n.parent
      let lanes = lane_members.get(ordinal).unwrap_or([])
      while parent is Some(p) {
        if p == instance.root && !self.visuals.contains((resource, p, tag)) {
          break
        }
        if subprocess == None && is_type(index.nodes[p].element, SubProcess) {
          subprocess = Some(c.render_id(resource, p, tag))
        }
        if node.kind == Lane && actual(index.nodes[p].element) == Some(Lane) {
          let lane = c.render_id(resource, p, tag)
          if !lanes.contains(lane) {
            lanes.insert(0, lane)
          }
        }
        if p == instance.root {
          break
        }
        parent = index.nodes[p].parent
      }
      if subprocess == None {
        subprocess = instance.container
      }
      let attached = c
        .resolve_field(resource, ordinal, "attachedToRef")
        .get(0)
        .bind(key => self.visual(key, tag, n.element))
        .map(i => self.nodes[i].id)
      let groups : Array[String] = []
      if node.kind != Group {
        for key in c.resolve_field(resource, ordinal, "categoryValueRef") {
          for group in category_groups.get(key).unwrap_or([]) {
            if !groups.contains(group) {
              groups.push(group)
            }
          }
        }
      }
      self.nodes[i] = node.with_ownership(
        @model.Ownership::new(
          pool?=instance.pool,
          lanes~,
          subprocess?,
          attached_to?=attached,
          groups~,
        ),
      )
    }
  }
}

///|
fn Projection::connections(self : Projection, instance : Instance) -> Unit {
  let c = self.converter
  let index = c.sources[instance.resource].index
  for n in index.nodes {
    if !instance.members.contains(n.ordinal) || n.payload {
      continue
    }
    let e = n.element
    guard connection_kind(e) is Some(kind) else { continue }
    let sources = c.resolve_field(instance.resource, n.ordinal, "sourceRef")
    let targets = c.resolve_field(instance.resource, n.ordinal, "targetRef")
    guard targets.length() == 1 else {
      c.add("bpmn/invalid-reference", "Connection requires one target", e~)
      continue
    }
    let data = kind == DataAssociation ||
      kind == DataInputAssociation ||
      kind == DataOutputAssociation
    if !data && sources.length() != 1 {
      c.add("bpmn/invalid-reference", "Connection requires one source", e~)
      continue
    }
    let di = self.geometry_for((instance.resource, n.ordinal), false)
    let geometry = di.map(i => {
      self.used_di[i] = true
      c.edge(i)
    })
    guard self.display_endpoint(
        targets[0],
        instance.tag,
        di,
        "targetElement",
        e,
      )
      is Some(target) else {
      continue
    }
    let semantic_target = c.identity(targets[0].0, targets[0].1)
    let condition = e.children
      .iter()
      .find_first(c => c.kind == ConditionExpression)
      .map(c => c.content)
    let count = Int32::max(1, sources.length())
    for j in 0..<count {
      let source_key = sources.get(j)
      let source = source_key.bind(key => {
        self.display_endpoint(key, instance.tag, di, "sourceElement", e)
      })
      if source_key != None && source == None {
        continue
      }
      let identity = c.identity(instance.resource, n.ordinal)
      let base = c.render_id(instance.resource, n.ordinal, instance.tag)
      let id = if count == 1 { base } else { base + "@source-\{j}" }
      let is_default = source_key
        .map(key => {
          c
          .resolve_field(key.0, key.1, "default")
          .contains((instance.resource, n.ordinal))
        })
        .unwrap_or(false)
      let direction : @model.AssociationDirection = match
        e.attribute("associationDirection") {
        Some("One") => One
        Some("Both") => Both
        _ => None
      }
      self.flows.push(
        @model.Flow::new(
          id,
          source.map(i => self.nodes[i].id).unwrap_or(""),
          self.nodes[target].id,
          points=integer_points(geometry),
          identity~,
          kind~,
          has_source=source_key != None,
          semantic_source?=source_key.map(key => c.identity(key.0, key.1)),
          semantic_target~,
          geometry?,
          label=e.attribute("name").unwrap_or(""),
          condition?,
          is_default~,
          direction~,
        ),
      )
    }
  }
}

///|
/// Pure view conversion over caller-supplied resources. Geometry remains optional;
/// the SVG renderer owns complete-DI versus whole-view layout policy.
pub fn to_diagram(
  document : @bpmn.Document,
  selector~ : ViewSelector = Automatic,
  resources~ : @bpmn.ResourceSet = @bpmn.ResourceSet::new(),
  resource_id? : String,
  limits~ : @bpmn.Limits = @bpmn.Limits::new(),
  geometry_policy~ : @model.GeometryPolicy = PreferDi,
) -> Conversion {
  let documents = resources.documents.iter().to_array()
  if resource_id is Some(id) && !documents.iter().any(d => d.location == id) {
    documents.push(@bpmn.DocumentResource::new(id, document))
  }
  let resources = @bpmn.ResourceSet::new(
    documents~,
    external=resources.external,
  )
  let c = Converter::{
    ignore_di: geometry_policy == @model.GeometryPolicy::Automatic,
    sources: [],
    dependencies: Map([]),
    resources,
    limits,
    diagnostics: [],
    failed: false,
    work: 0,
  }
  fn result(diagram : @render.Diagram?) -> Conversion {
    {
      diagram: if c.failed {
        None
      } else {
        diagram
      },
      diagnostics: ReadOnlyArray::from_array(c.diagnostics),
    }
  }
  if limits.nodes <= 0 ||
    limits.depth <= 0 ||
    limits.diagnostics <= 0 ||
    limits.token_units <= 0 ||
    limits.source_units <= 0 ||
    limits.output_units <= 0 {
    return {
      diagram: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "bpmn/conversion-limit", "All limits must be positive",
        ),
      ],
    }
  }
  let root = make_source(document, resource_id, resources, limits)
  c.sources.push(root)
  if !c.charge(root.references.references.length()) {
    return result(None)
  }
  if !root.index.complete || !root.references.complete {
    c.add("bpmn/conversion-limit", "View validation exceeded its limits")
    return result(None)
  }
  guard c.select(selector) is Some(selected) else { return result(None) }
  let view = c.sources[selected.resource].index.nodes[selected.node].element
  if actual(view) != Some(Process) &&
    !is_type(view, SubProcess) &&
    actual(view) != Some(Collaboration) {
    c.add(
      "bpmn/unsupported-view",
      "Choreography and conversation rendering is deferred",
      e=view,
    )
    return result(None)
  }
  let p = Projection::{
    converter: c,
    instances: [],
    nodes: [],
    flows: [],
    visuals: Map([]),
    selected: Map([]),
    di: Map([]),
    di_order: [],
    used_di: Map([]),
    shapes: Map([]),
    visual_order: [],
  }
  if !c.ignore_di {
    p.selected_di(selected)
  }
  if c.failed {
    return result(None)
  }
  p.include_scope(selected.resource, selected.node, "", None)
  if c.failed {
    return result(None)
  }
  guard p.instances.get(0) is Some(root_instance) else {
    c.add("bpmn/conversion-limit", "Root view scope was not completed")
    return result(None)
  }
  if actual(view) == Some(Collaboration) {
    let index = c.sources[selected.resource].index
    for n in index.nodes {
      if !root_instance.members.contains(n.ordinal) ||
        actual(n.element) != Some(Participant) {
        continue
      }
      let pool = c.render_id(selected.resource, n.ordinal, "")
      let processes = c.resolve_field(
        selected.resource,
        n.ordinal,
        "processRef",
      )
      if processes.length() > 1 {
        c.add(
          "bpmn/ambiguous-endpoint",
          "Participant has multiple process targets",
          e=n.element,
        )
      }
      for key in processes {
        if actual(c.sources[key.0].index.nodes[key.1].element) != Some(Process) {
          c.add(
            "bpmn/invalid-reference",
            "Participant must identify a process",
            e=n.element,
          )
          continue
        }
        p.include_scope(key.0, key.1, pool, Some(pool))
      }
    }
  }
  let mut instance_index = 0
  while instance_index < p.instances.length() && !c.failed {
    let instance = p.instances[instance_index]
    instance_index += 1
    p.collect(instance)
    let index = c.sources[instance.resource].index
    for n in index.nodes {
      if !instance.members.contains(n.ordinal) ||
        actual(n.element) != Some(CallActivity) {
        continue
      }
      let visual = p.visuals.get((instance.resource, n.ordinal, instance.tag))
      if visual.map(i => p.nodes[i].expanded == Some(true)).unwrap_or(false) {
        for
          key in c.resolve_field(instance.resource, n.ordinal, "calledElement") {
          if actual(c.sources[key.0].index.nodes[key.1].element) ==
            Some(Process) {
            let call = p.nodes[visual.unwrap()].id
            p.include_scope(key.0, key.1, call, instance.pool, container=call)
          }
        }
      }
    }
  }
  // Root-level messages and stores can have explicit selected-plane shapes.
  for key in p.di_order {
    if p.selected.contains(key) {
      continue
    }
    let element = c.sources[key.0].index.nodes[key.1].element
    if actual(element) == Some(Message) || actual(element) == Some(DataStore) {
      p.selected[key] = true
      p.add_node(
        {
          resource: key.0,
          root: key.1,
          tag: "",
          pool: None,
          container: None,
          members: Map([(key.1, true)]),
        },
        key.1,
        node_kind(element).unwrap(),
      )
    } else {
      c.add(
        "bpmn/invalid-reference",
        "DI element is outside the selected view",
        e=element,
      )
    }
  }
  if selected.plane != None {
    for instance in p.instances {
      if instance.pool is Some(pool) {
        let has_internal_di = p.di_order
          .iter()
          .any(key => {
            key.0 == instance.resource && instance.members.contains(key.1)
          })
        if !has_internal_di {
          for i, node in p.nodes {
            if node.id == pool && node.geometry != None {
              p.nodes[i] = node.with_black_box(true)
            }
          }
        }
      }
    }
  }
  p.ownership()
  for instance in p.instances {
    p.connections(instance)
  }
  for key in p.di_order {
    for di in p.di[key] {
      if !p.used_di.contains(di) {
        c.add(
          "bpmn/unsupported-element",
          "Selected DI has no graphical projection",
          e=c.sources[0].index.nodes[di].element,
        )
      }
    }
  }
  let seen : Array[@bpmn.ValidationFinding] = []
  for source in c.sources {
    for finding in source.findings {
      if seen.contains(finding) {
        continue
      }
      seen.push(finding)
      let mut resource : Int32? = None
      for r, s in c.sources {
        if s.id == finding.resource_id {
          resource = Some(r)
          break
        }
      }
      let selected = resource
        .map(r => {
          finding.node
          .map(n => {
            p.selected.contains((r, n)) ||
            c.dependencies.contains((r, n)) ||
            n == 0
          })
          .unwrap_or(false)
        })
        .unwrap_or(false)
      let fatal = selected &&
        finding.diagnostic.code != "bpmn/unresolved-import"
      let diagnostic = map_diagnostic(finding.diagnostic)
      if c.diagnostics.length() < limits.diagnostics {
        c.diagnostics.push(
          if fatal {
            diagnostic
          } else {
            { ..diagnostic, severity: Warning, }
          },
        )
      } else {
        c.add("bpmn/conversion-limit", "Combined diagnostic limit exceeded")
      }
      if fatal {
        c.failed = true
      }
    }
  }
  let ids = Map([])
  for node in p.nodes {
    if ids.contains(node.id) {
      c.add("bpmn/duplicate-id", "Duplicate generated render identity")
    }
    ids[node.id] = true
  }
  for flow in p.flows {
    if ids.contains(flow.id) {
      c.add("bpmn/duplicate-id", "Duplicate generated render identity")
    }
    ids[flow.id] = true
  }
  let id = c.render_id(selected.resource, selected.node, "")
  let bpmn = @model.Bpmn::new(
    id,
    p.nodes,
    p.flows,
    label=view.attribute("name").unwrap_or(id),
    source=c.identity(selected.resource, selected.node),
    kind=if actual(view) == Some(Collaboration) {
      Collaboration
    } else {
      Process
    },
    plane?=selected.plane.map(i => c.identity(0, i)),
  )
  result(Some(Bpmn(bpmn)))
}

///|
/// Read, select, convert and render without performing filesystem/network I/O.
pub fn render_svg(
  source : String,
  selector~ : ViewSelector = Automatic,
  resources~ : @bpmn.ResourceSet = @bpmn.ResourceSet::new(),
  geometry_policy~ : @model.GeometryPolicy = PreferDi,
  connectors~ : @svg.ConnectorOptions = @svg.ConnectorOptions::new(),
) -> @render.Rendered {
  let read = @bpmn.read(source)
  guard read.document is Some(document) else {
    return @render.Rendered::failed(
      "image/svg+xml",
      read.diagnostics.map(map_diagnostic),
    )
  }
  let converted = to_diagram(document, selector~, resources~, geometry_policy~)
  // A successful selected view has already checked its semantic fields. Lowering
  // findings in other views or explicitly ignored DI remain visible as warnings.
  let diagnostics = read.diagnostics
    .map(d => {
      let mapped = map_diagnostic(d)
      if converted.diagram != None {
        { ..mapped, severity: Warning, }
      } else {
        mapped
      }
    })
    .iter()
    .to_array()
  diagnostics.append(converted.diagnostics)
  guard converted.diagram is Some(diagram) else {
    return @render.Rendered::failed("image/svg+xml", diagnostics)
  }
  let rendered = @svg.SvgRenderer::new(bpmn_policy=geometry_policy, connectors~).render(
    diagram,
  )
  diagnostics.append(rendered.diagnostics)
  match rendered.output {
    Some(output) =>
      @render.Rendered::ok(output, rendered.media_type, diagnostics~)
    None => @render.Rendered::failed(rendered.media_type, diagnostics)
  }
}
