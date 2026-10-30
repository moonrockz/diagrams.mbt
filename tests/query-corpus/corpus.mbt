///|
/// The shared normalized query corpus. `run_corpus` executes every case of
/// `fixtures/cases.txt` and returns the normalized text that
/// `fixtures/expected.txt` holds. The Python runner in
/// `apps/python-native/python/tests/test_query_corpus.py` writes the same text
/// through the Python API. Each case runs with batch sizes 1, 64 and 256,
/// which must agree.
priv struct Case {
  name : String
  document : String
  namespaces : Array[(String, String)]
  fields : Array[String]
  limits : Array[Int]?
  root_id : String?
  query : String
}

///|
fn parse_cases(text : String) -> Array[Case] raise Failure {
  let cases = []
  let lines = text.split("\n").map(l => l.to_owned()).to_array()
  let mut i = 0
  while i < lines.length() {
    let line = lines[i]
    if !line.has_prefix("=== ") {
      i += 1
      continue
    }
    let name = line.view(start_offset=4).to_owned()
    i += 1
    let mut document = ""
    let namespaces = []
    let mut fields = []
    let mut limits = None
    let mut root_id = None
    let mut query = ""
    while i < lines.length() && !lines[i].has_prefix("=== ") {
      let current = lines[i]
      i += 1
      guard current.find(": ") is Some(_) || current == "query:" else {
        fail("bad line in \{name}: \{current}")
      }
      if current == "query:" {
        let body = []
        while i < lines.length() && !lines[i].has_prefix("=== ") {
          body.push(lines[i])
          i += 1
        }
        while body.last() is Some("") {
          body.pop() |> ignore
        }
        query = body.join("\n")
        break
      }
      let colon = current.find(": ").unwrap()
      let key = current.view(end_offset=colon).to_owned()
      let value = current.view(start_offset=colon + 2).to_owned()
      match key {
        "document" => document = value
        "namespaces" => {
          let parts = value.split(" ").map(p => p.to_owned()).to_array()
          namespaces.push((parts[0], parts[1]))
        }
        "fields" => fields = value.split(" ").map(p => p.to_owned()).to_array()
        "limits" =>
        {
          let values = []
          for p in value.split(" ") {
            values.push(@string.parse_int(p) catch { _ => fail("bad limit in \{name}") })
          }
          limits = Some(values)
        }
        "root-id" => root_id = Some(value)
        "query-json" => {
          let parsed = @json.parse(value) catch {
            _ => fail("query-json of \{name} is not JSON")
          }
          guard parsed is String(text) else {
            fail("query-json of \{name} is not a string")
          }
          query = text
        }
        _ => fail("unknown key \{key} in \{name}")
      }
    }
    cases.push({ name, document, namespaces, fields, limits, root_id, query })
  }
  cases
}

///|
/// The generated deep document: 10,000 nested vendor elements.
pub fn deep_document() -> String {
  "<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' xmlns:v='urn:v' targetNamespace='urn:deep'>" +
  "<v:n>".repeat(10000) +
  "<v:leaf/>" +
  "</v:n>".repeat(10000) +
  "</b:definitions>"
}

///|
/// A JSON-style quoted string with the escapes that the Python runner uses.
fn quote(text : String) -> String {
  let out = StringBuilder()
  out.write_char('"')
  for c in text {
    match c {
      '"' => out.write_string("\\\"")
      '\\' => out.write_string("\\\\")
      '\n' => out.write_string("\\n")
      '\r' => out.write_string("\\r")
      '\t' => out.write_string("\\t")
      _ =>
        if c.to_int() < 0x20 {
          let hex = "0123456789abcdef"
          out.write_string("\\u00")
          out.write_char(hex.get_char(c.to_int() / 16).unwrap())
          out.write_char(hex.get_char(c.to_int() % 16).unwrap())
        } else {
          out.write_char(c)
        }
    }
  }
  out.write_char('"')
  out.to_string()
}

///|
fn name_text(name : @query.Name) -> String {
  name.clark()
}

///|
fn position_text(p : @query.QueryPosition) -> String {
  "\{p.offset}:\{p.line}:\{p.column}"
}

///|
fn value_text(value : @query.Projected) -> String {
  match value {
    Absent => "-"
    Text(text) => quote(text)
    Scalar(scalar) => "\{scalar.tag}:\{quote(scalar.text)}"
    Name(name) => name_text(name)
    Int(n) => n.to_string()
    Location(location) => {
      let source = location.source_id.unwrap_or("-")
      "\{source}@\{position_text(location.start)}-\{position_text(location.end)}"
    }
    Path(steps) =>
      steps
      .iter()
      .map(step => "/\{name_text(step.field)}[\{step.index}@\{step.position}]")
      .join("")
  }
}

///|
fn diagnostic_text(d : @query.QueryDiagnostic) -> String {
  let span = match d.span {
    Some(s) =>
      "\{s.start.offset}-\{s.end.offset} \{s.start.line}:\{s.start.column}-\{s.end.line}:\{s.end.column}"
    None => "-"
  }
  "error \{d.code} \{span}"
}

///|
fn failure_text(failure : @query.QueryFailure) -> String {
  match failure {
    Limit(Work) => "failed limit work"
    Limit(Pending) => "failed limit pending"
    Limit(Results) => "failed limit results"
    Limit(Output) => "failed limit output"
    IncompatibleSchema(expected~, actual~) =>
      "failed incompatible-schema \{expected} \{actual}"
    InvalidRoot => "failed invalid-root"
    InvalidLimits => "failed invalid-limits"
  }
}

///|
fn run_batches(
  plan : @query.QueryPlan,
  tree : @query_bpmn.BpmnTree,
  root : Int?,
  projection : @query.Projection,
  limits : @query.ExecutionLimits,
  size : Int,
  document : String,
) -> Array[String] {
  let cursor = plan.execute(tree, root?, projection~, limits~)
  let lines = []
  while true {
    match cursor.next_batch(size) {
      Rows(rows) =>
        for row in rows {
          let captures = row.captures.map(c => {
            let values = c.values.iter().map(value_text).join(",")
            "\{c.name}=\{document}#\{c.node}{\{values}}"
          })
          lines.push("match \{row.pattern}: " + captures.iter().join(" "))
        }
      Complete => {
        lines.push("end complete")
        break
      }
      Stopped => {
        lines.push("end stopped")
        break
      }
      Failed(failure) => {
        lines.push("end " + failure_text(failure))
        break
      }
    }
  }
  lines
}

///|
fn run_case(case : Case, fixtures : Map[String, String]) -> Array[String] {
  let source = if case.document == "generated:deep" {
    deep_document()
  } else {
    fixtures.get(case.document).unwrap()
  }
  let limits = @bpmn.Limits::new(depth=20000)
  let document = @bpmn.read(source, source_id=case.document, limits~).document.unwrap()
  let tree = @query_bpmn.BpmnTree::new(
    @bpmn.DocumentTree::new(document, limits~).tree.unwrap(),
  )
  let lines = []
  let plan = match @query_bpmn.compile(case.query, namespaces=case.namespaces) {
    Ok(plan) => plan
    Err(diagnostics) => {
      for d in diagnostics {
        lines.push(diagnostic_text(d))
      }
      return lines
    }
  }
  lines.push("plan " + plan.normalized().replace_all(old="\n", new=" | "))
  let bindings = @query_bpmn.default_namespaces.iter().to_array()
  bindings.append(case.namespaces)
  let projection = match
    @query.Projection::new(
      @query_bpmn.schema,
      case.fields.map(@query.FieldRequest::parse),
      namespaces=bindings,
    ) {
    Ok(projection) => projection
    Err(diagnostics) => {
      for d in diagnostics {
        lines.push(diagnostic_text(d))
      }
      return lines
    }
  }
  let root = case.root_id.map(id => {
    let mut found = -1
    for i in 0..<tree.node_count() {
      if found < 0 && tree.node(i).unwrap().id() == Some(id) {
        found = i
      }
    }
    found
  })
  let limits = match case.limits {
    Some(v) =>
      @query.ExecutionLimits::new(
        work=v[0],
        pending=v[1],
        results=v[2],
        output_units=v[3],
      )
    None => @query.ExecutionLimits::new()
  }
  let one = run_batches(plan, tree, root, projection, limits, 1, case.document)
  let mid = run_batches(plan, tree, root, projection, limits, 64, case.document)
  let big = run_batches(plan, tree, root, projection, limits, 256, case.document)
  if one != mid || one != big {
    lines.push("batch-mismatch")
  }
  lines.append(one)
  lines
}

///|
/// Runs every case and returns the normalized corpus output.
pub fn run_corpus() -> String raise Failure {
  let fixtures : Map[String, String] = Map([])
  for f in documents {
    fixtures[f.0] = f.1
  }
  let out = StringBuilder()
  for case in parse_cases(cases_text) {
    out.write_string("=== \{case.name}\n")
    for line in run_case(case, fixtures) {
      out.write_string(line)
      out.write_char('\n')
    }
  }
  out.to_string()
}
