///|
/// The typed subject of a trace request. An EBNF subject names its start rule
/// by rule identity.
pub(all) enum Subject {
  Regex(@regex.Regex)
  Ebnf(@ebnf.Grammar, String)
} derive(Eq, Debug)

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
pub struct SubjectIdentity {
  kind : SubjectKind
  model_id : String
  view_id : String
  fingerprint : String
  start_rule : String?
} derive(Eq, Debug)

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
pub struct TraceLimits {
  input : Int
  attempts : Int
  steps : Int
  depth : Int
  work : Int
} derive(Eq, Debug)

///|
pub extend TraceLimits with Eq::{equal, not_equal}

///|
pub extend TraceLimits with @debug.Debug::{to_repr}

///|
pub fn TraceLimits::new(
  input? : Int = 65536,
  attempts? : Int = 256,
  steps? : Int = 100000,
  depth? : Int = 256,
  work? : Int = 1000000,
) -> TraceLimits {
  { input, attempts, steps, depth, work }
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
pub struct TraceRequest {
  subject : Subject
  view_id : String
  input : String
  limits : TraceLimits
} derive(Eq, Debug)

///|
pub extend TraceRequest with Eq::{equal, not_equal}

///|
pub extend TraceRequest with @debug.Debug::{to_repr}

///|
pub fn TraceRequest::regex(
  model : @regex.Regex,
  input : String,
  view_id? : String,
  limits? : TraceLimits = TraceLimits::new(),
) -> TraceRequest {
  { subject: Regex(model), view_id: view_id.unwrap_or(model.id), input, limits }
}

///|
pub fn TraceRequest::ebnf(
  grammar : @ebnf.Grammar,
  start_rule : String,
  input : String,
  view_id? : String,
  limits? : TraceLimits = TraceLimits::new(),
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
pub struct InputSpan {
  start : Int
  end : Int
} derive(Eq, Debug)

///|
pub extend InputSpan with Eq::{equal, not_equal}

///|
pub extend InputSpan with @debug.Debug::{to_repr}

///|
pub fn InputSpan::new(start : Int, end : Int) -> InputSpan {
  { start, end }
}

///|
/// One oriented trace step. A visit passes through a term from its entry to
/// its exit. A traversal follows a drawn connector, forward or reversed.
pub(all) enum Step {
  Visit(String, InputSpan?)
  Traverse(String, Bool)
} derive(Eq, Debug)

///|
pub extend Step with Eq::{equal, not_equal}

///|
pub extend Step with @debug.Debug::{to_repr}

///|
/// The place where an attempt failed.
pub(all) enum FailureTarget {
  /// A consuming term, reference or empty term.
  Terminal(String)
  /// An anchor or lookaround constraint.
  Assertion(String)
  /// The entry boundary of a node, rule or pattern.
  Entry(String)
  /// The exit boundary of a node, rule or pattern, such as the end of input.
  Exit(String)
} derive(Eq, Debug)

///|
pub extend FailureTarget with Eq::{equal, not_equal}

///|
pub extend FailureTarget with @debug.Debug::{to_repr}

///|
pub struct FailurePoint {
  target : FailureTarget
  position : Int?
  message : String?
} derive(Eq, Debug)

///|
pub extend FailurePoint with Eq::{equal, not_equal}

///|
pub extend FailurePoint with @debug.Debug::{to_repr}

///|
pub fn FailurePoint::new(
  target : FailureTarget,
  position? : Int,
  message? : String,
) -> FailurePoint {
  { target, position, message }
}

///|
pub(all) enum AttemptStatus {
  Matched
  NotMatched
} derive(Eq, Debug)

///|
pub extend AttemptStatus with Eq::{equal, not_equal}

///|
pub extend AttemptStatus with @debug.Debug::{to_repr}

///|
/// One finite attempt of an external engine. Repeated or backtracked steps
/// stay separate, even when they reuse a term or connector.
pub struct Attempt {
  id : String
  status : AttemptStatus
  steps : ReadOnlyArray[Step]
  failure : FailurePoint?
  /// True when consecutive steps must meet at shared points.
  continuous : Bool
  label : String?
} derive(Eq, Debug)

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
  continuous? : Bool = true,
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
pub struct Trace {
  subject : SubjectIdentity
  input : String
  provider : String
  attempts : ReadOnlyArray[Attempt]
} derive(Eq, Debug)

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
pub(all) enum TraceResult {
  Matched(Trace)
  NotMatched(Trace)
  Unsupported(String)
  Exhausted(String)
  ProviderError(String)
} derive(Eq, Debug)

///|
pub extend TraceResult with Eq::{equal, not_equal}

///|
pub extend TraceResult with @debug.Debug::{to_repr}

///|
/// A publicly implementable hook for an external regex matcher or grammar
/// parser. This library bundles no implementation. A provider that supports
/// one subject kind returns `Unsupported` for the other.
pub(open) trait RailroadTraceProvider {
  trace(Self, TraceRequest) -> TraceResult
}
