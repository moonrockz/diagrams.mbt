///|
priv enum Expansion {
  Series(ReadOnlyArray[Control], Int32)
  Sections(ReadOnlyArray[SectionInfo], Int32)
  One(Control, Int32)
  Combine(Bool, Int32)
}

///|
/// Choose conditional sections and finite loop counts explicitly. Frame labels
/// remain descriptions; the planner never evaluates their text.
pub fn PlaybackPlan::sequence(
  catalog : Catalog,
  selections~ : ArrayView[Selection] = [],
  duration_ms~ : Int64 = 1000L,
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
  if !(catalog.source is Sequence(_)) {
    budget.error(
      "animation/plan-mismatch", "Sequence choices require a sequence catalog",
    )
    return fail()
  }
  let frames = Map([])
  for frame in catalog.frames {
    frames[frame.key] = frame
  }
  let choices = Map([])
  for selection in selections {
    if !budget.charge(selection.frame_key.length() + 1) {
      return fail()
    }
    if choices.contains(selection.frame_key) {
      budget.error(
        "animation/invalid-selection", "A frame has more than one choice",
      )
      return fail()
    }
    guard frames.get(selection.frame_key) is Some(frame) else {
      budget.error(
        "animation/invalid-selection", "Choice names an unknown frame",
      )
      return fail()
    }
    let valid = match (frame.kind, selection.choice) {
      (Alt, Alternative(i)) => i >= 0 && i < frame.sections.length()
      (Opt, Optional(_)) => true
      (Loop, Repetitions(n)) => n >= 0 && n <= limits.steps
      _ => false
    }
    if !valid {
      budget.error(
        "animation/invalid-selection", "Choice does not match its frame or is out of bounds",
      )
      return fail()
    }
    choices[selection.frame_key] = selection.choice
  }
  let jobs = [Expansion::Series(catalog.controls, 0)]
  let values : Array[Motion] = []
  let mut leaves = 0
  while jobs.pop() is Some(job) {
    if !budget.charge(1) {
      return fail()
    }
    match job {
      Combine(parallel, count) => {
        let reversed = Array::makei(count, _ => values.pop().unwrap())
        let children = Array::makei(count, i => reversed[count - 1 - i])
        values.push(
          if parallel {
            Motion::parallel(children)
          } else {
            Motion::serial(children)
          },
        )
      }
      Series(controls, depth) => {
        if depth > limits.depth {
          budget.error(
            "animation/plan-limit", "Selected scenario depth limit exceeded",
          )
          return fail()
        }
        if !budget.charge(controls.length()) {
          return fail()
        }
        jobs.push(Combine(false, controls.length()))
        for i in 0..<controls.length() {
          jobs.push(One(controls[controls.length() - 1 - i], depth))
        }
      }
      Sections(sections, depth) => {
        if !budget.charge(sections.length()) {
          return fail()
        }
        jobs.push(Combine(false, sections.length()))
        for i in 0..<sections.length() {
          jobs.push(Series(sections[sections.length() - 1 - i].controls, depth))
        }
      }
      One(control, depth) =>
        match control {
          Message(index) => {
            if leaves >= limits.steps {
              budget.error(
                "animation/plan-limit", "Selected scenario step limit exceeded",
              )
              return fail()
            }
            leaves += 1
            values.push(
              Motion::Step(catalog.occurrences[index].key, duration_ms),
            )
          }
          Frame(index) => {
            let frame = catalog.frames[index]
            match frame.kind {
              Alt =>
                match choices.get(frame.key) {
                  Some(Alternative(section)) =>
                    jobs.push(
                      Series(frame.sections[section].controls, depth + 1),
                    )
                  _ => {
                    budget.error(
                      "animation/selection-required", "Choose one alternative section explicitly",
                    )
                    return fail()
                  }
                }
              Opt =>
                match choices.get(frame.key) {
                  Some(Optional(true)) =>
                    jobs.push(Sections(frame.sections, depth + 1))
                  Some(Optional(false)) => values.push(Motion::serial([]))
                  _ => {
                    budget.error(
                      "animation/selection-required", "Choose whether to include an optional frame explicitly",
                    )
                    return fail()
                  }
                }
              Loop =>
                match choices.get(frame.key) {
                  Some(Repetitions(count)) => {
                    if !budget.charge(count) {
                      return fail()
                    }
                    jobs.push(Combine(false, count))
                    for _ in 0..<count {
                      jobs.push(Sections(frame.sections, depth + 1))
                    }
                  }
                  _ => {
                    budget.error(
                      "animation/selection-required", "Choose a finite loop repetition count explicitly",
                    )
                    return fail()
                  }
                }
              Par | ParOver => {
                if !budget.charge(frame.sections.length()) {
                  return fail()
                }
                jobs.push(Combine(true, frame.sections.length()))
                for i in 0..<frame.sections.length() {
                  jobs.push(
                    Series(
                      frame.sections[frame.sections.length() - 1 - i].controls,
                      depth + 1,
                    ),
                  )
                }
              }
              _ => jobs.push(Sections(frame.sections, depth + 1))
            }
          }
        }
    }
  }
  PlaybackPlan::scenario(catalog, values.pop().unwrap(), limits~)
}
