///|
pub struct Limits {
  nodes : Int32
  edges : Int32
  depth : Int32
  work : Int32
  output_units : Int32
  width : Int32
  height : Int32
  minimum_approach : Double
} derive(Eq, Debug)

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
  output_units~ : Int32 = 16777216,
  width~ : Int32 = 1000000,
  height~ : Int32 = 1000000,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, edges, depth, work, output_units, width, height, }
}

///|
pub fn Limits::with_minimum_approach(self : Limits, minimum_approach : Double) -> Limits { { ..self, minimum_approach } }

///|
pub struct Connection {
  transition : @model.Transition
  source : String
  target : String
  line : ReadOnlyArray[@vector.Point]
  label : @vector.Label?
} derive(Eq, Debug)

///|
pub struct Geometry {
  view : @model.StateDiagram
  shapes : ReadOnlyArray[@vector.Shape]
  connections : ReadOnlyArray[Connection]
  width : Int32
  height : Int32
  priv graph : @graph.Geometry
  priv drawing : @vector.Result
  boundaries : ReadOnlyArray[(String,String)]
} derive(Eq, Debug)

///|
pub struct Result {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub fn diagnostics(values : ArrayView[@diagrams.Diagnostic]) -> ReadOnlyArray[@diagrams.Diagnostic] {
  ReadOnlyArray::from_array(values.map(d => { ..d, code: d.code.replace_all(old="flowchart/",new="state/").replace_all(old="swimlane/",new="state/") }))
}

///|
/// Region containers are drawing groups only. They never create graph edges.
pub fn layout(view : @model.StateDiagram, limits~ : Limits = Limits::new()) -> Result {
  let findings = @model.validate(view, nodes_limit=limits.nodes, regions_limit=limits.nodes, edges_limit=limits.edges, depth_limit=limits.depth, work_limit=limits.work)
  if !findings.is_empty() { return { geometry: None, diagnostics: findings } }
  for state in view.states {
    if state.role is Unsupported(role) { return {geometry:None,diagnostics:[@diagrams.Diagnostic::error("state/unsupported-role","Unsupported state symbol: "+role)]} }
  }
  let mut adapter_work=0
  let mut exhausted=false
  fn charge(n : Int32) -> Bool {
    if n < 0 || n > limits.work-adapter_work { exhausted=true; false }
    else { adapter_work+=n; true }
  }
  let states=Map(view.states.map(s => (s.id,s)))
  let regions=Map(view.regions.map(r => (r.id,r)))
  let paths : Map[String,Array[String]] = Map([])
  fn path(region : String) -> Array[String] {
    if paths.get(region) is Some(p) { if !charge(p.length()) { return [] }; return p }
    let reversed=[]
    let mut cursor=Some(region)
    while cursor is Some(id) {
      if !charge(2) { return [] }
      let r=regions[id]
      if r.owner is Some(owner) {
        reversed.push(id)
        reversed.push(owner)
        cursor=Some(states[owner].region)
      } else { cursor=None }
    }
    let ordered=[]
    for i=reversed.length()-1; i>=0; i=i-1 { ordered.push(reversed[i]) }
    paths[region]=ordered
    ordered
  }
  let owned : Map[String,Array[@model.Region]] = Map([])
  for r in view.regions { if r.owner is Some(owner) { owned.get_or_init(owner,()=>[]).push(r) } }
  let ordered=[]
  for s in view.states {
    let rs=owned.get(s.id).unwrap_or([])
    if rs.length()>1 { ordered.push((s.id,if rs[1].separator == Vertical { @flowchart.Direction::LR } else { TB })) }
  }
  let mut padding=48.0
  for e in view.transitions { padding=padding.max(e.label.length().to_double()*8.0+32.0) }
  let groups=[]
  for s in view.states {
    if s.role == Composite {
      groups.push(@flowchart.Group::new(s.id,label=s.label + (if s.descriptions.is_empty() { "" } else { "\n" + s.descriptions.join("\n") }),parent?=path(s.region).last(),expanded=s.expanded,direction?=(match s.direction { Some(d) => Some(d); None => { let rs=owned.get(s.id).unwrap_or([]); if rs.length()>1 { Some(if rs[1].separator == Vertical { @flowchart.Direction::LR } else { TB }) } else { None } } })))
    }
  }
  for r in view.regions {
    if r.owner is Some(owner) {
      groups.push(@flowchart.Group::new(r.id,label="",parent=owner,direction?=r.direction))
    }
  }
  let nodes=[]
  for s in view.states {
    if s.role == Composite { continue }
    let (shape,label) : (String,String) = match s.role {
      Initial => ("f-circ", "")
      Final => ("fr-circ", "")
      Choice => ("diamond", s.label)
      Fork | Join => ("fork", "")
      ShallowHistory => ("circle", "H")
      DeepHistory => ("circle", "H*")
      EntryPoint => ("circle", s.label)
      ExitPoint => ("cross-circ", s.label)
      InputPin => ("rect", "in: " + s.label)
      OutputPin => ("rect", "out: " + s.label)
      ExpansionInput => ("div-rect", "in[]: " + s.label)
      ExpansionOutput => ("div-rect", "out[]: " + s.label)
      _ => ("rounded", s.label)
    }
    let label=label + (if s.descriptions.is_empty() { "" } else { "\n" + s.descriptions.join("\n") })
    nodes.push(@flowchart.Node::new(s.id,label~,shape~,groups=path(s.region)[:]))
  }
  let edges=view.transitions.map(e => @flowchart.Connection::new(e.id,e.source,e.target,label=e.label,style=e.style,source_marker=e.source_marker,target_marker=e.target_marker,min_length=e.min_length,direction_hint?=e.direction_hint,origin?=e.origin))
  let notes=view.notes.map(n => @flowchart.Note::new(n.id,n.text,targets=n.targets[:],placement=n.placement,connection_targets=n.connection_targets[:],groups=path(n.region)[:]))
  if exhausted { return {geometry:None,diagnostics:[@diagrams.Diagnostic::error("state/work-limit","State layout adaptation work exhausted")]} }
  let graph=@flowchart.Flowchart::new(view.id,nodes[:],edges[:],groups=groups[:],notes=notes[:],direction=view.direction,title?=view.title,accessibility_title?=view.accessibility_title,accessibility_description=view.accessibility_description.unwrap_or("State structure and supplied scenarios. Guards, actions and history remain descriptive data."))
  let result=@graph.layout(graph,ordered_scopes=ordered[:],region_directions=view.regions.map(r => (r.id,if r.separator == Vertical { @flowchart.Direction::LR } else { TB }))[:],scope_padding=padding,limits=@graph.Limits::new(nodes=limits.nodes,edges=limits.edges,depth=limits.depth,work=limits.work,output_units=limits.output_units,width=limits.width,height=limits.height,minimum_approach=limits.minimum_approach))
  guard result.geometry is Some(g) else { return {geometry:None,diagnostics:diagnostics(result.diagnostics[:])} }
  let boundaries=view.states.iter().filter_map(s => {
    if [@model.Role::EntryPoint,ExitPoint,InputPin,OutputPin,ExpansionInput,ExpansionOutput].contains(s.role) {
      regions[s.region].owner.map(owner => (s.id,owner))
    } else { None }
  }).to_array()
  let drawing=if boundaries.is_empty() { g.drawing_result() } else { g.drawing().overlay([],boundaries=boundaries[:],limits=@vector.Limits::new(nodes=limits.nodes,edges=limits.edges,depth=limits.depth,work=limits.work,output_units=limits.output_units,minimum_approach=limits.minimum_approach)) }
  guard drawing.geometry is Some(d) else { return {geometry:None,diagnostics:diagnostics(drawing.diagnostics[:])} }
  if d.width>limits.width || d.height>limits.height { return {geometry:None,diagnostics:[@diagrams.Diagnostic::error("state/layout-limit","State dimensions exceed configured bounds after boundary routing")]} }
  let by_id=Map(view.transitions.map(e => (e.id,e)))
  let connections=d.connections.iter().filter_map(e => by_id.get(e.connection.id).map(t => Connection::{transition:t,source:e.source,target:e.target,line:e.line,label:e.label})).to_array()
  { geometry:Some({view,shapes:d.shapes,connections:ReadOnlyArray::from_array(connections),width:d.width,height:d.height,graph:g,drawing,boundaries:ReadOnlyArray::from_array(boundaries.iter().concat(boundaries.iter().map(p => (p.0,states[p.0].region))).to_array())}),diagnostics:diagnostics(result.diagnostics[:]) }
}

///|
pub fn Geometry::drawing(self : Geometry) -> @graph.Geometry { self.graph }

///|
pub fn check(geometry : Geometry, palette : @theme.Palette, work_limit~ : Int32 = 1000000) -> ReadOnlyArray[@vector.Finding] { @vector.check(geometry.drawing.geometry.unwrap(),@vector.palette(palette),work_limit~,intentional_containment=geometry.graph.intentional_containment()[:],boundary_attachments=geometry.boundaries[:]) }

///|
pub fn Geometry::drawing_result(self : Geometry) -> @vector.Result { self.drawing }

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}


///|
pub extend Connection with Eq::{equal, not_equal}

///|
pub extend Connection with @debug.Debug::{to_repr}


///|
pub extend Geometry with Eq::{equal, not_equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}


///|
pub extend Result with Eq::{equal, not_equal}

///|
pub extend Result with @debug.Debug::{to_repr}

///|
pub struct RegionSeparator {
  region : String
  orientation : @model.Separator
  start : @vector.Point
  end : @vector.Point
} derive(Eq, Debug)

///|
pub extend RegionSeparator with Eq::{equal, not_equal}

///|
pub extend RegionSeparator with @debug.Debug::{to_repr}

///|
/// The actual drawn compartment lines, independent of source transitions.
pub fn Geometry::separators(self : Geometry) -> ReadOnlyArray[RegionSeparator] {
  let shapes=Map(self.shapes.map(s => (s.id,s)))
  let previous : Map[String,String] = Map([])
  let result=[]
  for r in self.view.regions {
    if r.owner is Some(owner) && shapes.get(r.id) is Some(shape) && shapes.get(owner) is Some(parent) {
      if previous.get(owner) is Some(id) && shapes.get(id) is Some(old) {
        let a=old.box; let b=shape.box; let p=parent.box
        let (start,end) : (@vector.Point,@vector.Point) = if r.separator == Vertical {
          let x=(a.x+a.width+b.x)/2.0
          ({x,y:(a.y.min(b.y)-24.0).max(p.y+48.0)},{x,y:p.y+p.height})
        } else {
          let y=(a.y+a.height+b.y)/2.0
          ({x:(a.x.min(b.x)-24.0).max(p.x),y},{x:p.x+p.width,y})
        }
        result.push({region:r.id,orientation:r.separator,start,end})
      }
      previous[owner]=r.id
    }
  }
  ReadOnlyArray::from_array(result)
}
