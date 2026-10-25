///|
fn bpmn_catalog(view : @bpmn.Bpmn) -> @animation.Catalog raise {
  let result=@animation.Catalog::bpmn(view)
  assert_true(result.catalog is Some(_),msg=@debug.to_string(result.diagnostics))
  result.catalog.unwrap()
}

///|
fn small_catalog() -> @animation.Catalog raise {
  bpmn_catalog(@bpmn.Bpmn::new("P",[@bpmn.Node::new("A",Task),@bpmn.Node::new("B",Task)],[@bpmn.Flow::new("AB","A","B"),@bpmn.Flow::new("BA","B","A")]))
}

///|
fn plan(result : @animation.PlanResult) -> @animation.PlaybackPlan raise {
  assert_true(result.plan != None,msg=@debug.to_string(result.diagnostics)); result.plan.unwrap()
}

///|
test "integer samples preserve parallel branch timing repeated occurrences and exact completion" {
  let catalog=small_catalog(); let a=catalog.flow("AB").unwrap().key; let b=catalog.flow("BA").unwrap().key
  let motion=@animation.Motion::serial([
    @animation.Motion::parallel([Step(a,1000L),@animation.Motion::serial([Step(b,500L),Step(a,500L)])]),
    Step(a,1000L),
  ])
  let result=plan(@animation.PlaybackPlan::scenario(catalog,motion))
  assert_eq(result.duration_ms,2000L); assert_eq(result.steps.length(),4)
  let quarter=result.sample_at(250L)
  assert_eq(quarter.active.length(),2); assert_eq(quarter.active[0].numerator,250L); assert_eq(quarter.active[1].denominator,500L)
  let later=result.sample_at(750L)
  assert_eq(later.active[0].ordinal,0); assert_eq(later.active[1].ordinal,2)
  assert_eq(later.active[0].concurrent_groups,later.active[1].concurrent_groups)
  assert_eq(result.sample_at(1000L).active[0].ordinal,3)
  assert_true(result.sample_at(2000L).finished); assert_eq(result.sample_at(2000L).active,[])
  assert_eq(result.sample_at(-1L),result.sample_at(0L))
  assert_eq(result.sample_at(3000L),result.sample_at(2000L))
  assert_eq(result.sample_at(750L),result.sample_at(750L))
  let altered=bpmn_catalog(@bpmn.Bpmn::new("P",[@bpmn.Node::new("A",Task,label="Different source"),@bpmn.Node::new("B",Task)],[@bpmn.Flow::new("AB","A","B"),@bpmn.Flow::new("BA","B","A")]))
  assert_true(result.matches(catalog)); assert_false(result.matches(altered))
  guard catalog.graph.route("A","B") is Found(route) else { fail("missing route") }
  let mismatch=@animation.PlaybackPlan::route(altered,route)
  assert_eq(mismatch.plan,None); assert_eq(mismatch.diagnostics[0].code,"animation/plan-mismatch")
  let t=@test.Test("explicit integer-time samples")
  t.write(@debug.to_string([result.sample_at(0L),quarter,later,result.sample_at(1000L),result.sample_at(2000L)])); t.snapshot(filename="motion.txt")
}

///|
test "scenario validation bounds duration identities depth and inclusive step size" {
  let catalog=small_catalog(); let key=catalog.flow("AB").unwrap().key
  for duration in [0L,-1L,@animation.max_duration_ms+1L] {
    let invalid=@animation.PlaybackPlan::scenario(catalog,Step(key,duration))
    assert_eq(invalid.plan,None); assert_eq(invalid.diagnostics[0].code,"animation/invalid-duration")
  }
  assert_eq(plan(@animation.PlaybackPlan::scenario(catalog,Step(key,@animation.max_duration_ms))).duration_ms,@animation.max_duration_ms)
  let overflow=@animation.PlaybackPlan::scenario(catalog,@animation.Motion::serial([Step(key,@animation.max_duration_ms),Step(key,1L)]))
  assert_eq(overflow.plan,None); assert_eq(overflow.diagnostics[0].code,"animation/plan-limit")
  let unknown=@animation.PlaybackPlan::scenario(catalog,Step("missing",1L))
  assert_eq(unknown.plan,None); assert_eq(unknown.diagnostics[0].code,"animation/invalid-identity")
  let nested=@animation.Motion::serial([@animation.Motion::parallel([Step(key,1L)])])
  assert_eq(@animation.PlaybackPlan::scenario(catalog,nested,limits=@animation.Limits::new(depth=1)).plan,None)
  let actions=Array::make(100000,@animation.Motion::Step(key,1L)); let frozen=@animation.Motion::serial(actions)
  actions.push(Step(key,1L))
  let maximum=plan(@animation.PlaybackPlan::scenario(catalog,frozen,limits=@animation.Limits::new(work=10000000)))
  assert_eq(maximum.steps.length(),100000); assert_eq(maximum.duration_ms,100000L)
  assert_eq(maximum.sample_at(99999L).active[0].ordinal,99999)
  assert_eq(@animation.PlaybackPlan::scenario(catalog,@animation.Motion::serial(actions),limits=@animation.Limits::new(work=10000000)).plan,None)
  let empty=plan(@animation.PlaybackPlan::scenario(catalog,@animation.Motion::serial([])))
  assert_true(empty.sample_at(0L).finished)
  assert_eq(empty.repeating().plan,None)
}

///|
fn sequence_catalog() -> @animation.Catalog raise {
  let message=fn(sender : String, receiver : String, label : String) -> @sequence.Event { Message(@sequence.Message::new(sender,receiver,label)) }
  let source=@sequence.Sequence::new([@sequence.Participant::new("A"),@sequence.Participant::new("B")],[
    message("A","B","request"),
    Frame(@sequence.Frame::new(Alt,@sequence.Section::new([message("B","A","found")],label="found"),rest=[@sequence.Section::new([message("A","A","missing")],label="missing")])),
    Frame(@sequence.Frame::new(Loop,@sequence.Section::new([message("A","B","retry")],label="caller chooses count"))),
    Frame(@sequence.Frame::new(Par,@sequence.Section::new([message("A","B","left 1"),message("B","A","left 2")]),rest=[@sequence.Section::new([message("A","B","right")])])),
    message("B","A","done"),
  ])
  let result=@animation.Catalog::sequence(source,view_id="Exchange")
  assert_true(result.catalog is Some(_),msg=@debug.to_string(result.diagnostics)); result.catalog.unwrap()
}

///|
test "sequence alternatives finite loops parallel sections and self-message occurrence paths are explicit" {
  let catalog=sequence_catalog()
  assert_eq(catalog.frames.length(),3); assert_eq(catalog.occurrences.length(),8)
  assert_eq(catalog.occurrences[2].path,[1,1,0]); assert_eq(catalog.occurrences[2].message.unwrap().sender,catalog.occurrences[2].message.unwrap().receiver)
  assert_eq(@animation.PlaybackPlan::sequence(catalog).diagnostics[0].code,"animation/selection-required")
  let choices=[@animation.Selection::new(catalog.frames[0].key,Alternative(1)),@animation.Selection::new(catalog.frames[1].key,Repetitions(2))]
  let selected=plan(@animation.PlaybackPlan::sequence(catalog,selections=choices))
  assert_eq(selected.duration_ms,7000L); assert_eq(selected.steps.length(),8)
  assert_false(selected.steps.iter().any(s => s.occurrence.message.unwrap().label == "found"))
  assert_eq(selected.steps.iter().filter(s => s.occurrence.message.unwrap().label == "retry").count(),2)
  assert_eq(selected.sample_at(4500L).active.length(),2); assert_eq(selected.sample_at(5500L).active.length(),1)
  assert_eq(selected.sample_at(5500L).active[0].key,catalog.occurrences[5].key)
  choices[1]=@animation.Selection::new(catalog.frames[1].key,Repetitions(0))
  assert_eq(plan(@animation.PlaybackPlan::sequence(catalog,selections=choices)).duration_ms,5000L)
  assert_eq(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(catalog.frames[0].key,Alternative(2))]).diagnostics[0].code,"animation/invalid-selection")
  assert_eq(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(catalog.frames[1].key,Repetitions(-1))]).diagnostics[0].code,"animation/invalid-selection")
  let first=catalog.occurrences[0].key; let last=catalog.occurrences[7].key
  assert_eq(catalog.graph.route(last,first),Unreachable)
  guard catalog.graph.route(first,last) is Found(route) else { fail("missing structural occurrence route") }
  let structural=plan(@animation.PlaybackPlan::route(catalog,route))
  assert_true(structural.steps.length() < catalog.occurrences.length())
  assert_eq(plan(@animation.PlaybackPlan::illustrative(catalog)).steps.length(),8)
}

///|
test "BPMN queries distinguish message opt-in limits ties cycles and hidden semantic endpoints" {
  let nodes=[@bpmn.Node::new("A",Task),@bpmn.Node::new("B",Task),@bpmn.Node::new("C",Task),@bpmn.Node::new("D",Task),@bpmn.Node::new("External",Participant,black_box=true),@bpmn.Node::new("Sub",SubProcess),@bpmn.Node::new("Hidden",Task,ownership=@bpmn.Ownership::new(subprocess="Sub"))]
  let flows=[@bpmn.Flow::new("AB","A","B",condition="amount > 0"),@bpmn.Flow::new("AC","A","C"),@bpmn.Flow::new("BD","B","D"),@bpmn.Flow::new("CD","C","D"),@bpmn.Flow::new("DA","D","A"),@bpmn.Flow::new("M","D","External",kind=MessageFlow),@bpmn.Flow::new("Note","A","External",kind=Association),@bpmn.Flow::new("HiddenMessage","Sub","External",kind=MessageFlow,semantic_source=nodes[6].source)]
  let catalog=bpmn_catalog(@bpmn.Bpmn::new("P",nodes,flows)); let graph=catalog.graph
  guard graph.route("A","D") is Found(route) else { fail("missing route") }
  assert_eq(route.edges.iter().map(e => catalog.occurrence(e.occurrence.unwrap()).unwrap().flow.unwrap().id).to_array(),["AB","BD"])
  assert_eq(catalog.flow("AB").unwrap().flow.unwrap().condition,Some("amount > 0"))
  assert_eq(graph.route("A","External"),Unreachable)
  assert_true(graph.route("A","External",kinds=[SequenceFlow,MessageFlow]) is Found(_))
  assert_eq(graph.route("Sub","External",kinds=[MessageFlow]),Unreachable)
  assert_eq(graph.lookup("Hidden"),Err(OutsideView("Hidden")))
  assert_eq(graph.lookup("Unknown"),Err(InvalidEndpoint("Unknown")))
  assert_eq(graph.route("A","D",limits=@animation.Limits::new(nodes=1)),Failed(Limit(Nodes)))
  assert_eq(graph.reachable("A",limits=@animation.Limits::new(edges=1)),Failed(Limit(Edges)))
  assert_eq(graph.route("A","D",limits=@animation.Limits::new(work=1)),Failed(Limit(Work)))
  assert_eq(graph.route("A","D",limits=@animation.Limits::new(results=1)),Failed(Limit(Results)))
  guard graph.reachable("A") is Complete(reached) else { fail("cycle search failed") }
  assert_eq(reached.length(),4)
}

///|
test "display proxies never route through another instance of a shared process" {
  let shared=@bpmn.SourceIdentity::new(resource_id="shared",source_id="T",path=[0,0,0])
  let nodes=[@bpmn.Node::new("P1",Participant,black_box=true),@bpmn.Node::new("P2",Participant),@bpmn.Node::new("T1",Task,source=shared,ownership=@bpmn.Ownership::new(pool="P1")),@bpmn.Node::new("T2",Task,source=shared,ownership=@bpmn.Ownership::new(pool="P2")),@bpmn.Node::new("Other",Participant,black_box=true)]
  let flow=@bpmn.Flow::new("M","P1","Other",kind=MessageFlow,semantic_source=shared)
  let catalog=bpmn_catalog(@bpmn.Bpmn::new("C",nodes,[flow],kind=Collaboration))
  assert_true(catalog.flow("M") != None)
  assert_eq(catalog.graph.route("T2","Other",kinds=[MessageFlow]),Unreachable)
  assert_eq(catalog.graph.route("P1","Other",kinds=[MessageFlow]),Unreachable)
}

///|
test "boundary visibility follows its attachment while a collapsed subprocess keeps its outside boundary" {
  let nodes=[@bpmn.Node::new("Sub",SubProcess),@bpmn.Node::new("Inside",Task,ownership=@bpmn.Ownership::new(subprocess="Sub")),@bpmn.Node::new("HiddenBoundary",BoundaryEvent,ownership=@bpmn.Ownership::new(attached_to="Inside")),@bpmn.Node::new("OuterBoundary",BoundaryEvent,ownership=@bpmn.Ownership::new(attached_to="Sub"))]
  let scope=@bpmn.Bpmn::new("P",nodes,[]).scope().scope.unwrap()
  assert_eq(scope.visible,[true,false,false,true])
}

///|
test "optional and nested choices require only the frames actually selected" {
  let call=@sequence.Event::Message(@sequence.Message::new("A","A","call"))
  let nested=@sequence.Event::Frame(@sequence.Frame::new(Loop,@sequence.Section::new([call])))
  let source=@sequence.Sequence::new([@sequence.Participant::new("A")],[Frame(@sequence.Frame::new(Alt,@sequence.Section::new([nested]),rest=[@sequence.Section::new([call])]))])
  let catalog=@animation.Catalog::sequence(source).catalog.unwrap()
  let alternative=catalog.frames[0].key; let loop_frame=catalog.frames[1].key
  assert_eq(plan(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(alternative,Alternative(1))])).steps.length(),1)
  assert_eq(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(alternative,Alternative(0))]).diagnostics[0].code,"animation/selection-required")
  assert_eq(plan(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(alternative,Alternative(0)),@animation.Selection::new(loop_frame,Repetitions(2))])).steps.length(),2)
  for kind in [@sequence.FrameKind::Opt,Critical,Break,Rect,ParOver] {
    let source=@sequence.Sequence::new([@sequence.Participant::new("A")],[Frame(@sequence.Frame::new(kind,@sequence.Section::new([call])))])
    let catalog=@animation.Catalog::sequence(source).catalog.unwrap()
    let selections=if kind == Opt { [@animation.Selection::new(catalog.frames[0].key,Optional(true))] } else { [] }
    assert_eq(plan(@animation.PlaybackPlan::sequence(catalog,selections~)).steps.length(),1)
    assert_eq(catalog.frames[0].kind,kind)
    if kind == Opt { assert_eq(plan(@animation.PlaybackPlan::sequence(catalog,selections=[@animation.Selection::new(catalog.frames[0].key,Optional(false))])).steps.length(),0) }
  }
  let illustrative=plan(@animation.PlaybackPlan::illustrative(small_catalog()))
  assert_eq(illustrative.sample_at(illustrative.duration_ms+250L),illustrative.sample_at(250L))
  assert_false(illustrative.sample_at(illustrative.duration_ms).finished)
}

///|
test "kind-indexed searches honor small query budgets on high-degree nodes" {
  let nodes=[@bpmn.Node::new("A",Task),@bpmn.Node::new("Pool",Participant,black_box=true)]
  let flows=[]
  for i in 0..<500 { nodes.push(@bpmn.Node::new("N\{i}",Task)); flows.push(@bpmn.Flow::new("F\{i}","A","N\{i}")) }
  flows.push(@bpmn.Flow::new("M","A","Pool",kind=MessageFlow))
  let graph=bpmn_catalog(@bpmn.Bpmn::new("P",nodes,flows)).graph
  guard graph.reachable("A",kinds=[MessageFlow],limits=@animation.Limits::new(edges=1,work=4)) is Complete(nodes) else { fail("selected-kind budget should complete") }
  assert_eq(nodes.iter().map(n => n.id).to_array(),["A","Pool"])
}

///|
test "repeated query kinds are normalized before visiting a chain" {
  let nodes=Array::makei(128,i => @bpmn.Node::new("N\{i}",Task))
  let flows=Array::makei(127,i => @bpmn.Flow::new("F\{i}","N\{i}","N\{i+1}"))
  let graph=bpmn_catalog(@bpmn.Bpmn::new("P",nodes,flows)).graph
  let kinds=Array::make(4096,@animation.EdgeKind::SequenceFlow)
  let limits=@animation.Limits::new(work=5000)
  guard graph.reachable("N0",kinds~,limits~) is Complete(nodes) else { fail("kind normalization reachability failed") }
  assert_eq(nodes.length(),128)
  guard graph.route("N0","N127",kinds~,limits~) is Found(route) else { fail("kind normalization route failed") }
  assert_eq(route.edges.length(),127)
}
