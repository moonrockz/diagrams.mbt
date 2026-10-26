///|
priv struct BpmnPaint {
  paint : Paint
  limit : Int32
  diagnostics : Array[@diagrams.Diagnostic]
  mut used : Int32
  mut failed : Bool
  mut work : Int32
  work_limit : Int32
}

///|
fn BpmnPaint::fail(self : BpmnPaint, code : String, message : String) -> Unit {
  if !self.failed {
    self.diagnostics.push(@diagrams.Diagnostic::error(code, message))
  }
  self.failed = true
}

///|
fn BpmnPaint::reserve(self : BpmnPaint, units : Int32) -> Bool {
  if self.failed {
    return false
  }
  if units < 0 || units > self.limit - self.used {
    self.fail("bpmn/render-limit", "BPMN SVG output limit exceeded")
    return false
  }
  self.used += units
  true
}

///|
/// Validate XML 1.0 characters and account for the writer's escaped UTF-16 size.
fn BpmnPaint::escaped(
  self : BpmnPaint,
  value : String,
  attribute : Bool,
) -> Bool {
  let mut i = 0
  while i < value.length() {
    let u = value.code_unit_at(i).to_int()
    i += 1
    if u >= 0xd800 && u <= 0xdbff {
      if i >= value.length() ||
        value.code_unit_at(i).to_int() < 0xdc00 ||
        value.code_unit_at(i).to_int() > 0xdfff {
        self.fail(
          "bpmn/invalid-xml-character", "BPMN text contains an unpaired surrogate",
        )
        return false
      }
      i += 1
      if !self.reserve(2) {
        return false
      }
      continue
    }
    if (u < 32 && u != 9 && u != 10 && u != 13) ||
      (u >= 0xdc00 && u <= 0xdfff) ||
      u == 0xfffe ||
      u == 0xffff {
      self.fail(
        "bpmn/invalid-xml-character", "BPMN text contains a forbidden XML character",
      )
      return false
    }
    let units = if u == 38 {
      5
    } else if u == 60 || u == 62 {
      4
    } else if u == 13 || (attribute && (u == 9 || u == 10)) {
      5
    } else if attribute && u == 34 {
      6
    } else {
      1
    }
    if !self.reserve(units) {
      return false
    }
  }
  true
}

///|
fn BpmnPaint::text(self : BpmnPaint, value : String) -> @writer.Node {
  if !self.escaped(value, false) {
    return @writer.text("")
  }
  @writer.text(value)
}

///|
fn BpmnPaint::element(
  self : BpmnPaint,
  name : String,
  attrs~ : ArrayView[(String, String)] = [],
  children~ : ArrayView[@writer.Node] = [],
) -> @writer.Node {
  if !self.reserve(name.length() * 2 + 64) {
    return @writer.element("g")
  }
  for (key, value) in attrs {
    if !self.reserve(key.length() + 4) || !self.escaped(value, true) {
      return @writer.element("g")
    }
  }
  @writer.element(name, attrs~, children~)
}

///|
fn BpmnPaint::path(
  self : BpmnPaint,
  d : String,
  stroke : String,
  fill~ : String = "none",
  width~ : String = "1.5",
  dash? : String,
) -> @writer.Node {
  let attrs = [
    ("d", d),
    ("fill", fill),
    ("stroke", stroke),
    ("stroke-width", width),
    ("stroke-linejoin", "round"),
    ("stroke-linecap", "round"),
  ]
  if dash is Some(dash) {
    attrs.push(("stroke-dasharray", dash))
  }
  self.element("path", attrs~)
}

///|
fn BpmnPaint::circle(
  self : BpmnPaint,
  x : String,
  y : String,
  radius : String,
  stroke : String,
  fill~ : String = "none",
  width~ : String = "1.5",
  dash? : String,
) -> @writer.Node {
  let attrs = [
    ("cx", x),
    ("cy", y),
    ("r", radius),
    ("fill", fill),
    ("stroke", stroke),
    ("stroke-width", width),
  ]
  if dash is Some(dash) {
    attrs.push(("stroke-dasharray", dash))
  }
  self.element("circle", attrs~)
}

///|
fn BpmnPaint::rect(
  self : BpmnPaint,
  x : String,
  y : String,
  width : String,
  height : String,
  stroke : String,
  fill~ : String = "none",
  radius~ : String = "0",
  weight~ : String = "1.5",
  dash? : String,
) -> @writer.Node {
  let attrs = [
    ("x", x),
    ("y", y),
    ("width", width),
    ("height", height),
    ("rx", radius),
    ("fill", fill),
    ("stroke", stroke),
    ("stroke-width", weight),
  ]
  if dash is Some(dash) {
    attrs.push(("stroke-dasharray", dash))
  }
  self.element("rect", attrs~)
}

///|
fn BpmnPaint::metadata(
  self : BpmnPaint,
  id : String,
  identity : @bpmn.SourceIdentity,
  properties : @bpmn.RenderProperties?,
) -> Array[(String, String)] {
  let attrs = [("data-id", id)]
  if identity.source_id is Some(id) {
    attrs.push(("data-source-id", id))
  }
  if identity.resource_id is Some(id) {
    attrs.push(("data-source-resource", id))
  }
  let path = StringBuilder()
  let mut units = 0
  for i, index in identity.path {
    let part = (if i == 0 { "" } else { "/" }) + index.to_string()
    if part.length() > self.limit - self.used - units {
      self.fail(
        "bpmn/render-limit", "Source identity metadata exceeds the output budget",
      )
      break
    }
    units += part.length()
    path.write_string(part)
  }
  attrs.push(("data-source-path", path.to_string()))
  if properties.bind(p => p.link) is Some(link) {
    attrs.push(("data-link", link.target))
  }
  if properties.bind(p => p.description) is Some(description) {
    attrs.push(("data-description", description))
  }
  attrs
}

///|
fn bpmn_kind(kind : @bpmn.NodeKind) -> String {
  match kind {
    StartEvent => "startEvent"
    EndEvent => "endEvent"
    IntermediateCatchEvent => "intermediateCatchEvent"
    IntermediateThrowEvent => "intermediateThrowEvent"
    BoundaryEvent => "boundaryEvent"
    Task => "task"
    UserTask => "userTask"
    ServiceTask => "serviceTask"
    SendTask => "sendTask"
    ReceiveTask => "receiveTask"
    ManualTask => "manualTask"
    BusinessRuleTask => "businessRuleTask"
    ScriptTask => "scriptTask"
    SubProcess => "subProcess"
    AdHocSubProcess => "adHocSubProcess"
    Transaction => "transaction"
    CallActivity => "callActivity"
    ExclusiveGateway => "exclusiveGateway"
    InclusiveGateway => "inclusiveGateway"
    ParallelGateway => "parallelGateway"
    ComplexGateway => "complexGateway"
    EventBasedGateway => "eventBasedGateway"
    Participant => "participant"
    Lane => "lane"
    DataObject => "dataObject"
    DataObjectReference => "dataObjectReference"
    DataStore => "dataStore"
    DataStoreReference => "dataStoreReference"
    DataInput => "dataInput"
    DataOutput => "dataOutput"
    Group => "group"
    TextAnnotation => "textAnnotation"
    Message => "message"
  }
}

///|
fn bpmn_connection(kind : @bpmn.ConnectionKind) -> String {
  match kind {
    SequenceFlow => "sequenceFlow"
    MessageFlow => "messageFlow"
    Association => "association"
    DataInputAssociation => "dataInputAssociation"
    DataOutputAssociation => "dataOutputAssociation"
    DataAssociation => "dataAssociation"
  }
}

///|
fn bpmn_event(kind : @bpmn.EventKind) -> String {
  match kind {
    Message => "message"
    Timer => "timer"
    Conditional => "conditional"
    Link => "link"
    Signal => "signal"
    Error => "error"
    Escalation => "escalation"
    Cancel => "cancel"
    Compensation => "compensation"
    Terminate => "terminate"
  }
}

///|
fn bpmn_detail(node : @bpmn.Node, key : String) -> String? {
  node.markers.details.iter().find_first(p => p.0 == "@" + key).map(p => p.1)
}

///|
fn BpmnPaint::charge(self : BpmnPaint, amount : Int32) -> Bool {
  if amount < 0 || amount > self.work_limit - self.work {
    self.fail("bpmn/render-limit", "BPMN painting work limit exceeded")
    return false
  }
  self.work += amount
  true
}
