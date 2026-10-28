///|
/// Source-independent state roles. History and boundaries describe drawn structure.
pub(all) enum Role {
  Simple
  Composite
  Initial
  Final
  Choice
  Fork
  Join
  ShallowHistory
  DeepHistory
  EntryPoint
  ExitPoint
  InputPin
  OutputPin
  ExpansionInput
  ExpansionOutput
  Unsupported(String)
} derive(Eq, Debug)

///|
pub(all) enum Separator {
  Horizontal
  Vertical
} derive(Eq, Debug)

///|
pub struct State {
  id : String
  label : String
  region : String
  role : Role
  descriptions : ReadOnlyArray[String]
  expanded : Bool
  direction : @flowchart.Direction?
  origin : @flowchart.SourceBinding?
} derive(Eq, Debug)

///|
pub fn State::new(
  id : String,
  label~ : String = id,
  region~ : String = "root",
  role~ : Role = Simple,
  descriptions~ : ArrayView[String] = [],
  expanded~ : Bool = true,
  direction? : @flowchart.Direction,
  origin? : @flowchart.SourceBinding,
) -> State {
  {
    id,
    label,
    region,
    role,
    descriptions: ReadOnlyArray::from_array(descriptions),
    expanded,
    direction,
    origin,
  }
}

///|
pub struct Region {
  id : String
  owner : String?
  members : ReadOnlyArray[String]
  separator : Separator
  direction : @flowchart.Direction?
  origin : @flowchart.SourceBinding?
} derive(Eq, Debug)

///|
pub fn Region::new(
  id : String,
  owner? : String,
  members~ : ArrayView[String] = [],
  separator~ : Separator = Horizontal,
  direction? : @flowchart.Direction,
  origin? : @flowchart.SourceBinding,
) -> Region {
  {
    id,
    owner,
    members: ReadOnlyArray::from_array(members),
    separator,
    direction,
    origin,
  }
}

///|
pub struct Transition {
  id : String
  source : String
  target : String
  label : String
  style : @flowchart.LineStyle
  source_marker : @flowchart.Marker
  target_marker : @flowchart.Marker
  min_length : Int32
  direction : @flowchart.FlowDirection
  direction_hint : @flowchart.Direction?
  origin : @flowchart.SourceBinding?
} derive(Eq, Debug)

///|
pub fn Transition::new(
  id : String,
  source : String,
  target : String,
  label~ : String = "",
  style~ : @flowchart.LineStyle = Solid,
  source_marker~ : @flowchart.Marker = None,
  target_marker~ : @flowchart.Marker = Arrow,
  min_length~ : Int32 = 1,
  direction_hint? : @flowchart.Direction,
  origin? : @flowchart.SourceBinding,
) -> Transition {
  let edge = @flowchart.Connection::new(
    id,
    source,
    target,
    label~,
    style~,
    source_marker~,
    target_marker~,
    min_length~,
    direction_hint?,
    origin?,
  )
  {
    id,
    source,
    target,
    label,
    style,
    source_marker,
    target_marker,
    min_length,
    direction: edge.direction,
    direction_hint,
    origin,
  }
}

///|
pub struct Note {
  id : String
  text : String
  targets : ReadOnlyArray[String]
  connection_targets : ReadOnlyArray[String]
  placement : String
  region : String
  origin : @flowchart.SourceBinding?
} derive(Eq, Debug)

///|
pub fn Note::new(
  id : String,
  text : String,
  targets~ : ArrayView[String] = [],
  connection_targets~ : ArrayView[String] = [],
  placement~ : String = "right",
  region~ : String = "root",
  origin? : @flowchart.SourceBinding,
) -> Note {
  {
    id,
    text,
    targets: ReadOnlyArray::from_array(targets),
    connection_targets: ReadOnlyArray::from_array(connection_targets),
    placement,
    region,
    origin,
  }
}

///|
pub struct StateDiagram {
  id : String
  states : ReadOnlyArray[State]
  transitions : ReadOnlyArray[Transition]
  regions : ReadOnlyArray[Region]
  notes : ReadOnlyArray[Note]
  direction : @flowchart.Direction
  title : String?
  accessibility_title : String?
  accessibility_description : String?
} derive(Eq, Debug)

///|
pub fn StateDiagram::new(
  id : String,
  states : ArrayView[State],
  transitions : ArrayView[Transition],
  regions~ : ArrayView[Region] = [Region::new("root")],
  notes~ : ArrayView[Note] = [],
  direction~ : @flowchart.Direction = TB,
  title? : String,
  accessibility_title? : String,
  accessibility_description? : String,
) -> StateDiagram {
  let membership : Map[String, Array[String]] = Map([])
  for state in states {
    match membership.get(state.region) {
      Some(ids) => ids.push(state.id)
      None => membership[state.region] = [state.id]
    }
  }
  let regions = regions.map(region => {
    if region.members.is_empty() {
      {
        ..region,
        members: ReadOnlyArray::from_array(
          membership.get(region.id).unwrap_or([]),
        ),
      }
    } else {
      region
    }
  })
  {
    id,
    states: ReadOnlyArray::from_array(states),
    transitions: ReadOnlyArray::from_array(transitions),
    regions: ReadOnlyArray::from_array(regions),
    notes: ReadOnlyArray::from_array(notes),
    direction,
    title,
    accessibility_title,
    accessibility_description,
  }
}

///|
pub fn State::with_label(self : State, label : String) -> State {
  { ..self, label, }
}

///|
pub fn State::with_descriptions(
  self : State,
  descriptions : ArrayView[String],
) -> State {
  { ..self, descriptions: ReadOnlyArray::from_array(descriptions), }
}

///|
pub fn StateDiagram::with_states(
  self : StateDiagram,
  states : ArrayView[State],
) -> StateDiagram {
  { ..self, states: ReadOnlyArray::from_array(states), }
}

///|
pub fn StateDiagram::with_direction(
  self : StateDiagram,
  direction : @flowchart.Direction,
) -> StateDiagram {
  { ..self, direction, }
}

///|
pub extend Role with Eq::{equal, not_equal}

///|
pub extend Role with @debug.Debug::{to_repr}

///|
pub extend Separator with Eq::{equal, not_equal}

///|
pub extend Separator with @debug.Debug::{to_repr}

///|
pub extend State with Eq::{equal, not_equal}

///|
pub extend State with @debug.Debug::{to_repr}

///|
pub extend Region with Eq::{equal, not_equal}

///|
pub extend Region with @debug.Debug::{to_repr}

///|
pub extend Transition with Eq::{equal, not_equal}

///|
pub extend Transition with @debug.Debug::{to_repr}

///|
pub extend Note with Eq::{equal, not_equal}

///|
pub extend Note with @debug.Debug::{to_repr}

///|
pub extend StateDiagram with Eq::{equal, not_equal}

///|
pub extend StateDiagram with @debug.Debug::{to_repr}
