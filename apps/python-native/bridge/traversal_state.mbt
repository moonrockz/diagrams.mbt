///|
/// A registered tree and its nodes in preorder. `nodes[i]` has ordinal `i`.
priv struct BpTreeEntry {
  tree : @bpmn.DocumentTree
  nodes : ReadOnlyArray[@bpmn.NodeRef]
}

///|
/// A graph and the inputs that rebuild the bp_trees of its document nodes.
priv struct BpGraphEntry {
  graph : @bpmn.DocumentGraph
  document : @bpmn.Document
  resource_id : String?
  resources : @bpmn.ResourceSet
  limits : @bpmn.Limits
}

///|
let bp_documents : Registry[@bpmn.Document] = Registry::new(1)

///|
let bp_graphs : Registry[BpGraphEntry] = Registry::new(2)

///|
let bp_readers : Registry[BpReaderEntry] = Registry::new(3)

///|
/// The terminal state of an event reader. `Stopped` follows `stop()` before
/// the end; `Complete` follows a read past the last event.
priv enum BpReaderState {
  Running
  Complete
  Stopped
}

///|
fn BpReaderState::name(self : BpReaderState) -> String {
  match self {
    Running => "running"
    Complete => "complete"
    Stopped => "stopped"
  }
}

///|
priv struct BpReaderEntry {
  reader : @bpmn.EventReader
  mut state : BpReaderState
}

///|
fn BpReaderEntry::stop(self : BpReaderEntry) -> Unit {
  self.reader.stop()
  if self.state is Running {
    self.state = Stopped
  }
}

///|
fn BpReaderEntry::next(self : BpReaderEntry) -> @bpmn.TraversalEvent? {
  let event = self.reader.next()
  if event is None && self.state is Running {
    self.state = Complete
  }
  event
}

///|
let bp_cursors : Registry[@bpmn.TreeCursor] = Registry::new(4)

///|
let bp_resource_sets : Registry[@bpmn.ResourceSet] = Registry::new(5)

///|
let bp_trees : Registry[BpTreeEntry] = Registry::new(6)

///|
/// Indexes `tree` in preorder. The ordinal of a node is its preorder index;
/// the index refuses a tree that breaks this rule.
fn bp_tree_entry(tree : @bpmn.DocumentTree) -> BpTreeEntry raise BridgeError {
  let nodes : Array[@bpmn.NodeRef] = []
  @bpmn.walk(tree.root(), node => {
    nodes.push(node)
    Continue
  })
  guard nodes.length() == tree.length() else {
    raise BridgeError("internal", "The tree index misses nodes.")
  }
  for i, node in nodes {
    guard node.handle().ordinal == i else {
      raise BridgeError("internal", "A node ordinal is not its preorder index.")
    }
  }
  { tree, nodes: ReadOnlyArray::from_array(nodes), }
}

///|
/// Registers `tree` and returns its token (kind 6).
fn bp_add_tree(tree : @bpmn.DocumentTree) -> Int64 raise BridgeError {
  bp_trees.add(bp_tree_entry(tree))
}

///|
/// The tree of a tree token (kind 6).
fn tree_of(token : Int64) -> @bpmn.DocumentTree raise BridgeError {
  bp_trees.get(token).tree
}

///|
/// The node with `ordinal` in the tree of `tree_token`. An ordinal outside the
/// tree raises `invalid-argument`.
fn node_of(
  tree_token : Int64,
  ordinal : Int32,
) -> @bpmn.NodeRef raise BridgeError {
  let entry = bp_trees.get(tree_token)
  guard ordinal >= 0 && ordinal < entry.nodes.length() else {
    raise bp_invalid_argument("The node ordinal is outside the tree.")
  }
  entry.nodes[ordinal]
}

///|
fn bp_node_arg(
  args : ArrayView[Rec],
  index : Int32,
) -> @bpmn.NodeRef raise BridgeError {
  node_of(arg_int(args, index), arg_int32(args, index + 1))
}

///|
/// Closes the object of `token`, whatever its traversal kind. Returns `false`
/// when it is already closed.
fn bp_close_token(token : Int64) -> Bool raise BridgeError {
  match token >> 48 {
    1L => bp_documents.remove(token)
    2L => bp_graphs.remove(token)
    3L => bp_readers.remove(token)
    4L => bp_cursors.remove(token)
    5L => bp_resource_sets.remove(token)
    6L => bp_trees.remove(token)
    _ =>
      raise BridgeError(
        "wrong-token", "The token does not name a traversal object.",
      )
  }
}
