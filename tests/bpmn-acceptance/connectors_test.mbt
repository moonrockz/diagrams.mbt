///|
fn supplied_connector_source(short~ : Bool = false) -> String {
  let corner = if short { "290" } else { "160" }
  "<b:definitions xmlns:b=\"http://www.omg.org/spec/BPMN/20100524/MODEL\" xmlns:bd=\"http://www.omg.org/spec/BPMN/20100524/DI\" xmlns:dc=\"http://www.omg.org/spec/DD/20100524/DC\" xmlns:di=\"http://www.omg.org/spec/DD/20100524/DI\" targetNamespace=\"urn:connectors\"><b:process id=\"P\"><b:task id=\"A\"/><b:task id=\"B\"/><b:sequenceFlow id=\"AB\" sourceRef=\"A\" targetRef=\"B\"/></b:process><bd:BPMNDiagram id=\"D\"><bd:BPMNPlane id=\"Plane\" bpmnElement=\"P\"><bd:BPMNShape bpmnElement=\"A\"><dc:Bounds x=\"20\" y=\"40\" width=\"100\" height=\"80\"/></bd:BPMNShape><bd:BPMNShape bpmnElement=\"B\"><dc:Bounds x=\"300\" y=\"140\" width=\"100\" height=\"80\"/></bd:BPMNShape><bd:BPMNEdge bpmnElement=\"AB\"><di:waypoint x=\"120\" y=\"80\"/><di:waypoint x=\"\{corner}\" y=\"80\"/><di:waypoint x=\"\{corner}\" y=\"180\"/><di:waypoint x=\"300\" y=\"180\"/></bd:BPMNEdge></bd:BPMNPlane></bd:BPMNDiagram></b:definitions>"
}

///|
test "supplied connector display styling preserves source waypoints and writing" {
  let document = @bpmn.read(supplied_connector_source()).document.unwrap()
  let before = @bpmn.write(document)
  let diagram = @adapter.to_diagram(document).diagram.unwrap()
  guard diagram is Bpmn(view) else { fail("BPMN required") }
  let original = @bpmn_layout.layout(view, policy=RequireDi).geometry.unwrap()
  for policy in [@model.GeometryPolicy::PreferDi, RequireDi] {
    let unstyled = @svg.SvgRenderer::new(
      bpmn_policy=policy,
      connectors=@svg.ConnectorOptions::new(style=Curved),
    ).render(diagram)
    assert_true(
      unstyled.output is Some(_),
      msg=@debug.to_string(unstyled.diagnostics),
    )
    let unchanged = @svg.inspect_connectors(unstyled.output.unwrap())
    assert_true(unchanged.iter().all(p => p.route == p.path && p.mask is None))
    let styled = @svg.SvgRenderer::new(
      bpmn_policy=policy,
      connectors=@svg.ConnectorOptions::new(
        style=Curved,
        style_supplied_bpmn=true,
      ),
    ).render(diagram)
    assert_true(
      styled.output is Some(_),
      msg=@debug.to_string(styled.diagnostics),
    )
    let paths = @svg.inspect_connectors(styled.output.unwrap())
    assert_true(paths[0].path.svg().contains("C"))
    assert_eq(paths[0].route, unchanged[0].route)
    assert_eq(
      original,
      @bpmn_layout.layout(view, policy=RequireDi).geometry.unwrap(),
    )
  }
  assert_eq(@bpmn.write(document), before)
}

///|
test "unstyled supplied connectors honor caller work and output limits" {
  let document = @bpmn.read(supplied_connector_source()).document.unwrap()
  let before = @bpmn.write(document)
  let diagram = @adapter.to_diagram(document).diagram.unwrap()
  for policy in [@model.GeometryPolicy::PreferDi, RequireDi] {
    for
      limits in [
        @svg.ConnectorLimits::new(segments=0),
        @svg.ConnectorLimits::new(output_units=1),
      ] {
      let rendered = @svg.SvgRenderer::new(
        bpmn_policy=policy,
        connectors=@svg.ConnectorOptions::new(style=Curved, limits~),
      ).render(diagram)
      assert_true(rendered.output is None)
      assert_true(
        rendered.diagnostics.iter().any(d => d.code == "connector/limit"),
      )
    }
  }
  assert_eq(@bpmn.write(document), before)
}

///|
test "unsafe styling refuses a short imported terminal without moving supplied geometry" {
  let document = @bpmn.read(supplied_connector_source(short=true)).document.unwrap()
  let before = @bpmn.write(document)
  let diagram = @adapter.to_diagram(document).diagram.unwrap()
  assert_true(
    @svg.SvgRenderer::new(bpmn_policy=RequireDi).render(diagram).output
    is Some(_),
  )
  let result = @svg.SvgRenderer::new(
    bpmn_policy=RequireDi,
    connectors=@svg.ConnectorOptions::new(
      style=Curved,
      style_supplied_bpmn=true,
    ),
  ).render(diagram)
  assert_true(result.output is None)
  assert_true(
    result.diagnostics.iter().any(d => d.code == "connector/routing-conflict"),
  )
  assert_eq(@bpmn.write(document), before)
}

///|
test "explicit supplied display styling rejects a pre-existing unrelated collision" {
  let source = supplied_connector_source()
    .replace_all(
      old="<b:task id=\"B\"/>",
      new="<b:task id=\"B\"/><b:task id=\"C\"/>",
    )
    .replace_all(
      old="x=\"20\" y=\"40\" width=\"100\" height=\"80\"",
      new="x=\"20\" y=\"80\" width=\"100\" height=\"60\"",
    )
    .replace_all(
      old="x=\"300\" y=\"140\" width=\"100\" height=\"80\"",
      new="x=\"400\" y=\"80\" width=\"100\" height=\"60\"",
    )
    .replace_all(
      old="<bd:BPMNEdge",
      new="<bd:BPMNShape bpmnElement=\"C\"><dc:Bounds x=\"210\" y=\"80\" width=\"50\" height=\"60\"/></bd:BPMNShape><bd:BPMNEdge",
    )
    .replace_all(old="x=\"120\" y=\"80\"", new="x=\"120\" y=\"110\"")
    .replace_all(old="x=\"160\" y=\"80\"", new="x=\"160\" y=\"110\"")
    .replace_all(old="x=\"160\" y=\"180\"", new="x=\"360\" y=\"110\"")
    .replace_all(old="x=\"300\" y=\"180\"", new="x=\"400\" y=\"110\"")
  let document = @bpmn.read(source).document.unwrap()
  let diagram = @adapter.to_diagram(document).diagram.unwrap()
  assert_true(
    @svg.SvgRenderer::new(bpmn_policy=RequireDi).render(diagram).output
    is Some(_),
  )
  let styled = @svg.SvgRenderer::new(
    bpmn_policy=RequireDi,
    connectors=@svg.ConnectorOptions::new(
      style=Curved,
      style_supplied_bpmn=true,
    ),
  ).render(diagram)
  assert_true(styled.output is None)
  assert_true(
    styled.diagnostics.iter().any(d => d.code == "connector/routing-conflict"),
  )
}

///|
test "supplied curves protect endpoint labels separately from outline attachment" {
  let source =
    #|<b:definitions xmlns:b="http://www.omg.org/spec/BPMN/20100524/MODEL" xmlns:bd="http://www.omg.org/spec/BPMN/20100524/DI" xmlns:dc="http://www.omg.org/spec/DD/20100524/DC" xmlns:di="http://www.omg.org/spec/DD/20100524/DI" targetNamespace="urn:probe">
    #|<b:process id="Process"><b:task id="a"/><b:task id="b" name="B"/><b:sequenceFlow id="f" sourceRef="a" targetRef="b"/></b:process>
    #|<bd:BPMNDiagram id="D"><bd:BPMNPlane id="P" bpmnElement="Process">
    #|<bd:BPMNShape bpmnElement="a"><dc:Bounds x="20" y="190" width="20" height="20"/></bd:BPMNShape>
    #|<bd:BPMNShape bpmnElement="b"><dc:Bounds x="400" y="90" width="20" height="20"/><bd:BPMNLabel><dc:Bounds x="180" y="178" width="15" height="20"/></bd:BPMNLabel></bd:BPMNShape>
    #|<bd:BPMNEdge bpmnElement="f"><di:waypoint x="40" y="200"/><di:waypoint x="200" y="200"/><di:waypoint x="200" y="100"/><di:waypoint x="400" y="100"/></bd:BPMNEdge>
    #|</bd:BPMNPlane></bd:BPMNDiagram></b:definitions>
  let model = @adapter.to_diagram(@bpmn.read(source).document.unwrap()).diagram.unwrap()
  let rendered = @svg.SvgRenderer::new(
    bpmn_policy=RequireDi,
    connectors=@svg.ConnectorOptions::new(
      style=Rounded,
      corner_radius=50.0,
      style_supplied_bpmn=true,
    ),
  ).render(model)
  let paths = rendered.output.map(@svg.inspect_connectors).unwrap_or([])
  assert_true(
    rendered.output is Some(_),
    msg=@debug.to_string(rendered.diagnostics),
  )
  assert_eq(
    @svg.check_connectors(
      paths[:],
      [{ owner: "label:b", x: 180.0, y: 178.0, width: 15.0, height: 20.0, }],
      width=1000.0,
      height=1000.0,
    ),
    [],
  )
  assert_true(paths[0].path.svg().contains("Q"))
}
