///|
/// Validate references and ownership, without evaluating state-machine behavior.
/// Exhaustion uses state/model-limit, state/depth-limit or state/work-limit.
pub fn validate(
  model : StateDiagram,
  nodes_limit~ : Int32 = 10000,
  edges_limit~ : Int32 = 50000,
  regions_limit~ : Int32 = 10000,
  depth_limit~ : Int32 = 256,
  diagnostics_limit~ : Int32 = 256,
  work_limit~ : Int32 = 1000000,
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  let out : Array[@diagrams.Diagnostic] = []
  let mut work = 0
  let mut halted = false
  fn error(code : String, text : String) {
    if halted {
      return
    }
    if out.length() >= diagnostics_limit {
      halted = true
      if !out.is_empty() {
        out[out.length() - 1] = @diagrams.Diagnostic::error(
          "state/diagnostic-limit", "State validation diagnostic budget exhausted",
        )
      }
    } else {
      out.push(@diagrams.Diagnostic::error("state/" + code, text))
    }
  }
  fn charge(n : Int32) -> Bool {
    if halted {
      return false
    }
    if n < 0 || n > work_limit - work {
      error("work-limit", "State validation work budget exhausted")
      halted = true
      false
    } else {
      work += n
      true
    }
  }
  fn text(value : String) -> Bool {
    charge(value.length() + 1)
  }
  fn optional(value : String?) -> Bool {
    value.map(text).unwrap_or(true)
  }
  fn origin(value : @flowchart.SourceBinding?) -> Bool {
    guard value is Some(value) else { return true }
    if !text(value.format) || !text(value.path) {
      return false
    }
    if value.span is Some(span) &&
      (
        span.start.offset < 0 ||
        span.end.offset < span.start.offset ||
        span.start.line < 1 ||
        span.start.column < 1 ||
        span.end.line < span.start.line ||
        span.end.column < 1 ||
        (
          span.start.line == span.end.line &&
          span.end.column < span.start.column
        )
      ) {
      error("source-binding", "Invalid source span: " + value.path)
    }
    true
  }
  if nodes_limit <= 0 ||
    edges_limit <= 0 ||
    regions_limit <= 0 ||
    depth_limit <= 0 ||
    diagnostics_limit <= 0 ||
    work_limit <= 0 {
    return [
      @diagrams.Diagnostic::error(
        "state/invalid-limits", "State validation limits must be positive",
      ),
    ]
  }
  if model.states.length() > nodes_limit ||
    model.notes.length() > nodes_limit - model.states.length() ||
    model.regions.length() > regions_limit ||
    model.transitions.length() > edges_limit {
    error("model-limit", "State model size budget exhausted")
    return ReadOnlyArray::from_array(out)
  }
  if !text(model.id) ||
    !optional(model.title) ||
    !optional(model.accessibility_title) ||
    !optional(model.accessibility_description) {
    return ReadOnlyArray::from_array(out)
  }
  let ids : Map[String, Bool] = Map([])
  let states : Map[String, State] = Map([])
  let regions : Map[String, Region] = Map([])
  fn add(id : String) -> Bool {
    if !text(id) {
      return false
    }
    if id == "" || ids.contains(id) {
      error("duplicate-id", "Ambiguous state element identity: " + id)
    }
    ids[id] = true
    !halted
  }
  for state in model.states {
    if !add(state.id) ||
      !text(state.label) ||
      !text(state.region) ||
      !origin(state.origin) ||
      !charge(state.descriptions.length()) {
      return ReadOnlyArray::from_array(out)
    }
    if state.role is Unsupported(symbol) && !text(symbol) {
      return ReadOnlyArray::from_array(out)
    }
    for description in state.descriptions {
      if !text(description) {
        return ReadOnlyArray::from_array(out)
      }
    }
    states[state.id] = state
  }
  for region in model.regions {
    if !add(region.id) ||
      !optional(region.owner) ||
      !origin(region.origin) ||
      !charge(region.members.length()) {
      return ReadOnlyArray::from_array(out)
    }
    regions[region.id] = region
  }
  let membership : Map[String, String] = Map([])
  for region in model.regions {
    if region.owner is Some(owner) {
      match states.get(owner) {
        Some(state) =>
          if state.role != Composite {
            error(
              "invalid-owner",
              "Region owner must be a composite state: " + owner,
            )
          }
        None => error("missing-owner", "Missing region owner: " + owner)
      }
    }
    let members : Map[String, Bool] = Map([])
    for id in region.members {
      if !text(id) {
        return ReadOnlyArray::from_array(out)
      }
      if members.contains(id) {
        error("region-member", "Duplicate region member: " + id)
      }
      members[id] = true
      membership[id] = region.id
      match states.get(id) {
        Some(state) =>
          if state.region != region.id {
            error("region-member", "Inconsistent region membership: " + id)
          }
        None => error("region-member", "Missing state member: " + id)
      }
    }
  }
  for state in model.states {
    if !regions.contains(state.region) {
      error("missing-region", "Missing owning region for " + state.id)
    }
    if membership.get(state.id) != Some(state.region) {
      error(
        "region-member",
        "State is absent from its owning region membership: " + state.id,
      )
    }
    let mut cursor = Some(state.id)
    let seen : Map[String, Bool] = Map([])
    let mut depth = 0
    while cursor is Some(id) {
      if !charge(1) {
        return ReadOnlyArray::from_array(out)
      }
      if seen.contains(id) {
        error("ownership-cycle", "State ownership cycle at " + id)
        break
      }
      seen[id] = true
      if depth >= depth_limit {
        error("depth-limit", "State ownership depth budget exhausted")
        return ReadOnlyArray::from_array(out)
      }
      depth += 1
      guard states.get(id) is Some(current) else { break }
      match regions.get(current.region) {
        Some(region) => cursor = region.owner
        None => {
          error("missing-region", "Missing owning region for " + id)
          break
        }
      }
    }
  }
  let transition_ids : Map[String, Bool] = Map([])
  for transition in model.transitions {
    if !add(transition.id) ||
      !text(transition.source) ||
      !text(transition.target) ||
      !text(transition.label) ||
      !origin(transition.origin) {
      return ReadOnlyArray::from_array(out)
    }
    transition_ids[transition.id] = true
    if !states.contains(transition.source) ||
      !states.contains(transition.target) {
      error("missing-endpoint", "Missing transition endpoint: " + transition.id)
    }
    if transition.min_length < 1 {
      error(
        "invalid-length",
        "Transition length must be positive: " + transition.id,
      )
    }
  }
  for note in model.notes {
    if !add(note.id) ||
      !text(note.text) ||
      !text(note.placement) ||
      !text(note.region) ||
      !origin(note.origin) ||
      !charge(note.targets.length() + note.connection_targets.length()) {
      return ReadOnlyArray::from_array(out)
    }
    if !regions.contains(note.region) {
      error("missing-region", "Missing note region: " + note.id)
    }
    if !["left", "right", "top", "bottom", "floating"].contains(note.placement) {
      error("note-placement", "Invalid note placement: " + note.id)
    }
    for target in note.connection_targets {
      if !text(target) {
        return ReadOnlyArray::from_array(out)
      }
      if !transition_ids.contains(target) {
        error("note-target", "Missing note transition: " + target)
      }
    }
    for target in note.targets {
      if !text(target) {
        return ReadOnlyArray::from_array(out)
      }
      if !states.contains(target) {
        error("note-target", "Missing note target: " + target)
      }
    }
  }
  ReadOnlyArray::from_array(out)
}

///|
pub fn fresh_id(
  stem : String,
  used : ArrayView[String],
  work_limit~ : Int32 = 1000000,
) -> Result[String, @diagrams.Diagnostic] {
  @flowchart.fresh_id(stem, used, work_limit~).map_err(d => {
    ..d,
    code: d.code.replace_all(old="flowchart/", new="state/"),
  })
}
