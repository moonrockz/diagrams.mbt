///|
/// The sequence model of a Mermaid AST and the conversion diagnostics.
pub struct Conversion {
  sequence : @model.Sequence
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// All semantic diagnostic codes. Reading has its own syntax diagnostic codes.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "mermaid/inactive-deactivation", "mermaid/destroyed-participant",
  "mermaid/conflicting-participant-kind", "mermaid/invalid-participant-config",
  "mermaid/missing-destroying-message", "mermaid/invalid-links",
  "mermaid/conflicting-box-group", "mermaid/duplicate-creation",
]

///|
/// Convert a typed AST into a format-independent sequence. All state belongs
/// to this call. Frames retain their sections and recursively ordered events.
pub fn to_sequence(diagram : @ast.Diagram) -> Conversion {
  let participants : Array[@model.Participant] = []
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let declared : Map[String, @model.ParticipantKind] = Map([])
  let active : Map[String, Int] = Map([])
  let destroyed : Map[String, Bool] = Map([])
  let pending : Array[(String, @diagrams.Span)] = []
  let mut title = None
  let mut accessibility_title = None
  let mut accessibility_description = None
  let mut numbering = false
  let mut next_number = 1.0
  let mut step = 1.0
  let mut box_index = 0
  fn error(code : String, message : String, span : @diagrams.Span) {
    diagnostics.push(@diagrams.Diagnostic::error(code, message, span~))
  }
  fn index(id : String) -> Int {
    for i, p in participants {
      if p.id == id { return i }
    }
    participants.push(@model.Participant::new(id))
    participants.length() - 1
  }
  fn use_participant(id : String, span : @diagrams.Span) {
    ignore(index(id))
    if destroyed.get(id).unwrap_or(false) {
      error("mermaid/destroyed-participant", "Participant \{id} was destroyed", span)
    }
  }
  fn activation(id : String, start : Bool, events : Array[@model.Event], span : @diagrams.Span) {
    use_participant(id, span)
    let depth = active.get(id).unwrap_or(0)
    if start {
      active[id] = depth + 1
      events.push(Activate(id))
    } else {
      if depth == 0 {
        error("mermaid/inactive-deactivation", "Participant \{id} is not active", span)
      } else {
        active[id] = depth - 1
      }
      events.push(Deactivate(id))
    }
  }
  fn walk(list : ReadOnlyArray[@ast.Statement], group : @model.BoxGroup?) -> Array[@model.Event] {
    let events : Array[@model.Event] = []
    for statement in list {
      let span = statement.span
      match statement.kind {
        Participant(p) => {
          let existed = participants.iter().any(old => old.id == p.id)
          let i = index(p.id)
          let old = participants[i]
          let metadata = participant_metadata(p.config)
          let (kind, shown_label) = match metadata {
            Some((kind, shown_label)) => (kind.unwrap_or(if p.keyword == Actor { Actor } else { Participant }), shown_label)
            None => {
              error("mermaid/invalid-participant-config", "Invalid configuration for \{p.id}", span)
              (if p.keyword == Actor { Actor } else { Participant }, None)
            }
          }
          if declared.get(p.id) is Some(previous) && previous != kind {
            error("mermaid/conflicting-participant-kind", "Participant \{p.id} has a different declared kind", span)
          } else {
            declared[p.id] = kind
            if group is Some(g) && old.group is Some(previous) && g != previous {
              error("mermaid/conflicting-box-group", "Participant \{p.id} belongs to a different box", span)
            }
            participants[i] = @model.Participant::new(
              p.id, label=p.label.unwrap_or(shown_label.unwrap_or(old.label)), kind~,
              group?=match old.group { Some(g) => Some(g); None => group }, link?=old.link, properties?=old.properties,
            )
          }
          if p.created {
            if existed {
              error("mermaid/duplicate-creation", "Participant \{p.id} already exists", span)
            }
            events.push(Create(p.id))
          } else if destroyed.get(p.id).unwrap_or(false) {
            error("mermaid/destroyed-participant", "Participant \{p.id} was destroyed", span)
          }
        }
        Message(m) => {
          use_participant(m.sender, span)
          if m.receiver != m.sender { use_participant(m.receiver, span) }
          let (line, sender_head, receiver_head) = arrow_ends(m)
          let number = if numbering { Some(next_number) } else { None }
          next_number = ((next_number + step) * 100.0 + 0.5).floor() / 100.0
          events.push(Message(@model.Message::new(
            m.sender, m.receiver, m.text, line~, sender_head~, receiver_head~,
            link?=message_link(m.text), number?,
          )))
          match m.activation {
            Some(Activate) => activation(m.receiver, true, events, span)
            Some(Deactivate) => activation(m.sender, false, events, span)
            None => ()
          }
          for (id, destroy_span) in pending {
            if id != m.sender && id != m.receiver {
              error("mermaid/missing-destroying-message", "Next message does not destroy \{id}", destroy_span)
            }
            destroyed[id] = true
            active[id] = 0
            events.push(Destroy(id))
          }
          pending.clear()
        }
        Destroy(id) => {
          use_participant(id, span)
          pending.push((id, span))
        }
        Activate(id) => activation(id, true, events, span)
        Deactivate(id) => activation(id, false, events, span)
        Note(n) => {
          for id in n.participants { use_participant(id, span) }
          let placement : @model.Placement = match n.placement { LeftOf => LeftOf; RightOf => RightOf; Over => Over }
          events.push(Note(@model.Note::new(placement, n.participants[:], n.text)))
        }
        Frame(f) => {
          let kind : @model.FrameKind = match f.kind {
            Loop => Loop; Alt => Alt; Opt => Opt; Par => Par; ParOver => ParOver;
            Critical => Critical; Break => Break; Rect => Rect
          }
          let sections = f.sections.map(s => @model.Section::new(
            walk(s.statements, group),
            label?=if s.label == "" || f.kind == Rect { None } else { Some(s.label) },
          )).iter().to_array()
          if sections.length() > 0 {
            events.push(Frame(@model.Frame::new(kind, sections[0], rest=sections[1:], colour?=if f.kind == Rect { Some(f.sections[0].label) } else { None })))
          }
        }
        Box(b) => {
          let (label, colour) = box_data(b.label)
          let g = @model.BoxGroup::new("box:\{box_index}", label, colour?)
          box_index += 1
          events.append(walk(b.statements, Some(g)))
        }
        Title(text) => title = Some(text)
        AccTitle(text) => accessibility_title = Some(text)
        AccDescr(text) => accessibility_description = Some(text)
        Autonumber(n) => match n {
          Off => { numbering = false; events.push(Autonumber(Off)) }
          On(start~, step=new_step) => {
            let start = start.bind(s => try Some(@string.parse_double(s)) catch { _ => None })
            let new_step = new_step.bind(s => try Some(@string.parse_double(s)) catch { _ => None })
            numbering = true
            // Omitted values resume the current counter and step.
            if start is Some(n) && n != 0.0 { next_number = n }
            if new_step is Some(n) && n != 0.0 { step = n }
            events.push(Autonumber(On(start~, step=new_step)))
          }
        }
        Link(l) => {
          let i = index(l.participant)
          if l.kind == Links && !(json_value(l.text) is Some(Object(_))) {
            error("mermaid/invalid-links", "Links for \{l.participant} must be a JSON object", span)
          }
          if statement_link(l) is Some(link) {
            let p = participants[i]
            participants[i] = @model.Participant::new(p.id, label=p.label, kind=p.kind, group?=p.group, link~, properties?=p.properties)
          }
        }
      }
    }
    events
  }
  let events = walk(diagram.statements, None)
  for (id, span) in pending {
    error("mermaid/missing-destroying-message", "No destroying message for \{id}", span)
  }
  {
    sequence: @model.Sequence::new(participants, events, title?, accessibility_title?, accessibility_description?),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
