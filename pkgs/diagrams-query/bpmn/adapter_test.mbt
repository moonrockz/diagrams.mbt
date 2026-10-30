///|
let model_uri = "http://www.omg.org/spec/BPMN/20100524/MODEL"

///|
/// A document with nested activities, DI, vendor content, comments, a PI,
/// duplicate IDs, a sequence-flow cycle, CRLF and non-BMP text.
let source : String =
  "<?xml version='1.0'?>\r\n<!-- head \u{1D518} -->\r\n" +
  "<b:definitions xmlns:b='\{model_uri}' xmlns:di='http://www.omg.org/spec/BPMN/20100524/DI' xmlns:v='urn:v' targetNamespace='urn:t'>\r\n" +
  "<b:process id='P'>\r\n" +
  "  <b:userTask id='A' name='Approve'/>\r\n" +
  "  <b:serviceTask id='S'/>\r\n" +
  "  <b:subProcess id='Sub' name=''>\r\n" +
  "    <b:userTask id='Inner' name='Approve'/>\r\n" +
  "  </b:subProcess>\r\n" +
  "  <b:task id='D'/>\r\n" +
  "  <b:task id='D'/>\r\n" +
  "  <b:sequenceFlow id='F1' sourceRef='A' targetRef='S'/>\r\n" +
  "  <b:sequenceFlow id='F2' sourceRef='S' targetRef='A'/>\r\n" +
  "  <b:extensionElements><v:userTask v:flag='on'>text<!--c--><?pi data?></v:userTask></b:extensionElements>\r\n" +
  "</b:process>\r\n" +
  "<di:BPMNDiagram id='Dia'/>\r\n" +
  "</b:definitions>\r\n<?end done?>"

///|
fn tree_of(text : String, source_id? : String = "memory:q") -> @bpmn.BpmnTree {
  let document = @model.read(text, source_id~).document.unwrap()
  @bpmn.BpmnTree::new(@model.DocumentTree::new(document).tree.unwrap())
}

///|
fn ids(tree : @bpmn.BpmnTree, query : String) -> String {
  let plan = @bpmn.compile(query, namespaces=[("v", "urn:v")]).unwrap()
  let result = plan.collect(tree)
  let rows = result.matches.map(m => {
    let captures = m.captures.map(c => {
      let node = tree.captured(c)
      let label = match node.id() {
        Some(id) => id
        None => @bpmn.category_name(node.category())
      }
      "\{c.name}=\{label}"
    })
    "\{m.pattern}: " + captures.iter().join(" ")
  })
  rows.iter().join("\n") + "\n" + (if result.outcome is Complete { "complete" } else { "incomplete" })
}

///|
test "the design examples run against the BPMN adapter" {
  let tree = tree_of(source)
  // Candidate roots include nested activities.
  inspect(
    ids(tree, "((bpmn.userTask) @task\n  (#attr-eq? @task \"name\" \"Approve\"))"),
    content=(
      #|0: task=A
      #|0: task=Inner
      #|complete
    ),
  )
  // A named field constrains direct children only.
  inspect(
    ids(tree, "(bpmn.process\n  bpmn.flowElement: (bpmn.userTask) @task) @process"),
    content=(
      #|0: task=A process=P
      #|complete
    ),
  )
  inspect(
    ids(tree, "[ (bpmn.userTask) (bpmn.serviceTask) ] @task"),
    content=(
      #|0: task=A
      #|0: task=S
      #|0: task=Inner
      #|complete
    ),
  )
  inspect(
    ids(tree, "((category.activity) @activity\n  (#missing-attr? @activity \"name\"))"),
    content=(
      #|0: activity=S
      #|0: activity=D
      #|0: activity=D
      #|complete
    ),
  )
  // Missing and empty names differ.
  inspect(
    ids(tree, "((category.activity) @a (#attr-eq? @a \"name\" \"\"))"),
    content=(
      #|0: a=Sub
      #|complete
    ),
  )
}

///|
test "complete document content is queryable and namespaces stay distinct" {
  let tree = tree_of(source)
  inspect(
    ids(tree, "(category.comment) @c (category.processing-instruction) @p (category.document) @d"),
    content=(
      #|2: d=document
      #|0: c=comment
      #|0: c=comment
      #|1: p=processing-instruction
      #|1: p=processing-instruction
      #|complete
    ),
  )
  // The vendor userTask has the same local name in another namespace.
  inspect(ids(tree, "(v.userTask) @v"), content=(
    #|0: v=extension
    #|complete
  ))
  inspect(
    ids(tree, "((v.userTask) @v (#attr-eq? @v \"v:flag\" \"on\"))"),
    content=(
      #|0: v=extension
      #|complete
    ),
  )
  inspect(ids(tree, "(bpmndi.BPMNDiagram) @d"), content=(
    #|0: d=Dia
    #|complete
  ))
  // Text, comment and PI children of the vendor element keep their order.
  inspect(
    ids(tree, "((v.userTask (category.text) @t (category.comment) @c (category.processing-instruction) @p) (#text-eq? @t \"text\") (#text-eq? @p \"data\"))"),
    content=(
      #|0: t=text c=comment p=processing-instruction
      #|complete
    ),
  )
  // A different query prefix for the same URI selects the same nodes.
  let plan = @query.compile("(m.userTask) @t", @bpmn.schema, namespaces=[
    ("m", model_uri),
  ]).unwrap()
  assert_eq(
    plan.collect(tree).matches.map(m => m.captures[0].node),
    @bpmn.compile("(bpmn.userTask) @t").unwrap().collect(tree).matches.map(m => m.captures[0].node),
  )
  // Reserved names must exist; open extension names need not.
  inspect(
    @bpmn.compile("(bpmn.userTaskX)").map_err(d => d[0].code).unwrap_err(),
    content="query/unknown-kind",
  )
  inspect(@bpmn.compile("(v.anything v.child: (_))", namespaces=[("v", "urn:v")]) is Ok(_), content="true")
}

///|
test "query captures and walks identify the same nodes" {
  let tree = tree_of(source)
  let walked : Array[@model.NodeRef] = []
  @model.walk(tree.tree.root(), n => {
    if n.id() == Some("Inner") {
      walked.push(n)
    }
    Continue
  })
  let projection = @query.Projection::new(@bpmn.schema, [
    Extra("id"),
    Attribute("name"),
    Location,
    Path,
    Field,
    Kind,
    Category,
  ]).unwrap()
  let result = @bpmn.compile("((bpmn.userTask) @t (#attr-eq? @t \"id\" \"Inner\"))")
    .unwrap()
    .collect(tree, projection~)
  let node = tree.captured(result.matches[0].captures[0])
  assert_eq(node, walked[0])
  assert_eq(node.handle(), walked[0].handle())
  assert_eq(tree.index(walked[0]), Some(result.matches[0].captures[0].node))
  let values = result.matches[0].captures[0].values
  debug_inspect(values[0], content=(
    #|Scalar({ tag: "identifier", text: "Inner" })
  ))
  debug_inspect(values[1], content=(
    #|Scalar({ tag: "text", text: "Approve" })
  ))
  // Locations are UTF-16 with one break per CRLF, after a non-BMP comment.
  let location = node.location().unwrap()
  debug_inspect(
    values[2],
    content=(
      #|Location(
      #|  {
      #|    source_id: Some("memory:q"),
      #|    start: { offset: 329, line: 8, column: 5 },
      #|    end: { offset: 368, line: 8, column: 44 },
      #|  },
      #|)
    ),
  )
  assert_eq(location.start.offset, source.find("<b:userTask id='Inner'").unwrap())
  assert_eq(location.start.line, 8)
  debug_inspect(values[4], content=(
    #|Name(
    #|  {
    #|    namespace_uri: "http://www.omg.org/spec/BPMN/20100524/MODEL",
    #|    local_name: "flowElement",
    #|  },
    #|)

  ))
  debug_inspect(values[6], content=(
    #|Text("activity")
  ))
  guard values[3] is Path(steps) else { fail("no path") }
  assert_eq(steps.length(), node.path().steps().length())
  for i, step in node.path().steps() {
    assert_eq(steps[i].field, @bpmn.field_name(step.field))
    assert_eq(steps[i].index, step.index)
    assert_eq(steps[i].position, step.content_index)
  }
}

///|
test "constructed documents are queryable without locations" {
  let task = @model.Element::new(UserTask, attributes=[("id", "T"), ("name", "Approve")])
  let process = @model.Element::new(Process, attributes=[("id", "P")], children=[task])
  let definitions = @model.Element::new(
    Definitions,
    attributes=[("targetNamespace", "urn:t")],
    children=[process],
  )
  let document = @model.Document::new(definitions)
  let tree = @bpmn.BpmnTree::new(@model.DocumentTree::new(document).tree.unwrap())
  inspect(ids(tree, "(bpmn.process bpmn.flowElement: (bpmn.userTask) @t)"), content=(
    #|0: t=T
    #|complete
  ))
  let projection = @query.Projection::new(@bpmn.schema, [Location]).unwrap()
  let result = @bpmn.compile("(bpmn.userTask) @t").unwrap().collect(tree, projection~)
  debug_inspect(result.matches[0].captures[0].values[0], content="Absent")
}

///|
test "handles of another revision are not reused" {
  let a = tree_of(source)
  // BPMN revision identity follows the source: equal text is one revision,
  // and a changed source is another.
  let same = tree_of(source)
  let changed = tree_of(source.replace(old="name='Approve'", new="name=\"Approve\""))
  let node = a.captured(
    @bpmn.compile("(bpmn.userTask) @t").unwrap().collect(a).matches[0].captures[0],
  )
  assert_eq(a.index(node), Some(node.handle().ordinal))
  assert_eq(same.index(node), Some(node.handle().ordinal))
  assert_eq(changed.index(node), None)
  // The same query still finds the corresponding node in the new revision,
  // with a distinct handle.
  let rebuilt = changed.captured(
    @bpmn.compile("(bpmn.userTask) @t").unwrap().collect(changed).matches[0].captures[0],
  )
  assert_true(rebuilt.handle() != node.handle())
  assert_true(changed.tree.lookup(node.handle()) is DocumentMismatch)
  let other_resource = @bpmn.BpmnTree::new(
    @model.DocumentTree::new(
      @model.read(source).document.unwrap(),
      resource_id="other",
    ).tree.unwrap(),
  )
  assert_eq(other_resource.index(node), None)
}

///|
test "containment matching ignores the sequence-flow cycle" {
  let tree = tree_of(source)
  inspect(
    ids(tree, "[(bpmn.userTask) (bpmn.serviceTask)] @t (bpmn.sequenceFlow (_) @target)"),
    content=(
      #|0: t=A
      #|0: t=S
      #|0: t=Inner
      #|complete
    ),
  )
}

///|
test "captured handles feed explicit graph operations" {
  let document = @model.read(source).document.unwrap()
  let tree = @bpmn.BpmnTree::new(@model.DocumentTree::new(document).tree.unwrap())
  let graph = @model.DocumentGraph::new(document).graph.unwrap()
  let result = @bpmn.compile("((bpmn.task) @t (#attr-eq? @t \"id\" \"D\"))").unwrap().collect(tree)
  inspect(result.matches.length(), content="2")
  let second = tree.captured(result.matches[1].captures[0])
  // A handle endpoint names exactly the captured node.
  match graph.lookup(Node(second.handle())) {
    Ok(Document(node)) => assert_eq(node.handle(), second.handle())
    _ => fail("unexpected lookup")
  }
  // An ID-only lookup still reports the ambiguity.
  assert_true(graph.lookup(Id("D")) is Err(Ambiguous(_)))
  // Reachability over the captured start keeps the default edge kinds.
  let start = tree.captured(
    @bpmn.compile("((bpmn.userTask) @t (#attr-eq? @t \"id\" \"A\"))").unwrap().collect(tree).matches[0].captures[0],
  )
  match graph.reachable(Node(start.handle())) {
    Complete(nodes) => inspect(nodes.map(n => n.id().unwrap()).iter().join(","), content="A,S")
    Failed(_) => fail("reachability failed")
  }
  assert_true(graph.route(Node(start.handle()), Id("S")) is Found(_))
  assert_true(
    graph.reachable(Node(start.handle()), limits=@model.GraphLimits::new(nodes=1)) is Failed(Limit(Nodes)),
  )
}

///|
test "typed forms compile with the default prefixes" {
  let form = @query.QueryForm::new([
    @query.Rule::new(
      @query.Pattern::node(
        Kind(@query.QName::new("userTask", prefix="bpmn")),
        captures=["task"],
      ),
      predicates=[@query.Predicate::attr_eq("task", "name", "Approve")],
    ),
  ])
  let typed = @bpmn.compile_form(form).unwrap()
  let text = @bpmn.compile(
    "((bpmn.userTask) @task (#attr-eq? @task \"name\" \"Approve\"))",
  ).unwrap()
  assert_eq(typed.normalized(), text.normalized())
  let tree = tree_of(source)
  assert_eq(typed.collect(tree), text.collect(tree))
}
