///|
/// The stable diagnostic codes of trace validation and the provider driver.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "trace/subject-mismatch", "trace/stale", "trace/invalid-target", "trace/invalid-role",
  "trace/discontinuous", "trace/invalid-span", "trace/invalid-attempt", "trace/limit",
  "trace/invalid-request", "trace/unsupported", "trace/exhausted", "trace/provider-error",
  "railroad/topology-limit",
]

///|
/// A trace that passed structural validation against one subject, with the
/// topology it refers to. Validation never re-runs or verifies matching.
pub struct ValidatedTrace {
  trace : Trace
  topology : Topology
}

///|
pub struct TraceValidation {
  validated : ValidatedTrace?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn step_points(topology : Topology, step : Step) -> (String, String)? {
  match step {
    Visit(id, _) => topology.term(id).map(t => (t.entry, t.exit))
    Traverse(id, reversed) =>
      topology
      .connector(id)
      .map(c => if reversed { (c.to, c.from) } else { (c.from, c.to) })
  }
}

///|
/// Validate supplied evidence: subject kind, model/view identity, structural
/// fingerprint, targets, roles, declared continuity, spans and bounds. It
/// reports invalid evidence without guessing targets from labels.
pub fn validate_trace(
  trace : Trace,
  subject : Subject,
  view_id? : String,
  limits? : TraceLimits = TraceLimits::new(),
) -> TraceValidation {
  let out : Array[@diagrams.Diagnostic] = []
  fn fail(code : String, message : String) -> TraceValidation {
    out.push(@diagrams.Diagnostic::error(code, message))
    { validated: None, diagnostics: ReadOnlyArray::from_array(out) }
  }
  if !limits.valid() {
    return fail("trace/limit", "Trace limits must be positive")
  }
  let expected = subject.identity(view_id=view_id.unwrap_or(subject.model_id()))
  if trace.subject.kind != expected.kind {
    return fail(
      "trace/subject-mismatch", "The trace describes another subject kind",
    )
  }
  if trace.subject.model_id != expected.model_id ||
    trace.subject.view_id != expected.view_id {
    return fail(
      "trace/subject-mismatch",
      "The trace names model '\{trace.subject.model_id}' and view '\{trace.subject.view_id}', not '\{expected.model_id}' and '\{expected.view_id}'",
    )
  }
  if trace.subject.fingerprint != expected.fingerprint {
    return fail(
      "trace/stale", "The trace was made for a different structure of this model",
    )
  }
  if trace.subject.start_rule != expected.start_rule {
    return fail("trace/subject-mismatch", "The trace names another start rule")
  }
  if trace.input.length() > limits.input {
    return fail("trace/limit", "Trace input exceeds its limit")
  }
  if trace.attempts.length() > limits.attempts {
    return fail("trace/limit", "Trace attempt limit exceeded")
  }
  let built = match subject {
    Regex(model) =>
      Topology::regex(
        model,
        limits=@regex.Limits::new(depth=limits.depth, work=limits.work),
      )
    Ebnf(grammar, _) =>
      Topology::ebnf(
        grammar,
        limits=@ebnf.Limits::new(depth=limits.depth, work=limits.work),
      )
  }
  guard built.topology is Some(topology) else {
    return { validated: None, diagnostics: built.diagnostics }
  }
  let ids : Map[String, Bool] = Map([])
  let mut steps = 0
  let mut work = 0
  let length = trace.input.length()
  fn span_ok(span : InputSpan) -> Bool {
    span.start >= 0 && span.start <= span.end && span.end <= length
  }
  for attempt in trace.attempts {
    if attempt.id.is_empty() || ids.contains(attempt.id) {
      return fail(
        "trace/invalid-attempt", "Each attempt needs a unique, nonempty identity",
      )
    }
    ids[attempt.id] = true
    if attempt.status == Matched && attempt.failure != None {
      return fail(
        "trace/invalid-attempt",
        "Matched attempt '\{attempt.id}' cannot have a failure point",
      )
    }
    if attempt.steps.length() > limits.steps - steps {
      return fail("trace/limit", "Trace step limit exceeded")
    }
    steps += attempt.steps.length()
    let mut previous : String? = None
    for i, step in attempt.steps {
      work += 1
      if work > limits.work {
        return fail("trace/limit", "Trace validation work limit exceeded")
      }
      guard step_points(topology, step) is Some((from, to)) else {
        let id = match step {
          Visit(id, _) | Traverse(id, _) => id
        }
        return fail(
          "trace/invalid-target",
          "Attempt '\{attempt.id}' step \{i} names '\{id}', which is not a \{if step is Visit(_, _) { "visible term" } else { "drawn connector" }} of this subject",
        )
      }
      if step is Visit(_, Some(span)) && !span_ok(span) {
        return fail(
          "trace/invalid-span",
          "Attempt '\{attempt.id}' step \{i} has a span outside the input",
        )
      }
      if attempt.continuous && previous is Some(point) && point != from {
        return fail(
          "trace/discontinuous",
          "Attempt '\{attempt.id}' step \{i} does not start where step \{i - 1} ends",
        )
      }
      previous = Some(to)
    }
    if attempt.failure is Some(failure) {
      if failure.position is Some(position) &&
        (position < 0 || position > length) {
        return fail(
          "trace/invalid-span",
          "Attempt '\{attempt.id}' has a failure position outside the input",
        )
      }
      let valid = match failure.target {
        Terminal(id) =>
          topology
          .term(id)
          .map(t => t.kind is (Consumed | Reference(_) | Empty))
          .unwrap_or(false)
        Assertion(id) =>
          topology
          .term(id)
          .map(t => t.kind is (Anchor | Assertion))
          .unwrap_or(false)
        Entry(id) => topology.entry(id) != None
        Exit(id) => topology.exit(id) != None
      }
      if !valid {
        return fail(
          "trace/invalid-role",
          "Attempt '\{attempt.id}' has a failure point with a wrong target or role",
        )
      }
    }
  }
  { validated: Some({ trace, topology }), diagnostics: [] }
}

///|
/// Validate a provider result. A matched result needs a matched attempt;
/// a non-match result has none.
pub fn validate_result(
  result : TraceResult,
  subject : Subject,
  view_id? : String,
  limits? : TraceLimits = TraceLimits::new(),
) -> TraceValidation {
  fn fail(code : String, message : String) -> TraceValidation {
    { validated: None, diagnostics: [@diagrams.Diagnostic::error(code, message)] }
  }
  match result {
    Matched(trace) | NotMatched(trace) => {
      let matched = trace.attempts.iter().any(a => a.status == Matched)
      if (result is Matched(_)) != matched {
        return fail(
          "trace/invalid-attempt", "The result outcome disagrees with its attempts",
        )
      }
      validate_trace(trace, subject, view_id?, limits~)
    }
    Unsupported(reason) =>
      fail("trace/unsupported", "The provider does not support this subject: " + reason)
    Exhausted(reason) =>
      fail("trace/exhausted", "The provider exhausted its budget: " + reason)
    ProviderError(reason) => fail("trace/provider-error", "The provider failed: " + reason)
  }
}

///|
/// Check a request before a provider receives it.
pub fn TraceRequest::validate(
  self : TraceRequest,
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  fn fail(message : String) -> ReadOnlyArray[@diagrams.Diagnostic] {
    [@diagrams.Diagnostic::error("trace/invalid-request", message)]
  }
  if !self.limits.valid() {
    return fail("Trace limits must be positive")
  }
  if self.input.length() > self.limits.input {
    return fail("Trace input exceeds its limit")
  }
  if self.view_id.is_empty() {
    return fail("A trace request needs a view identity")
  }
  match self.subject {
    Ebnf(grammar, start) =>
      if !grammar.rules().iter().any(r => r.id == start) {
        return fail("The start rule '\{start}' is not a rule of this grammar")
      }
    Regex(_) => ()
  }
  []
}

///|
/// The result of an explicit provider run.
pub struct TraceRun {
  result : TraceResult?
  validated : ValidatedTrace?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Invoke `provider` once for `request` and validate its result. This is the
/// only library entry point that calls a provider.
pub fn[P : RailroadTraceProvider] run(
  provider : P,
  request : TraceRequest,
) -> TraceRun {
  let invalid = request.validate()
  if !invalid.is_empty() {
    return { result: None, validated: None, diagnostics: invalid }
  }
  let result = provider.trace(request)
  let checked = validate_result(
    result,
    request.subject,
    view_id=request.view_id,
    limits=request.limits,
  )
  { result: Some(result), validated: checked.validated, diagnostics: checked.diagnostics }
}

///|
/// A run that did not reach a provider, with the reasons.
pub fn TraceRun::refused(
  diagnostics : ArrayView[@diagrams.Diagnostic],
) -> TraceRun {
  { result: None, validated: None, diagnostics: ReadOnlyArray::from_array(diagnostics) }
}
