///|
fn minimal() -> @render.Diagram { @adapter.to_diagram(@bpmn.read(@corpus.inputs[5].source).document.unwrap()).diagram.unwrap() }

///|
fn supplied(name : String) -> @render.Diagram {
  let input=@corpus.render_inputs.iter().find_first(i => i.name == name).unwrap()
  @adapter.to_diagram(@bpmn.read(input.source).document.unwrap()).diagram.unwrap()
}

///|
fn exchange() -> @sequence.Sequence {
  @sequence.Sequence::new([@sequence.Participant::new("A",label="Client"),@sequence.Participant::new("B",label="API")],[
    Message(@sequence.Message::new("A","B","request")),
    Message(@sequence.Message::new("B","B","self")),
    Message(@sequence.Message::new("B","A","reply")),
  ],title="Request and reply")
}

///|
fn finite_exchange() -> (@sequence.Sequence,@animation.PlaybackPlan) {
  let message=fn(sender : String, receiver : String, label : String) -> @sequence.Event { Message(@sequence.Message::new(sender,receiver,label)) }
  let sequence=@sequence.Sequence::new([@sequence.Participant::new("A"),@sequence.Participant::new("B")],[
    message("A","B","request"),
    Frame(@sequence.Frame::new(Alt,@sequence.Section::new([message("B","A","found")],label="found"),rest=[@sequence.Section::new([message("A","A","missing")],label="missing")])),
    Frame(@sequence.Frame::new(Loop,@sequence.Section::new([message("A","B","retry")],label="explicit repetitions"))),
    Frame(@sequence.Frame::new(Par,@sequence.Section::new([message("A","B","left 1"),message("B","A","left 2")]),rest=[@sequence.Section::new([message("A","B","right")])])),
    message("B","A","done"),
  ],title="Finite chosen scenario")
  let catalog=@animation.Catalog::sequence(sequence,view_id="Finite exchange").catalog.unwrap()
  let choices=[@animation.Selection::new(catalog.frames[0].key,Alternative(1)),@animation.Selection::new(catalog.frames[1].key,Repetitions(2))]
  (sequence,@animation.PlaybackPlan::sequence(catalog,selections=choices).plan.unwrap())
}

///|
fn chain() -> @render.Diagram {
  Bpmn(@model.Bpmn::new("Chain",[@model.Node::new("A",Task,label="A"),@model.Node::new("B",Task,label="B"),@model.Node::new("C",Task,label="C")],[@model.Flow::new("AB","A","B"),@model.Flow::new("BC","B","C")]))
}

///|
fn cyclic() -> @render.Diagram {
  Bpmn(@model.Bpmn::new("Cycle",[@model.Node::new("A",Task,label="A"),@model.Node::new("B",Task,label="B"),@model.Node::new("C",Task,label="C"),@model.Node::new("D",Task,label="D")],[@model.Flow::new("AB","A","B"),@model.Flow::new("AC","A","C"),@model.Flow::new("BD","B","D"),@model.Flow::new("CD","C","D"),@model.Flow::new("DA","D","A")]))
}

///|
fn hostile() -> @sequence.Sequence {
  let text="</script><img src=x onerror=globalThis.motionPwned=1> 😀 & \"quoted\"\u2028\u2029"
  let link=@sequence.Link::new(Smithy,"javascript:globalThis.motionPwned=2")
  @sequence.Sequence::new([@sequence.Participant::new("A",label=text),@sequence.Participant::new("B")],[Message(@sequence.Message::new("A","B",text,link~))],title=text)
}

///|
test "standalone HTML scenes and validated plans have exact portable bytes" {
  let snapshots : Array[Json]=[]
  let (finite,playback)=finite_exchange()
  let empty=@sequence.Sequence::new([],[],title="Empty finite scenario")
  let empty_catalog=@animation.Catalog::sequence(empty).catalog.unwrap()
  let empty_plan=@animation.PlaybackPlan::scenario(empty_catalog,@animation.Motion::serial([])).plan.unwrap()
  let bpmn_diagram=minimal()
  guard bpmn_diagram is Bpmn(bpmn_view) else { fail("fixture kind") }
  let bpmn_catalog=@animation.Catalog::bpmn(bpmn_view).catalog.unwrap()
  let first=bpmn_catalog.flow("Flow_1").unwrap().key; let second=bpmn_catalog.flow("Flow_2").unwrap().key
  let concurrent=@animation.PlaybackPlan::scenario(bpmn_catalog,@animation.Motion::serial([@animation.Motion::parallel([Step(first,1000L),Step(first,500L)]),Step(second,750L)])).plan.unwrap()
  let chain_diagram=chain()
  guard chain_diagram is Bpmn(chain_view) else { fail("fixture kind") }
  let chain_catalog=@animation.Catalog::bpmn(chain_view).catalog.unwrap()
  let one_step=@animation.PlaybackPlan::scenario(chain_catalog,Step(chain_catalog.flow("AB").unwrap().key,1000L)).plan.unwrap()
  for (name,diagram,renderer) in [
    ("bpmn-default",minimal(),@animated.AnimatedRenderer::new()),
    ("bpmn-cyclic",cyclic(),@animated.AnimatedRenderer::new()),
    ("bpmn-concurrent",bpmn_diagram,@animated.AnimatedRenderer::new(playback=concurrent)),
    ("bpmn-supplied",supplied("collaboration-di.bpmn"),@animated.AnimatedRenderer::new()),
    ("bpmn-automatic",supplied("process-di.bpmn"),@animated.AnimatedRenderer::new(svg=@svg.SvgRenderer::new(bpmn_policy=Automatic))),
    ("sequence-default",@render.Diagram::Sequence(exchange()),@animated.AnimatedRenderer::new()),
    ("sequence-finite",Sequence(finite),@animated.AnimatedRenderer::new(playback~)),
    ("hostile",Sequence(hostile()),@animated.AnimatedRenderer::new()),
    ("plan-limit",chain_diagram,@animated.AnimatedRenderer::new(playback=one_step,limits=@animation.Limits::new(steps=1))),
    ("query-limit",chain(),@animated.AnimatedRenderer::new(query_limits=@animation.Limits::new(nodes=1))),
    ("prefix-a",minimal(),@animated.AnimatedRenderer::new(svg=@svg.SvgRenderer::new(id_prefix="A",mode=Fixed(Dark)))),
    ("prefix-b",minimal(),@animated.AnimatedRenderer::new(svg=@svg.SvgRenderer::new(id_prefix="B",mode=Fixed(Light)))),
    ("empty-finite",Sequence(empty),@animated.AnimatedRenderer::new(playback=empty_plan)),
  ] {
    let result=renderer.render(diagram)
    assert_eq(result.media_type,"text/html")
    assert_true(result.output != None,msg="\{name}: \{@debug.to_string(result.diagnostics)}")
    assert_true(result.diagnostics.iter().all(d => d.severity != Error),msg="\{name}: \{@debug.to_string(result.diagnostics)}")
    let html=result.output.unwrap()
    assert_true(html.contains("data-diagram-viewer")); assert_true(html.contains("data-control=\"seek\""))
    assert_eq(html.split("</script>").count(),3)
    assert_false(html.contains("<img")); assert_false(html.contains("<iframe"))
    let canonical=renderer.svg.render(diagram).output.unwrap()
    let scene=renderer.svg.scene(diagram,sequence_view_id=renderer.playback.map(p => p.view_id).unwrap_or("sequence")).scene.unwrap()
    let pure=renderer.playback.unwrap_or_else(() => @animation.PlaybackPlan::illustrative(scene.catalog).plan.unwrap())
    let times=[0L,250L,750L,1000L,1250L,4500L,5500L,7000L].filter(t => t <= pure.duration_ms)
    if !times.contains(pure.duration_ms) { times.push(pure.duration_ms) }
    let samples=times.map(t => {
      let sample=pure.sample_at(t)
      let active=sample.active.iter().map(a => Json([Json(a.ordinal),Json(a.key),Json(a.numerator.to_string()),Json(a.denominator.to_string())])).to_array()
      Json([Json(t.to_string()),Json(sample.elapsed_ms.to_string()),Json(sample.finished),Json(active)])
    })
    let endpoints=scene.catalog.graph.nodes.filter(n => match n.kind { Bpmn(_) | Message => true; _ => false })
    let query=if endpoints.length() > 0 {
      let from=endpoints[0].id; let to=endpoints[endpoints.length()-1].id
      let result=scene.catalog.graph.route(from,to,limits=renderer.query_limits)
      let (status,keys)=match result {
        Found(route) => {
          match @animation.PlaybackPlan::route(scene.catalog,route,limits=renderer.limits).plan {
            Some(selected) => ("found",selected.steps.iter().map(s => s.occurrence.key).to_array())
            None => ("limit",[])
          }
        }
        Unreachable => ("unreachable",[])
        Failed(_) => ("limit",[])
      }
      Json([Json(from),Json(to),Json(status),Json(keys)])
    } else { let empty : Array[Json]=[]; Json(empty) }
    snapshots.push(Json([Json(name),Json(html),Json(canonical),Json(samples),query]))
  }
  let t=@test.Test("offline animation artifacts"); t.write(Json(snapshots).stringify()); t.snapshot(filename="players.json")
}

///|
test "full plans reject another source and invalid renderer limits without partial HTML" {
  let original=exchange(); let catalog=@animation.Catalog::sequence(original).catalog.unwrap()
  let plan=@animation.PlaybackPlan::illustrative(catalog).plan.unwrap()
  let changed=@sequence.Sequence::new(original.participants,original.events,title="Different source")
  let mismatch=@animated.AnimatedRenderer::new(playback=plan).render(Sequence(changed))
  assert_eq(mismatch.output,None); assert_eq(mismatch.diagnostics[0].code,"animation/plan-mismatch")
  let bounded=@animated.AnimatedRenderer::new(output_units=10).render(Sequence(original))
  assert_eq(bounded.output,None); assert_eq(bounded.diagnostics[0].code,"animation/render-limit")
  let invalid=@animated.AnimatedRenderer::new(query_limits=@animation.Limits::new(work=0)).render(Sequence(original))
  assert_eq(invalid.output,None); assert_eq(invalid.diagnostics[0].code,"animation/plan-limit")
}

///|
test "script-context JSON preserves hostile canonical bytes and encodes terminators and separators" {
  let diagram=@render.Diagram::Sequence(hostile())
  let html=@animated.AnimatedRenderer::new().render(diagram).output.unwrap()
  let prefix="<script type=\"application/json\" data-motion-data>"
  let start=html.find(prefix).unwrap()+prefix.length()
  let tail=html[start:].to_owned(); let encoded=tail[:tail.find("</script>").unwrap()].to_owned()
  for token in ["<","&","\u2028","\u2029"] { assert_false(encoded.contains(token)) }
  guard @json.parse(encoded) is {"canonical":String(canonical),..} else { fail("invalid embedded data") }
  assert_eq(canonical,@svg.SvgRenderer::new().render(diagram).output.unwrap())
  assert_true(canonical.contains("&lt;/script&gt;"))
}
