///|
pub(all) enum Side {
  Left
  Right
  Top
  Bottom
} derive(Eq, Debug)

///|
pub(all) enum Axis {
  Row
  Column
} derive(Eq, Debug)

///|
pub struct Group {
  id : String
  label : String
  parent : String?
  icon : @icons.Reference?
} derive(Eq, Debug)

///|
pub fn Group::new(
  id : String,
  label~ : String = id,
  parent? : String,
  icon? : @icons.Reference,
) -> Group {
  { id, label, parent, icon, }
}

///|
pub struct Service {
  id : String
  label : String
  parent : String?
  icon : @icons.Reference?
  icon_text : String?
} derive(Eq, Debug)

///|
pub fn Service::new(
  id : String,
  label~ : String = id,
  parent? : String,
  icon? : @icons.Reference,
  icon_text? : String,
) -> Service {
  { id, label, parent, icon, icon_text, }
}

///|
pub struct Junction {
  id : String
  parent : String?
} derive(Eq, Debug)

///|
pub fn Junction::new(id : String, parent? : String) -> Junction {
  { id, parent, }
}

///|
pub struct Endpoint {
  id : String
  side : Side
  group : Bool
} derive(Eq, Debug)

///|
pub fn Endpoint::new(
  id : String,
  side : Side,
  group~ : Bool = false,
) -> Endpoint {
  { id, side, group, }
}

///|
pub struct Connection {
  id : String
  source : Endpoint
  target : Endpoint
  label : String?
  source_head : Bool
  target_head : Bool
} derive(Eq, Debug)

///|
pub fn Connection::new(
  id : String,
  source : Endpoint,
  target : Endpoint,
  label? : String,
  source_head~ : Bool = false,
  target_head~ : Bool = false,
) -> Connection {
  { id, source, target, label, source_head, target_head, }
}

///|
pub struct Alignment {
  axis : Axis
  members : ReadOnlyArray[String]
} derive(Eq, Debug)

///|
pub fn Alignment::new(axis : Axis, members : ArrayView[String]) -> Alignment {
  { axis, members: ReadOnlyArray::from_array(members), }
}

///|
pub struct Architecture {
  id : String
  groups : ReadOnlyArray[Group]
  services : ReadOnlyArray[Service]
  junctions : ReadOnlyArray[Junction]
  connections : ReadOnlyArray[Connection]
  alignments : ReadOnlyArray[Alignment]
  title : String?
  accessibility_title : String?
  accessibility_description : String?
} derive(Eq, Debug)

///|
pub fn Architecture::new(
  id : String,
  services : ArrayView[Service],
  connections : ArrayView[Connection],
  groups~ : ArrayView[Group] = [],
  junctions~ : ArrayView[Junction] = [],
  alignments~ : ArrayView[Alignment] = [],
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
) -> Architecture {
  {
    id,
    services: ReadOnlyArray::from_array(services),
    connections: ReadOnlyArray::from_array(connections),
    groups: ReadOnlyArray::from_array(groups),
    junctions: ReadOnlyArray::from_array(junctions),
    alignments: ReadOnlyArray::from_array(alignments),
    title,
    accessibility_title,
    accessibility_description,
  }
}

///|
pub fn validate(
  model : Architecture,
  nodes_limit~ : Int32 = 10000,
  edges_limit~ : Int32 = 50000,
  depth_limit~ : Int32 = 256,
  work_limit~ : Int32 = 1000000,
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  let out = []
  let ids : Map[String, Bool] = Map([])
  let parents : Map[String, String?] = Map([])
  let groups : Map[String, Group] = Map([])
  let nodes : Map[String, Bool] = Map([])
  let mut work = 0
  let mut exceeded = false
  fn error(code : String, text : String) {
    if out.length() < 256 {
      out.push(@diagrams.Diagnostic::error("architecture/" + code, text))
    }
  }
  fn charge(n : Int32) -> Bool {
    if exceeded {
      return false
    }
    if n < 0 || n > work_limit - work {
      exceeded = true
      error("work-limit", "Architecture validation work budget exhausted")
      false
    } else {
      work += n
      true
    }
  }
  fn add(id : String, parent : String?) {
    if !charge(id.length() + 1) {
      return
    }
    if id == "" || ids.contains(id) {
      error("duplicate-id", "Ambiguous element ID: " + id)
    }
    ids[id] = true
    parents[id] = parent
  }
  if nodes_limit < 0 ||
    edges_limit < 0 ||
    depth_limit < 0 ||
    work_limit < 0 ||
    model.groups.length() + model.services.length() + model.junctions.length() >
    nodes_limit ||
    model.connections.length() > edges_limit ||
    model.alignments.length() > nodes_limit {
    error("model-limit", "Architecture model size budget exhausted")
    return ReadOnlyArray::from_array(out[:])
  }
  if !charge(
      model.id.length() +
      model.title.map(v => v.length()).unwrap_or(0) +
      model.accessibility_title.map(v => v.length()).unwrap_or(0) +
      model.accessibility_description.map(v => v.length()).unwrap_or(0),
    ) {
    return ReadOnlyArray::from_array(out[:])
  }
  for g in model.groups {
    if !charge(
        g.label.length() +
        g.icon.map(i => i.pack.length() + i.key.length()).unwrap_or(0),
      ) {
      break
    }
    add(g.id, g.parent)
    groups[g.id] = g
  }
  for n in model.services {
    if !charge(
        n.label.length() +
        n.icon_text.map(v => v.length()).unwrap_or(0) +
        n.icon.map(i => i.pack.length() + i.key.length()).unwrap_or(0),
      ) {
      break
    }
    add(n.id, n.parent)
    nodes[n.id] = true
  }
  for n in model.junctions {
    add(n.id, n.parent)
    nodes[n.id] = true
  }
  for id, parent in parents {
    let mut next = parent
    let seen : Map[String, Bool] = Map([])
    let mut depth = 0
    while next is Some(p) {
      if !charge(1) {
        break
      }
      if !groups.contains(p) {
        error("invalid-parent", "Missing group " + p + " for " + id)
        break
      }
      if p == id || seen.contains(p) {
        error("ownership-cycle", "Ownership cycle at " + id)
        break
      }
      seen[p] = true
      depth += 1
      if depth > depth_limit {
        error("depth-limit", "Ownership depth budget exhausted at " + id)
        break
      }
      next = parents.get(p).unwrap_or(None)
    }
  }
  let edges : Map[String, Bool] = Map([])
  for edge in model.connections {
    if (edge.source.group || edge.target.group) &&
      parents.get(edge.source.id).unwrap_or(None) != None &&
      parents.get(edge.source.id) == parents.get(edge.target.id) {
      error(
        "invalid-group-attachment",
        "Group-boundary connection does not cross groups: " + edge.id,
      )
    }
    if !charge(
        1 + edge.id.length() + edge.label.map(v => v.length()).unwrap_or(0),
      ) {
      break
    }
    if edge.id == "" || edges.contains(edge.id) {
      error("duplicate-connection", "Ambiguous connection ID: " + edge.id)
    }
    edges[edge.id] = true
    for endpoint in [edge.source, edge.target] {
      if !nodes.contains(endpoint.id) {
        error("invalid-endpoint", "Missing service or junction: " + endpoint.id)
      }
      if endpoint.group && parents.get(endpoint.id).unwrap_or(None) == None {
        error(
          "invalid-group-attachment",
          "No containing group for " + endpoint.id,
        )
      }
    }
  }
  for align in model.alignments {
    if !charge(align.members.length()) {
      break
    }
    if align.members.length() < 2 {
      error("invalid-alignment", "Alignment requires at least two members")
    }
    let seen : Map[String, Bool] = Map([])
    for id in align.members {
      if !nodes.contains(id) || seen.contains(id) {
        error("invalid-alignment", "Invalid alignment member: " + id)
      }
      seen[id] = true
    }
  }
  ReadOnlyArray::from_array(out[:])
}

///|
pub extend Side with Eq::{equal, not_equal}

///|
pub extend Side with @debug.Debug::{to_repr}

///|
pub extend Axis with Eq::{equal, not_equal}

///|
pub extend Axis with @debug.Debug::{to_repr}

///|
pub extend Group with Eq::{equal, not_equal}

///|
pub extend Group with @debug.Debug::{to_repr}

///|
pub extend Service with Eq::{equal, not_equal}

///|
pub extend Service with @debug.Debug::{to_repr}

///|
pub extend Junction with Eq::{equal, not_equal}

///|
pub extend Junction with @debug.Debug::{to_repr}

///|
pub extend Endpoint with Eq::{equal, not_equal}

///|
pub extend Endpoint with @debug.Debug::{to_repr}

///|
pub extend Connection with Eq::{equal, not_equal}

///|
pub extend Connection with @debug.Debug::{to_repr}

///|
pub extend Alignment with Eq::{equal, not_equal}

///|
pub extend Alignment with @debug.Debug::{to_repr}

///|
pub extend Architecture with Eq::{equal, not_equal}

///|
pub extend Architecture with @debug.Debug::{to_repr}

///|
pub fn Side::to_string(self : Side) -> String {
  match self {
    Left => "L"
    Right => "R"
    Top => "T"
    Bottom => "B"
  }
}
