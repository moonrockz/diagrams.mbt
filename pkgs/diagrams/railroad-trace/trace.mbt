///|
/// The typed subject of a trace request. An EBNF subject names its start rule
/// by rule identity.
#derive(Eq, Debug)
pub(all) enum Subject {
  Regex(@regex.Regex)
  Ebnf(@ebnf.Grammar, String)
}

///|
pub extend Subject with Eq::{equal, not_equal}

///|
pub extend Subject with @debug.Debug::{to_repr}

///|
pub fn Subject::kind(self : Subject) -> SubjectKind {
  match self {
    Regex(_) => Regex
    Ebnf(_, _) => Ebnf
  }
}

///|
pub fn Subject::model_id(self : Subject) -> String {
  match self {
    Regex(model) => model.id
    Ebnf(grammar, _) => grammar.id
  }
}

///|
/// The provenance of a trace: subject kind, model and view identity and the
/// structural fingerprint of the model.
#derive(Eq, Debug)
pub struct SubjectIdentity {
  kind : SubjectKind
  model_id : String
  view_id : String
  fingerprint : String
  start_rule : String?
}

///|
pub extend SubjectIdentity with Eq::{equal, not_equal}

///|
pub extend SubjectIdentity with @debug.Debug::{to_repr}

///|
pub fn Subject::identity(self : Subject, view_id? : String) -> SubjectIdentity {
  {
    kind: self.kind(),
    model_id: self.model_id(),
    view_id: view_id.unwrap_or(self.model_id()),
    fingerprint: self.fingerprint(),
    start_rule: match self {
      Ebnf(_, rule) => Some(rule)
      Regex(_) => None
    },
  }
}

///|
/// Explicit trace bounds. Providers honor them cooperatively; validation
/// enforces them for every supplied trace.
#derive(Eq, Debug)
pub struct TraceLimits {
  input : Int32
  attempts : Int32
  steps : Int32
  depth : Int32
  work : Int32
}

///|
pub extend TraceLimits with Eq::{equal, not_equal}

///|
pub extend TraceLimits with @debug.Debug::{to_repr}

///|
pub fn TraceLimits::new(
  input~ : Int32 = 65536,
  attempts~ : Int32 = 256,
  steps~ : Int32 = 100000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
) -> TraceLimits {
  { input, attempts, steps, depth, work, }
}

///|
pub fn TraceLimits::valid(self : TraceLimits) -> Bool {
  self.input > 0 &&
  self.attempts > 0 &&
  self.steps > 0 &&
  self.depth > 0 &&
  self.work > 0
}

///|
/// One immutable request to an external matching or parsing engine.
#derive(Eq, Debug)
pub struct TraceRequest {
  subject : Subject
  view_id : String
  input : String
  limits : TraceLimits
}

///|
pub extend TraceRequest with Eq::{equal, not_equal}

///|
pub extend TraceRequest with @debug.Debug::{to_repr}

///|
pub fn TraceRequest::regex(
  model : @regex.Regex,
  input : String,
  view_id? : String,
  limits~ : TraceLimits = TraceLimits::new(),
) -> TraceRequest {
  {
    subject: Regex(model),
    view_id: view_id.unwrap_or(model.id),
    input,
    limits,
  }
}

///|
pub fn TraceRequest::ebnf(
  grammar : @ebnf.Grammar,
  start_rule : String,
  input : String,
  view_id? : String,
  limits~ : TraceLimits = TraceLimits::new(),
) -> TraceRequest {
  {
    subject: Ebnf(grammar, start_rule),
    view_id: view_id.unwrap_or(grammar.id),
    input,
    limits,
  }
}

///|
/// The provenance that a trace for this request must carry.
pub fn TraceRequest::identity(self : TraceRequest) -> SubjectIdentity {
  self.subject.identity(view_id=self.view_id)
}

///|
/// The semantic topology of the requested subject, for mapping engine events.
pub fn TraceRequest::topology(self : TraceRequest) -> TopologyResult {
  match self.subject {
    Regex(model) => Topology::regex(model)
    Ebnf(grammar, _) => Topology::ebnf(grammar)
  }
}

///|
/// A half-open UTF-16 span of the input.
#derive(Eq, Debug)
pub struct InputSpan {
  start : Int32
  end : Int32
}

///|
pub extend InputSpan with Eq::{equal, not_equal}

///|
pub extend InputSpan with @debug.Debug::{to_repr}

///|
pub fn InputSpan::new(start : Int32, end : Int32) -> InputSpan {
  { start, end, }
}

///|
/// One oriented trace step. A visit passes through a term from its entry to
/// its exit. A traversal follows a drawn connector, forward or reversed.
#derive(Eq, Debug)
pub(all) enum Step {
  Visit(String, InputSpan?)
  Traverse(String, Bool)
}

///|
pub extend Step with Eq::{equal, not_equal}

///|
pub extend Step with @debug.Debug::{to_repr}

///|
/// The place where an attempt failed.
#derive(Eq, Debug)
pub(all) enum FailureTarget {
  /// A consuming term, reference or empty term.
  Terminal(String)
  /// An anchor or lookaround constraint.
  Assertion(String)
  /// The entry boundary of a node, rule or pattern.
  Entry(String)
  /// The exit boundary of a node, rule or pattern, such as the end of input.
  Exit(String)
}

///|
pub extend FailureTarget with Eq::{equal, not_equal}

///|
pub extend FailureTarget with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct FailurePoint {
  target : FailureTarget
  position : Int32?
  message : String?
}

///|
pub extend FailurePoint with Eq::{equal, not_equal}

///|
pub extend FailurePoint with @debug.Debug::{to_repr}

///|
pub fn FailurePoint::new(
  target : FailureTarget,
  position? : Int32,
  message? : String,
) -> FailurePoint {
  { target, position, message, }
}

///|
#derive(Eq, Debug)
pub(all) enum AttemptStatus {
  Matched
  NotMatched
}

///|
pub extend AttemptStatus with Eq::{equal, not_equal}

///|
pub extend AttemptStatus with @debug.Debug::{to_repr}

///|
/// One finite attempt of an external engine. Repeated or backtracked steps
/// stay separate, even when they reuse a term or connector.
#derive(Eq, Debug)
pub struct Attempt {
  id : String
  status : AttemptStatus
  steps : ReadOnlyArray[Step]
  failure : FailurePoint?
  /// True when consecutive steps must meet at shared points.
  continuous : Bool
  label : String?
}

///|
pub extend Attempt with Eq::{equal, not_equal}

///|
pub extend Attempt with @debug.Debug::{to_repr}

///|
pub fn Attempt::new(
  id : String,
  status : AttemptStatus,
  steps : ArrayView[Step],
  failure? : FailurePoint,
  continuous~ : Bool = true,
  label? : String,
) -> Attempt {
  {
    id,
    status,
    steps: ReadOnlyArray::from_array(steps),
    failure,
    continuous,
    label,
  }
}

///|
/// Immutable evidence that an external engine supplied. It is separate from
/// the diagram and is never computed by this library.
#derive(Eq, Debug)
pub struct Trace {
  subject : SubjectIdentity
  input : String
  provider : String
  attempts : ReadOnlyArray[Attempt]
}

///|
pub extend Trace with Eq::{equal, not_equal}

///|
pub extend Trace with @debug.Debug::{to_repr}

///|
/// Make a trace bound to the subject of `request`.
pub fn Trace::new(
  request : TraceRequest,
  provider : String,
  attempts : ArrayView[Attempt],
) -> Trace {
  {
    subject: request.identity(),
    input: request.input,
    provider,
    attempts: ReadOnlyArray::from_array(attempts),
  }
}

///|
/// The outcome of a provider. Unsupported, exhausted and error results are
/// not evidence of a non-match.
#derive(Eq, Debug)
pub(all) enum TraceResult {
  Matched(Trace)
  NotMatched(Trace)
  Unsupported(String)
  Exhausted(String)
  ProviderError(String)
}

///|
pub extend TraceResult with Eq::{equal, not_equal}

///|
pub extend TraceResult with @debug.Debug::{to_repr}

///|
/// A publicly implementable hook for an external regex matcher or grammar
/// parser. This library bundles no implementation. A provider that supports
/// one subject kind returns `Unsupported` for the other.
pub(open) trait RailroadTraceProvider {
  fn trace(Self, TraceRequest) -> TraceResult
}
