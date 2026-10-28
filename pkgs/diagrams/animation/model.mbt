///|
pub let max_duration_ms : Int64 = 9007199254740991L

///|
pub struct Limits {
  nodes : Int32
  edges : Int32
  steps : Int32
  results : Int32
  work : Int32
  depth : Int32
} derive(Eq, Debug)

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  steps~ : Int32 = 100000,
  results~ : Int32 = 10000,
  work~ : Int32 = 1000000,
  depth~ : Int32 = 256,
) -> Limits {
  { nodes, edges, steps, results, work, depth, }
}

///|
pub fn Limits::valid(self : Limits) -> Bool {
  self.nodes > 0 &&
  self.edges > 0 &&
  self.steps > 0 &&
  self.steps <= 100000 &&
  self.results > 0 &&
  self.work > 0 &&
  self.depth > 0
}

///|
pub(all) enum OccurrenceKind {
  Bpmn(@bpmn.ConnectionKind)
  SequenceMessage
  Swimlane(@swimlane.FlowDirection)
  State(@state.Transition)
  Flowchart(@flowchart.Connection)
  Architecture(@architecture.Connection)
  /// A drawn railroad connector with its structural role.
  Railroad(@railroad_trace.ConnectorRole)
  /// A drawn connector from a data row to its nested container.
  DataConnector
  /// A visible node or row without a connection path.
  Visit(VisitKind)
} derive(Eq, Debug)

///|
/// The kind of a node-visit target.
pub(all) enum VisitKind {
  StateNode(@state.Role)
  StateNote
  FlowchartNode(@flowchart.Role)
  FlowchartNote
  /// A railroad term: a literal, class, terminal, reference or constraint.
  RailroadTerm(@railroad_trace.TermKind)
  /// One member row of a data container.
  DataRow
  /// A data container box, or a scalar root box.
  DataBox
} derive(Eq, Debug)

///|
pub struct Occurrence {
  key : String
  index : Int32
  kind : OccurrenceKind
  path : ReadOnlyArray[Int32]
  source : @bpmn.SourceIdentity?
  flow : @bpmn.Flow?
  message : @sequence.Message?
  swimlane_connection : @swimlane.Connection?
  railroad_connector : @railroad_trace.Connector?
  railroad_term : @railroad_trace.Term?
  data_member : @data_tree.Member?
  data_node : @data_tree.Node?
} derive(Eq, Debug)

///|
/// True for a node-visit target, which has no connection path.
pub fn Occurrence::is_visit(self : Occurrence) -> Bool {
  self.kind is Visit(_)
}

///|
pub(all) enum Control {
  Message(Int32)
  Frame(Int32)
} derive(Eq, Debug)

///|
pub struct SectionInfo {
  role : @sequence.SectionRole
  label : String?
  controls : ReadOnlyArray[Control]
} derive(Eq, Debug)

///|
pub struct FrameInfo {
  key : String
  path : ReadOnlyArray[Int32]
  kind : @sequence.FrameKind
  sections : ReadOnlyArray[SectionInfo]
} derive(Eq, Debug)

///|
pub(all) enum NodeKind {
  Bpmn(@bpmn.NodeKind)
  Message
  FrameEnter
  FrameExit
  Start
  End
  SwimlaneNode
  StateNode(@state.State)
  StateRegion(@state.Region)
  StateNote(@state.Note)
  FlowchartNode(@flowchart.Node)
  FlowchartGroup
  FlowchartLane
  FlowchartNote(@flowchart.Note)
  FlowchartRegion(@flowchart.Region, String)
  SwimlaneGroup
  SwimlaneLane
  ArchitectureService
  ArchitectureJunction
  ArchitectureGroup
  /// An entry, exit or junction point of a railroad.
  RailroadPoint
  /// One structured-data value.
  DataValue
} derive(Eq, Debug)

///|
pub struct GraphNode {
  id : String
  label : String
  kind : NodeKind
  occurrence : String?
  source_node : @bpmn.Node?
  swimlane_node : @swimlane.Node?
} derive(Eq, Debug)

///|
pub(all) enum EdgeKind {
  SequenceFlow
  MessageFlow
  Order
  SwimlaneFlow
  StateTransition
  FlowchartFlow
  ArchitectureFlow
  Undirected
  /// A drawn railroad connector or a term traversal, in drawing direction.
  Railroad
  /// A data parent/child containment relation.
  Containment
} derive(Eq, Debug)

///|
pub struct GraphEdge {
  kind : EdgeKind
  source : String
  target : String
  occurrence : String?
  reversed : Bool
} derive(Eq, Debug)

///|
pub struct Graph {
  view_id : String
  nodes : ReadOnlyArray[GraphNode]
  edges : ReadOnlyArray[GraphEdge]
  priv source : @render.Diagram
  priv indices : Map[String, Int32]
  priv outside : Map[String, Bool]
  priv outgoing : Map[(Int32, Int32), Array[(Int32, Int32)]]
  priv incoming : Map[(Int32, Int32), Array[(Int32, Int32)]]
}

///|
pub struct Catalog {
  view_id : String
  source : @render.Diagram
  occurrences : ReadOnlyArray[Occurrence]
  frames : ReadOnlyArray[FrameInfo]
  controls : ReadOnlyArray[Control]
  graph : Graph
  priv keys : Map[String, Int32]
  priv flows : Map[String, Int32]
}

///|
pub fn Catalog::occurrence(self : Catalog, key : String) -> Occurrence? {
  self.keys.get(key).map(i => self.occurrences[i])
}

///|
pub fn Catalog::flow(self : Catalog, id : String) -> Occurrence? {
  self.flows.get(id).map(i => self.occurrences[i])
}

///|
pub fn Catalog::connection(self : Catalog, id : String) -> Occurrence? {
  self.flow(id)
}

///|
pub struct CatalogResult {
  catalog : Catalog?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub(all) enum Motion {
  Step(String, Int64)
  OrientedStep(String, Int64, Bool)
  /// A timed visit to a visible node or row, without a connection path.
  Visit(String, Int64)
  Serial(ReadOnlyArray[Motion])
  Parallel(ReadOnlyArray[Motion])
} derive(Eq, Debug)

///|
pub fn Motion::serial(children : ArrayView[Motion]) -> Motion {
  Serial(ReadOnlyArray::from_array(children))
}

///|
pub fn Motion::parallel(children : ArrayView[Motion]) -> Motion {
  Parallel(ReadOnlyArray::from_array(children))
}

///|
pub(all) enum Choice {
  Alternative(Int32)
  Repetitions(Int32)
  Optional(Bool)
  ExceptionSections(ReadOnlyArray[Int32])
} derive(Eq, Debug)

///|
pub struct Selection {
  frame_key : String
  choice : Choice
} derive(Eq, Debug)

///|
pub fn Selection::new(frame_key : String, choice : Choice) -> Selection {
  { frame_key, choice, }
}

///|
pub(all) enum PlaybackMode {
  Finite
  Illustrative
} derive(Eq, Debug)

///|
pub struct ScheduledStep {
  ordinal : Int32
  occurrence : Occurrence
  start_ms : Int64
  duration_ms : Int64
  concurrent_groups : ReadOnlyArray[Int32]
  reversed : Bool
  visit : Bool
} derive(Eq, Debug)

///|
pub struct PlaybackPlan {
  view_id : String
  mode : PlaybackMode
  duration_ms : Int64
  steps : ReadOnlyArray[ScheduledStep]
  priv source : @render.Diagram
} derive(Eq, Debug)

///|
pub fn PlaybackPlan::matches(self : PlaybackPlan, catalog : Catalog) -> Bool {
  self.view_id == catalog.view_id && self.source == catalog.source
}

///|
pub struct PlanResult {
  plan : PlaybackPlan?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub struct Active {
  ordinal : Int32
  key : String
  numerator : Int64
  denominator : Int64
  concurrent_groups : ReadOnlyArray[Int32]
  reversed : Bool
  visit : Bool
} derive(Eq, Debug)

///|
pub struct Sample {
  elapsed_ms : Int64
  duration_ms : Int64
  finished : Bool
  active : ReadOnlyArray[Active]
} derive(Eq, Debug)

///|
pub fn PlaybackPlan::sample_at(
  self : PlaybackPlan,
  elapsed_ms : Int64,
) -> Sample {
  let nonnegative = Int64::max(0L, elapsed_ms)
  let elapsed = if self.mode == Illustrative && self.duration_ms > 0L {
    nonnegative % self.duration_ms
  } else {
    Int64::min(nonnegative, self.duration_ms)
  }
  let active = []
  for step in self.steps {
    if elapsed >= step.start_ms && elapsed < step.start_ms + step.duration_ms {
      active.push({
        ordinal: step.ordinal,
        key: step.occurrence.key,
        numerator: elapsed - step.start_ms,
        denominator: step.duration_ms,
        concurrent_groups: step.concurrent_groups,
        reversed: step.reversed,
        visit: step.visit,
      })
    }
  }
  {
    elapsed_ms: elapsed,
    duration_ms: self.duration_ms,
    finished: self.mode == Finite && elapsed >= self.duration_ms,
    active: ReadOnlyArray::from_array(active),
  }
}

///|
pub(all) enum Direction {
  Forward
  Reverse
  Both
} derive(Eq, Debug)

///|
pub(all) enum LimitKind {
  Nodes
  Edges
  Results
  Work
  Steps
  Depth
} derive(Eq, Debug)

///|
pub(all) enum QueryFailure {
  InvalidEndpoint(String)
  OutsideView(String)
  InvalidLimits
  Limit(LimitKind)
} derive(Eq, Debug)

///|
pub struct Route {
  view_id : String
  direction : Direction
  nodes : ReadOnlyArray[GraphNode]
  edges : ReadOnlyArray[GraphEdge]
  reversed : ReadOnlyArray[Bool]
  priv source : @render.Diagram
} derive(Eq, Debug)

///|
pub(all) enum RouteResult {
  Found(Route)
  Unreachable
  Failed(QueryFailure)
} derive(Eq, Debug)

///|
pub(all) enum ReachabilityResult {
  Complete(ReadOnlyArray[GraphNode])
  Failed(QueryFailure)
} derive(Eq, Debug)

///|
priv struct Budget {
  limits : Limits
  diagnostics : Array[@diagrams.Diagnostic]
  mut work : Int32
  mut failed : Bool
}

///|
fn Budget::error(self : Budget, code : String, message : String) -> Unit {
  if !self.failed {
    self.diagnostics.push(@diagrams.Diagnostic::error(code, message))
  }
  self.failed = true
}

///|
fn Budget::charge(self : Budget, units : Int32) -> Bool {
  if units < 0 || units > self.limits.work - self.work {
    self.error("animation/plan-limit", "Animation work limit exceeded")
    return false
  }
  self.work += units
  true
}

///|
fn path_key(prefix : String, path : ArrayView[Int32]) -> String {
  let result = StringBuilder()
  result.write_string(prefix)
  for i, index in path {
    if i > 0 {
      result.write_char('/')
    }
    result.write_string(index.to_string())
  }
  result.to_string()
}

///|
fn flow_key(view : String, id : String) -> String {
  "bpmn:\{view.length()}:\{view}:\{id.length()}:\{id}"
}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend OccurrenceKind with Eq::{equal, not_equal}

///|
pub extend OccurrenceKind with @debug.Debug::{to_repr}

///|
pub extend VisitKind with Eq::{equal, not_equal}

///|
pub extend VisitKind with @debug.Debug::{to_repr}

///|
pub extend Occurrence with Eq::{equal, not_equal}

///|
pub extend Occurrence with @debug.Debug::{to_repr}

///|
pub extend Control with Eq::{equal, not_equal}

///|
pub extend Control with @debug.Debug::{to_repr}

///|
pub extend SectionInfo with Eq::{equal, not_equal}

///|
pub extend SectionInfo with @debug.Debug::{to_repr}

///|
pub extend FrameInfo with Eq::{equal, not_equal}

///|
pub extend FrameInfo with @debug.Debug::{to_repr}

///|
pub extend NodeKind with Eq::{equal, not_equal}

///|
pub extend NodeKind with @debug.Debug::{to_repr}

///|
pub extend GraphNode with Eq::{equal, not_equal}

///|
pub extend GraphNode with @debug.Debug::{to_repr}

///|
pub extend EdgeKind with Eq::{equal, not_equal}

///|
pub extend EdgeKind with @debug.Debug::{to_repr}

///|
pub extend GraphEdge with Eq::{equal, not_equal}

///|
pub extend GraphEdge with @debug.Debug::{to_repr}

///|
pub extend Motion with Eq::{equal, not_equal}

///|
pub extend Motion with @debug.Debug::{to_repr}

///|
pub extend Choice with Eq::{equal, not_equal}

///|
pub extend Choice with @debug.Debug::{to_repr}

///|
pub extend Selection with Eq::{equal, not_equal}

///|
pub extend Selection with @debug.Debug::{to_repr}

///|
pub extend PlaybackMode with Eq::{equal, not_equal}

///|
pub extend PlaybackMode with @debug.Debug::{to_repr}

///|
pub extend ScheduledStep with Eq::{equal, not_equal}

///|
pub extend ScheduledStep with @debug.Debug::{to_repr}

///|
pub extend PlaybackPlan with Eq::{equal, not_equal}

///|
pub extend PlaybackPlan with @debug.Debug::{to_repr}

///|
pub extend Active with Eq::{equal, not_equal}

///|
pub extend Active with @debug.Debug::{to_repr}

///|
pub extend Sample with Eq::{equal, not_equal}

///|
pub extend Sample with @debug.Debug::{to_repr}

///|
pub extend Direction with Eq::{equal, not_equal}

///|
pub extend Direction with @debug.Debug::{to_repr}

///|
pub extend LimitKind with Eq::{equal, not_equal}

///|
pub extend LimitKind with @debug.Debug::{to_repr}

///|
pub extend QueryFailure with Eq::{equal, not_equal}

///|
pub extend QueryFailure with @debug.Debug::{to_repr}

///|
pub extend Route with Eq::{equal, not_equal}

///|
pub extend Route with @debug.Debug::{to_repr}

///|
pub extend RouteResult with Eq::{equal, not_equal}

///|
pub extend RouteResult with @debug.Debug::{to_repr}

///|
pub extend ReachabilityResult with Eq::{equal, not_equal}

///|
pub extend ReachabilityResult with @debug.Debug::{to_repr}
