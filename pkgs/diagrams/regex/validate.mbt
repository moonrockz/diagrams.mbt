///|
/// Explicit bounds for model validation and indexing.
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
/// The stable diagnostic codes of model validation.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "regex/invalid-identity", "regex/duplicate-identity", "regex/missing-node", "regex/containment-cycle",
  "regex/orphan-node", "regex/invalid-bounds", "regex/invalid-node", "regex/model-limit",
]

///|
/// A validated view of a regex model with constant-time lookups. Every node
/// except the root has exactly one parent, so the arena is a finite tree.
pub struct Index {
  regex : Regex
  priv positions : Map[String, Int]
  priv parents : Map[String, String]
  priv depths : Map[String, Int]
  /// Node identities in pre-order (drawing order).
  order : ReadOnlyArray[String]
}

///|
pub struct IndexResult {
  index : Index?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub fn Index::node(self : Index, id : String) -> Node? {
  self.positions.get(id).map(i => self.regex.nodes[i])
}

///|
pub fn Index::parent(self : Index, id : String) -> String? {
  self.parents.get(id)
}

///|
pub fn Index::depth(self : Index, id : String) -> Int? {
  self.depths.get(id)
}

///|
/// Validate identities, ownership, bounds and explicit limits without recursion.
pub fn Index::build(regex : Regex, limits? : Limits = Limits::new()) -> IndexResult {
  let out : Array[@diagrams.Diagnostic] = []
  let mut work = 0
  let mut halted = false
  fn error(code : String, message : String) {
    if out.length() < 64 {
      out.push(@diagrams.Diagnostic::error("regex/" + code, message))
    }
  }
  fn charge(units : Int) -> Bool {
    if halted {
      return false
    }
    if units < 0 || units > limits.work - work {
      halted = true
      error("model-limit", "Regex validation work limit exceeded")
      return false
    }
    work += units
    true
  }
  fn failed() -> IndexResult {
    { index: None, diagnostics: ReadOnlyArray::from_array(out) }
  }
  if limits.nodes <= 0 || limits.depth <= 0 || limits.work <= 0 {
    error("model-limit", "Regex limits must be positive")
    return failed()
  }
  if regex.nodes.length() > limits.nodes {
    error("model-limit", "Regex node limit exceeded")
    return failed()
  }
  if regex.id.is_empty() {
    error("invalid-identity", "A regex model needs a view identity")
  }
  let positions : Map[String, Int] = Map([])
  for i, node in regex.nodes {
    if !charge(node.id.length() + 1) {
      return failed()
    }
    if node.id.is_empty() {
      error("invalid-identity", "Regex node \{i} has an empty identity")
    } else if positions.contains(node.id) {
      error("duplicate-identity", "Duplicate regex node identity '\{node.id}'")
    } else {
      positions[node.id] = i
    }
    match node.kind {
      Literal(text) =>
        if text.is_empty() {
          error("invalid-node", "Literal '\{node.id}' has no text")
        }
      Set(_, items) =>
        if items.is_empty() {
          error("invalid-node", "Character set '\{node.id}' has no items")
        }
      Backreference(number) =>
        if number.is_empty() || number.iter().any(c => c < '0' || c > '9') {
          error("invalid-node", "Backreference '\{node.id}' needs a group number")
        }
      Class(Property(name)) | Class(Posix(name)) | Class(CodePoint(name)) =>
        if name.is_empty() {
          error("invalid-node", "Class '\{node.id}' has no name")
        }
      Sequence(items) =>
        if items.is_empty() {
          error("invalid-node", "Sequence '\{node.id}' has no items")
        }
      Choice(items) =>
        if items.length() < 2 {
          error("invalid-node", "Choice '\{node.id}' needs two alternatives")
        }
      Group(Named(name), _) =>
        if name.is_empty() {
          error("invalid-node", "Named group '\{node.id}' has no name")
        }
      Repeat(bounds, _) =>
        if bounds.min < 0 ||
          (bounds.max is Some(max) && max < bounds.min) ||
          bounds.spelling.is_empty() {
          error(
            "invalid-bounds",
            "Repeat '\{node.id}' has invalid bounds \{bounds.spelling}",
          )
        }
      _ => ()
    }
  }
  if !out.is_empty() {
    return failed()
  }
  guard positions.contains(regex.root) else {
    error("missing-node", "Regex root '\{regex.root}' is not a node")
    return failed()
  }
  let parents : Map[String, String] = Map([])
  let depths : Map[String, Int] = Map([(regex.root, 0)])
  let order : Array[String] = []
  let stack : Array[String] = [regex.root]
  while stack.pop() is Some(id) {
    if !charge(1) {
      return failed()
    }
    order.push(id)
    let node = regex.nodes[positions[id]]
    let depth = depths[id]
    let children = node.children()
    if !charge(children.length()) {
      return failed()
    }
    for i in 0..<children.length() {
      let child = children[children.length() - 1 - i]
      guard positions.contains(child) else {
        error("missing-node", "Node '\{id}' refers to missing node '\{child}'")
        return failed()
      }
      if child == regex.root || parents.contains(child) {
        error(
          "containment-cycle",
          "Node '\{child}' has more than one owner or contains itself",
        )
        return failed()
      }
      if depth + 1 > limits.depth {
        error("model-limit", "Regex depth limit exceeded at '\{child}'")
        return failed()
      }
      parents[child] = id
      depths[child] = depth + 1
      stack.push(child)
    }
  }
  if order.length() != regex.nodes.length() {
    for node in regex.nodes {
      if !depths.contains(node.id) {
        error("orphan-node", "Node '\{node.id}' is not reachable from the root")
        break
      }
    }
    return failed()
  }
  {
    index: Some({
      regex,
      positions,
      parents,
      depths,
      order: ReadOnlyArray::from_array(order),
    }),
    diagnostics: [],
  }
}

///|
/// Validate a constructed model. An empty result means the model is valid.
pub fn validate(
  regex : Regex,
  limits? : Limits = Limits::new(),
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  Index::build(regex, limits~).diagnostics
}
