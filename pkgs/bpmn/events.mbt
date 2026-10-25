///|
pub(all) enum Control { Continue; SkipChildren; Stop } derive(Eq, Debug)

///|
pub extend Control with Eq::{equal, not_equal}

///|
pub extend Control with @debug.Debug::{to_repr}

///|
pub(all) enum TraversalEvent { Enter(NodeRef); Leave(NodeRef) } derive(Eq, Debug)

///|
pub extend TraversalEvent with Eq::{equal, not_equal}

///|
pub extend TraversalEvent with @debug.Debug::{to_repr}

///|
pub(open) trait EventSource {
  fn next(Self) -> TraversalEvent?
  fn skip_children(Self) -> Unit
  fn stop(Self) -> Unit
}

///|
priv struct EventFrame { node : NodeRef; mut next : Int }

///|
pub struct EventReader { priv stack : Array[EventFrame]; priv mut pending : NodeRef?; priv mut started : Bool; priv mut done : Bool }

///|
pub fn EventReader::new(root : NodeRef) -> EventReader { {stack:[],pending:Some(root),started:false,done:false} }

///|
pub impl EventSource for EventReader with next(self) {
  if self.done { return None }
  if !self.started { self.started=true; return self.pending.map(n => Enter(n)) }
  if self.pending is Some(node) { self.pending=None; self.stack.push({node,next:0}) }
  guard self.stack.last() is Some(top) else { self.done=true; return None }
  let children=top.node.tree.records[top.node.ordinal].children
  if top.next < children.length() {
    let node=NodeRef::{tree:top.node.tree,ordinal:children[top.next]}; top.next+=1; self.pending=Some(node); Some(Enter(node))
  } else { self.stack.pop() |> ignore; Some(Leave(top.node)) }
}

///|
pub impl EventSource for EventReader with skip_children(self) {
  if self.started && self.pending is Some(node) { self.pending=None; self.stack.push({node,next:node.tree.records[node.ordinal].children.length()}) }
}

///|
pub impl EventSource for EventReader with stop(self) { self.done=true; self.pending=None; self.stack.clear() }

///|
pub extend EventReader with EventSource::{next, skip_children, stop}

///|
pub fn EventReader::iter(self : EventReader) -> Iter[TraversalEvent] { Iter::new(() => self.next()) }

///|
pub fn[S : EventSource] push_events(source : S, enter : (NodeRef) -> Control, leave~ : (NodeRef) -> Unit = _ => ()) -> Unit {
  while source.next() is Some(event) { match event {
    Enter(node) => match enter(node) { Continue => (); SkipChildren => source.skip_children(); Stop => { source.stop(); return } }
    Leave(node) => leave(node)
  } }
}

///|
pub fn walk(root : NodeRef, enter : (NodeRef) -> Control, leave~ : (NodeRef) -> Unit = _ => ()) -> Unit { push_events(EventReader::new(root),enter,leave~) }

///|
pub fn[A] fold(root : NodeRef, initial : A, enter : (A,NodeRef) -> (A,Control), leave~ : (A,NodeRef) -> A = (value,_) => value) -> A {
  let mut value=initial
  walk(root,node => { let (next,control)=enter(value,node); value=next; control },leave=node => value=leave(value,node))
  value
}

///|
priv struct ReductionFrame[R] { node : NodeRef; mut next : Int; results : Array[R] }

///|
pub fn[R] reduce_pruned(root : NodeRef, enter : (NodeRef) -> Control, combine : (NodeRef,ArrayView[R]) -> R) -> R? {
  let empty : Array[R] = []
  match enter(root) { Stop => return None; SkipChildren => return Some(combine(root,empty)); Continue => () }
  let stack : Array[ReductionFrame[R]] = [{node:root,next:0,results:[]}]
  while stack.last() is Some(top) {
    let children=top.node.tree.records[top.node.ordinal].children
    if top.next < children.length() {
      let node=NodeRef::{tree:top.node.tree,ordinal:children[top.next]}; top.next+=1
      match enter(node) { Stop => return None; SkipChildren => top.results.push(combine(node,empty)); Continue => stack.push({node,next:0,results:[]}) }
    } else {
      stack.pop() |> ignore
      let value=combine(top.node,top.results)
      match stack.last() { Some(parent) => parent.results.push(value); None => return Some(value) }
    }
  }
  None
}

///|
pub fn[R] reduce(root : NodeRef, combine : (NodeRef,ArrayView[R]) -> R) -> R { reduce_pruned(root,_ => Continue,combine).unwrap() }
