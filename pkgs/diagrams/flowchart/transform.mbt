///|
/// Replace a label while preserving identity, control role and source binding.
pub fn Node::with_label(self : Node, label : String) -> Node {
  { ..self, label, }
}

///|
/// Replace the ordered nodes, copying the caller's collection.
pub fn Flowchart::with_nodes(
  self : Flowchart,
  nodes : ArrayView[Node],
) -> Flowchart {
  { ..self, nodes: ReadOnlyArray::from_array(nodes), }
}

///|
/// Allocate a deterministic identity without colliding with authored identities.
pub fn fresh_id(
  stem : String,
  used : ArrayView[String],
  work_limit~ : Int32 = 1000000,
) -> Result[String, @diagrams.Diagnostic] {
  if work_limit <= 0 || stem.is_empty() {
    return Err(
      @diagrams.Diagnostic::error(
        "flowchart/invalid-limits", "An ID stem and positive work limit are required",
      ),
    )
  }
  let taken : Map[String, Bool] = Map([])
  let mut work = 0
  for id in used {
    if id.length() >= work_limit - work {
      return Err(
        @diagrams.Diagnostic::error(
          "flowchart/id-limit", "Identity allocation work limit exceeded",
        ),
      )
    }
    work += id.length() + 1
    taken[id] = true
  }
  let mut candidate = stem
  let mut suffix = 0
  while true {
    if candidate.length() >= work_limit - work {
      return Err(
        @diagrams.Diagnostic::error(
          "flowchart/id-limit", "Identity allocation work limit exceeded",
        ),
      )
    }
    work += candidate.length() + 1
    if !taken.contains(candidate) {
      return Ok(candidate)
    }
    suffix += 1
    candidate = stem + ":" + suffix.to_string()
  } nobreak {
    Err(
      @diagrams.Diagnostic::error(
        "flowchart/id-limit", "Identity allocation work limit exceeded",
      ),
    )
  }
}
