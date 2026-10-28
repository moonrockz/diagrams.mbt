///|
pub struct Conversion {
  flowchart : @model.Flowchart?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
priv struct Pending {
  id : String
  label : String
  role : @model.ConnectionRole
}

///|
priv struct Control {
  kind : String
  entry : String
  exit : String
  region : String
  parent : String?
  tails : Array[Pending]
  branches : Array[@model.Branch]
  members : Array[String]
  mut condition : String
  mut branch_condition : String
  mut branch_at : Int32
  mut branch_label : String
  mut last_decision : String
  mut has_else : Bool
  mut backward : String?
  origin : @model.SourceBinding
}

///|
fn arrow_hint(arrow : String) -> @model.Direction? {
  let word = StringBuilder()
  let mut bracket = false
  for ch in arrow {
    if ch == '[' {
      bracket = true
    } else if ch == ']' {
      bracket = false
    } else if !bracket && ch >= 'a' && ch <= 'z' {
      word.write_char(ch)
    }
  }
  match word.to_string() {
    "l" | "le" | "left" => Some(RL)
    "r" | "ri" | "right" => Some(LR)
    "u" | "up" => Some(BT)
    "d" | "do" | "down" => Some(TB)
    _ => if arrow == "->" { Some(LR) } else { None }
  }
}

///|
/// Convert native syntax to explicit structural topology. Expressions remain
/// descriptive; pending continuation sets never execute source conditions.
pub fn to_flowchart(
  document : Document,
  id~ : String = "activity",
  limits~ : @envelope.Limits = @envelope.Limits::new(),
) -> Conversion {
  let nodes : Array[@model.Node] = []
  let edges : Array[@model.Connection] = []
  let groups : Array[@model.Group] = []
  let lanes : Array[@model.Lane] = []
  let notes : Array[@model.Note] = []
  let regions : Array[@model.Region] = []
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let pending : Array[Pending] = []
  let controls : Array[Control] = []
  let group_path : Array[String] = []
  let lane_ids : Map[String, Bool] = Map([])
  let used : Map[String, Bool] = Map([])
  let named : Map[String, String] = Map([])
  let legacy_actions : Map[String, String] = Map([])
  let unresolved : Array[(String, String, @model.SourceBinding)] = []
  let mut lane : String? = None
  let mut work = 0
  let mut failed = false
  let mut serial = 0
  let mut last : String? = None
  let mut span : @diagrams.Span? = None
  let mut origin = @model.SourceBinding::new("plantuml", "0")
  let mut next_label = ""
  let mut next_style : @model.LineStyle = Solid
  let mut next_direction : @model.Direction? = None
  fn error(code : String, message : String) {
    failed = true
    if diagnostics.length() < limits.diagnostics.max(1) {
      diagnostics.push(@diagrams.Diagnostic::error(code, message, span?))
    }
  }
  fn charge(n : Int32) -> Bool {
    if n < 0 || n > limits.work - work {
      error("activity/limit", "Activity conversion work limit exceeded")
      false
    } else {
      work += n
      true
    }
  }
  fn fresh(prefix : String) -> String {
    let mut value = "__activity_" + prefix + serial.to_string()
    serial += 1
    while used.contains(value) {
      value = "__activity_" + prefix + serial.to_string()
      serial += 1
    }
    used[value] = true
    value
  }
  // Reserve every authored name before generating IDs, including forward labels.
  for statement in document.items {
    match statement.kind {
      Label(name) | Goto(name) => used[name] = true
      Edge(from, _, target, _) => {
        fn reserve(value : Endpoint) {
          match value {
            Alias(name) | Synchronization(name) => used[name] = true
            Action(_, Some(name), _) => used[name] = true
            _ => ()
          }
        }
        if from is Some(value) {
          reserve(value)
        }
        reserve(target)
      }
      _ => ()
    }
  }
  fn connect(
    source : String,
    target : String,
    label : String,
    role : @model.ConnectionRole,
  ) {
    if edges.length() >= limits.edges ||
      !charge(source.length() + target.length() + label.length() + 1) {
      error("activity/limit", "Activity connection limit exceeded")
      return
    }
    edges.push(
      @model.Connection::new(
        fresh("edge"),
        source,
        target,
        label~,
        style=next_style,
        role~,
        direction_hint?=next_direction,
        origin~,
      ),
    )
  }
  fn link_to(target : String) {
    for value in pending {
      connect(
        value.id,
        target,
        if next_label.is_empty() {
          value.label
        } else {
          next_label
        },
        value.role,
      )
    }
    pending.clear()
    next_label = ""
    next_style = Solid
  }
  fn current(value : String) {
    pending.clear()
    pending.push({ id: value, label: "", role: Flow, })
    last = Some(value)
  }
  fn node(
    label : String,
    role : @model.Role,
    shape : String,
    connect_in : Bool,
  ) -> String {
    if label.contains("<img:") || label.contains("<img ") {
      error(
        "activity/external-asset", "External images are not loaded by the activity library",
      )
    }
    let key = fresh("node")
    if nodes.length() + groups.length() + lanes.length() + notes.length() >=
      limits.nodes ||
      !charge(label.length() + 1) {
      error("activity/limit", "Activity node limit exceeded")
      return key
    }
    let region_ids = controls.iter().map(c => c.region).collect()
    nodes.push(
      @model.Node::new(
        key,
        label=label.replace_all(old="\\n", new="\n"),
        role~,
        shape~,
        lane?,
        groups=group_path[:],
        regions=region_ids[:],
        origin~,
      ),
    )
    for control in controls {
      control.members.push(key)
    }
    if connect_in {
      link_to(key)
      current(key)
    }
    key
  }
  fn branch(control : Control) {
    let members = control.members[control.branch_at:]
    control.branches.push(
      @model.Branch::new(
        fresh("branch"),
        label=control.branch_label,
        members~,
        condition?=if control.branch_condition.is_empty() {
          None
        } else {
          Some(control.branch_condition)
        },
        origin=control.origin,
      ),
    )
    control.branch_at = control.members.length()
  }
  fn open(
    kind : String,
    entry : String,
    exit : String,
    condition : String,
    label : String,
  ) {
    if controls.length() >= limits.depth {
      error("activity/limit", "Activity control nesting limit exceeded")
      return
    }
    let parent = controls.last().map(c => c.region)
    controls.push({
      kind,
      entry,
      exit,
      region: fresh("region"),
      parent,
      tails: [],
      branches: [],
      members: [],
      condition,
      branch_condition: condition,
      branch_at: 0,
      branch_label: label,
      last_decision: entry,
      has_else: false,
      backward: None,
      origin,
    })
  }
  fn close_region(
    control : Control,
    kind : @model.RegionKind,
    join_specification : String?,
  ) {
    regions.push(
      @model.Region::new(
        control.region,
        kind,
        parent?=control.parent,
        entry=control.entry,
        exit=control.exit,
        members=control.members[:],
        branches=control.branches[:],
        condition=control.condition,
        join_specification?,
        origin=control.origin,
      ),
    )
  }
  fn save_tails(control : Control) {
    for value in pending {
      control.tails.push(value)
    }
    branch(control)
    pending.clear()
  }
  fn close_conditional() {
    guard controls.pop() is Some(control) else {
      error("activity/invalid-ast", "Conditional close without open")
      return
    }
    if control.kind != "if" &&
      control.kind != "switch" &&
      control.kind != "legacy-if" {
      error("activity/invalid-ast", "Mismatched conditional close")
      return
    }
    branch(control)
    if control.kind == "legacy-if" {
      close_region(control, Conditional, None)
      return
    }
    for value in pending {
      control.tails.push(value)
    }
    pending.clear()
    if !control.has_else {
      control.tails.push({ id: control.last_decision, label: "", role: Branch, })
    }
    for value in control.tails {
      connect(value.id, control.exit, value.label, value.role)
    }
    current(control.exit)
    close_region(control, Conditional, None)
  }
  fn legacy_endpoint(value : Endpoint, target : Bool) -> String {
    match value {
      Start(top) => {
        let code = if target && !nodes.is_empty() {
          "__legacy_end"
        } else {
          "__legacy_start"
        }
        if named.get(code) is Some(key) {
          key
        } else {
          let key = node(
            "",
            if target && !nodes.is_empty() {
              ActivityFinal
            } else {
              Start
            },
            if target && !nodes.is_empty() {
              "fr-circ"
            } else {
              "sm-circ"
            },
            false,
          )
          named[code] = key
          ignore(top)
          key
        }
      }
      Final => {
        let key = node("", ActivityFinal, "fr-circ", false)
        key
      }
      Action(label, code, decoration) => {
        if !decoration.is_empty() {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Legacy action presentation is retained as source data",
              span?,
            ),
          )
        }
        let identity = code.unwrap_or(label)
        match legacy_actions.get(identity) {
          Some(key) => key
          None => {
            let key = node(label, Action, "rounded", false)
            legacy_actions[identity] = key
            if code is Some(code) {
              named[code] = key
            }
            key
          }
        }
      }
      Alias(code) =>
        match
          (if named.contains(code) {
            named.get(code)
          } else {
            legacy_actions.get(code)
          }) {
          Some(key) => key
          None => {
            let key = node(code, Action, "rounded", false)
            named[code] = key
            key
          }
        }
      Synchronization(code) =>
        match named.get("bar:" + code) {
          Some(key) => key
          None => {
            let key = node("", Join, "fork", false)
            named["bar:" + code] = key
            key
          }
        }
    }
  }
  if !limits.valid() {
    error("plantuml/invalid-limits", "Activity limits must be positive")
  }
  for index, statement in document.items {
    if failed || !charge(1) {
      break
    }
    span = statement.span
    origin = @model.SourceBinding::new("plantuml", index.to_string(), span?)
    match statement.kind {
      ActionList(label, depth) =>
        ignore(
          node(
            (if depth > 1 { "*".repeat(depth - 1) + " " } else { "" }) + label,
            Action,
            "rounded",
            true,
          ),
        )
      LegacyDecision(from, arrow, condition, label) => {
        let source = match from {
          Some(value) => Some(legacy_endpoint(value, false))
          None => last
        }
        let entry = node(condition, Decision, "diamond", false)
        if source is Some(source) {
          connect(source, entry, label, Branch)
        }
        ignore(arrow)
        open("legacy-if", entry, entry, condition, "")
        current(entry)
      }
      Action(label, terminator, decoration) => {
        let shape = match terminator {
          "]" => "rect"
          "/" => "lean-r"
          "<" | ">" => "odd"
          "|" => "fork"
          "}" => "diamond"
          _ => "rounded"
        }
        let key = node(label, Action, shape, true)
        if decoration.find("[[") is Some(start) &&
          decoration.find("]]") is Some(end) &&
          end > start + 2 {
          let link = part(decoration, start + 2, end)
            .split(" ")
            .next()
            .unwrap_or("")
            .to_owned()
          for i, value in nodes {
            if value.id == key {
              nodes[i] = @model.Node::new(
                value.id,
                label=value.label,
                label_kind=value.label_kind,
                shape=value.shape,
                metadata=value.metadata[:],
                lane?=value.lane,
                groups=value.groups[:],
                properties=@model.RenderProperties::new(link~),
                role=value.role,
                regions=value.regions[:],
                origin?=value.origin,
              )
            }
          }
        }
        if !decoration.is_empty() {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Action decoration is retained as source data",
              span?,
            ),
          )
        }
      }
      Start => ignore(node("", Start, "sm-circ", true))
      Stop | End => {
        ignore(
          node(
            "",
            if statement.kind == Stop {
              ActivityFinal
            } else {
              FlowFinal
            },
            if statement.kind == Stop {
              "fr-circ"
            } else {
              "cross-circ"
            },
            true,
          ),
        )
        pending.clear()
      }
      If(condition, label) => {
        let entry = node(condition, Decision, "diamond", true)
        let exit = node("", Merge, "diamond", false)
        open("if", entry, exit, condition, label)
        pending.clear()
        pending.push({ id: entry, label, role: Branch, })
      }
      ElseIf(condition, label) | ElseIfIncoming(_, condition, label) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "elseif without if")
          continue
        }
        save_tails(control)
        let incoming = match statement.kind {
          ElseIfIncoming(value, _, _) => value
          _ => ""
        }
        pending.push({
          id: control.last_decision,
          label: incoming,
          role: Branch,
        })
        let decision = node(condition, Decision, "diamond", true)
        control.last_decision = decision
        control.branch_label = label
        control.branch_condition = condition
        pending.clear()
        pending.push({ id: decision, label, role: Branch, })
      }
      Else(label) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "else without if")
          continue
        }
        save_tails(control)
        control.branch_label = label
        control.branch_condition = ""
        control.has_else = true
        pending.push({ id: control.last_decision, label, role: Branch, })
        if control.kind == "legacy-if" {
          last = Some(control.last_decision)
        }
      }
      EndIf | EndSwitch => close_conditional()
      Switch(condition) => {
        let entry = node(condition, Decision, "diamond", true)
        let exit = node("", Merge, "diamond", false)
        open("switch", entry, exit, condition, "")
        if controls.last() is Some(control) {
          control.has_else = true
        }
        pending.clear()
      }
      Case(label) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "case without switch")
          continue
        }
        if !control.members.is_empty() || !pending.is_empty() {
          save_tails(control)
        }
        control.branch_label = label
        control.branch_condition = label
        pending.push({ id: control.entry, label, role: Branch, })
      }
      While(condition, label) => {
        let entry = node(condition, Decision, "diamond", true)
        let exit = node("", Merge, "anchor", false)
        open("while", entry, exit, condition, label)
        pending.clear()
        pending.push({ id: entry, label, role: Branch, })
      }
      EndWhile(label) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "endwhile without while")
          continue
        }
        if control.kind != "while" {
          error("activity/invalid-ast", "Mismatched loop end")
          continue
        }
        if control.backward is Some(text) {
          ignore(node(text, Action, "rounded", true))
        }
        for value in pending {
          connect(value.id, control.entry, value.label, LoopBack)
        }
        connect(control.entry, control.exit, label, LoopExit)
        branch(control)
        ignore(controls.pop())
        current(control.exit)
        close_region(control, Loop, None)
      }
      Repeat(action) => {
        let label = if action.has_prefix(":") {
          after(action, ":").trim_end(chars=";").to_owned()
        } else {
          action
        }
        let entry = node(
          label,
          if label.is_empty() {
            Connector
          } else {
            Action
          },
          if label.is_empty() {
            "anchor"
          } else {
            "rounded"
          },
          true,
        )
        let exit = node("", Merge, "anchor", false)
        open("repeat", entry, exit, "", "")
      }
      RepeatWhile(condition, yes, no) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "repeat while without repeat")
          continue
        }
        if control.kind != "repeat" {
          error("activity/invalid-ast", "Mismatched repeat end")
          continue
        }
        control.condition = condition
        control.branch_condition = condition
        let decision = node(condition, Decision, "diamond", true)
        if control.backward is Some(text) {
          pending.clear()
          pending.push({ id: decision, label: yes, role: LoopBack, })
          let back = node(text, Action, "rounded", true)
          connect(back, control.entry, "", LoopBack)
        } else {
          connect(decision, control.entry, yes, LoopBack)
        }
        connect(decision, control.exit, no, LoopExit)
        branch(control)
        ignore(controls.pop())
        current(control.exit)
        close_region(control, Loop, None)
      }
      Backward(text) => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "backward outside a loop")
          continue
        }
        control.backward = Some(text)
      }
      Break => {
        let mut found = false
        for i = controls.length() - 1; i >= 0; i = i - 1 {
          let control = controls[i]
          if control.kind == "repeat" || control.kind == "while" {
            for value in pending {
              connect(value.id, control.exit, value.label, LoopExit)
            }
            pending.clear()
            found = true
            break
          }
        }
        if !found {
          error("activity/invalid-ast", "break outside a loop")
        }
      }
      Fork | Split => {
        let entry = node(
          "",
          Fork,
          if statement.kind == Fork {
            "fork"
          } else {
            "anchor"
          },
          true,
        )
        let exit = node("", Join, "fork", false)
        open(
          if statement.kind == Fork {
            "fork"
          } else {
            "split"
          },
          entry,
          exit,
          "",
          "",
        )
        current(entry)
      }
      ForkAgain | SplitAgain => {
        guard controls.last() is Some(control) else {
          error("activity/invalid-ast", "Parallel branch outside a region")
          continue
        }
        save_tails(control)
        current(control.entry)
      }
      EndFork(merge, label) => {
        guard controls.pop() is Some(control) else {
          error("activity/invalid-ast", "end fork without fork")
          continue
        }
        if control.kind != "fork" {
          error("activity/invalid-ast", "Mismatched fork end")
          continue
        }
        save_tails(control)
        for value in control.tails {
          connect(value.id, control.exit, value.label, Parallel)
        }
        if merge {
          for i, node in nodes {
            if node.id == control.exit {
              nodes[i] = @model.Node::new(
                node.id,
                label=node.label,
                label_kind=node.label_kind,
                shape="diamond",
                metadata=node.metadata[:],
                lane?=node.lane,
                groups=node.groups[:],
                properties?=node.properties,
                role=Merge,
                regions=node.regions[:],
                origin?=node.origin,
              )
            }
          }
        }
        current(control.exit)
        close_region(
          control,
          Parallel,
          if label.is_empty() {
            None
          } else {
            Some(label)
          },
        )
      }
      EndSplit => {
        guard controls.pop() is Some(control) else {
          error("activity/invalid-ast", "end split without split")
          continue
        }
        if control.kind != "split" {
          error("activity/invalid-ast", "Mismatched split end")
          continue
        }
        save_tails(control)
        for value in control.tails {
          connect(value.id, control.exit, value.label, Parallel)
        }
        current(control.exit)
        close_region(control, Split, None)
      }
      Kill | Detach => {
        if last is Some(key) {
          for i, value in nodes {
            if value.id == key {
              let metadata = value.metadata.iter().to_array()
              metadata.push(
                (
                  "plantuml/termination",
                  if statement.kind == Kill {
                    "kill"
                  } else {
                    "detach"
                  },
                ),
              )
              nodes[i] = @model.Node::new(
                value.id,
                label=value.label,
                label_kind=value.label_kind,
                shape=value.shape,
                metadata=metadata[:],
                lane?=value.lane,
                groups=value.groups[:],
                properties?=value.properties,
                role=value.role,
                regions=value.regions[:],
                origin?=value.origin,
              )
            }
          }
        }
        pending.clear()
      }
      Connector(label) => {
        let key = match named.get("connector:" + label) {
          Some(key) => {
            link_to(key)
            current(key)
            key
          }
          None => {
            let key = node(label, Connector, "circle", true)
            named["connector:" + label] = key
            key
          }
        }
        ignore(key)
      }
      Label(name) =>
        if named.contains("label:" + name) {
          error("activity/invalid-ast", "Duplicate label " + name)
        } else {
          let key = node("", Connector, "anchor", true)
          named["label:" + name] = key
        }
      Goto(name) => {
        for value in pending {
          unresolved.push((value.id, name, origin))
        }
        pending.clear()
      }
      Group(_, label, before, decoration) => {
        if !before.is_empty() || !decoration.is_empty() {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Group presentation is retained as source data",
              span?,
            ),
          )
        }
        let key = fresh("group")
        groups.push(@model.Group::new(key, label~, parent?=group_path.last()))
        group_path.push(key)
      }
      EndGroup =>
        if group_path.pop() == None {
          error("activity/invalid-ast", "Group end without group")
        }
      Lane(code, label, color) => {
        if !lane_ids.contains(code) {
          if used.contains(code) {
            error("activity/invalid-ast", "Lane identity collision " + code)
          }
          used[code] = true
          lane_ids[code] = true
          lanes.push(@model.Lane::new(code, label~))
        }
        lane = Some(code)
        if !color.is_empty() {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Lane color is retained as source data",
              span?,
            ),
          )
        }
      }
      Note(placement, text, code, _) => {
        if text.contains("<img:") || text.contains("<img ") {
          error(
            "activity/external-asset", "External note images are not loaded",
          )
        }
        let key = code.unwrap_or_else(() => fresh("note"))
        let targets = last.iter().collect()
        notes.push(
          @model.Note::new(
            key,
            text,
            targets=targets[:],
            placement~,
            groups=group_path[:],
            lane?,
            origin~,
          ),
        )
      }
      NoteOnLink(text, _) => {
        let targets = edges.last().map(e => e.id).iter().to_array()
        if targets.is_empty() {
          error(
            "activity/invalid-ast", "A note on link needs a preceding connection",
          )
        }
        notes.push(
          @model.Note::new(
            fresh("note"),
            text,
            connection_targets=targets[:],
            groups=group_path[:],
            lane?,
            origin~,
          ),
        )
      }
      Arrow(style, text) => {
        if text.contains("#") {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Arrow color is retained as source data",
              span?,
            ),
          )
        }
        next_style = match style {
          "invisible" => Invisible
          "dotted" => Dotted
          "thick" => Thick
          _ => Solid
        }
        let cleaned = text.trim_end(chars=";").to_owned()
        if cleaned.find(">") is Some(at) {
          next_label = trim(part(cleaned, at + 1, cleaned.length()))
        }
      }
      Edge(from, arrow, target, label) => {
        if arrow.contains("#") {
          diagnostics.push(
            @diagrams.Diagnostic::warning(
              "activity/unapplied-presentation",
              "Arrow color is retained as source data",
              span?,
            ),
          )
        }
        let source = match from {
          Some(value) => Some(legacy_endpoint(value, false))
          None => last
        }
        let target = legacy_endpoint(target, true)
        next_direction = arrow_hint(arrow)
        if !arrow.is_empty() && source is Some(source) {
          next_style = if arrow.contains("hidden") {
            Invisible
          } else if arrow.contains(".") {
            Dotted
          } else {
            Solid
          }
          connect(source, target, label, Flow)
          next_style = Solid
          next_direction = None
        } else if !arrow.is_empty() {
          error("activity/invalid-ast", "Legacy arrow has no previous activity")
        }
        current(target)
      }
      LegacyIf(condition) => {
        let entry = node(condition, Decision, "diamond", true)
        open("legacy-if", entry, entry, condition, "")
        current(entry)
      }
      Presentation(_) =>
        diagnostics.push(
          @diagrams.Diagnostic::warning(
            "activity/unapplied-presentation",
            "Presentation data is retained but not applied",
            span?,
          ),
        )
    }
  }
  for (source, name, binding) in unresolved {
    origin = binding
    match named.get("label:" + name) {
      Some(target) => connect(source, target, "", Flow)
      None => error("activity/unresolved-label", "Unknown label " + name)
    }
  }
  if !controls.is_empty() || !group_path.is_empty() {
    error("activity/unclosed-control", "Unclosed activity control or group")
  }
  let title = document.statements
    .iter()
    .filter_map(s => {
      match s {
        @envelope.Title(value) => Some(value)
        _ => None
      }
    })
    .next()
  let model = @model.Flowchart::new(
    id,
    nodes[:],
    edges[:],
    groups=groups[:],
    lanes=lanes[:],
    notes=notes[:],
    regions=regions[:],
    title?,
  )
  if !failed {
    let findings = @model.validate(
      model,
      nodes_limit=limits.nodes,
      edges_limit=limits.edges,
      depth_limit=limits.depth,
      work_limit=(limits.work - work).max(0),
    )
    for finding in findings {
      diagnostics.push(finding)
      failed = true
    }
  }
  {
    flowchart: if failed {
      None
    } else {
      Some(model)
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
