///|
pub struct Conversion {
  architecture : @model.Architecture?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "architecture/duplicate-id", "architecture/duplicate-connection", "architecture/invalid-parent",
  "architecture/ownership-cycle", "architecture/depth-limit", "architecture/invalid-endpoint",
  "architecture/invalid-group-attachment", "architecture/invalid-alignment", "architecture/model-limit",
  "architecture/work-limit", "architecture/metadata-option",
]

///|
pub fn to_architecture(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
  id~ : String = "architecture",
) -> Conversion {
  let spans : Map[String, @diagrams.Span] = Map([])
  let alignment_spans : Map[String, @diagrams.Span] = Map([])
  let groups = []
  let services = []
  let junctions = []
  let connections = []
  let alignments = []
  let mut title = None
  let mut accessibility_title = None
  let mut accessibility_description = None
  let diagnostics = []
  let mut work = 0
  let mut node_count = 0
  let mut edge_count = 0
  let mut alignment_count = 0
  for statement in diagram.statements {
    work += 1
    match statement.kind {
      Group(id~, icon~, label~, parent~) => {
        node_count += 1
        work += id.length() +
          icon.map(v => v.length()).unwrap_or(0) +
          label.map(v => v.length()).unwrap_or(0) +
          parent.map(v => v.length()).unwrap_or(0)
      }
      Service(id~, icon~, icon_text~, label~, parent~) => {
        node_count += 1
        work += id.length() +
          icon.map(v => v.length()).unwrap_or(0) +
          icon_text.map(v => v.length()).unwrap_or(0) +
          label.map(v => v.length()).unwrap_or(0) +
          parent.map(v => v.length()).unwrap_or(0)
      }
      Junction(id~, parent~) => {
        node_count += 1
        work += id.length() + parent.map(v => v.length()).unwrap_or(0)
      }
      Edge(source~, target~, label~, ..) => {
        edge_count += 1
        work += source.id.length() +
          target.id.length() +
          label.map(v => v.length()).unwrap_or(0)
      }
      Alignment(members~, ..) => {
        alignment_count += 1
        work += members.length()
        for name in members {
          work += name.length()
          if work > limits.work {
            break
          }
        }
      }
      Title(v) | AccTitle(v) | AccDescription(v) | Comment(v) =>
        work += v.length()
    }
    let code = if work > limits.work {
      Some("work-limit")
    } else if node_count > limits.nodes {
      Some("node-limit")
    } else if edge_count > limits.edges {
      Some("edge-limit")
    } else if alignment_count > limits.alignments {
      Some("alignment-limit")
    } else {
      None
    }
    if code is Some(code) {
      return {
        architecture: None,
        diagnostics: [
          @diagrams.Diagnostic::error(
            "architecture/" + code,
            "Conversion budget exhausted",
            span=statement.span,
          ),
        ],
      }
    }
  }
  for statement in diagram.statements {
    match statement.kind {
      Group(id~, ..) | Service(id~, ..) | Junction(id~, ..) =>
        spans[id] = statement.span
      Edge(..) => spans["edge-\{connections.length()}"] = statement.span
      Alignment(members~, ..) =>
        for name in members {
          alignment_spans[name] = statement.span
        }
      _ => ()
    }
    match statement.kind {
      Group(id~, icon~, label~, parent~) => {
        let icon = icon.map(key => @icons.Reference::new("architecture", key))
        groups.push(@model.Group::new(id, label?, parent?, icon?))
      }
      Service(id~, icon~, icon_text~, label~, parent~) => {
        let icon = icon.map(key => @icons.Reference::new("architecture", key))
        services.push(
          @model.Service::new(id, label?, parent?, icon?, icon_text?),
        )
      }
      Junction(id~, parent~) =>
        junctions.push(@model.Junction::new(id, parent?))
      Edge(source~, target~, label~, source_head~, target_head~) =>
        connections.push(
          @model.Connection::new(
            "edge-\{connections.length()}",
            source,
            target,
            label?,
            source_head~,
            target_head~,
          ),
        )
      Alignment(axis~, members~) =>
        alignments.push(
          @model.Alignment::new(axis, members.iter().to_array()[:]),
        )
      Title(v) => title = Some(v)
      AccTitle(v) => accessibility_title = Some(v)
      AccDescription(v) => accessibility_description = Some(v)
      Comment(_) => ()
    }
  }
  let model = @model.Architecture::new(
    id,
    services[:],
    connections[:],
    groups=groups[:],
    junctions=junctions[:],
    alignments=alignments[:],
    title?,
    accessibility_title?,
    accessibility_description?,
  )
  let declared_groups : Map[String, Bool] = Map([])
  for statement in diagram.statements {
    match statement.kind {
      Group(id~, parent~, ..) => {
        if parent is Some(parent) && !declared_groups.contains(parent) {
          diagnostics.push(
            @diagrams.Diagnostic::error(
              "architecture/invalid-parent",
              "Group parent must be declared before child: " + parent,
              span=statement.span,
            ),
          )
        }
        declared_groups[id] = true
      }
      _ => ()
    }
  }
  let parents : Map[String, String?] = Map([])
  for service in services {
    parents[service.id] = service.parent
  }
  for junction in junctions {
    parents[junction.id] = junction.parent
  }
  for statement in diagram.statements {
    if statement.kind is Edge(source~, target~, ..) &&
      (source.group || target.group) {
      let a = parents.get(source.id).unwrap_or(None)
      let b = parents.get(target.id).unwrap_or(None)
      if a != None && a == b {
        diagnostics.push(
          @diagrams.Diagnostic::error(
            "architecture/invalid-group-attachment",
            "Group-boundary connection must cross groups",
            span=statement.span,
          ),
        )
      }
    }
  }
  for
    finding in @model.validate(
      model,
      nodes_limit=limits.nodes,
      edges_limit=limits.edges,
      depth_limit=limits.depth,
      work_limit=limits.work,
    ) {
    let key = match finding.message.rev_find(" ") {
      Some(i) => finding.message[i + 1:].to_owned()
      None => finding.message
    }
    let span = if finding.code == "architecture/invalid-alignment" {
      alignment_spans.get(key)
    } else {
      spans.get(key)
    }
    diagnostics.push({ ..finding, span, })
  }
  if diagram.front_matter != None || !diagram.directives.is_empty() {
    diagnostics.push(
      @diagrams.Diagnostic::warning(
        "architecture/metadata-option", "Source metadata is retained; layout follows caller options",
      ),
    )
  }
  if diagnostics.length() > limits.diagnostics.max(1) {
    diagnostics.truncate(limits.diagnostics.max(1))
    diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
      "architecture/diagnostic-limit", "Conversion diagnostic budget exhausted",
    )
  }
  {
    architecture: if diagnostics.iter().any(d => d.severity == Error) {
      None
    } else {
      Some(model)
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
  }
}
