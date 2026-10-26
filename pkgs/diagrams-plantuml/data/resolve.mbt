///|
/// The identity of the value at an ownership path. The root value is `v`;
/// the value of member 2 of the value of root member 0 is `v/0/2`.
pub fn value_id(path : ArrayView[Int32]) -> String {
  path_id("v", path)
}

///|
/// The identity of the member occurrence at an ownership path, for example
/// `m/0/2`. Member identities never use names or scalar text.
pub fn member_id(path : ArrayView[Int32]) -> String {
  path_id("m", path)
}

///|
fn path_id(head : String, path : ArrayView[Int32]) -> String {
  let out = StringBuilder()
  out.write_string(head)
  for position in path {
    out.write_char('/')
    out.write_string(position.to_string())
  }
  out.to_string()
}

///|
fn key_text(key : @data_tree.Key) -> String {
  match key {
    Name(name) => name
    Index(i) => i.to_string()
  }
}

///|
/// The result of selector resolution.
pub struct Resolution {
  highlights : Array[@data_tree.Highlight]
  diagnostics : Array[@diagrams.Diagnostic]
  /// False when the work bound stopped resolution.
  complete : Bool
}

///|
/// Resolve selectors to member identities of `tree`, in document order.
/// A selector that selects nothing gives a warning and no highlight. A plain
/// selector that selects more than one member occurrence highlights all of
/// them and gives a warning. A stereotype is kept as inert style metadata and
/// gives a warning that it is not applied. Codes use `prefix`, for example
/// `json/unresolved-highlight`.
pub fn resolve(
  tree : @data_tree.DataTree,
  selectors : ArrayView[Selector],
  prefix : String,
  work_limit~ : Int32 = 1000000,
) -> Resolution {
  let highlights = []
  let diagnostics = []
  let nodes : Map[String, @data_tree.Node] = Map([])
  for node in tree.nodes {
    nodes[node.id] = node
  }
  let mut work = 0
  let mut complete = true
  fn charge(units : Int32) -> Bool {
    if !complete {
      return false
    }
    if units > work_limit - work {
      complete = false
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "\{prefix}/work-limit",
          "Highlight resolution exceeds its work limit",
        ),
      )
      return false
    }
    work += units
    true
  }
  // Member identities in document order: a member, then the members below
  // its value, then the next member.
  let rank : Map[String, Int32] = Map([])
  let walk : Array[@data_tree.Member] = []
  fn push_members(id : String) {
    if nodes.get(id) is Some(node) {
      let members = node.members()
      for i in 0..<members.length() {
        walk.push(members[members.length() - 1 - i])
      }
    }
  }
  push_members(tree.root)
  while walk.pop() is Some(entry) {
    if !charge(1) {
      return { highlights, diagnostics, complete, }
    }
    rank[entry.id] = rank.length()
    push_members(entry.value)
  }
  for selector in selectors {
    let segments = selector.segments
    let matched : Map[String, Bool] = Map([])
    let seen : Map[String, Bool] = Map([])
    let pending = [(tree.root, 0)]
    while pending.pop() is Some((id, s)) {
      if !charge(1) {
        return { highlights, diagnostics, complete, }
      }
      if s >= segments.length() {
        continue
      }
      let visit = "\{s}:\{id}"
      if seen.contains(visit) {
        continue
      }
      seen[visit] = true
      guard nodes.get(id) is Some(node) else { continue }
      let members = node.members()
      let last = s == segments.length() - 1
      match segments[s] {
        Deep =>
          if last {
            let below = [id]
            while below.pop() is Some(inner) {
              if !charge(1) {
                return { highlights, diagnostics, complete, }
              }
              guard nodes.get(inner) is Some(container) else { continue }
              for entry in container.members() {
                matched[entry.id] = true
                below.push(entry.value)
              }
            }
          } else {
            pending.push((id, s + 1))
            for entry in members {
              if nodes.get(entry.value) is Some(child) && child.is_container() {
                pending.push((entry.value, s))
              }
            }
          }
        segment => {
          let counts : Map[String, Int32] = Map([])
          for entry in members {
            if !charge(1) {
              return { highlights, diagnostics, complete, }
            }
            let text = key_text(entry.key)
            let seen_count = counts.get(text).unwrap_or(0) + 1
            counts[text] = seen_count
            let selects = match segment {
              Any => true
              Name(name) => text == name
              Occurrence(name, n) =>
                entry.key is Name(_) && text == name && seen_count == n
              Deep => false
            }
            if !selects {
              continue
            }
            if last {
              matched[entry.id] = true
            } else if nodes.get(entry.value) is Some(child) &&
              child.is_container() {
              pending.push((entry.value, s + 1))
            }
          }
        }
      }
    }
    let targets = matched.keys().to_array()
    targets.sort_by((a, b) => {
      rank.get(a).unwrap_or(0).compare(rank.get(b).unwrap_or(0))
    })
    let span = selector.span
    if targets.is_empty() {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "\{prefix}/unresolved-highlight",
          "The highlight selects no member; it is not applied",
          span?,
        ),
      )
      continue
    }
    if selector.is_plain() && targets.length() > 1 {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "\{prefix}/ambiguous-highlight",
          "The highlight selects \{targets.length()} member occurrences; all are highlighted. Quote a name and add '#n' to select one occurrence",
          span?,
        ),
      )
    }
    if selector.stereotype is Some(_) {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "\{prefix}/unapplied-highlight-style",
          "The highlight stereotype is retained as metadata; library themes paint the highlight",
          span?,
        ),
      )
    }
    highlights.push(
      @data_tree.Highlight::new(targets, style?=selector.stereotype),
    )
  }
  { highlights, diagnostics, complete, }
}
