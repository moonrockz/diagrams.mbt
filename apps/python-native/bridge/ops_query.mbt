///|
/// Query schema, compilation, execution and projection operations. They call
/// the public `moonrockz/diagrams-query` compiler and evaluator; the boundary
/// only converts records.
///
/// Records:
/// - diagnostic: `(code, severity, message, span)`; span is
///   `((offset, line, column), (offset, line, column))` or `None`.
/// - compile result: `("ok", plan_token, normalized, language_version,
///   schema_id, schema_version, pattern_count, capture_names)` or
///   `("error", diagnostics)`.
/// - form: `(rules...)`; rule `(pattern, predicates)`; pattern
///   `("node", selector, parts, captures)` or `("alt", branches, captures)`;
///   selector `("kind", prefix | None, local)`, `("category", name)` or
///   `("any",)`; part `("child", pattern)`, `("field", prefix | None, local,
///   pattern)` or `("absent", prefix | None, local)`; predicate
///   `(name, capture, operands)`.
/// - batch: `("rows", matches)`, `("complete",)`, `("stopped",)` or
///   `("failed", failure)`; match `(pattern, captures)`; capture
///   `(name, node_record, values)`; failure `("limit", "work" | "pending" |
///   "results" | "output")`, `("incompatible-schema", expected, actual)`,
///   `("invalid-root",)` or `("invalid-limits",)`.
/// - value: `("absent",)`, `("text", s)`, `("scalar", tag, text)`,
///   `("name", uri, local)`, `("int", n)`, `("location", source_id,
///   (offset, line, column), (offset, line, column))` or `("path", steps)` with
///   steps `(uri, local, index, position)`.
fn query_op(op : String, args : ArrayView[Rec]) -> Rec? raise BridgeError {
  let value = match op {
    "query_schema" => schema_record(@query_bpmn.schema)
    "query_parse" =>
      match @query.parse(arg_str(args, 0), limits=compile_limits(args, 1)) {
        Ok(form) => Rec::list([Str("ok"), form_record(form)])
        Err(diagnostics) => Rec::list([Str("error"), diagnostics_record(diagnostics)])
      }
    "query_compile" =>
      compiled(
        @query.compile(
          arg_str(args, 0),
          @query_bpmn.schema,
          namespaces=namespace_bindings(args, 1),
          limits=compile_limits(args, 2),
        ),
      )
    "query_compile_form" =>
      compiled(
        @query.compile_form(
          form_of(args, 0),
          @query_bpmn.schema,
          namespaces=namespace_bindings(args, 1),
          limits=compile_limits(args, 2),
        ),
      )
    "query_plan_close" => Bool(plans.remove(arg_int(args, 0)))
    "query_view_open" => {
      let tree = tree_of(arg_int(args, 0))
      Int(views.add(@query_bpmn.BpmnTree::new(tree)))
    }
    "query_view_close" => Bool(views.remove(arg_int(args, 0)))
    "query_execute" => execute(args)
    "query_next_batch" => {
      let cursor = cursors.get(arg_int(args, 0))
      batch_record(cursor, cursor.cursor.next_batch(arg_int32(args, 1)))
    }
    "query_stop" => {
      cursors.get(arg_int(args, 0)).cursor.stop()
      Null
    }
    "query_state" => state_record(cursors.get(arg_int(args, 0)).cursor.state())
    "query_close" => {
      let token = arg_int(args, 0)
      let closed = cursors.remove(token)
      Bool(closed)
    }
    _ => return None
  }
  Some(value)
}

///|
priv struct QueryCursorEntry {
  view : @query_bpmn.BpmnTree
  cursor : @query.QueryCursor[@query_bpmn.BpmnTree]
}

///|
let plans : Registry[@query.QueryPlan] = Registry::new(16)

///|
let cursors : Registry[QueryCursorEntry] = Registry::new(17)

///|
let views : Registry[@query_bpmn.BpmnTree] = Registry::new(18)

///|
/// Open query objects by registry name.
fn query_live() -> Array[(String, Int)] {
  [
    ("query_plan", plans.live()),
    ("query_cursor", cursors.live()),
    ("query_view", views.live()),
  ]
}

///|
fn schema_record(schema : @query.Schema) -> Rec {
  let names = (names : ReadOnlyArray[@query.Name]) => Rec::list(
    names.iter().map(n => Rec::list([Str(n.namespace_uri), Str(n.local_name)])).to_array(),
  )
  let strings = (items : ReadOnlyArray[String]) => Rec::list(
    items.iter().map(s => Rec::Str(s)).to_array(),
  )
  Rec::list([
    Str(schema.id),
    Rec::int(schema.version),
    Rec::int(@query.language_version),
    names(schema.kinds),
    strings(schema.categories),
    names(schema.fields),
    strings(schema.reserved_namespaces),
    Bool(schema.open_extensions),
    strings(schema.scalar_tags),
    strings(schema.extra_fields),
    Rec::list(
      @query_bpmn.default_namespaces
      .iter()
      .map(b => Rec::list([Str(b.0), Str(b.1)]))
      .to_array(),
    ),
    strings(@query.query_diagnostic_codes),
  ])
}

///|
fn namespace_bindings(
  args : ArrayView[Rec],
  index : Int,
) -> Array[(String, String)] raise BridgeError {
  let bindings = []
  for item in arg_list(args, index) {
    match item {
      List([Str(prefix), Str(uri)]) => bindings.push((prefix, uri))
      _ =>
        raise BridgeError(
          "invalid-argument", "A namespace binding must be a (prefix, uri) tuple of str.",
        )
    }
  }
  bindings
}

///|
fn limit_values(
  args : ArrayView[Rec],
  index : Int,
  count : Int,
) -> Array[Int]? raise BridgeError {
  match args.get(index) {
    None | Some(Null) => None
    Some(List(items)) if items.length() == count => {
      let values = []
      for i in 0..<count {
        values.push(arg_int32(items[:], i))
      }
      Some(values)
    }
    _ =>
      raise BridgeError(
        "invalid-argument", "Limits must be None or a tuple of \{count} ints.",
      )
  }
}

///|
fn compile_limits(
  args : ArrayView[Rec],
  index : Int,
) -> @query.CompileLimits raise BridgeError {
  match limit_values(args, index, 6) {
    None => @query.CompileLimits::new()
    Some(v) =>
      @query.CompileLimits::new(
        source_units=v[0],
        patterns=v[1],
        pattern_nodes=v[2],
        nesting=v[3],
        captures=v[4],
        predicates=v[5],
      )
  }
}

///|
fn execution_limits(
  args : ArrayView[Rec],
  index : Int,
) -> @query.ExecutionLimits raise BridgeError {
  match limit_values(args, index, 4) {
    None => @query.ExecutionLimits::new()
    Some(v) =>
      @query.ExecutionLimits::new(
        work=v[0],
        pending=v[1],
        results=v[2],
        output_units=v[3],
      )
  }
}

///|
fn position_rec(p : @query.QueryPosition) -> Rec {
  Rec::list([Rec::int(p.offset), Rec::int(p.line), Rec::int(p.column)])
}

///|
fn diagnostics_record(diagnostics : ReadOnlyArray[@query.QueryDiagnostic]) -> Rec {
  Rec::list(
    diagnostics
    .iter()
    .map(d => Rec::list([
      Str(d.code),
      Str(
        match d.severity {
          Error => "error"
          Warning => "warning"
        },
      ),
      Str(d.message),
      match d.span {
        Some(span) => Rec::list([position_rec(span.start), position_rec(span.end)])
        None => Null
      },
    ]))
    .to_array(),
  )
}

///|
fn compiled(
  result : Result[@query.QueryPlan, ReadOnlyArray[@query.QueryDiagnostic]],
) -> Rec raise BridgeError {
  match result {
    Ok(plan) =>
      Rec::list([
        Str("ok"),
        Int(plans.add(plan)),
        Str(plan.normalized()),
        Rec::int(plan.language_version),
        Str(plan.schema_id),
        Rec::int(plan.schema_version),
        Rec::int(plan.pattern_count),
        Rec::list(plan.capture_names.iter().map(n => Rec::Str(n)).to_array()),
      ])
    Err(diagnostics) => Rec::list([Str("error"), diagnostics_record(diagnostics)])
  }
}

///|
fn qname_rec(name : @query.QName) -> Array[Rec] {
  [Rec::str_opt(name.prefix), Str(name.local_name)]
}

///|
fn pattern_record(pattern : @query.Pattern) -> Rec {
  match pattern {
    Node(selector, parts, captures) => {
      let sel = match selector {
        Kind(name) => {
          let items = [Rec::Str("kind")]
          items.append(qname_rec(name))
          Rec::list(items)
        }
        Category(name) => Rec::list([Str("category"), Str(name)])
        Wildcard => Rec::list([Str("any")])
      }
      let part_records = parts.map(part => match part {
        Child(p) => Rec::list([Str("child"), pattern_record(p)])
        Field(name, p) => {
          let items = [Rec::Str("field")]
          items.append(qname_rec(name))
          items.push(pattern_record(p))
          Rec::list(items)
        }
        Absent(name) => {
          let items = [Rec::Str("absent")]
          items.append(qname_rec(name))
          Rec::list(items)
        }
      })
      Rec::list([
        Str("node"),
        sel,
        List(part_records),
        Rec::list(captures.iter().map(c => Rec::Str(c)).to_array()),
      ])
    }
    Alternation(branches, captures) =>
      Rec::list([
        Str("alt"),
        List(branches.map(pattern_record)),
        Rec::list(captures.iter().map(c => Rec::Str(c)).to_array()),
      ])
  }
}

///|
fn form_record(form : @query.QueryForm) -> Rec {
  Rec::list(
    form.rules
    .iter()
    .map(rule => Rec::list([
      pattern_record(rule.pattern),
      Rec::list(
        rule.predicates
        .iter()
        .map(p => Rec::list([
          Str(p.name),
          Str(p.capture),
          Rec::list(p.operands.iter().map(o => Rec::Str(o)).to_array()),
        ]))
        .to_array(),
      ),
    ]))
    .to_array(),
  )
}

///|
fn strings_of(value : Rec, what : String) -> Array[String] raise BridgeError {
  guard value is List(items) else {
    raise BridgeError("invalid-argument", "\{what} must be a tuple of str.")
  }
  let strings = []
  for item in items {
    guard item is Str(text) else {
      raise BridgeError("invalid-argument", "\{what} must be a tuple of str.")
    }
    strings.push(text)
  }
  strings
}

///|
fn qname_of(prefix : Rec, local_name : Rec) -> @query.QName raise BridgeError {
  match (prefix, local_name) {
    (Null, Str(name)) => @query.QName::new(name)
    (Str(p), Str(name)) => @query.QName::new(name, prefix=p)
    _ =>
      raise BridgeError(
        "invalid-argument", "A name must be (prefix or None, local name).",
      )
  }
}

///|
/// Decodes a pattern record. Nesting is bounded by the record depth limit.
fn pattern_of(value : Rec) -> @query.Pattern raise BridgeError {
  match value {
    List([Str("node"), selector, List(parts), captures]) => {
      let sel : @query.Selector = match selector {
        List([Str("kind"), prefix, name]) => Kind(qname_of(prefix, name))
        List([Str("category"), Str(name)]) => Category(name)
        List([Str("any")]) => Wildcard
        _ => raise BridgeError("invalid-argument", "Unknown selector record.")
      }
      let decoded : Array[@query.Part] = []
      for part in parts {
        let p : @query.Part = match part {
          List([Str("child"), pattern]) => Child(pattern_of(pattern))
          List([Str("field"), prefix, name, pattern]) =>
            Field(qname_of(prefix, name), pattern_of(pattern))
          List([Str("absent"), prefix, name]) => Absent(qname_of(prefix, name))
          _ => raise BridgeError("invalid-argument", "Unknown part record.")
        }
        decoded.push(p)
      }
      @query.Pattern::node(
        sel,
        parts=decoded,
        captures=strings_of(captures, "Captures"),
      )
    }
    List([Str("alt"), List(branches), captures]) => {
      let decoded = []
      for branch in branches {
        decoded.push(pattern_of(branch))
      }
      @query.Pattern::alternation(decoded, captures=strings_of(captures, "Captures"))
    }
    _ => raise BridgeError("invalid-argument", "Unknown pattern record.")
  }
}

///|
fn form_of(args : ArrayView[Rec], index : Int) -> @query.QueryForm raise BridgeError {
  let rules = []
  for rule in arg_list(args, index) {
    match rule {
      List([pattern, List(predicates)]) => {
        let decoded = []
        for predicate in predicates {
          match predicate {
            List([Str(name), Str(capture), operands]) =>
              decoded.push(
                @query.Predicate::new(
                  name,
                  capture,
                  operands=strings_of(operands, "Operands"),
                ),
              )
            _ => raise BridgeError("invalid-argument", "Unknown predicate record.")
          }
        }
        rules.push(@query.Rule::new(pattern_of(pattern), predicates=decoded))
      }
      _ => raise BridgeError("invalid-argument", "Unknown rule record.")
    }
  }
  @query.QueryForm::new(rules)
}

///|
/// `query_execute(plan, view, root_ordinal | None, fields, namespaces,
/// limits | None)` returns `("ok", cursor_token)` or `("error",
/// diagnostics)` for an invalid projection.
fn execute(args : ArrayView[Rec]) -> Rec raise BridgeError {
  let plan = plans.get(arg_int(args, 0))
  let view = views.get(arg_int(args, 1))
  let root = match args.get(2) {
    Some(Int(ordinal)) => Some(ordinal.to_int())
    Some(Null) | None => None
    _ => raise BridgeError("invalid-argument", "Argument 2 must be an int or None.")
  }
  let fields = strings_of(args.get(3).unwrap_or(List([])), "Fields")
  let projection = @query.Projection::new(
    @query_bpmn.schema,
    fields.map(@query.FieldRequest::parse),
    namespaces=namespace_bindings(args, 4),
  )
  match projection {
    Err(diagnostics) => Rec::list([Str("error"), diagnostics_record(diagnostics)])
    Ok(projection) => {
      let cursor = plan.execute(
        view,
        root?,
        projection~,
        limits=execution_limits(args, 5),
      )
      Rec::list([Str("ok"), Int(cursors.add({ view, cursor }))])
    }
  }
}

///|
fn failure_record(failure : @query.QueryFailure) -> Rec {
  match failure {
    Limit(limit) =>
      Rec::list([
        Str("limit"),
        Str(
          match limit {
            Work => "work"
            Pending => "pending"
            Results => "results"
            Output => "output"
          },
        ),
      ])
    IncompatibleSchema(expected~, actual~) =>
      Rec::list([Str("incompatible-schema"), Str(expected), Str(actual)])
    InvalidRoot => Rec::list([Str("invalid-root")])
    InvalidLimits => Rec::list([Str("invalid-limits")])
  }
}

///|
fn state_record(state : @query.CursorState) -> Rec {
  match state {
    Running => Rec::list([Str("running")])
    Complete => Rec::list([Str("complete")])
    Stopped => Rec::list([Str("stopped")])
    Failed(failure) => Rec::list([Str("failed"), failure_record(failure)])
  }
}

///|
fn value_record(value : @query.Projected) -> Rec {
  match value {
    Absent => Rec::list([Str("absent")])
    Text(text) => Rec::list([Str("text"), Str(text)])
    Scalar(scalar) => Rec::list([Str("scalar"), Str(scalar.tag), Str(scalar.text)])
    Name(name) => Rec::list([Str("name"), Str(name.namespace_uri), Str(name.local_name)])
    Int(n) => Rec::list([Str("int"), Rec::int(n)])
    Location(location) =>
      Rec::list([
        Str("location"),
        Rec::str_opt(location.source_id),
        position_rec(location.start),
        position_rec(location.end),
      ])
    Path(steps) =>
      Rec::list([
        Str("path"),
        List(
          steps.map(step => Rec::list([
            Str(step.field.namespace_uri),
            Str(step.field.local_name),
            Rec::int(step.index),
            Rec::int(step.position),
          ])),
        ),
      ])
  }
}

///|
fn batch_record(entry : QueryCursorEntry, batch : @query.QueryBatch) -> Rec {
  match batch {
    Rows(rows) =>
      Rec::list([
        Str("rows"),
        List(
          rows.map(row => Rec::list([
            Rec::int(row.pattern),
            List(
              row.captures.map(c => Rec::list([
                Str(c.name),
                node_record(entry.view.captured(c)),
                List(c.values.map(value_record)),
              ])),
            ),
          ])),
        ),
      ])
    Complete => Rec::list([Str("complete")])
    Stopped => Rec::list([Str("stopped")])
    Failed(failure) => Rec::list([Str("failed"), failure_record(failure)])
  }
}
