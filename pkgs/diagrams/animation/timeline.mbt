///|
priv struct Timing {
  action : Motion
  children : Array[Int32]
  groups : ReadOnlyArray[Int32]
  mut duration : Int64
  mut start : Int64
}

///|
/// Validate a finite, explicit scenario. Parallel children share a start and the
/// following serial item waits for the longest branch, without stage barriers.
pub fn PlaybackPlan::scenario(
  catalog : Catalog,
  motion : Motion,
  limits~ : Limits = Limits::new(),
) -> PlanResult {
  let budget = Budget::{ limits, diagnostics: [], work: 0, failed: false, }
  fn fail() -> PlanResult {
    { plan: None, diagnostics: ReadOnlyArray::from_array(budget.diagnostics), }
  }
  if !limits.valid() {
    budget.error(
      "animation/plan-limit", "Animation limits must be positive and steps at most 100000",
    )
    return fail()
  }
  let timing : Array[Timing] = []
  let stack : Array[(Motion, Int32?, Int32, ReadOnlyArray[Int32])] = [
    (motion, None, 0, []),
  ]
  let mut leaves = 0
  while stack.pop() is Some((action, parent, depth, groups)) {
    if !budget.charge(1 + groups.length()) {
      return fail()
    }
    if depth > limits.depth {
      budget.error("animation/plan-limit", "Scenario depth limit exceeded")
      return fail()
    }
    let index = timing.length()
    timing.push({ action, children: [], groups, duration: 0L, start: 0L, })
    if parent is Some(parent) {
      timing[parent].children.push(index)
    }
    let children : ReadOnlyArray[Motion] = match action {
      Step(key, duration)
      | OrientedStep(key, duration, _)
      | Visit(key, duration) => {
        if !budget.charge(key.length()) {
          return fail()
        }
        guard catalog.occurrence(key) is Some(occurrence) else {
          budget.error(
            "animation/invalid-identity", "Scenario names an occurrence outside its catalog",
          )
          return fail()
        }
        if occurrence.is_visit() != (action is Visit(_, _)) {
          budget.error(
            "animation/invalid-target-kind",
            if occurrence.is_visit() {
              "A connection step names a node-visit target; use Visit"
            } else {
              "A node visit names a connection occurrence; use Step"
            },
          )
          return fail()
        }
        if duration <= 0L || duration > max_duration_ms {
          budget.error(
            "animation/invalid-duration", "Step duration must be positive and exactly representable in JavaScript",
          )
          return fail()
        }
        if leaves >= limits.steps {
          budget.error("animation/plan-limit", "Scenario step limit exceeded")
          return fail()
        }
        leaves += 1
        timing[index].duration = duration
        []
      }
      Serial(children) | Parallel(children) => children
    }
    let groups = match action {
      Parallel(_) =>
        ReadOnlyArray::from_array(
          groups.iter().concat([index].iter()).to_array(),
        )
      _ => groups
    }
    if children.length() > limits.work - budget.work {
      budget.error(
        "animation/plan-limit", "Scenario size exceeds its work limit",
      )
      return fail()
    }
    for i in 0..<children.length() {
      stack.push(
        (children[children.length() - 1 - i], Some(index), depth + 1, groups),
      )
    }
  }
  for reversed in 0..<timing.length() {
    let index = timing.length() - 1 - reversed
    let node = timing[index]
    match node.action {
      Step(_, _) | OrientedStep(_, _, _) | Visit(_, _) => ()
      Serial(_) => {
        let mut total = 0L
        for child in node.children {
          if !budget.charge(1) {
            return fail()
          }
          let duration = timing[child].duration
          if duration > max_duration_ms - total {
            budget.error(
              "animation/plan-limit", "Total duration exceeds JavaScript's exact integer range",
            )
            return fail()
          }
          total += duration
        }
        node.duration = total
      }
      Parallel(_) =>
        for child in node.children {
          if !budget.charge(1) {
            return fail()
          }
          node.duration = Int64::max(node.duration, timing[child].duration)
        }
    }
  }
  let steps : Array[ScheduledStep] = []
  for node in timing {
    if !budget.charge(1) {
      return fail()
    }
    let mut cursor = node.start
    for child in node.children {
      timing[child].start = cursor
      if node.action is Serial(_) {
        cursor += timing[child].duration
      }
    }
    let leaf = match node.action {
      Step(key, duration) => Some((key, duration, false))
      OrientedStep(key, duration, reversed) => Some((key, duration, reversed))
      Visit(key, duration) => Some((key, duration, false))
      _ => None
    }
    if leaf is Some((key, duration, reversed)) {
      steps.push({
        ordinal: steps.length(),
        occurrence: catalog.occurrence(key).unwrap(),
        start_ms: node.start,
        duration_ms: duration,
        concurrent_groups: node.groups,
        reversed,
        visit: node.action is Visit(_, _),
      })
    }
  }
  {
    plan: Some({
      view_id: catalog.view_id,
      source: catalog.source,
      mode: Finite,
      duration_ms: timing[0].duration,
      steps: ReadOnlyArray::from_array(steps),
    }),
    diagnostics: [],
  }
}

///|
/// The authored catalog is an illustration, including separate alternatives.
/// Repeating it never asserts that these connections form a feasible execution.
pub fn PlaybackPlan::illustrative(
  catalog : Catalog,
  duration_ms~ : Int64 = 1000L,
  kinds~ : ArrayView[@bpmn.ConnectionKind] = [SequenceFlow, MessageFlow],
  limits~ : Limits = Limits::new(),
) -> PlanResult {
  let budget = Budget::{ limits, diagnostics: [], work: 0, failed: false, }
  fn fail() -> PlanResult {
    { plan: None, diagnostics: ReadOnlyArray::from_array(budget.diagnostics), }
  }
  if !limits.valid() {
    budget.error("animation/plan-limit", "Invalid animation limits")
    return fail()
  }
  if duration_ms <= 0L || duration_ms > max_duration_ms {
    budget.error(
      "animation/invalid-duration", "Illustrative duration must be positive and exactly representable in JavaScript",
    )
    return fail()
  }
  let selected_kinds = []
  for kind in kinds {
    if !budget.charge(1) {
      return fail()
    }
    if !selected_kinds.contains(kind) {
      selected_kinds.push(kind)
    }
  }
  let actions = []
  for occurrence in catalog.occurrences {
    if !budget.charge(1) {
      return fail()
    }
    let selected = match occurrence.kind {
      SequenceMessage => true
      Swimlane(_) => true
      Railroad(_) | DataConnector | Visit(_) => true
      Bpmn(kind) => selected_kinds.contains(kind)
    }
    if selected {
      if actions.length() >= limits.steps {
        budget.error("animation/plan-limit", "Illustrative step limit exceeded")
        return fail()
      }
      match occurrence.kind {
        Swimlane(Backward) =>
          actions.push(Motion::OrientedStep(occurrence.key, duration_ms, true))
        Visit(_) => actions.push(Motion::Visit(occurrence.key, duration_ms))
        _ => actions.push(Motion::Step(occurrence.key, duration_ms))
      }
    }
  }
  if actions.is_empty() {
    return {
      plan: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "animation/no-flow", "The selected view has no selected visible connection occurrences",
        ),
      ],
    }
  }
  let result = PlaybackPlan::scenario(catalog, Motion::serial(actions), limits~)
  { ..result, plan: result.plan.map(p => { ..p, mode: Illustrative, }), }
}

///|
/// Repeat a validated nonempty plan without changing its source or timing.
pub fn PlaybackPlan::repeating(self : PlaybackPlan) -> PlanResult {
  if self.duration_ms <= 0L || self.steps.is_empty() {
    return {
      plan: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "animation/no-flow", "A repeating plan needs a connection occurrence",
        ),
      ],
    }
  }
  { plan: Some({ ..self, mode: Illustrative, }), diagnostics: [], }
}
