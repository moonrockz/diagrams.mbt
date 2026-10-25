///|
fn minimal() -> @render.Diagram {
  @adapter.to_diagram(@bpmn.read(@corpus.inputs[5].source).document.unwrap()).diagram.unwrap()
}

///|
fn supplied(name : String) -> @render.Diagram {
  let input = @corpus.render_inputs
    .iter()
    .find_first(i => i.name == name)
    .unwrap()
  @adapter.to_diagram(@bpmn.read(input.source).document.unwrap()).diagram.unwrap()
}

///|
fn exchange() -> @sequence.Sequence {
  @sequence.Sequence::new(
    [
      @sequence.Participant::new("A", label="Client"),
      @sequence.Participant::new("B", label="API"),
    ],
    [
      Message(@sequence.Message::new("A", "B", "request")),
      Message(@sequence.Message::new("B", "B", "self")),
      Message(@sequence.Message::new("B", "A", "reply")),
    ],
    title="Request and reply",
  )
}

///|
fn finite_exchange() -> (@sequence.Sequence, @animation.PlaybackPlan) {
  let message = fn(
    sender : String,
    receiver : String,
    label : String,
  ) -> @sequence.Event {
    Message(@sequence.Message::new(sender, receiver, label))
  }
  let sequence = @sequence.Sequence::new(
    [@sequence.Participant::new("A"), @sequence.Participant::new("B")],
    [
      message("A", "B", "request"),
      Frame(
        @sequence.Frame::new(
          Alt,
          @sequence.Section::new([message("B", "A", "found")], label="found"),
          rest=[
            @sequence.Section::new(
              [message("A", "A", "missing")],
              label="missing",
            ),
          ],
        ),
      ),
      Frame(
        @sequence.Frame::new(
          Loop,
          @sequence.Section::new(
            [message("A", "B", "retry")],
            label="explicit repetitions",
          ),
        ),
      ),
      Frame(
        @sequence.Frame::new(
          Par,
          @sequence.Section::new([
            message("A", "B", "left 1"),
            message("B", "A", "left 2"),
          ]),
          rest=[@sequence.Section::new([message("A", "B", "right")])],
        ),
      ),
      message("B", "A", "done"),
    ],
    title="Finite chosen scenario",
  )
  let catalog = @animation.Catalog::sequence(
    sequence,
    view_id="Finite exchange",
  ).catalog.unwrap()
  let choices = [
    @animation.Selection::new(catalog.frames[0].key, Alternative(1)),
    @animation.Selection::new(catalog.frames[1].key, Repetitions(2)),
  ]
  (
    sequence,
    @animation.PlaybackPlan::sequence(catalog, selections=choices).plan.unwrap(),
  )
}

///|
fn chain() -> @render.Diagram {
  Bpmn(
    @model.Bpmn::new(
      "Chain",
      [
        @model.Node::new("A", Task, label="A"),
        @model.Node::new("B", Task, label="B"),
        @model.Node::new("C", Task, label="C"),
      ],
      [@model.Flow::new("AB", "A", "B"), @model.Flow::new("BC", "B", "C")],
    ),
  )
}

///|
fn cyclic() -> @render.Diagram {
  Bpmn(
    @model.Bpmn::new(
      "Cycle",
      [
        @model.Node::new("A", Task, label="A"),
        @model.Node::new("B", Task, label="B"),
        @model.Node::new("C", Task, label="C"),
        @model.Node::new("D", Task, label="D"),
      ],
      [
        @model.Flow::new("AB", "A", "B"),
        @model.Flow::new("AC", "A", "C"),
        @model.Flow::new("BD", "B", "D"),
        @model.Flow::new("CD", "C", "D"),
        @model.Flow::new("DA", "D", "A"),
      ],
    ),
  )
}

///|
fn hostile() -> @sequence.Sequence {
  let text = "</script><img src=x onerror=globalThis.motionPwned=1> 😀 & \"quoted\"\u2028\u2029"
  let link = @sequence.Link::new(Smithy, "javascript:globalThis.motionPwned=2")
  @sequence.Sequence::new(
    [
      @sequence.Participant::new("A", label=text),
      @sequence.Participant::new("B"),
    ],
    [Message(@sequence.Message::new("A", "B", text, link~))],
    title=text,
  )
}

///|
fn swimlane(direction : @swimlane.Direction) -> @swimlane.Swimlane {
  let direction = match direction {
    TB => "TB"
    BT => "BT"
    LR => "LR"
    RL => "RL"
  }
  let source = "swimlane-beta \{direction}\n  subgraph Customer[Customer requests and corrections]\n    A([Request])\n  end\n  subgraph Support[Support review]\n    B{Review}\n    C((Complete))\n  end\n  A AB@<-->|review or return| B\n  B BC@-->|approve| C\n  C CA@---|related| A\n  A parallel@-.->|expedite| B\n  A constraint@~~~ C\n"
  guard @mermaid.read_diagram(source).ast is Some(Swimlane(ast)) else {
    abort("Native review source did not parse")
  }
  @mermaid.to_swimlane(ast, id="Review").swimlane.unwrap()
}

///|
fn reverse_swimlane() -> (@render.Diagram, @animation.PlaybackPlan) {
  let view = swimlane(LR)
  let catalog = @animation.Catalog::swimlane(view).catalog.unwrap()
  let plan = @animation.PlaybackPlan::scenario(
    catalog,
    OrientedStep(catalog.connection("AB").unwrap().key, 1000L, true),
  ).plan.unwrap()
  (Swimlane(view), plan)
}

///|
fn scenario_swimlane() -> (@render.Diagram, @animation.PlaybackPlan) {
  let view = swimlane(LR)
  let catalog = @animation.Catalog::swimlane(view).catalog.unwrap()
  let a = catalog.connection("AB").unwrap().key
  let b = catalog.connection("BC").unwrap().key
  let playback = @animation.PlaybackPlan::scenario(
    catalog,
    @animation.Motion::serial([
      @animation.Motion::parallel([Step(a, 1000L), OrientedStep(a, 1000L, true)]),
      Step(b, 750L),
    ]),
  ).plan.unwrap()
  (Swimlane(view), playback)
}

///|
fn identity_swimlane() -> @render.Diagram {
  let source = "swimlane-beta LR\nsubgraph Handoff\nA\nend\nsubgraph Receiver\nB\nend\nA Handoff@--> B\n"
  guard @mermaid.read_diagram(source).ast is Some(Swimlane(ast)) else {
    abort("Missing identity fixture AST")
  }
  Swimlane(@mermaid.to_swimlane(ast, id="Identity").swimlane.unwrap())
}

///|
test "nested flow-map shape data follows the pinned native refusal" {
  let source = "swimlane-beta\nA@{\n  shape: rect\n  label: Request\n  metadata: {\n    a: one,\n    b: two\n  }\n  extra: true\n}\nA --> B\n"
  let result = @mermaid.read_diagram(source)
  assert_eq(result.tree.text(), source)
  assert_true(result.diagnostics.iter().any(d => d.severity == Error))
  assert_eq(@mermaid.render_svg(source).output, None)
}

///|
test "native indented nested metadata prints as valid native shape data" {
  let source = "swimlane-beta\nA@{\n  shape: rect\n  label: Request\n  metadata:\n    a: one\n    b: two\n  extra: true\n}\nA --> B\n"
  let result = @mermaid.read_diagram(source)
  assert_true(
    result.diagnostics.iter().all(d => d.severity != Error),
    msg=@debug.to_string(result.diagnostics),
  )
  guard result.ast is Some(parsed) else { fail("missing native AST") }
  let printed = @mermaid.print_diagram(parsed)
  assert_true(
    printed.output is Some(_),
    msg=@debug.to_string(printed.diagnostics),
  )
  assert_eq(@mermaid.read_diagram(printed.output.unwrap()).ast, Some(parsed))
}

///|
fn collapsed_swimlane() -> @render.Diagram {
  Swimlane(
    @swimlane.Swimlane::new(
      "Collapsed",
      [
        @swimlane.Node::new("Hidden", lane="L", groups=["G"]),
        @swimlane.Node::new("Visible", lane="L"),
      ],
      [@swimlane.Connection::new("Handoff", "Hidden", "Visible")],
      lanes=[@swimlane.Lane::new("L")],
      groups=[@swimlane.Group::new("G", lane="L", expanded=false)],
    ),
  )
}

///|
test "standalone HTML scenes and validated plans have exact portable bytes" {
  let snapshots : Array[Json] = []
  let (reverse_diagram, reverse_plan) = reverse_swimlane()
  let (scenario_diagram, scenario_plan) = scenario_swimlane()
  let (finite, playback) = finite_exchange()
  let empty = @sequence.Sequence::new([], [], title="Empty finite scenario")
  let empty_catalog = @animation.Catalog::sequence(empty).catalog.unwrap()
  let empty_plan = @animation.PlaybackPlan::scenario(
    empty_catalog,
    @animation.Motion::serial([]),
  ).plan.unwrap()
  let bpmn_diagram = minimal()
  guard bpmn_diagram is Bpmn(bpmn_view) else { fail("fixture kind") }
  let bpmn_catalog = @animation.Catalog::bpmn(bpmn_view).catalog.unwrap()
  let first = bpmn_catalog.flow("Flow_1").unwrap().key
  let second = bpmn_catalog.flow("Flow_2").unwrap().key
  let concurrent = @animation.PlaybackPlan::scenario(
    bpmn_catalog,
    @animation.Motion::serial([
      @animation.Motion::parallel([Step(first, 1000L), Step(first, 500L)]),
      Step(second, 750L),
    ]),
  ).plan.unwrap()
  let chain_diagram = chain()
  guard chain_diagram is Bpmn(chain_view) else { fail("fixture kind") }
  let chain_catalog = @animation.Catalog::bpmn(chain_view).catalog.unwrap()
  let one_step = @animation.PlaybackPlan::scenario(
    chain_catalog,
    Step(chain_catalog.flow("AB").unwrap().key, 1000L),
  ).plan.unwrap()
  for
    (name, diagram, renderer) in [
      (
        "bpmn-collaboration-dark",
        supplied("collaboration-di.bpmn"),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(mode=Fixed(Dark)),
        ),
      ),
      (
        "bpmn-collaboration-light",
        supplied("collaboration-di.bpmn"),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(mode=Fixed(Light)),
        ),
      ),
      (
        "sequence-scenario-dark",
        Sequence(finite),
        @animated.AnimatedRenderer::new(
          playback~,
          svg=@svg.SvgRenderer::new(mode=Fixed(Dark)),
        ),
      ),
      (
        "sequence-scenario-light",
        Sequence(finite),
        @animated.AnimatedRenderer::new(
          playback~,
          svg=@svg.SvgRenderer::new(mode=Fixed(Light)),
        ),
      ),
      ("swimlane-tb", Swimlane(swimlane(TB)), @animated.AnimatedRenderer::new()),
      ("swimlane-bt", Swimlane(swimlane(BT)), @animated.AnimatedRenderer::new()),
      ("swimlane-lr", Swimlane(swimlane(LR)), @animated.AnimatedRenderer::new()),
      ("swimlane-rl", Swimlane(swimlane(RL)), @animated.AnimatedRenderer::new()),
      (
        "swimlane-review-dark",
        Swimlane(swimlane(LR)),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(mode=Fixed(Dark)),
        ),
      ),
      (
        "swimlane-review-light",
        Swimlane(swimlane(LR)),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(mode=Fixed(Light)),
        ),
      ),
      (
        "swimlane-scenario",
        scenario_diagram,
        @animated.AnimatedRenderer::new(playback=scenario_plan),
      ),
      (
        "swimlane-reverse",
        reverse_diagram,
        @animated.AnimatedRenderer::new(playback=reverse_plan),
      ),
      (
        "swimlane-identity",
        identity_swimlane(),
        @animated.AnimatedRenderer::new(),
      ),
      (
        "swimlane-collapsed",
        collapsed_swimlane(),
        @animated.AnimatedRenderer::new(),
      ),
      ("bpmn-default", minimal(), @animated.AnimatedRenderer::new()),
      ("bpmn-cyclic", cyclic(), @animated.AnimatedRenderer::new()),
      (
        "bpmn-concurrent",
        bpmn_diagram,
        @animated.AnimatedRenderer::new(playback=concurrent),
      ),
      (
        "bpmn-supplied",
        supplied("collaboration-di.bpmn"),
        @animated.AnimatedRenderer::new(),
      ),
      (
        "bpmn-automatic",
        supplied("process-di.bpmn"),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(bpmn_policy=Automatic),
        ),
      ),
      (
        "sequence-default",
        @render.Diagram::Sequence(exchange()),
        @animated.AnimatedRenderer::new(),
      ),
      (
        "sequence-finite",
        Sequence(finite),
        @animated.AnimatedRenderer::new(playback~),
      ),
      ("hostile", Sequence(hostile()), @animated.AnimatedRenderer::new()),
      (
        "plan-limit",
        chain_diagram,
        @animated.AnimatedRenderer::new(
          playback=one_step,
          limits=@animation.Limits::new(steps=1),
        ),
      ),
      (
        "query-limit",
        chain(),
        @animated.AnimatedRenderer::new(
          query_limits=@animation.Limits::new(nodes=1),
        ),
      ),
      (
        "prefix-a",
        minimal(),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(id_prefix="A", mode=Fixed(Dark)),
        ),
      ),
      (
        "prefix-b",
        minimal(),
        @animated.AnimatedRenderer::new(
          svg=@svg.SvgRenderer::new(id_prefix="B", mode=Fixed(Light)),
        ),
      ),
      (
        "empty-finite",
        Sequence(empty),
        @animated.AnimatedRenderer::new(playback=empty_plan),
      ),
    ] {
    let result = renderer.render(diagram)
    assert_eq(result.media_type, "text/html")
    assert_true(
      result.output != None,
      msg="\{name}: \{@debug.to_string(result.diagnostics)}",
    )
    assert_true(
      result.diagnostics.iter().all(d => d.severity != Error),
      msg="\{name}: \{@debug.to_string(result.diagnostics)}",
    )
    let html = result.output.unwrap()
    assert_true(html.contains("data-diagram-viewer"))
    assert_true(html.contains("data-control=\"seek\""))
    assert_eq(html.split("</script>").count(), 3)
    assert_false(html.contains("<img"))
    assert_false(html.contains("<iframe"))
    let canonical = renderer.svg.render(diagram).output.unwrap()
    let scene = renderer.svg.scene(
      diagram,
      sequence_view_id=renderer.playback
        .map(p => p.view_id)
        .unwrap_or("sequence"),
    ).scene.unwrap()
    let pure = renderer.playback.unwrap_or_else(() => {
      @animation.PlaybackPlan::illustrative(scene.catalog).plan.unwrap()
    })
    let times = [0L, 250L, 750L, 1000L, 1250L, 4500L, 5500L, 7000L].filter(t => {
      t <= pure.duration_ms
    })
    if !times.contains(pure.duration_ms) {
      times.push(pure.duration_ms)
    }
    let samples = times.map(t => {
      let sample = pure.sample_at(t)
      let active = sample.active
        .iter()
        .map(a => {
          Json([
            Json(a.ordinal),
            Json(a.key),
            Json(a.numerator.to_string()),
            Json(a.denominator.to_string()),
          ])
        })
        .to_array()
      Json([
        Json(t.to_string()),
        Json(sample.elapsed_ms.to_string()),
        Json(sample.finished),
        Json(active),
      ])
    })
    let endpoints = scene.catalog.graph.nodes.filter(n => {
      match n.kind {
        Bpmn(_) | Message | SwimlaneNode => true
        _ => false
      }
    })
    let query = if endpoints.length() > 0 {
      let from = endpoints[0].id
      let to = endpoints[endpoints.length() - 1].id
      let result = scene.catalog.graph.route(
        from,
        to,
        limits=renderer.query_limits,
      )
      let (status, keys) = match result {
        Found(route) =>
          match
            @animation.PlaybackPlan::route(
              scene.catalog,
              route,
              limits=renderer.limits,
            ).plan {
            Some(selected) =>
              (
                "found",
                selected.steps.iter().map(s => s.occurrence.key).to_array(),
              )
            None => ("limit", [])
          }
        Unreachable => ("unreachable", [])
        Failed(_) => ("limit", [])
      }
      Json([Json(from), Json(to), Json(status), Json(keys)])
    } else {
      let empty : Array[Json] = []
      Json(empty)
    }
    snapshots.push(
      Json([Json(name), Json(html), Json(canonical), Json(samples), query]),
    )
  }
  let t = @test.Test("offline animation artifacts")
  t.write(Json(snapshots).stringify())
  t.snapshot(filename="players.json")
}

///|
test "full plans reject another source and invalid renderer limits without partial HTML" {
  let original = exchange()
  let catalog = @animation.Catalog::sequence(original).catalog.unwrap()
  let plan = @animation.PlaybackPlan::illustrative(catalog).plan.unwrap()
  let changed = @sequence.Sequence::new(
    original.participants,
    original.events,
    title="Different source",
  )
  let mismatch = @animated.AnimatedRenderer::new(playback=plan).render(
    Sequence(changed),
  )
  assert_eq(mismatch.output, None)
  assert_eq(mismatch.diagnostics[0].code, "animation/plan-mismatch")
  let bounded = @animated.AnimatedRenderer::new(output_units=10).render(
    Sequence(original),
  )
  assert_eq(bounded.output, None)
  assert_eq(bounded.diagnostics[0].code, "animation/render-limit")
  let invalid = @animated.AnimatedRenderer::new(
    query_limits=@animation.Limits::new(work=0),
  ).render(Sequence(original))
  assert_eq(invalid.output, None)
  assert_eq(invalid.diagnostics[0].code, "animation/plan-limit")
}

///|
test "script-context JSON preserves hostile canonical bytes and encodes terminators and separators" {
  let diagram = @render.Diagram::Sequence(hostile())
  let html = @animated.AnimatedRenderer::new().render(diagram).output.unwrap()
  let prefix = "<script type=\"application/json\" data-motion-data>"
  let start = html.find(prefix).unwrap() + prefix.length()
  let tail = html[start:].to_owned()
  let encoded = tail[:tail.find("</script>").unwrap()].to_owned()
  for token in ["<", "&", "\u2028", "\u2029"] {
    assert_false(encoded.contains(token))
  }
  guard @json.parse(encoded) is { "canonical": String(canonical), .. } else {
    fail("invalid embedded data")
  }
  assert_eq(canonical, @svg.SvgRenderer::new().render(diagram).output.unwrap())
  assert_true(canonical.contains("&lt;/script&gt;"))
}

///|
test "native two-lane source reaches static and animated output without sequence API changes" {
  let source = "swimlane-beta LR\n  subgraph Customer[Customer]\n    A([Request])\n  end\n  subgraph Support[Support]\n    B{Review}\n  end\n  A AB@--> B\n"
  let read = @mermaid.read_diagram(source)
  assert_eq(read.tree.text(), source)
  assert_true(
    read.diagnostics.iter().all(d => d.severity != Error),
    msg=@debug.to_string(read.diagnostics),
  )
  guard read.ast is Some(ast) else { fail("missing native AST") }
  let printed = @mermaid.print_diagram(ast).output.unwrap()
  assert_eq(@mermaid.read_diagram(printed).ast, Some(ast))
  guard ast is Swimlane(ast) else { fail("wrong kind") }
  let view = @mermaid.to_swimlane(ast).swimlane.unwrap()
  assert_eq(view.lanes.length(), 2)
  assert_eq(view.nodes[1].lane, Some("Support"))
  let svg = @mermaid.render_svg(source)
  assert_true(svg.output is Some(_), msg=@debug.to_string(svg.diagnostics))
  let renderer = @svg.SvgRenderer::new()
  let scene = renderer.scene(Swimlane(view)).scene.unwrap()
  assert_eq(scene.canonical_svg, svg.output.unwrap())
  assert_eq(scene.paths.length(), 1)
  let html = @animated.AnimatedRenderer::new().render(Swimlane(view))
  assert_true(html.output is Some(_), msg=@debug.to_string(html.diagnostics))
  assert_true(html.output.unwrap().contains("data-motion-data"))
}
