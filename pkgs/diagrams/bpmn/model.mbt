///|
/// Standard process/collaboration graphical kinds. Choreography and conversation
/// remain document values and are explicitly deferred by the adapter.
pub(all) enum NodeKind {
  StartEvent; EndEvent; IntermediateCatchEvent; IntermediateThrowEvent; BoundaryEvent
  Task; UserTask; ServiceTask; SendTask; ReceiveTask; ManualTask; BusinessRuleTask; ScriptTask
  SubProcess; AdHocSubProcess; Transaction; CallActivity
  ExclusiveGateway; InclusiveGateway; ParallelGateway; ComplexGateway; EventBasedGateway
  Participant; Lane; DataObject; DataObjectReference; DataStore; DataStoreReference; DataInput; DataOutput
  Group; TextAnnotation; Message
} derive(Eq, Debug)

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
/// The source identity is independent of the per-view render ID. Paths contain
/// source-order child indices and survive absence of an XML ID.
pub struct SourceIdentity { resource_id : String?; source_id : String?; path : ReadOnlyArray[Int] } derive(Eq, Debug)

///|
pub fn SourceIdentity::new(source_id? : String, resource_id? : String, path? : ArrayView[Int] = []) -> SourceIdentity { {source_id,resource_id,path:ReadOnlyArray::from_array(path)} }

///|
pub(all) enum ConnectionKind { SequenceFlow; MessageFlow; Association; DataInputAssociation; DataOutputAssociation; DataAssociation } derive(Eq, Debug)

///|
pub(all) enum AssociationDirection { None; One; Both } derive(Eq, Debug)

///|
pub(all) enum LoopKind { None; Standard; Sequential; Parallel } derive(Eq, Debug)

///|
pub(all) enum EventKind { Message; Timer; Conditional; Link; Signal; Error; Escalation; Cancel; Compensation; Terminate } derive(Eq, Debug)

///|
/// Flattened semantic settings retain source expressions as text. These values
/// describe a symbol; they are never evaluated as execution instructions.
pub struct EventMarker { kind : EventKind; identity : SourceIdentity?; settings : ReadOnlyArray[(String,String)] } derive(Eq, Debug)

///|
pub fn EventMarker::new(kind : EventKind, identity? : SourceIdentity, settings? : ArrayView[(String,String)] = []) -> EventMarker { {kind,identity,settings:ReadOnlyArray::from_array(settings)} }

///|
pub struct Markers {
  loop_kind : LoopKind
  called_kind : NodeKind?
  called_element : SourceIdentity?
  compensation : Bool
  event_subprocess : Bool
  interrupting : Bool
  parallel_multiple : Bool
  collection : Bool
  instantiate : Bool
  events : ReadOnlyArray[EventMarker]
  details : ReadOnlyArray[(String,String)]
} derive(Eq, Debug)

///|
pub fn Markers::new(loop_kind? : LoopKind = None, called_kind? : NodeKind, called_element? : SourceIdentity, compensation? : Bool = false, event_subprocess? : Bool = false, interrupting? : Bool = true, parallel_multiple? : Bool = false, collection? : Bool = false, instantiate? : Bool = false, events? : ArrayView[EventMarker] = [], details? : ArrayView[(String,String)] = []) -> Markers {
  {loop_kind,called_kind,called_element,compensation,event_subprocess,interrupting,parallel_multiple,collection,instantiate,events:ReadOnlyArray::from_array(events),details:ReadOnlyArray::from_array(details)}
}

///|
/// Links are explicit caller-supplied metadata. Vendor XML never creates one.
pub struct Link { target : String } derive(Eq, Debug)

///|
pub fn Link::new(target : String) -> Link { {target,} }

///|
pub struct RenderProperties { description : String?; sublabel : String?; link : Link? } derive(Eq, Debug)

///|
pub fn RenderProperties::new(description? : String, sublabel? : String, link? : Link) -> RenderProperties { {description,sublabel,link} }

///|
pub struct Ownership { pool : String?; lanes : ReadOnlyArray[String]; subprocess : String?; attached_to : String? } derive(Eq, Debug)

///|
pub fn Ownership::new(pool? : String, lanes? : ArrayView[String] = [], subprocess? : String, attached_to? : String) -> Ownership { {pool,lanes:ReadOnlyArray::from_array(lanes),subprocess,attached_to} }

///|
pub struct Node {
  id : String; source : SourceIdentity; kind : NodeKind; label : String
  bounds : Bounds; geometry : ShapeGeometry?; ownership : Ownership; markers : Markers
  expanded : Bool?; black_box : Bool; properties : RenderProperties?
} derive(Eq, Debug)

///|
/// Integer bounds remain the thin-slice convenience input. Exact selected DI
/// lives in geometry; absent geometry does not assert a zero-sized source shape.
pub fn Node::new(id : String, kind : NodeKind, bounds? : Bounds = {x:0,y:0,width:0,height:0}, label? : String = "", source? : SourceIdentity = SourceIdentity::new(source_id=id), geometry? : ShapeGeometry, ownership? : Ownership = Ownership::new(), markers? : Markers = Markers::new(), expanded? : Bool, black_box? : Bool = false, properties? : RenderProperties) -> Node { {id,source,kind,label,bounds,geometry,ownership,markers,expanded,black_box,properties} }

///|
pub fn Node::with_properties(self : Node, properties : RenderProperties) -> Node { {..self,properties:Some(properties)} }

///|
pub struct Flow {
  id : String; identity : SourceIdentity; kind : ConnectionKind; source : String; target : String
  has_source : Bool; semantic_source : SourceIdentity?; semantic_target : SourceIdentity
  points : ReadOnlyArray[Point]; geometry : EdgeGeometry?; label : String
  condition : String?; is_default : Bool; direction : AssociationDirection; properties : RenderProperties?
} derive(Eq, Debug)

///|
pub fn Flow::new(id : String, source : String, target : String, points? : ArrayView[Point] = [], identity? : SourceIdentity = SourceIdentity::new(source_id=id), kind? : ConnectionKind = SequenceFlow, has_source? : Bool = true, semantic_source? : SourceIdentity, semantic_target? : SourceIdentity = SourceIdentity::new(source_id=target), geometry? : EdgeGeometry, label? : String = "", condition? : String, is_default? : Bool = false, direction? : AssociationDirection = None, properties? : RenderProperties) -> Flow {
  {id,identity,kind,source,target,has_source,semantic_source:if has_source { Some(semantic_source.unwrap_or_else(() => SourceIdentity::new(source_id=source))) } else { None },semantic_target,points:ReadOnlyArray::from_array(points),geometry,label,condition,is_default,direction,properties}
}

///|
pub fn Flow::with_properties(self : Flow, properties : RenderProperties) -> Flow { {..self,properties:Some(properties)} }

///|
pub(all) enum ViewKind { Process; Collaboration } derive(Eq, Debug)

///|
pub struct Bpmn {
  id : String; label : String; source : SourceIdentity; kind : ViewKind; plane : SourceIdentity?
  nodes : ReadOnlyArray[Node]; flows : ReadOnlyArray[Flow]
} derive(Eq, Debug)

///|
pub fn Bpmn::new(id : String, nodes : ArrayView[Node], flows : ArrayView[Flow], label? : String = id, source? : SourceIdentity = SourceIdentity::new(source_id=id), kind? : ViewKind = Process, plane? : SourceIdentity) -> Bpmn { {id,label,source,kind,plane,nodes:ReadOnlyArray::from_array(nodes),flows:ReadOnlyArray::from_array(flows)} }

///|
pub extend SourceIdentity with Eq::{equal, not_equal}

///|
pub extend SourceIdentity with @debug.Debug::{to_repr}

///|
pub extend ConnectionKind with Eq::{equal, not_equal}

///|
pub extend ConnectionKind with @debug.Debug::{to_repr}

///|
pub extend AssociationDirection with Eq::{equal, not_equal}

///|
pub extend AssociationDirection with @debug.Debug::{to_repr}

///|
pub extend LoopKind with Eq::{equal, not_equal}

///|
pub extend LoopKind with @debug.Debug::{to_repr}

///|
pub extend EventKind with Eq::{equal, not_equal}

///|
pub extend EventKind with @debug.Debug::{to_repr}

///|
pub extend EventMarker with Eq::{equal, not_equal}

///|
pub extend EventMarker with @debug.Debug::{to_repr}

///|
pub extend Markers with Eq::{equal, not_equal}

///|
pub extend Markers with @debug.Debug::{to_repr}

///|
pub extend Link with Eq::{equal, not_equal}

///|
pub extend Link with @debug.Debug::{to_repr}

///|
pub extend RenderProperties with Eq::{equal, not_equal}

///|
pub extend RenderProperties with @debug.Debug::{to_repr}

///|
pub extend Ownership with Eq::{equal, not_equal}

///|
pub extend Ownership with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Flow with Eq::{equal, not_equal}

///|
pub extend Flow with @debug.Debug::{to_repr}

///|
pub extend ViewKind with Eq::{equal, not_equal}

///|
pub extend ViewKind with @debug.Debug::{to_repr}

///|
pub extend Bpmn with Eq::{equal, not_equal}

///|
pub extend Bpmn with @debug.Debug::{to_repr}

///|
pub fn Node::with_ownership(self : Node, ownership : Ownership) -> Node { {..self,ownership} }

///|
pub fn Node::with_black_box(self : Node, black_box : Bool) -> Node { {..self,black_box} }
