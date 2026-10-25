///|
pub struct TreeCursor { priv tree : DocumentTree; priv start : Int; priv mut current : Int }

///|
pub fn TreeCursor::new(root : NodeRef) -> TreeCursor { {tree:root.tree,start:root.ordinal,current:root.ordinal} }

///|
pub fn TreeCursor::node(self : TreeCursor) -> NodeRef { {tree:self.tree,ordinal:self.current} }

///|
pub fn TreeCursor::path(self : TreeCursor) -> NodePath { self.node().path() }

///|
pub fn TreeCursor::depth(self : TreeCursor) -> Int { self.tree.records[self.current].depth-self.tree.records[self.start].depth }

///|
pub fn TreeCursor::goto_parent(self : TreeCursor) -> Bool {
  if self.current == self.start { return false }
  guard self.tree.records[self.current].parent is Some(parent) else { return false }
  self.current=parent; true
}

///|
pub fn TreeCursor::goto_first_child(self : TreeCursor) -> Bool {
  guard self.tree.records[self.current].children.get(0) is Some(child) else { return false }
  self.current=child; true
}

///|
pub fn TreeCursor::goto_last_child(self : TreeCursor) -> Bool {
  guard self.tree.records[self.current].children.last() is Some(child) else { return false }
  self.current=child; true
}

///|
fn TreeCursor::sibling(self : TreeCursor, delta : Int) -> Bool {
  if self.current == self.start { return false }
  let node=self.tree.records[self.current]
  guard node.parent is Some(parent) && node.step is Some(step) else { return false }
  guard self.tree.records[parent].children.get(step.content_index+delta) is Some(sibling) else { return false }
  self.current=sibling; true
}

///|
pub fn TreeCursor::goto_next_sibling(self : TreeCursor) -> Bool { self.sibling(1) }

///|
pub fn TreeCursor::goto_previous_sibling(self : TreeCursor) -> Bool { self.sibling(-1) }
