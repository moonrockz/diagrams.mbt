///|
/// Explicit bounds for grammar validation and indexing.
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
/// The stable diagnostic codes of grammar validation.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "ebnf/invalid-identity", "ebnf/duplicate-identity", "ebnf/missing-node", "ebnf/containment-cycle",
  "ebnf/orphan-node", "ebnf/invalid-count", "ebnf/invalid-node", "ebnf/invalid-reference",
  "ebnf/unresolved-reference", "ebnf/ambiguous-reference", "ebnf/model-limit",
]

///|
/// How a reference resolved. Unresolved and ambiguous names stay renderable.
pub(all) enum Resolution {
  Resolved(String)
  Unresolved
  Ambiguous(ReadOnlyArray[String])
} derive(Eq, Debug)

///|
pub extend Resolution with Eq::{equal, not_equal}

///|
pub extend Resolution with @debug.Debug::{to_repr}

///|
/// A validated grammar with constant-time lookups. Each expression node has
/// exactly one owner. References are symbolic and never expand definitions.
pub struct Index {
  grammar : Grammar
  priv positions : Map[String, Int]
  priv rules : Map[String, Rule]
  priv parents : Map[String, String]
  priv owners : Map[String, String]
  priv depths : Map[String, Int]
  priv resolutions : Map[String, Resolution]
  /// Expression node identities in rule order, then pre-order.
  order : ReadOnlyArray[String]
}

///|
pub struct IndexResult {
  index : Index?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub fn Index::node(self : Index, id : String) -> Node? {
  self.positions.get(id).map(i => self.grammar.nodes[i])
}

///|
pub fn Index::rule(self : Index, id : String) -> Rule? {
  self.rules.get(id)
}

///|
/// The parent node of an expression node. The body root has no parent.
pub fn Index::parent(self : Index, id : String) -> String? {
  self.parents.get(id)
}

///|
/// The identity of the rule that owns an expression node.
pub fn Index::owner(self : Index, id : String) -> String? {
  self.owners.get(id)
}

///|
pub fn Index::depth(self : Index, id : String) -> Int? {
  self.depths.get(id)
}

///|
/// The resolution of a reference node, or `None` for another node kind.
pub fn Index::resolution(self : Index, id : String) -> Resolution? {
  self.resolutions.get(id)
}

///|
fn is_decimal(text : String) -> Bool {
  if text.is_empty() {
    return false
  }
  for c in text {
    if c < '0' || c > '9' {
      return false
    }
  }
  true
}

///|
/// Validate identities, ownership, references, counts and limits without
/// recursion. Unresolved and ambiguous names are warnings.
pub fn Index::build(
  grammar : Grammar,
  limits? : Limits = Limits::new(),
) -> IndexResult {
  let out : Array[@diagrams.Diagnostic] = []
  let warnings : Array[@diagrams.Diagnostic] = []
  let mut work = 0
  let mut halted = false
  fn error(code : String, message : String) {
    if out.length() < 64 {
      out.push(@diagrams.Diagnostic::error("ebnf/" + code, message))
    }
  }
  fn charge(units : Int) -> Bool {
    if halted {
      return false
    }
    if units < 0 || units > limits.work - work {
      halted = true
      error("model-limit", "Grammar validation work limit exceeded")
      return false
    }
    work += units
    true
  }
  fn failed() -> IndexResult {
    { index: None, diagnostics: ReadOnlyArray::from_array(out) }
  }
  if limits.nodes <= 0 || limits.depth <= 0 || limits.work <= 0 {
    error("model-limit", "Grammar limits must be positive")
    return failed()
  }
  if grammar.nodes.length() + grammar.items.length() > limits.nodes {
    error("model-limit", "Grammar node limit exceeded")
    return failed()
  }
  if grammar.id.is_empty() {
    error("invalid-identity", "A grammar needs a view identity")
  }
  let ids : Map[String, Bool] = Map([])
  let rules : Map[String, Rule] = Map([])
  let names : Map[String, Array[String]] = Map([])
  let rule_order : Array[Rule] = []
  for item in grammar.items {
    let (id, text) = match item {
      Rule(rule) => (rule.id, rule.name)
      Note(id, text) => (id, text)
    }
    if !charge(id.length() + text.length() + 1) {
      return failed()
    }
    if id.is_empty() {
      error("invalid-identity", "A grammar statement has an empty identity")
      continue
    }
    if ids.contains(id) {
      error("duplicate-identity", "Duplicate grammar identity '\{id}'")
      continue
    }
    ids[id] = true
    if item is Rule(rule) {
      if rule.name.is_empty() {
        error("invalid-node", "Rule '\{rule.id}' has no name")
      }
      rules[rule.id] = rule
      rule_order.push(rule)
      match names.get(rule.name) {
        Some(list) => list.push(rule.id)
        None => names[rule.name] = [rule.id]
      }
    }
  }
  let positions : Map[String, Int] = Map([])
  for i, node in grammar.nodes {
    if !charge(node.id.length() + 1) {
      return failed()
    }
    if node.id.is_empty() {
      error("invalid-identity", "Grammar node \{i} has an empty identity")
      continue
    }
    if ids.contains(node.id) || positions.contains(node.id) {
      error("duplicate-identity", "Duplicate grammar identity '\{node.id}'")
      continue
    }
    positions[node.id] = i
    match node.kind {
      Reference(name, target) => {
        if name.is_empty() {
          error("invalid-node", "Reference '\{node.id}' has no name")
        }
        if target is Some(rule) && !rules.contains(rule) {
          error(
            "invalid-reference",
            "Reference '\{node.id}' names missing rule identity '\{rule}'",
          )
        }
      }
      Sequence(items) =>
        if items.is_empty() {
          error("invalid-node", "Sequence '\{node.id}' has no items")
        }
      Choice(items) =>
        if items.length() < 2 {
          error("invalid-node", "Choice '\{node.id}' needs two alternatives")
        }
      Count(count, _) =>
        if !is_decimal(count) {
          error(
            "invalid-count",
            "Count '\{node.id}' must be a decimal number, not '\{count}'",
          )
        }
      _ => ()
    }
  }
  if !out.is_empty() {
    return failed()
  }
  let parents : Map[String, String] = Map([])
  let owners : Map[String, String] = Map([])
  let depths : Map[String, Int] = Map([])
  let resolutions : Map[String, Resolution] = Map([])
  let order : Array[String] = []
  for rule in rule_order {
    guard rule.body is Some(body) else { continue }
    guard positions.contains(body) else {
      error("missing-node", "Rule '\{rule.id}' refers to missing node '\{body}'")
      return failed()
    }
    if owners.contains(body) {
      error("containment-cycle", "Node '\{body}' has more than one owner")
      return failed()
    }
    owners[body] = rule.id
    depths[body] = 0
    let stack = [body]
    while stack.pop() is Some(id) {
      if !charge(1) {
        return failed()
      }
      order.push(id)
      let node = grammar.nodes[positions[id]]
      let depth = depths[id]
      if node.kind is Reference(name, target) {
        let resolution : Resolution = match target {
          Some(rule) => Resolved(rule)
          None =>
            match names.get(name) {
              Some([rule]) => Resolved(rule)
              Some(list) => Ambiguous(ReadOnlyArray::from_array(list))
              None => Unresolved
            }
        }
        match resolution {
          Unresolved =>
            warnings.push(
              @diagrams.Diagnostic::warning(
                "ebnf/unresolved-reference",
                "Reference '\{node.id}' names undefined rule '\{name}'",
              ),
            )
          Ambiguous(_) =>
            warnings.push(
              @diagrams.Diagnostic::warning(
                "ebnf/ambiguous-reference",
                "Reference '\{node.id}' names rule '\{name}', which has more than one definition",
              ),
            )
          Resolved(_) => ()
        }
        resolutions[id] = resolution
      }
      let children = node.children()
      if !charge(children.length()) {
        return failed()
      }
      for i in 0..<children.length() {
        let child = children[children.length() - 1 - i]
        guard positions.contains(child) else {
          error(
            "missing-node",
            "Node '\{id}' refers to missing node '\{child}'",
          )
          return failed()
        }
        if owners.contains(child) {
          error(
            "containment-cycle",
            "Node '\{child}' has more than one owner or contains itself",
          )
          return failed()
        }
        if depth + 1 > limits.depth {
          error("model-limit", "Grammar depth limit exceeded at '\{child}'")
          return failed()
        }
        parents[child] = id
        owners[child] = rule.id
        depths[child] = depth + 1
        stack.push(child)
      }
    }
  }
  if order.length() != grammar.nodes.length() {
    for node in grammar.nodes {
      if !owners.contains(node.id) {
        error("orphan-node", "Node '\{node.id}' is not owned by a rule")
        break
      }
    }
    return failed()
  }
  {
    index: Some({
      grammar,
      positions,
      rules,
      parents,
      owners,
      depths,
      resolutions,
      order: ReadOnlyArray::from_array(order),
    }),
    diagnostics: ReadOnlyArray::from_array(warnings),
  }
}

///|
/// Validate a constructed grammar. Errors prevent rendering; warnings for
/// unresolved or ambiguous names do not.
pub fn validate(
  grammar : Grammar,
  limits? : Limits = Limits::new(),
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  Index::build(grammar, limits~).diagnostics
}
