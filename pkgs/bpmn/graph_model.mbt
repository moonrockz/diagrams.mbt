///|
#derive(Eq, Debug)
pub(all) enum GraphEdgeKind {
  Containment
  SequenceFlow
  MessageFlow
  Association
  DataAssociation
  ConversationLink
  Reference
}

///|
pub extend GraphEdgeKind with Eq::{equal, not_equal}

///|
pub extend GraphEdgeKind with @debug.Debug::{to_repr}

///|
fn GraphEdgeKind::tag(self : GraphEdgeKind) -> Int32 {
  match self {
    Containment => 0
    SequenceFlow => 1
    MessageFlow => 2
    Association => 3
    DataAssociation => 4
    ConversationLink => 5
    Reference => 6
  }
}

///|
#derive(Eq, Debug)
pub(all) enum GraphDirection {
  Forward
  Reverse
  Both
}

///|
pub extend GraphDirection with Eq::{equal, not_equal}

///|
pub extend GraphDirection with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct GraphLimits {
  nodes : Int32
  edges : Int32
  results : Int32
  work : Int32
}

///|
pub extend GraphLimits with Eq::{equal, not_equal}

///|
pub extend GraphLimits with @debug.Debug::{to_repr}

///|
pub fn GraphLimits::new(
  nodes~ : Int32 = 100000,
  edges~ : Int32 = 200000,
  results~ : Int32 = 100000,
  work~ : Int32 = 1000000,
) -> GraphLimits {
  { nodes, edges, results, work, }
}

///|
fn GraphLimits::valid(self : GraphLimits) -> Bool {
  self.nodes > 0 && self.edges > 0 && self.results > 0 && self.work > 0
}

///|
#derive(Eq, Debug)
pub struct ExternalNode {
  symbol : ResolvedSymbol
  occurrence : Int32
}

///|
pub extend ExternalNode with Eq::{equal, not_equal}

///|
pub extend ExternalNode with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum GraphNode {
  Document(NodeRef)
  External(ExternalNode)
}

///|
pub extend GraphNode with Eq::{equal, not_equal}

///|
pub extend GraphNode with @debug.Debug::{to_repr}

///|
pub fn GraphNode::id(self : GraphNode) -> String? {
  match self {
    Document(node) => node.id()
    External(node) => Some(node.symbol.name.local_name)
  }
}

///|
#derive(Eq, Debug)
pub(all) enum GraphEndpoint {
  Node(NodeHandle)
  Id(String)
  Qualified(ExpandedName)
  Symbol(ResolvedSymbol)
}

///|
pub extend GraphEndpoint with Eq::{equal, not_equal}

///|
pub extend GraphEndpoint with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum GraphLimit {
  Nodes
  Edges
  Results
  Work
}

///|
pub extend GraphLimit with Eq::{equal, not_equal}

///|
pub extend GraphLimit with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum GraphFailure {
  InvalidEndpoint
  DocumentMismatch
  InvalidReference(NodeHandle)
  Ambiguous(ReadOnlyArray[GraphNode])
  Limit(GraphLimit)
  InvalidLimits
}

///|
pub extend GraphFailure with Eq::{equal, not_equal}

///|
pub extend GraphFailure with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct GraphEdge {
  kind : GraphEdgeKind
  source : GraphNode
  target : GraphNode
  connection : NodeRef?
}

///|
pub extend GraphEdge with Eq::{equal, not_equal}

///|
pub extend GraphEdge with @debug.Debug::{to_repr}

///|
priv struct GraphArc {
  neighbor : Int32?
  edge : Int32?
  failure : GraphFailure?
  order : Int32
  serial : Int32
}

///|
pub struct DocumentGraph {
  nodes : ReadOnlyArray[GraphNode]
  edges : ReadOnlyArray[GraphEdge]
  priv trees : ReadOnlyArray[DocumentTree]
  priv offsets : ReadOnlyArray[Int32]
  priv local_ids : @namespaces.HashMap[String, ReadOnlyArray[Int32]]
  priv qualified_ids : @namespaces.HashMap[
    (String, String),
    ReadOnlyArray[Int32],
  ]
  priv symbols : @namespaces.HashMap[
    (String, String, String),
    ReadOnlyArray[Int32],
  ]
  priv outgoing : @namespaces.HashMap[(Int32, Int32), ReadOnlyArray[GraphArc]]
  priv incoming : @namespaces.HashMap[(Int32, Int32), ReadOnlyArray[GraphArc]]
}

///|
pub impl @debug.Debug for DocumentGraph with fn to_repr(self) {
  @debug.Repr::Repr(("DocumentGraph", self.nodes.length(), self.edges.length()))
}

///|
pub extend DocumentGraph with @debug.Debug::{to_repr}

///|
#derive(Debug)
pub struct GraphBuildResult {
  graph : DocumentGraph?
  diagnostics : ReadOnlyArray[Diagnostic]
}

///|
pub extend GraphBuildResult with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum ReachabilityResult {
  Complete(ReadOnlyArray[GraphNode])
  Failed(GraphFailure)
}

///|
pub extend ReachabilityResult with Eq::{equal, not_equal}

///|
pub extend ReachabilityResult with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub struct GraphRoute {
  nodes : ReadOnlyArray[GraphNode]
  edges : ReadOnlyArray[GraphEdge]
}

///|
pub extend GraphRoute with Eq::{equal, not_equal}

///|
pub extend GraphRoute with @debug.Debug::{to_repr}

///|
#derive(Eq, Debug)
pub(all) enum RouteResult {
  Found(GraphRoute)
  Unreachable
  Failed(GraphFailure)
}

///|
pub extend RouteResult with Eq::{equal, not_equal}

///|
pub extend RouteResult with @debug.Debug::{to_repr}

///|
pub let graph_diagnostic_codes : ReadOnlyArray[String] = [
  "bpmn/graph-invalid-limits", "bpmn/graph-work-limit", "bpmn/graph-node-limit",
  "bpmn/graph-edge-limit",
]
