///|
fn document_tree(document : @bpmn.Document) -> @bpmn.DocumentTree { @bpmn.DocumentTree::new(document).tree.unwrap() }

///|
fn event_log(root : @bpmn.NodeRef) -> Array[(Bool,@bpmn.NodeHandle)] {
  @bpmn.EventReader::new(root).iter().map(event => match event { Enter(n) => (true,n.handle()); Leave(n) => (false,n.handle()) }).to_array()
}

///|
test "read-only nodes retain schema field paths source locations and opaque ordered content" {
  let source="<!--before--><b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:t'><b:process id='P'><b:subProcess id='Sub'><b:task id='T'/></b:subProcess><b:extensionElements><v:data xmlns:v='urn:v'>left<![CDATA[&raw]]><v:a/><!--c--><?p q?><v:b/>tail</v:data></b:extensionElements></b:process></b:definitions><?end done?>"
  let doc=@bpmn.read(source,source_id="memory:tree").document.unwrap()
  let tree=document_tree(doc); let root=tree.root()
  assert_eq(root.category(),Document)
  assert_eq(root.children()[0].category(),Comment)
  assert_eq(root.children().last().unwrap().category(),ProcessingInstruction)
  let found : Array[@bpmn.NodeRef] = []
  @bpmn.walk(root,n => { if n.id() == Some("T") { found.push(n) }; Continue })
  let task=found[0]
  assert_eq(task.kind(),Some(Task)); assert_eq(task.parent().unwrap().id(),Some("Sub"))
  assert_eq(task.location().unwrap().source_id,Some("memory:tree"))
  assert_eq(task.path().steps().last().unwrap().field,Named(@bpmn.Kind::FlowElement.name()))
  assert_true(task.path().resolve(tree) is Found(n) && n == task)
  assert_eq(task.scalar(@bpmn.ExpandedName::new("","id")),Some(Identifier("T")))
  let content : Array[@bpmn.NodeRef] = []
  @bpmn.walk(root,n => { if n.kind().map(k => k.local_name()) == Some("data") { content.push(n) }; Continue })
  let children=content[0].children()
  assert_eq(children.iter().map(n => n.category()).to_array(),[Text,Extension,Comment,ProcessingInstruction,Extension,Text])
  assert_eq(children[0].value(),Text("left&raw"))
  assert_true(children.iter().all(n => n.location() is Some(_)))
  assert_eq(children[0].location().unwrap().start.offset,source.find("left").unwrap())
  let process=root.children()[1].children()[0]
  assert_eq(process.field(Named(@bpmn.Kind::FlowElement.name())).unwrap().children.length(),1)
}

///|
test "revision handles reject lexical source changes resource changes and constructed binding changes" {
  let a=@bpmn.read("<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:t'><b:process id='P'/></b:definitions>",source_id="a").document.unwrap()
  let b=@bpmn.read("<b:definitions xmlns:b=\"\{model_uri}\" targetNamespace='urn:t'><b:process id='P'/></b:definitions>",source_id="a").document.unwrap()
  assert_eq(a,b)
  let ta=document_tree(a); let tb=document_tree(b)
  assert_true(tb.lookup(ta.root().handle()) is DocumentMismatch)
  let same=document_tree(a)
  assert_true(same.lookup(ta.root().handle()) is Found(_))
  let resource=@bpmn.DocumentTree::new(a,resource_id="different").tree.unwrap()
  assert_true(resource.lookup(ta.root().handle()) is DocumentMismatch)
  let root=@bpmn.Element::new(Definitions,attributes=[("targetNamespace","urn:t")],bindings=[("unused","urn:a")])
  let other=@bpmn.Element::new(Definitions,attributes=[("targetNamespace","urn:t")],bindings=[("unused","urn:b")])
  let a=@bpmn.Document::new(root); let b=@bpmn.Document::new(other)
  assert_eq(a,b)
  assert_true(document_tree(b).lookup(document_tree(a).root().handle()) is DocumentMismatch)
}

///|
struct LogVisitor { events : Array[(Bool,@bpmn.NodeHandle)]; typed : Array[Bool] }

///|
impl @bpmn.Visitor for LogVisitor with leave(self,node) { self.events.push((false,node.handle())) }

///|
impl @bpmn.Visitor for LogVisitor with enter(self,node) { self.events.push((true,node.handle())); Continue }

///|
impl @bpmn.Visitor for LogVisitor with visit_activity(self,value,node) { self.typed.push(value.element == node.element().unwrap()); Continue }

///|
test "walk fold reduce pull push visitor and cursor agree without following references" {
  let doc=validation_document("<b:process id='P'><b:task id='A'/><b:subProcess id='Sub'><b:task id='B'/></b:subProcess></b:process>")
  let root=document_tree(doc).root(); let expected=event_log(root)
  let walked : Array[(Bool,@bpmn.NodeHandle)] = []
  @bpmn.walk(root,n => { walked.push((true,n.handle())); Continue },leave=n => walked.push((false,n.handle())))
  assert_eq(walked,expected)
  let folded=@bpmn.fold(root,[],(events,n) => { events.push((true,n.handle())); (events,Continue) },leave=(events,n) => { events.push((false,n.handle())); events })
  assert_eq(folded,expected)
  let left : Array[@bpmn.NodeHandle] = []
  let count=@bpmn.reduce(root,(n,counts) => { left.push(n.handle()); 1+counts.iter().fold(init=0,(n,x) => n+x) })
  assert_eq(left,expected.iter().filter(p => !p.0).map(p => p.1).to_array())
  assert_eq(count,expected.length()/2)
  let visitor=LogVisitor::{events:[],typed:[]}; @bpmn.accept(root,visitor); assert_eq(visitor.events,expected); assert_true(visitor.typed.iter().all(b => b))
  let pushed : Array[(Bool,@bpmn.NodeHandle)] = []
  @bpmn.push_events(@bpmn.EventReader::new(root),n => { pushed.push((true,n.handle())); Continue },leave=n => pushed.push((false,n.handle())))
  assert_eq(pushed,expected)
  let cursor=@bpmn.TreeCursor::new(root)
  let entered : Array[@bpmn.NodeHandle] = []
  while true {
    entered.push(cursor.node().handle())
    if cursor.goto_first_child() { continue }
    while !cursor.goto_next_sibling() { if !cursor.goto_parent() { break } }
    if cursor.node() == root { break }
  }
  assert_eq(entered,expected.iter().filter(p => p.0).map(p => p.1).to_array())
}

///|
test "pruning leaves skipped nodes and stopping emits no ancestor leaves" {
  let root=document_tree(validation_document("<b:process><b:subProcess id='Sub'><b:task id='Hidden'/></b:subProcess><b:task id='Visible'/></b:process>")).root()
  let log : Array[(Bool,String?)] = []
  @bpmn.walk(root,n => { log.push((true,n.id())); if n.id() == Some("Sub") { SkipChildren } else { Continue } },leave=n => log.push((false,n.id())))
  assert_false(log.contains((true,Some("Hidden"))))
  assert_true(log.contains((false,Some("Sub"))))
  let stopped : Array[(Bool,String?)] = []
  @bpmn.walk(root,n => { stopped.push((true,n.id())); if n.id() == Some("Hidden") { Stop } else { Continue } },leave=n => stopped.push((false,n.id())))
  assert_eq(stopped.last(),Some((true,Some("Hidden"))))
  assert_eq(@bpmn.reduce_pruned(root,n => if n.id() == Some("Hidden") { Stop } else { Continue },(_,_ : ArrayView[Int]) => 1),None)
  let reader=@bpmn.EventReader::new(root)
  reader.skip_children(); assert_true(reader.next() is Some(Enter(_)))
  reader.skip_children(); assert_true(reader.next() is Some(Leave(_))); assert_eq(reader.next(),None)
  let first=@bpmn.EventReader::new(root); let second=@bpmn.EventReader::new(root)
  first.next() |> ignore; first.stop(); assert_eq(first.next(),None)
  assert_true(second.next() is Some(Enter(_)))
}

///|
test "nested walks have independent state and constructed nodes have optional locations" {
  let tree=document_tree(validation_document("<b:process><b:task id='T'/></b:process>")); let root=tree.root()
  let expected=event_log(root)
  let mut nested=0
  let nested_logs=[]
  @bpmn.walk(root,_ => { nested_logs.push(event_log(root)); nested+=1; Continue })
  assert_true(nested_logs.iter().all(log => log == expected))
  assert_eq(nested,tree.length())
  let constructed=document_tree(@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new().element]).document())
  let locations=[]
  @bpmn.walk(constructed.root(),n => { locations.push(n.location()); Continue })
  assert_true(locations.iter().all(l => l == None))
}

///|
test "all frozen document families agree across complete traversal styles" {
  let docs=[@bpmn.read(fixture()).document.unwrap()]
  for name in ["activities","events","collaboration","choreography-conversation","di-views"] { docs.push(model_document(name)) }
  for doc in docs {
    let tree=document_tree(doc); let root=tree.root(); let expected=event_log(root)
    let visitor=LogVisitor::{events:[],typed:[]}; @bpmn.accept(root,visitor)
    assert_eq(visitor.events,expected)
    let folded=@bpmn.fold(root,[],(events,n) => { events.push((true,n.handle())); (events,Continue) },leave=(events,n) => { events.push((false,n.handle())); events })
    assert_eq(folded,expected)
    let postorder : Array[@bpmn.NodeHandle] = []
    let count=@bpmn.reduce(root,(n,counts) => { postorder.push(n.handle()); 1+counts.iter().fold(init=0,(sum,n) => sum+n) })
    assert_eq(count,tree.length())
    assert_eq(postorder,expected.iter().filter(p => !p.0).map(p => p.1).to_array())
  }
}

///|
test "deep constructed walking events reduction and paths use heap state" {
  let mut element=@bpmn.Task::new(id="Deep").element
  for _ in 0..<10000 { element=@bpmn.SubProcess::new(contents=[Element(element)]).element }
  let doc=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(element)]).element]).document()
  let tree=@bpmn.DocumentTree::new(doc,limits=@bpmn.Limits::new(depth=10003)).tree.unwrap()
  let root=tree.root(); let mut enters=0; let mut leaves=0; let mut deepest : @bpmn.NodeRef? = None
  @bpmn.walk(root,n => { enters+=1; if n.id() == Some("Deep") { deepest=Some(n) }; Continue },leave=_ => leaves+=1)
  assert_eq(enters,10004); assert_eq(leaves,enters)
  assert_eq(@bpmn.EventReader::new(root).iter().count(),enters*2)
  assert_eq(@bpmn.reduce(root,(_ : @bpmn.NodeRef,counts : ArrayView[Int]) => 1+counts.iter().fold(init=0,(sum,n) => sum+n)),enters)
  assert_eq(deepest.unwrap().path().depth(),10003)
  assert_eq(deepest.unwrap().path().steps().length(),10003)
  assert_true(@bpmn.DocumentTree::new(doc).tree is None)
}

///|
test "traversal bounds reject partial arenas and cursor failures preserve position" {
  let doc=validation_document("<b:process><b:task id='T'/></b:process>")
  for (limits,code) in [
    (@bpmn.Limits::new(nodes=1),"bpmn/traversal-node-limit"),
    (@bpmn.Limits::new(depth=2),"bpmn/traversal-depth-limit"),
    (@bpmn.Limits::new(token_units=1),"bpmn/traversal-token-limit"),
    (@bpmn.Limits::new(nodes=0),"bpmn/traversal-invalid-limits"),
  ] { let result=@bpmn.DocumentTree::new(doc,limits~); assert_true(result.tree is None); assert_eq(result.diagnostics[0].code,code) }
  let root=document_tree(doc).root(); let cursor=@bpmn.TreeCursor::new(root)
  assert_false(cursor.goto_parent()); assert_false(cursor.goto_previous_sibling()); assert_eq(cursor.node(),root)
  assert_true(cursor.goto_last_child()); assert_eq(cursor.depth(),1)
  assert_true(cursor.goto_first_child()); assert_true(cursor.goto_first_child())
  let task=cursor.node(); assert_eq(task.id(),Some("T"))
  assert_false(cursor.goto_first_child()); assert_false(cursor.goto_next_sibling()); assert_eq(cursor.node(),task)
  let subtree=@bpmn.TreeCursor::new(task)
  assert_false(subtree.goto_parent()); assert_false(subtree.goto_previous_sibling()); assert_eq(subtree.node(),task)
}

///|
test "pruned reduction agrees with pruned event order and stopped reduction has no later callbacks" {
  let root=document_tree(validation_document("<b:process><b:subProcess id='Sub'><b:task id='Hidden'/></b:subProcess><b:task id='Visible'/></b:process>")).root()
  let log : Array[@bpmn.NodeHandle] = []
  let count=@bpmn.reduce_pruned(root,n => if n.id() == Some("Sub") { SkipChildren } else { Continue },(n,counts : ArrayView[Int]) => { log.push(n.handle()); 1+counts.iter().fold(init=0,(sum,n) => sum+n) })
  assert_eq(count,Some(5))
  let expected : Array[@bpmn.NodeHandle] = []
  @bpmn.walk(root,n => if n.id() == Some("Sub") { SkipChildren } else { Continue },leave=n => expected.push(n.handle()))
  assert_eq(log,expected)
  let reduced : Array[@bpmn.NodeHandle] = []
  let result=@bpmn.reduce_pruned(root,n => if n.id() == Some("Hidden") { Stop } else { Continue },(n,_ : ArrayView[Int]) => { reduced.push(n.handle()); 1 })
  assert_eq(result,None); assert_eq(reduced,[])
}

///|
test "detached names and QName identities obey the new traversal token budget" {
  let uri="urn:"+String::make(1100,'x')
  for attr in ["v:label='short'","name='short' calledElement='v:Target'"] {
    let source="<b:definitions xmlns:b='\{model_uri}' xmlns:v='\{uri}' targetNamespace='urn:t'><b:process><b:callActivity id='T' \{attr}/></b:process></b:definitions>"
    let element=@bpmn.read(source).document.unwrap().root.children[0].children[0]
    let detached=@bpmn.Definitions::new("urn:t",children=[@bpmn.Process::new(contents=[Element(element)]).element]).document()
    let limits=@bpmn.Limits::new(token_units=1000)
    let result=@bpmn.DocumentTree::new(detached,limits~)
    assert_true(result.tree is None); assert_eq(result.diagnostics[0].code,"bpmn/traversal-token-limit")
    assert_eq(@bpmn.validate_structure(detached,limits~).findings[0].diagnostic.code,"bpmn/validation-token-limit")
  }
}
