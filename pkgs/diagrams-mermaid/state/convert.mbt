///|
pub struct Conversion {
  state : @model.StateDiagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Convert explicit state structure without guard evaluation or state execution.
/// Ordinary Mermaid identifiers are global. Initial/final identities are scoped
/// to their owning region. Source order and parallel transition IDs are retained.
pub fn to_state(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
  id~ : String = "state",
) -> Conversion {
  let checked = @printer.print(diagram, limits~)
  if checked.output == None {
    return { state: None, diagnostics: checked.diagnostics, }
  }
  let states : Array[@model.State] = []
  let indices : Map[String, Int32] = Map([])
  let regions : Array[@model.Region] = [@model.Region::new("root")]
  let region_indices : Map[String, Int32] = Map([("root", 0)])
  let transitions : Array[@model.Transition] = []
  let notes : Array[@model.Note] = []
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let owners : Array[String] = []
  let parent_regions : Array[String] = []
  let region_numbers : Array[Int32] = []
  let mut region = "root"
  let mut direction : @flowchart.Direction = TB
  let mut accessibility_title : String? = None
  let mut accessibility_description : String? = None
  let mut title : String? = None
  let mut exhausted = false
  let mut work = 0
  fn finding(
    code : String,
    message : String,
    span : @diagrams.Span,
    warning : Bool,
  ) {
    if diagnostics.length() >= limits.diagnostics {
      exhausted = true
      if !diagnostics.is_empty() {
        diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
          "state/diagnostic-limit", "Conversion diagnostic budget exhausted",
        )
      }
      return
    }
    diagnostics.push(
      if warning {
        @diagrams.Diagnostic::warning("state/" + code, message, span~)
      } else {
        @diagrams.Diagnostic::error("state/" + code, message, span~)
      },
    )
  }
  fn ensure(
    name : String,
    role : @model.Role,
    span : @diagrams.Span,
  ) -> String {
    if name == "root" {
      finding(
        "reserved-id", "Pinned Mermaid reserves root and omits it from state topology",
        span, false,
      )
      exhausted = true
      return name
    }
    let name = if name == "[*]" {
      region + (if role == Initial { "::initial" } else { "::final" })
    } else {
      name
    }
    work += name.length() + 1
    if work > limits.work {
      finding("work-limit", "Conversion work budget exhausted", span, false)
      exhausted = true
      return name
    }
    match indices.get(name) {
      Some(index) => {
        let value = states[index]
        // Pinned dataFetcher retains a nested owner when a state is referenced
        // at the root, but a later nested occurrence updates its parent.
        if region != "root" && value.region != region {
          states[index] = @model.State::new(
            value.id,
            label=value.label,
            region~,
            role=value.role,
            descriptions=value.descriptions[:],
            expanded=value.expanded,
            direction?=value.direction,
            origin?=value.origin,
          )
        }
      }
      None => {
        if states.length() >= limits.states {
          finding("state-limit", "State budget exhausted", span, false)
          exhausted = true
          return name
        }
        indices[name] = states.length()
        states.push(
          @model.State::new(
            name,
            region~,
            role~,
            origin=@flowchart.SourceBinding::new("mermaid-state", name, span~),
          ),
        )
      }
    }
    name
  }
  fn describe(name : String, text : String) {
    if indices.get(name) is Some(index) {
      let value = states[index]
      let has_description = value.descriptions.length() > 0 ||
        value.label != value.id
      states[index] = if has_description {
        value.with_descriptions([..value.descriptions, text])
      } else {
        value.with_label(text)
      }
    }
  }
  if diagram.front_matter is Some(front) {
    work += front.length()
    for line in front.split("\n") {
      let text = @syntax.trim(line.to_owned())
      if text.has_prefix("title:") {
        title = Some(@syntax.trim(text[6:].to_owned()))
      }
    }
  }
  for statement in diagram.statements {
    if exhausted {
      break
    }
    work += 1
    if work > limits.work {
      finding(
        "work-limit",
        "Conversion work budget exhausted",
        statement.span,
        false,
      )
      exhausted = true
      break
    }
    match statement.kind {
      State(id~, label~, role~, description~, classes~) => {
        let r : @model.Role = if id == "[*]" {
          Initial
        } else {
          match role {
            Some("choice") => Choice
            Some("fork") => Fork
            Some("join") => Join
            _ => Simple
          }
        }
        let name = ensure(id, r, statement.span)
        if label is Some(text) {
          describe(name, text)
        }
        if description is Some(text) {
          describe(name, text)
        }
        if !classes.is_empty() {
          finding(
            "unapplied-presentation",
            "Inline classes are retained without applying source CSS",
            statement.span,
            true,
          )
        }
      }
      Description(id~, text~) => {
        let name = ensure(id, Simple, statement.span)
        describe(name, text)
      }
      Composite(id~, label~) => {
        let name = ensure(id, Composite, statement.span)
        if indices.get(name) is Some(index) {
          states[index] = @model.State::new(
            states[index].id,
            label=states[index].label,
            region=states[index].region,
            role=Composite,
            descriptions=states[index].descriptions[:],
            expanded=states[index].expanded,
            direction?=states[index].direction,
            origin?=states[index].origin,
          )
        }
        if label is Some(text) {
          describe(name, text)
        }
        owners.push(name)
        parent_regions.push(region)
        region_numbers.push(0)
        region = name + "::region-0"
        if regions.length() >= limits.regions {
          finding(
            "region-limit",
            "Region budget exhausted",
            statement.span,
            false,
          )
          exhausted = true
          break
        }
        if region_indices.contains(region) {
          finding(
            "redeclaration",
            "A composite body may be declared once",
            statement.span,
            false,
          )
          exhausted = true
          break
        }
        region_indices[region] = regions.length()
        regions.push(
          @model.Region::new(
            region,
            owner=name,
            origin=@flowchart.SourceBinding::new(
              "mermaid-state",
              region,
              span=statement.span,
            ),
          ),
        )
      }
      EndComposite => {
        ignore(owners.pop())
        ignore(region_numbers.pop())
        region = parent_regions.pop().unwrap_or("root")
      }
      Concurrent => {
        guard owners.last() is Some(owner) else {
          finding(
            "ownership",
            "Concurrent region requires an owner",
            statement.span,
            false,
          )
          continue
        }
        let last = region_numbers.length() - 1
        region_numbers[last] += 1
        region = owner + "::region-\{region_numbers[last]}"
        if regions.length() >= limits.regions {
          finding(
            "region-limit",
            "Region budget exhausted",
            statement.span,
            false,
          )
          exhausted = true
          break
        }
        region_indices[region] = regions.length()
        regions.push(
          @model.Region::new(
            region,
            owner~,
            origin=@flowchart.SourceBinding::new(
              "mermaid-state",
              region,
              span=statement.span,
            ),
          ),
        )
      }
      Transition(source~, target~, label~, source_classes~, target_classes~) => {
        let source = ensure(
          source,
          if source == "[*]" {
            Initial
          } else {
            Simple
          },
          statement.span,
        )
        let target = ensure(
          target,
          if target == "[*]" {
            Final
          } else {
            Simple
          },
          statement.span,
        )
        if transitions.length() >= limits.transitions {
          finding(
            "transition-limit",
            "Transition budget exhausted",
            statement.span,
            false,
          )
          exhausted = true
          break
        }
        let edge_id = "transition-\{transitions.length()}"
        transitions.push(
          @model.Transition::new(
            edge_id,
            source,
            target,
            label=label.unwrap_or(""),
            origin=@flowchart.SourceBinding::new(
              "mermaid-state",
              edge_id,
              span=statement.span,
            ),
          ),
        )
        if !source_classes.is_empty() || !target_classes.is_empty() {
          finding(
            "unapplied-presentation",
            "Inline classes are retained without applying source CSS",
            statement.span,
            true,
          )
        }
      }
      Note(target~, placement~, text~) => {
        let target = ensure(target, Simple, statement.span)
        let note_id = "note-\{notes.length()}"
        notes.push(
          @model.Note::new(
            note_id,
            text,
            targets=[target],
            placement~,
            region~,
            origin=@flowchart.SourceBinding::new(
              "mermaid-state",
              note_id,
              span=statement.span,
            ),
          ),
        )
      }
      FloatingNote(id~, text~) => {
        // Pinned grammar accepts floating notes but does not add them to the
        // upstream topology. Retain their text for inspection with a finding.
        notes.push(
          @model.Note::new(
            "floating-" + id,
            text,
            placement="floating",
            region~,
            origin=@flowchart.SourceBinding::new(
              "mermaid-state",
              id,
              span=statement.span,
            ),
          ),
        )
        finding(
          "unapplied-presentation",
          "Pinned Mermaid accepts but does not draw floating notes",
          statement.span,
          true,
        )
      }
      Direction(d) => {
        let value = @flowchart.direction(d).unwrap_or(TB)
        if owners.last() is Some(owner) {
          if indices.get(owner) is Some(index) {
            states[index] = @model.State::new(
              states[index].id,
              label=states[index].label,
              region=states[index].region,
              role=states[index].role,
              descriptions=states[index].descriptions[:],
              expanded=states[index].expanded,
              direction=value,
              origin?=states[index].origin,
            )
          }
          let index = region_indices.get(region).unwrap()
          regions[index] = @model.Region::new(
            regions[index].id,
            owner?=regions[index].owner,
            members=regions[index].members[:],
            separator=regions[index].separator,
            direction=value,
            origin?=regions[index].origin,
          )
        } else {
          direction = value
        }
      }
      AccTitle(text) => accessibility_title = Some(text)
      AccDescription(text) => accessibility_description = Some(text)
      Presentation(_) =>
        finding(
          "unapplied-presentation",
          "Source presentation is retained as inert data",
          statement.span,
          true,
        )
      Comment(_) => ()
      Invalid(_) =>
        finding(
          "invalid-ast",
          "Invalid source prevents complete conversion",
          statement.span,
          false,
        )
    }
  }
  for directive in diagram.directives {
    work += directive.length()
  }
  if work > limits.work {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "state/work-limit", "Conversion work budget exhausted",
      ),
    )
    exhausted = true
  }
  if diagram.front_matter != None || !diagram.directives.is_empty() {
    if diagnostics.length() >= limits.diagnostics {
      exhausted = true
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "state/diagnostic-limit", "Conversion diagnostic budget exhausted",
      )
    } else {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "state/unapplied-presentation", "Source configuration is retained and cannot override caller options",
        ),
      )
    }
  }
  if exhausted || diagnostics.iter().any(d => d.severity == Error) {
    return { state: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  let members : Map[String, Array[String]] = Map([])
  for value in states {
    let list = members.get_or_init(value.region, () => [])
    list.push(value.id)
  }
  for i in 0..<regions.length() {
    regions[i] = @model.Region::new(
      regions[i].id,
      owner?=regions[i].owner,
      members=members.get(regions[i].id).unwrap_or([]),
      separator=regions[i].separator,
      direction?=regions[i].direction,
      origin?=regions[i].origin,
    )
  }
  for value in states {
    if value.role == Composite && !value.descriptions.is_empty() {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "state/composite-descriptions", "Pinned Mermaid refuses multiple composite descriptions",
        ),
      )
    }
  }
  let model = @model.StateDiagram::new(
    id,
    states,
    transitions,
    regions~,
    notes~,
    direction~,
    title?,
    accessibility_title?,
    accessibility_description?,
  )
  for
    d in @model.validate(
      model,
      nodes_limit=limits.states,
      edges_limit=limits.transitions,
      regions_limit=limits.regions,
      depth_limit=limits.depth,
      work_limit=limits.work,
      diagnostics_limit=limits.diagnostics,
    ) {
    if diagnostics.length() >= limits.diagnostics {
      exhausted = true
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "state/diagnostic-limit", "Conversion diagnostic budget exhausted",
      )
      break
    } else {
      diagnostics.push(d)
    }
  }
  {
    state: if exhausted || diagnostics.iter().any(d => d.severity == Error) {
      None
    } else {
      Some(model)
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "state/invalid-ast", "state/state-limit", "state/region-limit", "state/transition-limit",
  "state/work-limit", "state/unapplied-presentation", "state/composite-descriptions",
  "state/redeclaration", "state/ownership", "state/reserved-id", "state/diagnostic-limit",
]
