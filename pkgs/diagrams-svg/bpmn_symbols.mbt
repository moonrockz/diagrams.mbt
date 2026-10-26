///|
fn bn(value : Double) -> String {
  @bpmn_layout.svg_number(value).unwrap()
}

///|
fn BpmnPaint::event_symbol(
  self : BpmnPaint,
  kind : @bpmn.EventKind,
  filled : Bool,
  stroke : String,
) -> Array[@writer.Node] {
  let fill = if filled { stroke } else { self.paint.color("bg") }
  match kind {
    Message =>
      [
        self.rect("1", "4", "22", "16", stroke, fill~),
        self.path(
          "M1 4 L12 13 L23 4",
          if filled {
            self.paint.color("bg")
          } else {
            stroke
          },
        ),
      ]
    Timer => {
      let parts = [
        self.circle("12", "12", "10.5", stroke),
        self.path("M12 5 V12 L17 15", stroke),
      ]
      for
        (x1, y1, x2, y2) in [
          (12, 2, 12, 4),
          (12, 20, 12, 22),
          (2, 12, 4, 12),
          (20, 12, 22, 12),
          (5, 5, 6, 6),
          (18, 18, 19, 19),
          (5, 19, 6, 18),
          (18, 6, 19, 5),
        ] {
        parts.push(self.path("M\{x1} \{y1} L\{x2} \{y2}", stroke, width="1"))
      }
      parts
    }
    Conditional =>
      [
        self.rect("4", "1", "16", "22", stroke, fill~),
        self.path(
          "M7 6 H17 M7 10 H17 M7 14 H17 M7 18 H17",
          if filled {
            self.paint.color("bg")
          } else {
            stroke
          },
          width="1",
        ),
      ]
    Link => [self.path("M1 8 H13 V2 L23 12 L13 22 V16 H1 Z", stroke, fill~)]
    Signal => [self.path("M12 1 L23 22 H1 Z", stroke, fill~)]
    Error => [self.path("M15 1 L4 13 H11 L8 23 L21 9 H14 Z", stroke, fill~)]
    Escalation => [self.path("M12 1 L23 22 L12 16 L1 22 Z", stroke, fill~)]
    Cancel =>
      [
        self.path(
          "M4 1 L12 9 L20 1 L23 4 L15 12 L23 20 L20 23 L12 15 L4 23 L1 20 L9 12 L1 4 Z",
          stroke,
          fill~,
        ),
      ]
    Compensation =>
      [self.path("M12 2 L1 12 L12 22 Z M23 2 L12 12 L23 22 Z", stroke, fill~)]
    Terminate => [self.circle("12", "12", "10", stroke, fill=stroke)]
  }
}

///|
fn BpmnPaint::event_contents(
  self : BpmnPaint,
  markers : @bpmn.Markers,
  filled : Bool,
  stroke : String,
) -> Array[@writer.Node] {
  if markers.events.length() > 1 && markers.parallel_multiple {
    [self.path("M12 2 V22 M2 12 H22", stroke, width="3")]
  } else if markers.events.length() > 1 {
    [
      self.path(
        "M12 1 L23 9 L19 22 H5 L1 9 Z",
        stroke,
        fill=if filled { stroke } else { self.paint.color("bg") },
      ),
    ]
  } else if markers.events.length() == 1 {
    self.event_symbol(markers.events[0].kind, filled, stroke)
  } else {
    []
  }
}

///|
fn multiple_participants(value : String) -> Bool {
  let digits = value.trim().trim_start(chars="+").trim_start(chars="0")
  digits.length() > 0 &&
  digits.iter().all(c => c >= '0' && c <= '9') &&
  (digits.length() > 1 || digits != "1")
}

///|
fn BpmnPaint::task_symbol(
  self : BpmnPaint,
  kind : @bpmn.NodeKind,
  stroke : String,
) -> Array[@writer.Node] {
  match kind {
    UserTask =>
      [
        self.circle("12", "5", "4", stroke),
        self.path(
          "M4 23 V18 Q4 12 12 12 Q20 12 20 18 V23 M8 16 V23 M16 16 V23", stroke,
        ),
      ]
    ServiceTask =>
      [
        self.path(
          "M9 1 H15 L16 5 L19 7 L23 7 L24 13 L20 15 L19 18 L19 22 L13 24 L10 20 L7 19 L3 20 L1 14 L5 11 L5 8 L4 4 Z",
          stroke,
          fill=self.paint.color("bg"),
        ),
        self.circle("12", "12", "4", stroke),
      ]
    SendTask => self.event_symbol(Message, true, stroke)
    ReceiveTask => self.event_symbol(Message, false, stroke)
    ManualTask =>
      [
        self.path(
          "M2 15 L5 12 L8 14 V3 Q8 0 11 3 V11 V2 Q13 -1 15 2 V11 V4 Q17 1 19 4 V12 V7 Q22 5 23 8 V16 Q22 22 17 24 H10 Q7 22 2 17 Z",
          stroke,
          fill=self.paint.color("bg"),
        ),
      ]
    BusinessRuleTask =>
      [
        self.rect("1", "2", "22", "20", stroke),
        self.path("M1 8 H23 M8 8 V22 M1 14 H23", stroke),
        self.rect("1", "2", "22", "6", stroke, fill=stroke),
      ]
    ScriptTask =>
      [
        self.path(
          "M5 1 H21 Q17 4 20 7 H7 V19 Q6 23 1 23 Q5 20 3 17 H17 Q19 20 16 23 H1 M8 10 H16 M8 14 H16",
          stroke,
        ),
      ]
    _ => []
  }
}

///|
fn BpmnPaint::loop_symbol(
  self : BpmnPaint,
  kind : @bpmn.LoopKind,
  stroke : String,
) -> Array[@writer.Node] {
  match kind {
    None => []
    Standard =>
      [self.path("M18 6 A9 9 0 1 0 21 16 M13 5 H20 V12", stroke, width="2")]
    Sequential => [self.path("M3 5 H21 M3 12 H21 M3 19 H21", stroke, width="2")]
    Parallel => [self.path("M5 3 V21 M12 3 V21 M19 3 V21", stroke, width="2")]
  }
}

///|
fn BpmnPaint::event_border(
  self : BpmnPaint,
  node : @bpmn.Node,
  stroke : String,
) -> Array[@writer.Node] {
  let dash = if !node.markers.interrupting { Some("4 3") } else { None }
  let parts = [
    self.circle(
      "50",
      "50",
      "50",
      stroke,
      fill=self.paint.color("bg"),
      width=if node.kind == EndEvent { "4" } else { "1.5" },
      dash?,
    ),
  ]
  if node.kind == IntermediateCatchEvent ||
    node.kind == IntermediateThrowEvent ||
    node.kind == BoundaryEvent {
    parts.push(self.circle("50", "50", "40", stroke, dash?))
  }
  parts
}

///|
fn BpmnPaint::outline(
  self : BpmnPaint,
  shape : @bpmn_layout.Shape,
) -> @writer.Node {
  let node = shape.node
  let stroke = self.paint.color(
    "\{@bpmn_layout.family(node.kind).name()}-stroke",
  )
  let fill = self.paint.color("\{@bpmn_layout.family(node.kind).name()}-fill")
  let mut normalize = "scale(0.01 0.0125)"
  let parts = match node.kind {
    StartEvent
    | EndEvent
    | IntermediateCatchEvent
    | IntermediateThrowEvent
    | BoundaryEvent => {
      normalize = "scale(0.01 0.01)"
      self.event_border(node, stroke)
    }
    ExclusiveGateway
    | InclusiveGateway
    | ParallelGateway
    | ComplexGateway
    | EventBasedGateway => {
      normalize = "scale(0.01 0.01)"
      [
        self.path(
          "M50 0 L100 50 L50 100 L0 50 Z",
          stroke,
          fill=self.paint.color("bg"),
        ),
      ]
    }
    Participant | Lane =>
      [self.rect("0", "0", "100", "80", stroke, fill=self.paint.color("bg"))]
    Group =>
      [self.rect("0", "0", "100", "80", stroke, radius="10", dash="4 3 1 3")]
    TextAnnotation => [self.path("M12 0 H0 V80 H12", stroke)]
    DataObject | DataObjectReference | DataInput | DataOutput =>
      [
        self.path(
          "M0 0 H75 L100 20 V80 H0 Z M75 0 V20 H100",
          stroke,
          fill=self.paint.color("bg"),
        ),
      ]
    DataStore | DataStoreReference =>
      [
        self.path(
          "M0 12 A50 12 0 0 1 100 12 V68 A50 12 0 0 1 0 68 Z M0 12 A50 12 0 0 0 100 12 M0 18 A50 12 0 0 0 100 18 M0 24 A50 12 0 0 0 100 24",
          stroke,
          fill=self.paint.color("bg"),
        ),
      ]
    Message =>
      [
        self.rect("0", "0", "100", "80", stroke, fill=self.paint.color("bg")),
        self.path("M0 0 L50 45 L100 0", stroke),
      ]
    Transaction =>
      [
        self.rect("0", "0", "100", "80", stroke, fill~, radius="10"),
        self.rect("4", "4", "92", "72", stroke, radius="7"),
      ]
    _ =>
      [
        self.rect(
          "0",
          "0",
          "100",
          "80",
          stroke,
          fill~,
          radius="10",
          weight=if node.kind == CallActivity { "4" } else { "1.5" },
          dash?=if node.markers.event_subprocess { Some("4 3") } else { None },
        ),
      ]
  }
  if @bpmn_layout.activity(node.kind) {
    parts.insert(
      0,
      self.rect(
        "0",
        "0",
        "100",
        "80",
        "none",
        fill=self.paint.color("bg"),
        radius="10",
      ),
    )
  }
  // Stroke widths are user units even when the normalized symbol is resized.
  let normalized = parts.map(part => {
    match part {
      Element(name, attrs, children) =>
        self.element(
          name,
          attrs=attrs
            .iter()
            .concat([("vector-effect", "non-scaling-stroke")].iter())
            .to_array(),
          children~,
        )
      _ => part
    }
  })
  let r = shape.bounds
  self.element(
    "g",
    attrs=[
      (
        "transform",
        "translate(\{r.x.token} \{r.y.token}) scale(\{r.width.token} \{r.height.token})",
      ),
      ("aria-hidden", "true"),
    ],
    children=[
      self.element("g", attrs=[("transform", normalize)], children=normalized),
    ],
  )
}

///|
fn BpmnPaint::markers(
  self : BpmnPaint,
  shape : @bpmn_layout.Shape,
  starts : ArrayView[@bpmn.Node],
) -> Array[@writer.Node] {
  let node = shape.node
  let r = shape.box
  let stroke = self.paint.color(
    "\{@bpmn_layout.family(node.kind).name()}-stroke",
  )
  let parts = []
  fn place(
    x : Double,
    y : Double,
    scale : Double,
    icons : ArrayView[@writer.Node],
  ) -> Unit {
    parts.push(
      self.element(
        "g",
        attrs=[
          ("transform", "translate(\{bn(x)} \{bn(y)}) scale(\{bn(scale)})"),
        ],
        children=icons,
      ),
    )
  }
  if @bpmn_layout.activity(node.kind) {
    let kind = if node.kind == CallActivity {
      node.markers.called_kind.unwrap_or(Task)
    } else {
      node.kind
    }
    place(10.0, 8.0, 0.8, self.task_symbol(kind, stroke))
    if kind == ReceiveTask && node.markers.instantiate {
      parts.push(self.circle("20", "18", "13", stroke))
    }
    let icons : Array[Array[@writer.Node]] = []
    if (
        node.kind == SubProcess ||
        node.kind == AdHocSubProcess ||
        node.kind == Transaction ||
        (
          node.kind == CallActivity &&
          node.markers.called_kind == Some(SubProcess)
        )
      ) &&
      !node.expanded.unwrap_or(false) {
      icons.push([
        self.rect("2", "2", "20", "20", stroke, fill=self.paint.color("bg")),
        self.path("M6 12 H18 M12 6 V18", stroke),
      ])
    }
    if node.markers.compensation {
      icons.push(self.event_symbol(Compensation, false, stroke))
    }
    if node.markers.loop_kind != None {
      icons.push(self.loop_symbol(node.markers.loop_kind, stroke))
    }
    if node.kind == AdHocSubProcess {
      icons.push([self.path("M2 14 Q7 4 12 14 Q17 24 22 14", stroke, width="2")])
    }
    for i, icon in icons {
      place(
        r.width / 2.0 - icons.length().to_double() * 10.0 + i.to_double() * 20.0,
        r.height - 19.0,
        0.65,
        icon,
      )
    }
    if node.markers.event_subprocess && !node.expanded.unwrap_or(false) {
      if starts.length() == 1 {
        let start = starts[0]
        let badge = @bpmn.Node::new("badge", StartEvent, markers=start.markers)
        let border = self.event_border(badge, stroke)
        parts.push(
          self.element(
            "g",
            attrs=[("transform", "translate(5 5) scale(0.24)")],
            children=border,
          ),
        )
        place(
          10.0,
          10.0,
          0.55,
          self.event_contents(start.markers, false, stroke),
        )
      }
    }
  }
  if node.kind == StartEvent ||
    node.kind == EndEvent ||
    node.kind == IntermediateCatchEvent ||
    node.kind == IntermediateThrowEvent ||
    node.kind == BoundaryEvent {
    let filled = node.kind == EndEvent || node.kind == IntermediateThrowEvent
    let size = Double::min(r.width, r.height) * 0.55
    let symbols = self.event_contents(node.markers, filled, stroke)
    place((r.width - size) / 2.0, (r.height - size) / 2.0, size / 24.0, symbols)
  }
  if node.kind == ExclusiveGateway ||
    node.kind == InclusiveGateway ||
    node.kind == ParallelGateway ||
    node.kind == ComplexGateway ||
    node.kind == EventBasedGateway {
    let symbols = match node.kind {
      ExclusiveGateway =>
        if node.geometry.bind(g => g.marker_visible).unwrap_or(true) {
          [self.path("M3 3 L21 21 M21 3 L3 21", stroke, width="3")]
        } else {
          []
        }
      InclusiveGateway => [self.circle("12", "12", "10", stroke, width="2.5")]
      ParallelGateway => [self.path("M12 1 V23 M1 12 H23", stroke, width="3")]
      ComplexGateway =>
        [
          self.path(
            "M12 1 V23 M1 12 H23 M4 4 L20 20 M4 20 L20 4",
            stroke,
            width="2.5",
          ),
        ]
      _ => {
        let parallel = bpmn_detail(node, "eventGatewayType") == Some("Parallel")
        let symbols = [self.circle("12", "12", "11", stroke)]
        if !node.markers.instantiate {
          symbols.push(self.circle("12", "12", "8.5", stroke, width="1"))
        }
        if parallel {
          symbols.push(self.path("M12 5 V19 M5 12 H19", stroke, width="2"))
        } else {
          symbols.push(self.path("M12 5 L19 10 L16 18 H8 L5 10 Z", stroke))
        }
        symbols
      }
    }
    let size = Double::min(r.width, r.height) * 0.55
    place((r.width - size) / 2.0, (r.height - size) / 2.0, size / 24.0, symbols)
  }
  if node.kind == Participant || node.kind == Lane {
    if node.geometry.bind(g => g.horizontal).unwrap_or(true) {
      parts.push(self.path("M30 0 V\{bn(r.height)}", stroke))
    } else {
      parts.push(self.path("M0 30 H\{bn(r.width)}", stroke))
    }
    if node.markers.details
      .iter()
      .any(p => {
        p.0 == "participantMultiplicity/@maximum" && multiple_participants(p.1)
      }) {
      place(
        r.width / 2.0 - 8.0,
        r.height - 18.0,
        0.65,
        self.loop_symbol(Parallel, stroke),
      )
    }
  }
  if node.kind == DataInput || node.kind == DataOutput {
    place(6.0, 6.0, 0.6, [
      self.path(
        "M2 8 H12 V2 L23 12 L12 22 V16 H2 Z",
        stroke,
        fill=if node.kind == DataOutput {
          stroke
        } else {
          self.paint.color("bg")
        },
      ),
    ])
  }
  if node.markers.collection {
    place(
      r.width / 2.0 - 8.0,
      r.height - 17.0,
      0.6,
      self.loop_symbol(Parallel, stroke),
    )
  }
  [
    self.element(
      "g",
      attrs=[
        (
          "transform",
          "translate(\{shape.bounds.x.token} \{shape.bounds.y.token})",
        ),
        ("class", "bpmn-markers"),
      ],
      children=parts,
    ),
  ]
}
