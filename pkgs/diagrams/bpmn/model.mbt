///|
/// Format-independent first-slice BPMN visual kinds.
pub(all) enum NodeKind { StartEvent; Task; EndEvent } derive(Eq, Debug)

///|
pub extend NodeKind with Eq::{equal, not_equal}

///|
pub extend NodeKind with @debug.Debug::{to_repr}

///|
pub(all) struct Point { x : Int; y : Int } derive(Eq, Debug)

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub(all) struct Bounds { x : Int; y : Int; width : Int; height : Int } derive(Eq, Debug)

///|
pub extend Bounds with Eq::{equal, not_equal}

///|
pub extend Bounds with @debug.Debug::{to_repr}

///|
pub struct Node { id : String; kind : NodeKind; label : String; bounds : Bounds } derive(Eq, Debug)

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub fn Node::new(id : String, kind : NodeKind, bounds : Bounds, label? : String = "") -> Node { { id, kind, label, bounds } }

///|
pub struct Flow { id : String; source : String; target : String; points : ReadOnlyArray[Point] } derive(Eq, Debug)

///|
pub extend Flow with Eq::{equal, not_equal}

///|
pub extend Flow with @debug.Debug::{to_repr}

///|
pub fn Flow::new(id : String, source : String, target : String, points : ArrayView[Point]) -> Flow { { id, source, target, points: ReadOnlyArray::from_array(points) } }

///|
pub struct Bpmn { id : String; nodes : ReadOnlyArray[Node]; flows : ReadOnlyArray[Flow] } derive(Eq, Debug)

///|
pub extend Bpmn with Eq::{equal, not_equal}

///|
pub extend Bpmn with @debug.Debug::{to_repr}

///|
pub fn Bpmn::new(id : String, nodes : ArrayView[Node], flows : ArrayView[Flow]) -> Bpmn { { id, nodes: ReadOnlyArray::from_array(nodes), flows: ReadOnlyArray::from_array(flows) } }
