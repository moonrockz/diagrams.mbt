///|
pub struct Conversion {
  state : @model.StateDiagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
fn role_of(decoration : String, composite : Bool) -> @model.Role {
  let decoration = decoration.to_lower()
  if composite {
    Composite
  } else if decoration.contains("<<start>>") {
    Initial
  } else if decoration.contains("<<end>>") {
    Final
  } else if decoration.contains("<<choice>>") {
    Choice
  } else if decoration.contains("<<fork>>") {
    Fork
  } else if decoration.contains("<<join>>") {
    Join
  } else if decoration.contains("<<history*>>") {
    DeepHistory
  } else if decoration.contains("<<history>>") {
    ShallowHistory
  } else if decoration.contains("<<entrypoint>>") {
    EntryPoint
  } else if decoration.contains("<<exitpoint>>") {
    ExitPoint
  } else if decoration.contains("<<inputpin>>") {
    InputPin
  } else if decoration.contains("<<outputpin>>") {
    OutputPin
  } else if decoration.contains("<<expansioninput>>") {
    ExpansionInput
  } else if decoration.contains("<<expansionoutput>>") {
    ExpansionOutput
  } else if decoration.contains("<<sdlreceive>>") {
    Unsupported("sdlreceive")
  } else {
    Simple
  }
}

///|
priv struct Scope {
  owner : String?
  scope_path : String?
  id : String
  separator : @model.Separator
  mut direction : @flowchart.Direction?
}

///|
fn qualified(scope : String?, code : String) -> String {
  if code.contains(".") {
    code
  } else {
    scope.map(s => s + "." + code).unwrap_or(code)
  }
}

///|
/// Build explicit state topology; descriptions and history never execute.
pub fn to_state(
  document : Document,
  id~ : String = "state",
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let diagnostics : Array[@diagrams.Diagnostic] = []
  if print_body(document, limits~) is Err(ds) {
    return { state: None, diagnostics: ds, }
  }
  let reserved : Map[String, Bool] = Map([])
  for item in document.items {
    match item.kind {
      Declaration(code, _, _, _) | Description(code, _) => reserved[code] = true
      Transition(a, _, b, _) => {
        reserved[a] = true
        reserved[b] = true
      }
      Note(_, _, _, Some(code)) => reserved[code] = true
      _ => ()
    }
  }
  fn fresh(prefix : String) -> String {
    let mut candidate = prefix
    while reserved.contains(candidate) {
      candidate += "_"
    }
    reserved[candidate] = true
    candidate
  }
  let regions : Array[Scope] = [
    {
      owner: None,
      scope_path: None,
      id: fresh("root"),
      separator: Horizontal,
      direction: None,
    },
  ]
  let contexts : Array[Int32] = []
  let stack : Array[Int32] = []
  let declared : Map[String, Int32] = Map([])
  let declaration_roles : Map[String, @model.Role] = Map([])
  let composite_labels : Map[String, String] = Map([])
  let declared_regions : Map[String, Int32] = Map([])
  let composite_regions : Map[String, Int32] = Map([])
  let mut current = 0
  let mut concurrent = 0
  let mut work = 0
  let mut failed = false
  fn error(code : String, text : String, span : @diagrams.Span?) {
    failed = true
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(@diagrams.Diagnostic::error(code, text, span?))
    }
  }
  for item_index, item in document.items {
    contexts.push(current)
    work += 1
    match item.kind {
      Declaration(code, label, decoration, composite) => {
        let name = qualified(regions[current].scope_path, code)
        declared[name] = item_index
        if composite && item.explicit_label {
          composite_labels[name] = label
        }
        if composite || !declaration_roles.contains(name) {
          declaration_roles[name] = role_of(decoration, composite)
        }
        let parts : Array[String] = []
        for value in name.split(".") {
          if parts.length() >= limits.depth {
            error(
              "state/limit",
              "Qualified state name depth limit exceeded",
              item.span,
            )
            break
          }
          parts.push(value.to_owned())
        }
        if failed {
          break
        }
        work += name.length()
        let mut parent_region = current
        let mut path = ""
        for n = 0; n + 1 < parts.length(); n = n + 1 {
          work += path.length() + parts[n].length() + 1
          if work > limits.work {
            error(
              "state/limit",
              "Qualified parent path work limit exceeded",
              item.span,
            )
            break
          }
          path = if path.is_empty() { parts[n] } else { path + "." + parts[n] }
          declaration_roles[path] = Composite
          if composite_regions.get(path) is Some(existing) {
            parent_region = existing
          } else {
            if regions.length() >= limits.regions || work > limits.work {
              error(
                "state/limit",
                "Region or work limit exceeded before parent expansion",
                item.span,
              )
              break
            }
            let index = regions.length()
            declared_regions[path] = parent_region
            declared[path] = item_index
            composite_regions[path] = index
            regions.push({
              owner: Some(path),
              scope_path: Some(path),
              id: fresh(path + "::region0"),
              separator: Horizontal,
              direction: None,
            })
            parent_region = index
          }
        }
        declared_regions[name] = parent_region
        if composite {
          stack.push(current)
          current = regions.length()
          composite_regions[name] = current
          regions.push({
            owner: Some(name),
            scope_path: Some(name),
            id: fresh(name + "::region0"),
            separator: Horizontal,
            direction: None,
          })
        }
      }
      Close => if !stack.is_empty() { current = stack.pop().unwrap() }
      Separator(vertical) => {
        let scope = regions[current]
        if scope.owner == None {
          error(
            "state/invalid-ast",
            "Concurrent region requires an owning state",
            item.span,
          )
        } else {
          current = regions.length()
          concurrent += 1
          let scope_path = scope.owner.unwrap() +
            ".CONC" +
            concurrent.to_string()
          composite_regions[scope_path] = current
          regions.push({
            owner: scope.owner,
            scope_path: Some(scope_path),
            id: fresh(scope_path + "::region0"),
            separator: if vertical {
              Vertical
            } else {
              Horizontal
            },
            direction: None,
          })
        }
      }
      Direction(direction) => regions[current].direction = Some(direction)
      _ => ()
    }
    if regions.length() > limits.regions ||
      stack.length() > limits.depth ||
      work > limits.work {
      error("state/limit", "Region, nesting or work limit exceeded", item.span)
      break
    }
  }
  if failed {
    return { state: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  let states : Array[@model.State] = []
  let transitions : Array[@model.Transition] = []
  let notes : Array[@model.Note] = []
  let known : Map[String, Int32] = Map([])
  let known_regions : Map[String, Int32] = Map([])
  fn resolve(code : String, region : Int32) -> String {
    if code.contains(".") {
      return code
    }
    let mut owner = regions[region].scope_path
    while owner is Some(path) {
      work += path.length() + code.length() + 1
      if work > limits.work {
        error("state/limit", "Name resolution work limit exceeded", None)
        return code
      }
      let candidate = path + "." + code
      if declared.contains(candidate) || known.contains(candidate) {
        return candidate
      }
      let mut at = -1
      for i = 0; i < path.length(); i = i + 1 {
        if path.code_unit_at(i).to_int() == 46 {
          at = i
        }
      }
      owner = if at < 0 { None } else { Some(part(path, 0, at)) }
      work += 1
      if work > limits.work {
        return code
      }
    }
    if declared.contains(code) || known.contains(code) {
      return code
    }
    // PlantUML resolves an unqualified name to a unique already declared child.
    let mut unique : String? = None
    let mut matches = 0
    for name in declared.keys() {
      work += name.length() + code.length() + 1
      if work > limits.work {
        error("state/limit", "Unique name lookup work limit exceeded", None)
        return code
      }
      if name.has_suffix("." + code) {
        unique = Some(name)
        matches += 1
      }
    }
    for name in known.keys() {
      if declared.contains(name) {
        continue
      }
      work += name.length() + code.length() + 1
      if work > limits.work {
        error("state/limit", "Implicit name lookup work limit exceeded", None)
        return code
      }
      if name.has_suffix("." + code) {
        unique = Some(name)
        matches += 1
      }
    }
    if matches == 1 {
      unique.unwrap()
    } else {
      qualified(regions[region].scope_path, code)
    }
  }
  fn ensure(
    name : String,
    region : Int32,
    role : @model.Role,
    origin : @flowchart.SourceBinding,
  ) -> String {
    let actual_region = declared_regions
      .get(name)
      .unwrap_or_else(() => known_regions.get(name).unwrap_or(region))
    if actual_region != region &&
      (
        regions[region].scope_path.unwrap_or("").contains(".CONC") ||
        regions[actual_region].scope_path.unwrap_or("").contains(".CONC")
      ) {
      error(
        "state/refused-scope",
        "The pinned PlantUML profile refuses this cross-region state reference",
        origin.span,
      )
      return name
    }
    if !known.contains(name) {
      if states.length() >= limits.nodes || work >= limits.work {
        error(
          "state/limit",
          "State count or conversion work limit exceeded",
          origin.span,
        )
        return name
      }
      let actual = declared_regions.get(name).unwrap_or(region)
      known[name] = states.length()
      known_regions[name] = actual
      let label = if role == Initial ||
        role == Final ||
        role == ShallowHistory ||
        role == DeepHistory {
        ""
      } else {
        name.split(".").to_array().last().unwrap_or(name[:]).to_owned()
      }
      states.push(
        @model.State::new(
          name,
          label~,
          region=regions[actual].id,
          role~,
          origin~,
        ),
      )
      work += 1
    }
    name
  }
  fn endpoint(
    code : String,
    region : Int32,
    source : Bool,
    origin : @flowchart.SourceBinding,
  ) -> String {
    if code == "[*]" {
      let marker = if source { "*start*" } else { "*end*" }
      let name = match regions[region].scope_path {
        None => marker
        Some(path) =>
          path +
          "." +
          marker +
          path.split(".").to_array().last().unwrap_or(path[:]).to_owned()
      }
      return ensure(name, region, if source { Initial } else { Final }, origin)
    }
    if code.has_suffix("[H]") || code.has_suffix("[H*]") {
      let deep = code.has_suffix("[H*]")
      let prefix = part(code, 0, code.length() - (if deep { 4 } else { 3 }))
      let scope = if prefix.is_empty() {
        region
      } else {
        let name = resolve(prefix, region)
        match composite_regions.get(name) {
          Some(index) => index
          None => {
            error(
              "state/invalid-ast",
              "History target must name a composite state",
              origin.span,
            )
            region
          }
        }
      }
      let marker = if deep { "*deephistory*" } else { "*historical*" }
      let name = match regions[scope].scope_path {
        None => marker
        Some(path) =>
          path +
          "." +
          marker +
          path.split(".").to_array().last().unwrap_or(path[:]).to_owned()
      }
      return ensure(
        name,
        scope,
        if deep {
          DeepHistory
        } else {
          ShallowHistory
        },
        origin,
      )
    }
    if code.has_prefix("==") && code.has_suffix("==") {
      let code = code.trim_start(chars="=").trim_end(chars="=").to_owned()
      let name = resolve(code, region)
      return ensure(name, region, Fork, origin)
    }
    let name = resolve(code, region)
    ensure(name, region, Simple, origin)
  }
  for item_index, item in document.items {
    let region = contexts[item_index]
    let origin = @flowchart.SourceBinding::new(
      "plantuml",
      item_index.to_string(),
      span?=item.span,
    )
    work += 1
    if work > limits.work {
      error("state/limit", "Conversion work limit exceeded", item.span)
      break
    }
    match item.kind {
      Declaration(code, label, decoration, composite) => {
        let name = qualified(regions[region].scope_path, code)
        let role = declaration_roles
          .get(name)
          .unwrap_or(role_of(decoration, composite))
        let parts = name.split(".").map(s => s.to_owned()).to_array()
        let mut path = ""
        for n = 0; n + 1 < parts.length(); n = n + 1 {
          work += path.length() + parts[n].length() + 1
          if work > limits.work {
            error(
              "state/limit",
              "Qualified parent path work limit exceeded",
              item.span,
            )
            break
          }
          path = if path.is_empty() { parts[n] } else { path + "." + parts[n] }
          if !path.contains(".CONC") {
            let _ = ensure(
              path,
              declared_regions.get(path).unwrap_or(region),
              Composite,
              origin,
            )
          }
        }
        let _ = ensure(name, region, role, origin)
        if known.get(name) is Some(index) {
          states[index] = @model.State::new(
            name,
            label=composite_labels.get(name).unwrap_or(label),
            region=states[index].region,
            role~,
            descriptions=states[index].descriptions[:],
            origin~,
          )
        }
        if !decoration.is_empty() && diagnostics.length() < limits.diagnostics {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "state/unapplied-presentation",
              "Colors and stereotypes remain author data",
              span?=item.span,
            ),
          )
        }
      }
      Description(code, text) => {
        let name = endpoint(code, region, true, origin)
        if known.get(name) is Some(index) {
          let descriptions = states[index].descriptions.iter().to_array()
          for line in text.replace_all(old="\\n", new="\n").split("\n") {
            descriptions.push(line.to_owned())
          }
          states[index] = states[index].with_descriptions(descriptions[:])
        }
      }
      Transition(from, arrow, target, label) => {
        let reverse = arrow.has_prefix("<") && !arrow.has_suffix(">")
        let a = endpoint(
          if reverse {
            target
          } else {
            from
          },
          region,
          true,
          origin,
        )
        let b = endpoint(
          if reverse {
            from
          } else {
            target
          },
          region,
          false,
          origin,
        )
        if transitions.length() >= limits.edges {
          error("state/limit", "Transition count limit exceeded", item.span)
          break
        }
        let hint = arrow_hint(arrow)
        let style : @flowchart.LineStyle = if arrow.contains("hidden") {
          Invisible
        } else if arrow.contains("dashed") ||
          arrow.contains("dotted") ||
          arrow.contains(".") {
          Dotted
        } else if arrow.contains("bold") {
          Thick
        } else {
          Solid
        }
        transitions.push(
          @model.Transition::new(
            fresh("transition/" + item_index.to_string()),
            a,
            b,
            label=label.replace_all(old="\\n", new="\n"),
            style~,
            source_marker=if arrow.has_prefix("x") {
              Cross
            } else if arrow.has_prefix("<") && arrow.has_suffix(">") {
              Arrow
            } else {
              None
            },
            target_marker=if arrow.has_suffix("o") {
              Circle
            } else if arrow.contains(">") || arrow.contains("<") {
              Arrow
            } else {
              None
            },
            direction_hint?=hint,
            origin~,
          ),
        )
      }
      Note(placement, target, text, code) => {
        let targets = match target {
          Some(target) =>
            if target == "@link" {
              []
            } else {
              [endpoint(target, region, true, origin)]
            }
          None => []
        }
        let connection_targets = if target == Some("@link") {
          match transitions.last() {
            Some(edge) => [edge.id]
            None => {
              error(
                "state/invalid-ast",
                "Link note has no preceding transition",
                item.span,
              )
              []
            }
          }
        } else {
          []
        }
        notes.push(
          @model.Note::new(
            code.unwrap_or_else(() => fresh("note/" + item_index.to_string())),
            text.replace_all(old="\\n", new="\n"),
            targets=targets[:],
            connection_targets=connection_targets[:],
            placement~,
            region=regions[region].id,
            origin~,
          ),
        )
      }
      _ => ()
    }
  }
  if failed {
    return { state: None, diagnostics: ReadOnlyArray::from_array(diagnostics), }
  }
  let members : Map[String, Array[String]] = Map([])
  for state in states {
    members.get_or_init(state.region, () => []).push(state.id)
  }
  let model_regions : Array[@model.Region] = []
  for region in regions {
    model_regions.push(
      @model.Region::new(
        region.id,
        owner?=region.owner,
        members=members.get(region.id).unwrap_or([])[:],
        separator=region.separator,
        direction?=region.direction,
      ),
    )
  }
  let mut title = None
  for statement in document.statements {
    if statement is Title(text) {
      title = Some(text)
    }
  }
  {
    state: Some(
      @model.StateDiagram::new(
        id,
        states[:],
        transitions[:],
        regions=model_regions[:],
        notes=notes[:],
        direction=regions[0].direction.unwrap_or(TB),
        title?,
      ),
    ),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
