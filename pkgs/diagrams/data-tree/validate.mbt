///|
/// Explicit bounds for data-tree validation and indexing.
pub struct Limits {
  nodes : Int
  depth : Int
  work : Int
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(
  nodes? : Int = 10000,
  depth? : Int = 256,
  work? : Int = 1000000,
) -> Limits {
  { nodes, depth, work }
}

///|
/// The stable diagnostic codes of data-tree validation.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "data-tree/invalid-identity", "data-tree/duplicate-identity", "data-tree/missing-node",
  "data-tree/containment-cycle", "data-tree/orphan-node", "data-tree/invalid-key",
  "data-tree/invalid-number", "data-tree/invalid-highlight", "data-tree/model-limit",
]

///|
/// A validated data tree with constant-time lookups. Each node except the root
/// has exactly one owning entry occurrence.
pub struct Index {
  tree : DataTree
  priv positions : Map[String, Int]
  priv members : Map[String, Member]
  priv owners : Map[String, String]
  priv containers : Map[String, String]
  priv depths : Map[String, Int]
  /// Node identities in pre-order.
  order : ReadOnlyArray[String]
}

///|
pub struct IndexResult {
  index : Index?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub fn Index::node(self : Index, id : String) -> Node? {
  self.positions.get(id).map(i => self.tree.nodes[i])
}

///|
pub fn Index::find_member(self : Index, id : String) -> Member? {
  self.members.get(id)
}

///|
/// The entry occurrence that owns a node. The root has none.
pub fn Index::owner(self : Index, node : String) -> Member? {
  self.owners.get(node).bind(id => self.members.get(id))
}

///|
/// The container node that holds a entry occurrence.
pub fn Index::container(self : Index, entry : String) -> String? {
  self.containers.get(entry)
}

///|
pub fn Index::depth(self : Index, node : String) -> Int? {
  self.depths.get(node)
}

///|
/// Validate identities, containment, keys, numbers, highlights and limits
/// without recursion. Scalar text is never interpreted as a reference.
pub fn Index::build(
  tree : DataTree,
  limits? : Limits = Limits::new(),
) -> IndexResult {
  let out : Array[@diagrams.Diagnostic] = []
  let mut work = 0
  let mut halted = false
  fn error(code : String, message : String) {
    if out.length() < 64 {
      out.push(@diagrams.Diagnostic::error("data-tree/" + code, message))
    }
  }
  fn charge(units : Int) -> Bool {
    if halted {
      return false
    }
    if units < 0 || units > limits.work - work {
      halted = true
      error("model-limit", "Data-tree validation work limit exceeded")
      return false
    }
    work += units
    true
  }
  fn failed() -> IndexResult {
    { index: None, diagnostics: ReadOnlyArray::from_array(out) }
  }
  if limits.nodes <= 0 || limits.depth <= 0 || limits.work <= 0 {
    error("model-limit", "Data-tree limits must be positive")
    return failed()
  }
  if tree.nodes.length() > limits.nodes {
    error("model-limit", "Data-tree node limit exceeded")
    return failed()
  }
  if tree.id.is_empty() {
    error("invalid-identity", "A data tree needs a view identity")
  }
  let positions : Map[String, Int] = Map([])
  let members : Map[String, Member] = Map([])
  let containers : Map[String, String] = Map([])
  for i, node in tree.nodes {
    if !charge(node.id.length() + 1) {
      return failed()
    }
    if node.id.is_empty() {
      error("invalid-identity", "Data node \{i} has an empty identity")
      continue
    }
    if positions.contains(node.id) || members.contains(node.id) {
      error("duplicate-identity", "Duplicate data identity '\{node.id}'")
      continue
    }
    positions[node.id] = i
    match node.value {
      Number(lexeme) =>
        if !charge(lexeme.length()) {
          return failed()
        } else if !valid_number(lexeme) {
          error(
            "invalid-number",
            "Node '\{node.id}' has an invalid number '\{lexeme}'",
          )
        }
      Text(text) => if !charge(text.length()) { return failed() }
      Object(list) | Array(list) => {
        let array = node.value is Array(_)
        if members.length() + list.length() > limits.nodes {
          error("model-limit", "Data-tree entry limit exceeded")
          return failed()
        }
        for position, entry in list {
          if !charge(entry.id.length() + 1) {
            return failed()
          }
          if entry.id.is_empty() {
            error("invalid-identity", "A entry of '\{node.id}' has no identity")
            continue
          }
          if positions.contains(entry.id) || members.contains(entry.id) {
            error("duplicate-identity", "Duplicate data identity '\{entry.id}'")
            continue
          }
          match (array, entry.key) {
            (true, Index(index)) if index == position => ()
            (false, Name(_)) => ()
            _ =>
              error(
                "invalid-key",
                "Member '\{entry.id}' has a key that does not match its container",
              )
          }
          members[entry.id] = entry
          containers[entry.id] = node.id
        }
      }
      _ => ()
    }
  }
  if !out.is_empty() {
    return failed()
  }
  for id, _ in members {
    if positions.contains(id) {
      error("duplicate-identity", "Duplicate data identity '\{id}'")
      return failed()
    }
  }
  guard positions.contains(tree.root) else {
    error("missing-node", "Data root '\{tree.root}' is not a node")
    return failed()
  }
  let owners : Map[String, String] = Map([])
  let depths : Map[String, Int] = Map([(tree.root, 0)])
  let order : Array[String] = []
  let stack = [tree.root]
  while stack.pop() is Some(id) {
    if !charge(1) {
      return failed()
    }
    order.push(id)
    let node = tree.nodes[positions[id]]
    let list = node.members()
    for i in 0..<list.length() {
      let entry = list[list.length() - 1 - i]
      guard positions.contains(entry.value) else {
        error(
          "missing-node",
          "Member '\{entry.id}' refers to missing node '\{entry.value}'",
        )
        return failed()
      }
      if entry.value == tree.root || owners.contains(entry.value) {
        error(
          "containment-cycle",
          "Node '\{entry.value}' has more than one owner or contains itself",
        )
        return failed()
      }
      let depth = depths[id] + 1
      if depth > limits.depth {
        error("model-limit", "Data-tree depth limit exceeded at '\{entry.value}'")
        return failed()
      }
      owners[entry.value] = entry.id
      depths[entry.value] = depth
      stack.push(entry.value)
    }
  }
  if order.length() != tree.nodes.length() {
    for node in tree.nodes {
      if !depths.contains(node.id) {
        error("orphan-node", "Node '\{node.id}' is not reachable from the root")
        break
      }
    }
    return failed()
  }
  for highlight in tree.highlights {
    if !charge(highlight.targets.length() + 1) {
      return failed()
    }
    for target in highlight.targets {
      if !positions.contains(target) && !members.contains(target) {
        error("invalid-highlight", "Highlight names missing target '\{target}'")
        return failed()
      }
    }
  }
  {
    index: Some({
      tree,
      positions,
      members,
      owners,
      containers,
      depths,
      order: ReadOnlyArray::from_array(order),
    }),
    diagnostics: [],
  }
}

///|
/// Validate a constructed data tree. An empty result means the tree is valid.
pub fn validate(
  tree : DataTree,
  limits? : Limits = Limits::new(),
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  Index::build(tree, limits~).diagnostics
}
