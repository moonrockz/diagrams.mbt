///|
pub(all) enum GraphEdgeKind { Containment; SequenceFlow; MessageFlow; Association; DataAssociation; ConversationLink; Reference } derive(Eq, Debug)

///|
pub extend GraphEdgeKind with Eq::{equal, not_equal}

///|
pub extend GraphEdgeKind with @debug.Debug::{to_repr}

///|
fn GraphEdgeKind::tag(self : GraphEdgeKind) -> Int { match self { Containment => 0; SequenceFlow => 1; MessageFlow => 2; Association => 3; DataAssociation => 4; ConversationLink => 5; Reference => 6 } }

///|
pub(all) enum GraphDirection { Forward; Reverse; Both } derive(Eq, Debug)

///|
pub extend GraphDirection with Eq::{equal, not_equal}

///|
pub extend GraphDirection with @debug.Debug::{to_repr}

///|
pub struct GraphLimits { nodes : Int; edges : Int; results : Int; work : Int } derive(Eq, Debug)

///|
pub extend GraphLimits with Eq::{equal, not_equal}

///|
pub extend GraphLimits with @debug.Debug::{to_repr}

///|
pub fn GraphLimits::new(nodes? : Int = 100000, edges? : Int = 200000, results? : Int = 100000, work? : Int = 1000000) -> GraphLimits { {nodes,edges,results,work} }

///|
fn GraphLimits::valid(self : GraphLimits) -> Bool { self.nodes > 0 && self.edges > 0 && self.results > 0 && self.work > 0 }

///|
pub struct ExternalNode { symbol : ResolvedSymbol; occurrence : Int } derive(Eq, Debug)

///|
pub extend ExternalNode with Eq::{equal, not_equal}

///|
pub extend ExternalNode with @debug.Debug::{to_repr}

///|
pub(all) enum GraphNode { Document(NodeRef); External(ExternalNode) } derive(Eq, Debug)

///|
pub extend GraphNode with Eq::{equal, not_equal}

///|
pub extend GraphNode with @debug.Debug::{to_repr}

///|
pub fn GraphNode::id(self : GraphNode) -> String? { match self { Document(node) => node.id(); External(node) => Some(node.symbol.name.local_name) } }

///|
pub(all) enum GraphEndpoint { Node(NodeHandle); Id(String); Qualified(ExpandedName); Symbol(ResolvedSymbol) } derive(Eq, Debug)

///|
pub extend GraphEndpoint with Eq::{equal, not_equal}

///|
pub extend GraphEndpoint with @debug.Debug::{to_repr}

///|
pub(all) enum GraphLimit { Nodes; Edges; Results; Work } derive(Eq, Debug)

///|
pub extend GraphLimit with Eq::{equal, not_equal}

///|
pub extend GraphLimit with @debug.Debug::{to_repr}

///|
pub(all) enum GraphFailure {
  InvalidEndpoint
  DocumentMismatch
  InvalidReference(NodeHandle)
  Ambiguous(ReadOnlyArray[GraphNode])
  Limit(GraphLimit)
  InvalidLimits
} derive(Eq, Debug)

///|
pub extend GraphFailure with Eq::{equal, not_equal}

///|
pub extend GraphFailure with @debug.Debug::{to_repr}

///|
pub struct GraphEdge { kind : GraphEdgeKind; source : GraphNode; target : GraphNode; connection : NodeRef? } derive(Eq, Debug)

///|
pub extend GraphEdge with Eq::{equal, not_equal}

///|
pub extend GraphEdge with @debug.Debug::{to_repr}

///|
priv struct GraphArc { neighbor : Int?; edge : Int?; failure : GraphFailure?; order : Int; serial : Int }

///|
pub struct DocumentGraph {
  nodes : ReadOnlyArray[GraphNode]
  edges : ReadOnlyArray[GraphEdge]
  priv trees : ReadOnlyArray[DocumentTree]
  priv offsets : ReadOnlyArray[Int]
  priv local_ids : @namespaces.HashMap[String,ReadOnlyArray[Int]]
  priv qualified_ids : @namespaces.HashMap[(String,String),ReadOnlyArray[Int]]
  priv symbols : @namespaces.HashMap[(String,String,String),ReadOnlyArray[Int]]
  priv outgoing : @namespaces.HashMap[(Int,Int),ReadOnlyArray[GraphArc]]
  priv incoming : @namespaces.HashMap[(Int,Int),ReadOnlyArray[GraphArc]]
}

///|
pub impl @debug.Debug for DocumentGraph with to_repr(self) { @debug.Repr::Repr(("DocumentGraph",self.nodes.length(),self.edges.length())) }

///|
pub extend DocumentGraph with @debug.Debug::{to_repr}

///|
pub struct GraphBuildResult { graph : DocumentGraph?; diagnostics : ReadOnlyArray[Diagnostic] } derive(Debug)

///|
pub extend GraphBuildResult with @debug.Debug::{to_repr}

///|
pub(all) enum ReachabilityResult { Complete(ReadOnlyArray[GraphNode]); Failed(GraphFailure) } derive(Eq, Debug)

///|
pub extend ReachabilityResult with Eq::{equal, not_equal}

///|
pub extend ReachabilityResult with @debug.Debug::{to_repr}

///|
pub struct GraphRoute { nodes : ReadOnlyArray[GraphNode]; edges : ReadOnlyArray[GraphEdge] } derive(Eq, Debug)

///|
pub extend GraphRoute with Eq::{equal, not_equal}

///|
pub extend GraphRoute with @debug.Debug::{to_repr}

///|
pub(all) enum RouteResult { Found(GraphRoute); Unreachable; Failed(GraphFailure) } derive(Eq, Debug)

///|
pub extend RouteResult with Eq::{equal, not_equal}

///|
pub extend RouteResult with @debug.Debug::{to_repr}

///|
pub let graph_diagnostic_codes : ReadOnlyArray[String] = ["bpmn/graph-invalid-limits","bpmn/graph-work-limit","bpmn/graph-node-limit","bpmn/graph-edge-limit"]
