///|
pub(all) enum Direction { TB; BT; LR; RL } derive(Eq, Debug)
///|
pub(all) enum LabelKind { Text; Markdown; Html } derive(Eq, Debug)
///|
pub(all) enum LineStyle { Solid; Dotted; Thick; Invisible } derive(Eq, Debug)
///|
pub(all) enum Marker { None; Arrow; Circle; Cross } derive(Eq, Debug)
///|
pub(all) enum FlowDirection { Forward; Backward; Both; Undirected; Invisible } derive(Eq, Debug)
///|
pub struct RenderProperties { link : String?; metadata : ReadOnlyArray[(String,String)] } derive(Eq, Debug)
///|
pub fn RenderProperties::new(link? : String, metadata? : ArrayView[(String,String)] = []) -> RenderProperties { {link, metadata:ReadOnlyArray::from_array(metadata)} }
///|
pub struct Lane { id : String; label : String; direction : Direction?; expanded : Bool } derive(Eq, Debug)
///|
pub fn Lane::new(id : String, label? : String = id, direction? : Direction, expanded? : Bool = true) -> Lane { {id,label,direction,expanded} }
///|
pub struct Group { id : String; label : String; parent : String?; lane : String?; direction : Direction?; expanded : Bool } derive(Eq, Debug)
///|
pub fn Group::new(id : String, label? : String = id, parent? : String, lane? : String, direction? : Direction, expanded? : Bool = true) -> Group { {id,label,parent,lane,direction,expanded} }
///|
pub struct Node { id : String; label : String; label_kind : LabelKind; shape : String; metadata : ReadOnlyArray[(String,String)]; lane : String?; groups : ReadOnlyArray[String]; properties : RenderProperties? } derive(Eq, Debug)
///|
pub fn Node::new(id : String, label? : String = id, label_kind? : LabelKind = Text, shape? : String = "rect", metadata? : ArrayView[(String,String)] = [], lane? : String, groups? : ArrayView[String] = [], properties? : RenderProperties) -> Node { {id,label,label_kind,shape:canonical_shape(shape),metadata:ReadOnlyArray::from_array(metadata),lane,groups:ReadOnlyArray::from_array(groups),properties} }
///|
pub struct Connection { id : String; source : String; target : String; label : String; label_kind : LabelKind; style : LineStyle; source_marker : Marker; target_marker : Marker; min_length : Int; direction : FlowDirection } derive(Eq, Debug)
///|
pub fn Connection::new(id : String, source : String, target : String, label? : String = "", label_kind? : LabelKind = Text, style? : LineStyle = Solid, source_marker? : Marker = None, target_marker? : Marker = Arrow, min_length? : Int = 1) -> Connection {
  let direction : FlowDirection = if style == Invisible { Invisible } else if source_marker == None && target_marker == None { Undirected } else if source_marker != None && target_marker != None { Both } else if source_marker != None { Backward } else { Forward }
  {id,source,target,label,label_kind,style,source_marker,target_marker,min_length,direction}
}
///|
pub struct Swimlane { id : String; direction : Direction; lanes : ReadOnlyArray[Lane]; groups : ReadOnlyArray[Group]; nodes : ReadOnlyArray[Node]; connections : ReadOnlyArray[Connection]; title : String?; accessibility_title : String?; accessibility_description : String? } derive(Eq, Debug)
///|
pub fn Swimlane::new(id : String, nodes : ArrayView[Node], connections : ArrayView[Connection], direction? : Direction = TB, lanes? : ArrayView[Lane] = [], groups? : ArrayView[Group] = [], title? : String, accessibility_title? : String, accessibility_description? : String) -> Swimlane { {id,direction,lanes:ReadOnlyArray::from_array(lanes),groups:ReadOnlyArray::from_array(groups),nodes:ReadOnlyArray::from_array(nodes),connections:ReadOnlyArray::from_array(connections),title,accessibility_title,accessibility_description} }
///|
pub fn direction(value : String) -> Direction? { match value { "TB" | "TD" => Some(TB); "BT" => Some(BT); "LR" => Some(LR); "RL" => Some(RL); _ => None } }
///|
pub fn canonical_shape(value : String) -> String {
  match value {
    "proc" | "process" | "square" | "rectangle" | "squareRect" => "rect"
    "event" | "round" | "roundedRect" => "rounded"
    "terminal" | "pill" => "stadium"
    "fr-rect" | "subprocess" | "subproc" | "framed-rectangle" => "subroutine"
    "cyl" | "db" | "database" => "cylinder"
    "data-store" => "datastore"
    "directory" => "folder"
    "circ" => "circle"
    "diam" | "decision" | "question" => "diamond"
    "hex" | "prepare" => "hexagon"
    "lean-right" | "in-out" | "lean_right" => "lean-r"
    "lean-left" | "out-in" | "lean_left" => "lean-l"
    "priority" | "trapezoid-bottom" | "trapezoid" => "trap-b"
    "manual" | "trapezoid-top" | "inv-trapezoid" | "inv_trapezoid" => "trap-t"
    "dbl-circ" | "double-circle" => "doublecircle"
    "card" | "notched-rectangle" => "notch-rect"
    "lined-rectangle" | "lined-process" | "lin-proc" | "shaded-process" => "lin-rect"
    "start" | "small-circle" | "stateStart" => "sm-circ"
    "stop" | "framed-circle" | "stateEnd" => "fr-circ"
    "join" | "forkJoin" => "fork"
    "collate" => "hourglass"
    "comment" | "brace-l" => "brace"
    "com-link" | "lightning-bolt" => "bolt"
    "document" => "doc"
    "half-rounded-rectangle" => "delay"
    "das" | "horizontal-cylinder" => "h-cyl"
    "disk" | "lined-cylinder" => "lin-cyl"
    "curved-trapezoid" | "display" => "curv-trap"
    "div-proc" | "divided-rectangle" | "divided-process" => "div-rect"
    "extract" | "triangle" => "tri"
    "internal-storage" | "window-pane" => "win-pane"
    "junction" | "filled-circle" => "f-circ"
    "loop-limit" | "notched-pentagon" => "notch-pent"
    "manual-file" | "flipped-triangle" => "flip-tri"
    "manual-input" | "sloped-rectangle" => "sl-rect"
    "documents" | "st-doc" | "stacked-document" => "docs"
    "procs" | "processes" | "stacked-rectangle" => "st-rect"
    "stored-data" | "bow-tie-rectangle" => "bow-rect"
    "summary" | "crossed-circle" => "cross-circ"
    "tagged-document" => "tag-doc"
    "tagged-rectangle" | "tag-proc" | "tagged-process" => "tag-rect"
    "paper-tape" => "flag"
    "rect_left_inv_arrow" => "odd"
    "lined-document" => "lin-doc"
    "doublecircle" => "doublecircle"
    "parallelogram" => "lean-r"
    "parallelogram-alt" => "lean-l"
    "asymmetric" => "odd"
    _ => value
  }
}
///|
pub let built_in_shapes : ReadOnlyArray[String] = ["rect", "ellipse", "rounded", "stadium", "subroutine", "cylinder", "datastore", "folder", "bucket", "console", "browser", "person", "circle", "bang", "cloud", "diamond", "hexagon", "lean-r", "lean-l", "trap-b", "trap-t", "doublecircle", "text", "notch-rect", "lin-rect", "sm-circ", "fr-circ", "fork", "hourglass", "brace", "brace-r", "braces", "bolt", "doc", "delay", "h-cyl", "lin-cyl", "curv-trap", "div-rect", "tri", "win-pane", "f-circ", "notch-pent", "flip-tri", "sl-rect", "docs", "st-rect", "bow-rect", "cross-circ", "tag-doc", "tag-rect", "flag", "odd", "lin-doc", "state", "choice", "note", "composite", "anchor"]
///|
pub fn validate(model : Swimlane, nodes_limit? : Int = 10000, edges_limit? : Int = 50000, depth_limit? : Int = 256, work_limit? : Int = 1000000) -> ReadOnlyArray[@diagrams.Diagnostic] {
 let out=[]; let ids : Map[String,Bool]=Map([]); let lanes : Map[String,Bool]=Map([]); let groups : Map[String,Group]=Map([])
 let mut work=0; let mut halted=false
 fn finding(code : String, value : String) { if out.length() < 256 { out.push(@diagrams.Diagnostic::error("swimlane/"+code,value)) } }
 fn limit() {
  if !halted {
   halted=true
   let diagnostic=@diagrams.Diagnostic::error("swimlane/model-limit","Model validation limit exceeded")
   if out.length() >= 256 { out[255]=diagnostic } else { out.push(diagnostic) }
  }
 }
 fn charge(units : Int) -> Bool {
  if halted { return false }
  if units < 0 || work_limit < 0 || units > work_limit-work { limit(); false } else { work+=units; true }
 }
 fn text(value : String) -> Bool { charge(value.length()) }
 fn optional(value : String?) -> Bool { match value { Some(value) => text(value); None => true } }
 fn metadata(values : ReadOnlyArray[(String,String)]) -> Bool {
  if !charge(values.length()) { return false }
  for pair in values { if !text(pair.0) || !text(pair.1) { return false } }; true
 }
 fn properties(value : RenderProperties?) -> Bool {
  match value { Some(value) => optional(value.link) && metadata(value.metadata); None => true }
 }
 fn add(id : String) {
  if !text(id) || !charge(1) { return }
  if id == "" || ids.contains(id) { finding("duplicate-id","Ambiguous element ID: "+id) }; ids[id]=true
 }
 if nodes_limit < 0 || edges_limit < 0 || depth_limit < 0 || !charge(1) { limit(); return ReadOnlyArray::from_array(out[:]) }
 let mut remaining=nodes_limit
 for count in [model.nodes.length(),model.lanes.length(),model.groups.length()] {
  if count > remaining { limit(); return ReadOnlyArray::from_array(out[:]) }; remaining-=count
 }
 if model.connections.length() > edges_limit { limit(); return ReadOnlyArray::from_array(out[:]) }
 if !text(model.id) || !optional(model.title) || !optional(model.accessibility_title) || !optional(model.accessibility_description) { return ReadOnlyArray::from_array(out[:]) }
 for lane in model.lanes { add(lane.id); if !text(lane.label) { return ReadOnlyArray::from_array(out[:]) }; lanes[lane.id]=true }
 for group in model.groups { add(group.id); if !text(group.label) || !optional(group.parent) || !optional(group.lane) { return ReadOnlyArray::from_array(out[:]) }; groups[group.id]=group }
 for node in model.nodes { add(node.id); if halted { return ReadOnlyArray::from_array(out[:]) } }
 for group in model.groups {
  if group.lane is Some(lane) && !lanes.contains(lane) { finding("ownership","Missing lane for group "+group.id) }
  if group.parent is Some(parent) && groups.get(parent) is Some(parent_group) && parent_group.lane != group.lane { finding("ownership","Group and parent have different lanes: "+group.id) }
  let seen : Map[String,Bool]=Map([]); let mut cursor=Some(group.id); let mut depth=0
  while cursor is Some(id) {
   if !charge(1) || depth >= depth_limit { limit(); return ReadOnlyArray::from_array(out[:]) }; depth+=1
   if seen.contains(id) { finding("ownership-cycle","Group ownership cycle at "+id); break }; seen[id]=true
   match groups.get(id) { Some(parent) => cursor=parent.parent; None => { finding("ownership","Missing group "+id); break } }
  }
 }
 for node in model.nodes {
  if !text(node.label) || !text(node.shape) || !optional(node.lane) || !metadata(node.metadata) || !properties(node.properties) || !charge(node.groups.length()) { return ReadOnlyArray::from_array(out[:]) }
  if node.groups.length() > depth_limit { limit(); return ReadOnlyArray::from_array(out[:]) }
  if node.lane is Some(lane) && !lanes.contains(lane) { finding("ownership","Missing lane for node "+node.id) }
  let mut parent : String?=None
  for id in node.groups {
   if !text(id) { return ReadOnlyArray::from_array(out[:]) }
   match groups.get(id) {
    Some(group) => { if group.parent != parent || group.lane != node.lane { finding("ownership","Inconsistent group path for node "+node.id) }; parent=Some(id) }
    None => finding("ownership","Missing group "+id)
   }
  }
 }
 let edge_ids : Map[String,Bool]=Map([])
 for edge in model.connections {
  if !text(edge.id) || !text(edge.source) || !text(edge.target) || !text(edge.label) || !charge(1) { return ReadOnlyArray::from_array(out[:]) }
  if edge_ids.contains(edge.id) || edge.id == "" { finding("duplicate-edge-id","Ambiguous connection ID: "+edge.id) }; edge_ids[edge.id]=true
  if !ids.contains(edge.source) { finding("missing-endpoint","Missing source "+edge.source+" of "+edge.id) }
  if !ids.contains(edge.target) { finding("missing-endpoint","Missing target "+edge.target+" of "+edge.id) }
  if edge.min_length < 1 { finding("invalid-length","Connection length must be positive: "+edge.id) }
 }
 ReadOnlyArray::from_array(out[:])
}
///|
pub extend Direction with Eq::{equal,not_equal}
///|
pub extend Direction with @debug.Debug::{to_repr}

///|
pub extend LabelKind with Eq::{equal,not_equal}
///|
pub extend LabelKind with @debug.Debug::{to_repr}

///|
pub extend LineStyle with Eq::{equal,not_equal}
///|
pub extend LineStyle with @debug.Debug::{to_repr}

///|
pub extend Marker with Eq::{equal,not_equal}
///|
pub extend Marker with @debug.Debug::{to_repr}

///|
pub extend FlowDirection with Eq::{equal,not_equal}
///|
pub extend FlowDirection with @debug.Debug::{to_repr}

///|
pub extend RenderProperties with Eq::{equal,not_equal}
///|
pub extend RenderProperties with @debug.Debug::{to_repr}

///|
pub extend Lane with Eq::{equal,not_equal}
///|
pub extend Lane with @debug.Debug::{to_repr}

///|
pub extend Group with Eq::{equal,not_equal}
///|
pub extend Group with @debug.Debug::{to_repr}

///|
pub extend Node with Eq::{equal,not_equal}
///|
pub extend Node with @debug.Debug::{to_repr}

///|
pub extend Connection with Eq::{equal,not_equal}
///|
pub extend Connection with @debug.Debug::{to_repr}

///|
pub extend Swimlane with Eq::{equal,not_equal}
///|
pub extend Swimlane with @debug.Debug::{to_repr}
///|
pub let diagnostic_codes : ReadOnlyArray[String] = ["swimlane/duplicate-id","swimlane/duplicate-edge-id","swimlane/ownership","swimlane/ownership-cycle","swimlane/missing-endpoint","swimlane/invalid-length","swimlane/model-limit"]
