///|
priv struct HtmlBudget {
  limit : Int32
  mut used : Int32
  mut failed : Bool
}

///|
fn HtmlBudget::reserve(self : HtmlBudget, units : Int32) -> Bool {
  if units < 0 || units > self.limit - self.used {
    self.failed = true
    return false
  }
  self.used += units
  true
}

///|
fn HtmlBudget::str(self : HtmlBudget, value : String) -> Json {
  if value.length() > (self.limit - self.used) / 6 {
    self.failed = true
    return Json("")
  }
  ignore(self.reserve(value.length() * 6 + 2))
  Json(value)
}

///|
fn HtmlBudget::number(self : HtmlBudget, value : Int32) -> Json {
  ignore(self.reserve(16))
  Json(value)
}

///|
fn HtmlBudget::object(
  self : HtmlBudget,
  fields : ArrayView[(String, Json)],
) -> Json {
  ignore(self.reserve(fields.length() * 32 + 2))
  Json(Map(fields))
}

///|
fn HtmlBudget::array(self : HtmlBudget, values : ArrayView[Json]) -> Json {
  ignore(self.reserve(values.length() + 2))
  Json(values.to_owned())
}

///|
fn description(node : @model.Node, budget : HtmlBudget) -> String {
  let result = StringBuilder()
  if node.properties.bind(p => p.description) is Some(text) {
    if !budget.reserve(text.length() + 1) {
      return ""
    }
    result.write_string(text)
    result.write_char('\n')
  }
  for event in node.markers.events {
    for (key, value) in event.settings {
      if !budget.reserve(key.length() + value.length() + 3) {
        return ""
      }
      result.write_string(key)
      result.write_string(": ")
      result.write_string(value)
      result.write_char('\n')
    }
  }
  result.to_string()
}

///|
fn endpoint_label(
  node : @animation.GraphNode,
  catalog : @animation.Catalog,
) -> String {
  if node.kind == Message &&
    node.occurrence.bind(key => catalog.occurrence(key)) is Some(occurrence) &&
    occurrence.message is Some(message) {
    let label = if message.label.is_empty() {
      message.sender + " → " + message.receiver
    } else {
      message.label
    }
    return "Message \{occurrence.index+1}: \{label}"
  }
  if !node.label.is_empty() {
    return node.label
  }
  node.swimlane_node
  .map(n => n.id)
  .unwrap_or_else(() => {
    node.source_node.bind(n => n.source.source_id).unwrap_or(node.id)
  })
}

///|
fn playback_data(
  scene : @svg.Scene,
  plan : @animation.PlaybackPlan,
  query_limits : @animation.Limits,
  step_limit : Int32,
  budget : HtmlBudget,
) -> Json {
  let steps = []
  for step in plan.steps {
    let groups = step.concurrent_groups
      .iter()
      .map(g => budget.number(g))
      .to_array()
    steps.push(
      budget.object([
        ("reversed", Json(step.reversed)),
        ("visit", Json(step.visit)),
        ("ordinal", budget.number(step.ordinal)),
        ("key", budget.str(step.occurrence.key)),
        ("start_ms", budget.str(step.start_ms.to_string())),
        ("duration_ms", budget.str(step.duration_ms.to_string())),
        ("groups", budget.array(groups)),
      ]),
    )
    if budget.failed {
      return Json(null)
    }
  }
  let paths = []
  for binding in scene.paths {
    paths.push(
      budget.object([
        (
          "label",
          budget.str(
            binding.occurrence.swimlane_connection
            .map(c => c.label)
            .unwrap_or(""),
          ),
        ),
        (
          "reversed",
          Json(
            binding.occurrence.swimlane_connection
            .map(c => c.direction == Backward)
            .unwrap_or(false),
          ),
        ),
        ("key", budget.str(binding.occurrence.key)),
        ("id", budget.str(binding.id)),
        ("index", budget.number(binding.occurrence.index)),
        (
          "kind",
          budget.str(
            if binding.occurrence.swimlane_connection is Some(_) {
              "swimlane"
            } else if binding.occurrence.flow is Some(_) {
              "bpmn"
            } else if binding.occurrence.railroad_connector is Some(_) {
              "railroad"
            } else if binding.occurrence.data_member is Some(_) {
              "data"
            } else {
              "sequence"
            },
          ),
        ),
        (
          "connection",
          binding.occurrence.swimlane_connection
          .map(c => budget.str(c.id))
          .unwrap_or_else(() => {
            binding.occurrence.flow
            .map(f => budget.str(f.id))
            .unwrap_or(Json(null))
          }),
        ),
      ]),
    )
    if budget.failed {
      return Json(null)
    }
  }
  let nodes = []
  for node in scene.catalog.graph.nodes {
    let kind = match node.kind {
      Bpmn(_) => "bpmn"
      SwimlaneNode | SwimlaneGroup | SwimlaneLane => "swimlane"
      Message => "message"
      RailroadPoint => "point"
      DataValue => "data"
      _ => "control"
    }
    let detail = node.source_node.map(n => description(n, budget)).unwrap_or("")
    nodes.push(
      budget.object([
        ("primary", Json(node.swimlane_node is Some(_))),
        ("id", budget.str(node.id)),
        ("label", budget.str(endpoint_label(node, scene.catalog))),
        ("kind", budget.str(kind)),
        (
          "occurrence",
          node.occurrence.map(k => budget.str(k)).unwrap_or(Json(null)),
        ),
        ("description", budget.str(detail)),
      ]),
    )
    if budget.failed {
      return Json(null)
    }
  }
  let edges = []
  for edge in scene.catalog.graph.edges {
    let kind = match edge.kind {
      SequenceFlow => "sequence"
      MessageFlow => "message"
      Order => "order"
      SwimlaneFlow => "swimlane"
      Undirected => "undirected"
      Railroad => "railroad"
      Containment => "containment"
    }
    edges.push(
      budget.object([
        ("reversed", Json(edge.reversed)),
        ("kind", budget.str(kind)),
        ("source", budget.str(edge.source)),
        ("target", budget.str(edge.target)),
        (
          "occurrence",
          edge.occurrence.map(k => budget.str(k)).unwrap_or(Json(null)),
        ),
      ]),
    )
    if budget.failed {
      return Json(null)
    }
  }
  let outside = []
  match scene.catalog.source {
    Swimlane(view) => {
      for node in view.nodes {
        if scene.catalog.graph.lookup(node.id) is Err(OutsideView(_)) {
          outside.push(budget.str(node.id))
        }
      }
      for group in view.groups {
        if scene.catalog.graph.lookup(group.id) is Err(OutsideView(_)) {
          outside.push(budget.str(group.id))
        }
      }
    }
    _ => ()
  }
  let node_bindings = []
  for binding in scene.nodes {
    let value = match binding.kind {
      Swimlane(id) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("swimlane")),
          ("id", budget.str(id)),
        ])
      Bpmn(id) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("bpmn")),
          ("id", budget.str(id)),
        ])
      Message(index) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("message")),
          ("index", budget.number(index)),
        ])
      Frame(index) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("frame")),
          ("index", budget.number(index)),
        ])
      RailroadTerm(id) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("term")),
          ("id", budget.str(id)),
        ])
      DataRow(id) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("row")),
          ("id", budget.str(id)),
        ])
      DataBox(id) =>
        budget.object([
          ("endpoint", budget.str(binding.endpoint)),
          ("kind", budget.str("box")),
          ("id", budget.str(id)),
        ])
    }
    node_bindings.push(value)
    if budget.failed {
      return Json(null)
    }
  }
  budget.object([
    ("version", budget.number(1)),
    ("step_limit", budget.number(step_limit)),
    ("view_id", budget.str(scene.catalog.view_id)),
    ("kind", budget.str(scene.catalog.source.kind_name())),
    ("canonical", budget.str(scene.canonical_svg)),
    ("accent", budget.str("#2563eb")),
    (
      "plan",
      budget.object([
        (
          "mode",
          budget.str(
            if plan.mode == Illustrative {
              "illustrative"
            } else {
              "finite"
            },
          ),
        ),
        ("duration_ms", budget.str(plan.duration_ms.to_string())),
        ("steps", budget.array(steps)),
      ]),
    ),
    ("paths", budget.array(paths)),
    ("node_bindings", budget.array(node_bindings)),
    ("outside", budget.array(outside)),
    (
      "graph",
      budget.object([
        ("nodes", budget.array(nodes)),
        ("edges", budget.array(edges)),
      ]),
    ),
    (
      "query_limits",
      budget.object([
        ("nodes", budget.number(query_limits.nodes)),
        ("edges", budget.number(query_limits.edges)),
        ("results", budget.number(query_limits.results)),
        ("work", budget.number(query_limits.work)),
      ]),
    ),
  ])
}

///|
fn safe_script_json(data : Json) -> String {
  data
  .stringify()
  .replace_all(old="<", new="\\u003c")
  .replace_all(old=">", new="\\u003e")
  .replace_all(old="&", new="\\u0026")
  .replace_all(old="\u2028", new="\\u2028")
  .replace_all(old="\u2029", new="\\u2029")
}
