///|
priv struct HtmlBudget { limit : Int; mut used : Int; mut failed : Bool }

///|
fn HtmlBudget::reserve(self : HtmlBudget, units : Int) -> Bool {
  if units < 0 || units > self.limit-self.used { self.failed=true; return false }
  self.used+=units; true
}

///|
fn HtmlBudget::str(self : HtmlBudget, value : String) -> Json {
  if value.length() > (self.limit-self.used)/6 { self.failed=true; return Json("") }
  ignore(self.reserve(value.length()*6+2)); Json(value)
}

///|
fn HtmlBudget::number(self : HtmlBudget, value : Int) -> Json { ignore(self.reserve(16)); Json(value) }

///|
fn HtmlBudget::object(self : HtmlBudget, fields : ArrayView[(String,Json)]) -> Json {
  ignore(self.reserve(fields.length()*32+2)); Json(Map(fields))
}

///|
fn HtmlBudget::array(self : HtmlBudget, values : ArrayView[Json]) -> Json {
  ignore(self.reserve(values.length()+2)); Json(values.to_owned())
}

///|
fn description(node : @model.Node, budget : HtmlBudget) -> String {
  let result=StringBuilder()
  if node.properties.bind(p => p.description) is Some(text) {
    if !budget.reserve(text.length()+1) { return "" }; result.write_string(text); result.write_char('\n')
  }
  for event in node.markers.events {
    for (key,value) in event.settings {
      if !budget.reserve(key.length()+value.length()+3) { return "" }
      result.write_string(key); result.write_string(": "); result.write_string(value); result.write_char('\n')
    }
  }
  result.to_string()
}

///|
fn endpoint_label(node : @animation.GraphNode, catalog : @animation.Catalog) -> String {
  if node.kind == Message && node.occurrence.bind(key => catalog.occurrence(key)) is Some(occurrence) && occurrence.message is Some(message) {
    let label=if message.label.is_empty() { message.sender+" → "+message.receiver } else { message.label }
    return "Message \{occurrence.index+1}: \{label}"
  }
  if !node.label.is_empty() { return node.label }
  node.source_node.bind(n => n.source.source_id).unwrap_or("Unnamed BPMN element")
}

///|
fn playback_data(scene : @svg.Scene, plan : @animation.PlaybackPlan, query_limits : @animation.Limits, step_limit : Int, budget : HtmlBudget) -> Json {
  let steps=[]
  for step in plan.steps {
    let groups=step.concurrent_groups.iter().map(g => budget.number(g)).to_array()
    steps.push(budget.object([
      ("ordinal",budget.number(step.ordinal)),("key",budget.str(step.occurrence.key)),
      ("start_ms",budget.str(step.start_ms.to_string())),("duration_ms",budget.str(step.duration_ms.to_string())),("groups",budget.array(groups)),
    ]))
    if budget.failed { return Json(null) }
  }
  let paths=[]
  for binding in scene.paths { paths.push(budget.object([("key",budget.str(binding.occurrence.key)),("id",budget.str(binding.id)),("index",budget.number(binding.occurrence.index)),("kind",budget.str(if binding.occurrence.flow is Some(_) { "bpmn" } else { "sequence" })),("connection",binding.occurrence.flow.map(f => budget.str(f.id)).unwrap_or(Json(null)))])); if budget.failed { return Json(null) } }
  let nodes=[]
  for node in scene.catalog.graph.nodes {
    let kind=match node.kind { Bpmn(_) => "bpmn"; Message => "message"; _ => "control" }
    let detail=node.source_node.map(n => description(n,budget)).unwrap_or("")
    nodes.push(budget.object([("id",budget.str(node.id)),("label",budget.str(endpoint_label(node,scene.catalog))),("kind",budget.str(kind)),("occurrence",node.occurrence.map(k => budget.str(k)).unwrap_or(Json(null))),("description",budget.str(detail))]))
    if budget.failed { return Json(null) }
  }
  let edges=[]
  for edge in scene.catalog.graph.edges {
    let kind=match edge.kind { SequenceFlow => "sequence"; MessageFlow => "message"; Order => "order" }
    edges.push(budget.object([("kind",budget.str(kind)),("source",budget.str(edge.source)),("target",budget.str(edge.target)),("occurrence",edge.occurrence.map(k => budget.str(k)).unwrap_or(Json(null)))]))
    if budget.failed { return Json(null) }
  }
  let node_bindings=[]
  for binding in scene.nodes {
    let value=match binding.kind {
      Bpmn(id) => budget.object([("endpoint",budget.str(binding.endpoint)),("kind",budget.str("bpmn")),("id",budget.str(id))])
      Message(index) => budget.object([("endpoint",budget.str(binding.endpoint)),("kind",budget.str("message")),("index",budget.number(index))])
      Frame(index) => budget.object([("endpoint",budget.str(binding.endpoint)),("kind",budget.str("frame")),("index",budget.number(index))])
    }
    node_bindings.push(value)
    if budget.failed { return Json(null) }
  }
  budget.object([
    ("version",budget.number(1)),("step_limit",budget.number(step_limit)),("view_id",budget.str(scene.catalog.view_id)),
    ("kind",budget.str(scene.catalog.source.kind_name())),("canonical",budget.str(scene.canonical_svg)),("accent",budget.str("#2563eb")),
    ("plan",budget.object([("mode",budget.str(if plan.mode == Illustrative { "illustrative" } else { "finite" })),("duration_ms",budget.str(plan.duration_ms.to_string())),("steps",budget.array(steps))])),
    ("paths",budget.array(paths)),("node_bindings",budget.array(node_bindings)),
    ("graph",budget.object([("nodes",budget.array(nodes)),("edges",budget.array(edges))])),
    ("query_limits",budget.object([("nodes",budget.number(query_limits.nodes)),("edges",budget.number(query_limits.edges)),("results",budget.number(query_limits.results)),("work",budget.number(query_limits.work))])),
  ])
}

///|
fn safe_script_json(data : Json) -> String {
  data.stringify().replace_all(old="<",new="\\u003c").replace_all(old=">",new="\\u003e").replace_all(old="&",new="\\u0026").replace_all(old="\u2028",new="\\u2028").replace_all(old="\u2029",new="\\u2029")
}
