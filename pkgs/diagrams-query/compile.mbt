///|
priv enum CSel {
  CKind(Name)
  CCategory(String)
  CAny
}

///|
priv enum CPart {
  CChild(Int)
  CField(Name, Int)
  CAbsent(Name)
}

///|
/// A compiled pattern node. An alternation has branches and no selector.
priv struct CNode {
  alternation : Bool
  sel : CSel
  parts : Array[CPart]
  branches : Array[Int]
  sites : Array[Int]
}

///|
priv enum CPredKind {
  HasAttr
  MissingAttr
  AttrEq
  AttrNotEq
  AttrIn
  TextEq
}

///|
priv struct CPred {
  kind : CPredKind
  capture : String
  attribute : Name
  values : Array[String]
}

///|
priv struct CRule {
  root : Int
  predicates : Array[CPred]
}

///|
/// A checked, immutable and reusable query plan for one adapter schema.
///
/// `capture_names` lists the capture sites in source order; a match reports
/// each bound site with its name. `normalized()` is the public normalized
/// representation: equal plans have equal normalized text.
pub struct QueryPlan {
  language_version : Int
  schema_id : String
  schema_version : Int
  pattern_count : Int
  capture_names : ReadOnlyArray[String]
  priv rules : ReadOnlyArray[CRule]
  priv nodes : ReadOnlyArray[CNode]
  priv text : String
}

///|
pub impl @debug.Debug for QueryPlan with to_repr(self) {
  @debug.Repr::Repr(("QueryPlan", self.schema_id, self.text))
}

///|
pub extend QueryPlan with @debug.Debug::{to_repr}

///|
pub fn QueryPlan::normalized(self : QueryPlan) -> String {
  self.text
}

///|
priv suberror CheckStop

///|
priv struct Checker {
  schema : Schema
  namespaces : Map[String, String]
  limits : CompileLimits
  spans : ReadOnlyArray[QuerySpan]
  diagnostics : Array[QueryDiagnostic]
  nodes : Array[CNode]
  site_names : Array[String]
  site_paths : Array[Array[(Int, Int)]]
  text : StringBuilder
  mut span_at : Int
  mut predicates : Int
}

///|
fn Checker::next_span(self : Checker) -> QuerySpan? {
  let i = self.span_at
  self.span_at += 1
  self.spans.get(i)
}

///|
fn Checker::report(
  self : Checker,
  code : String,
  message : String,
  span : QuerySpan?,
) -> Unit {
  self.diagnostics.push(error(code, message, span))
}

///|
fn Checker::stop(
  self : Checker,
  code : String,
  message : String,
  span : QuerySpan?,
) -> CheckStop {
  self.report(code, message, span)
  CheckStop
}

///|
fn Checker::resolve(
  self : Checker,
  name : QName,
  span : QuerySpan?,
) -> Name? {
  if (name.prefix is Some(prefix) && !is_identifier(prefix)) ||
    !is_identifier(name.local_name) {
    self.report("query/invalid-name", "\{name.local_name} is not a valid name.", span)
    return None
  }
  match name.prefix {
    None => Some(Name::new("", name.local_name))
    Some(prefix) =>
      match self.namespaces.get(prefix) {
        Some(uri) => Some(Name::new(uri, name.local_name))
        None => {
          self.report(
            "query/unbound-prefix",
            "The prefix \{prefix} has no namespace binding.",
            span,
          )
          None
        }
      }
  }
}

///|
fn write_name(text : StringBuilder, name : Name) -> Unit {
  if name.namespace_uri != "" {
    text.write_string("{")
    text.write_string(name.namespace_uri)
    text.write_string("}")
  }
  text.write_string(name.local_name)
}

///|
fn write_json_string(text : StringBuilder, value : String) -> Unit {
  text.write_char('"')
  for c in value {
    match c {
      '"' => text.write_string("\\\"")
      '\\' => text.write_string("\\\\")
      '\n' => text.write_string("\\n")
      '\r' => text.write_string("\\r")
      '\t' => text.write_string("\\t")
      _ =>
        if c.to_int() < 0x20 {
          let hex = "0123456789abcdef"
          text.write_string("\\u00")
          text.write_char(hex.get_char(c.to_int() / 16).unwrap())
          text.write_char(hex.get_char(c.to_int() % 16).unwrap())
        } else {
          text.write_char(c)
        }
    }
  }
  text.write_char('"')
}

///|
fn Checker::captures(
  self : Checker,
  captures : ReadOnlyArray[String],
  path : Array[(Int, Int)],
) -> Array[Int] raise CheckStop {
  let sites = []
  for name in captures {
    let span = self.next_span()
    if !is_capture_name(name) {
      self.report("query/invalid-name", "\{name} is not a valid capture name.", span)
    }
    if self.site_names.length() >= self.limits.captures {
      raise self.stop(
        "query/capture-limit", "The number of captures exceeds the compile limit.", span,
      )
    }
    sites.push(self.site_names.length())
    self.site_names.push(name)
    self.site_paths.push(path.copy())
    self.text.write_string(" @")
    self.text.write_string(name)
  }
  sites
}

///|
fn Checker::pattern(
  self : Checker,
  pattern : Pattern,
  depth : Int,
  path : Array[(Int, Int)],
) -> Int raise CheckStop {
  let span = self.next_span()
  if depth > self.limits.nesting {
    raise self.stop(
      "query/nesting-limit", "The pattern nesting exceeds the compile limit.", span,
    )
  }
  if self.nodes.length() >= self.limits.pattern_nodes {
    raise self.stop(
      "query/pattern-limit", "The number of patterns exceeds the compile limit.", span,
    )
  }
  let id = self.nodes.length()
  self.nodes.push({ alternation: false, sel: CAny, parts: [], branches: [], sites: [] })
  match pattern {
    Node(selector, parts, captures) => {
      let selector_span = self.next_span()
      self.text.write_string("(")
      let sel = match selector {
        Wildcard => {
          self.text.write_string("_")
          CAny
        }
        Category(category) => {
          if !self.schema.has_category(category) {
            self.report(
              "query/unknown-category",
              "The schema has no category \{category}.",
              selector_span,
            )
          }
          self.text.write_string("category.")
          self.text.write_string(category)
          CCategory(category)
        }
        Kind(qname) =>
          match self.resolve(qname, selector_span) {
            Some(name) => {
              if !self.schema.admits_kind(name) {
                self.report(
                  "query/unknown-kind",
                  "The schema has no kind \{name.clark()}.",
                  selector_span,
                )
              }
              write_name(self.text, name)
              CKind(name)
            }
            None => CAny
          }
      }
      let compiled : Array[CPart] = []
      for part in parts {
        self.text.write_string(" ")
        match part {
          Child(child) => compiled.push(CChild(self.pattern(child, depth + 1, path)))
          Field(qname, child) => {
            let field = self.field(qname, self.next_span())
            self.text.write_string(": ")
            compiled.push(CField(field, self.pattern(child, depth + 1, path)))
          }
          Absent(qname) => {
            self.text.write_string("!")
            compiled.push(CAbsent(self.field(qname, self.next_span())))
          }
        }
      }
      self.text.write_string(")")
      let sites = self.captures(captures, path)
      self.nodes[id] = { alternation: false, sel, parts: compiled, branches: [], sites }
    }
    Alternation(branches, captures) => {
      if branches.is_empty() {
        self.report("query/syntax", "An alternation needs at least one pattern.", span)
      }
      self.text.write_string("[")
      let compiled = []
      for i, branch in branches {
        if i > 0 {
          self.text.write_string(" ")
        }
        path.push((id, i))
        compiled.push(self.pattern(branch, depth + 1, path))
        path.pop() |> ignore
      }
      self.text.write_string("]")
      let sites = self.captures(captures, path)
      self.nodes[id] = { alternation: true, sel: CAny, parts: [], branches: compiled, sites }
    }
  }
  id
}

///|
fn Checker::field(self : Checker, qname : QName, span : QuerySpan?) -> Name {
  match self.resolve(qname, span) {
    Some(name) => {
      if !self.schema.admits_field(name) {
        self.report(
          "query/unknown-field",
          "The schema has no field \{name.clark()}.",
          span,
        )
      }
      write_name(self.text, name)
      name
    }
    None => Name::new("", qname.local_name)
  }
}

///|
/// True when the capture sites `a` and `b` lie in different branches of one
/// alternation, so no successful match binds both.
fn exclusive(a : Array[(Int, Int)], b : Array[(Int, Int)]) -> Bool {
  let mut i = 0
  while i < a.length() && i < b.length() && a[i].0 == b[i].0 {
    if a[i].1 != b[i].1 {
      return true
    }
    i += 1
  }
  false
}

///|
fn Checker::attribute(
  self : Checker,
  operand : String,
  span : QuerySpan?,
) -> Name {
  match operand.find(":") {
    None => {
      if operand == "" {
        self.report("query/invalid-name", "An attribute name cannot be empty.", span)
      }
      Name::new("", operand)
    }
    Some(colon) => {
      let prefix = operand.view(end_offset=colon).to_owned()
      let local_name = operand.view(start_offset=colon + 1).to_owned()
      if local_name == "" || local_name.contains(":") {
        self.report("query/invalid-name", "\{operand} is not a valid attribute name.", span)
        return Name::new("", operand)
      }
      match self.namespaces.get(prefix) {
        Some(uri) => Name::new(uri, local_name)
        None => {
          self.report(
            "query/unbound-prefix",
            "The prefix \{prefix} has no namespace binding.",
            span,
          )
          Name::new("", local_name)
        }
      }
    }
  }
}

///|
fn Checker::predicate(
  self : Checker,
  predicate : Predicate,
  first_site : Int,
) -> CPred? raise CheckStop {
  let span = self.next_span()
  self.predicates += 1 + predicate.operands.length()
  if self.predicates > self.limits.predicates {
    raise self.stop(
      "query/pattern-limit", "The number of predicates exceeds the compile limit.", span,
    )
  }
  if unsupported_predicate(predicate.name) is Some((code, message)) {
    self.report(code, message, span)
    return None
  }
  let (kind, arity_ok) = match predicate.name {
    "has-attr?" => (Some(HasAttr), predicate.operands.length() == 1)
    "missing-attr?" => (Some(MissingAttr), predicate.operands.length() == 1)
    "attr-eq?" => (Some(AttrEq), predicate.operands.length() == 2)
    "attr-not-eq?" => (Some(AttrNotEq), predicate.operands.length() == 2)
    "attr-in?" => (Some(AttrIn), predicate.operands.length() >= 2)
    "text-eq?" => (Some(TextEq), predicate.operands.length() == 1)
    _ => (None, false)
  }
  guard kind is Some(kind) else {
    self.report(
      "query/unknown-predicate",
      "#\{predicate.name} is not a version 1 predicate.",
      span,
    )
    return None
  }
  if !arity_ok {
    self.report(
      "query/predicate-arity",
      "#\{predicate.name} has the wrong number of operands.",
      span,
    )
    return None
  }
  let mut known = false
  for i in first_site..<self.site_names.length() {
    if self.site_names[i] == predicate.capture {
      known = true
    }
  }
  if !known {
    self.report(
      "query/unknown-capture",
      "@\{predicate.capture} is not a capture of this pattern.",
      span,
    )
    return None
  }
  self.text.write_string(" (#")
  self.text.write_string(predicate.name)
  self.text.write_string(" @")
  self.text.write_string(predicate.capture)
  for operand in predicate.operands {
    self.text.write_string(" ")
    write_json_string(self.text, operand)
  }
  self.text.write_string(")")
  match kind {
    TextEq =>
      Some({
        kind,
        capture: predicate.capture,
        attribute: Name::new("", ""),
        values: [predicate.operands[0]],
      })
    _ =>
      Some({
        kind,
        capture: predicate.capture,
        attribute: self.attribute(predicate.operands[0], span),
        values: predicate.operands.iter().drop(1).collect(),
      })
  }
}

///|
/// Checks a typed query form against `schema` and returns its plan. Query
/// text uses the same checks through `compile`.
pub fn compile_form(
  form : QueryForm,
  schema : Schema,
  namespaces? : ArrayView[(String, String)] = [],
  limits? : CompileLimits = CompileLimits::new(),
) -> Result[QueryPlan, ReadOnlyArray[QueryDiagnostic]] {
  if !limits.valid() {
    return Err([invalid_limits()])
  }
  let bindings : Map[String, String] = Map([])
  for binding in namespaces {
    let (prefix, uri) = binding
    if !is_identifier(prefix) ||
      prefix == "category" ||
      uri == "" ||
      bindings.contains(prefix) {
      return Err([
        error(
          "query/invalid-namespace-map",
          "The namespace binding \{prefix} is invalid: prefixes are unique identifiers other than category, and URIs are not empty.",
          None,
        ),
      ])
    }
    bindings[prefix] = uri
  }
  let checker = Checker::{
    schema,
    namespaces: bindings,
    limits,
    spans: form.spans,
    diagnostics: [],
    nodes: [],
    site_names: [],
    site_paths: [],
    text: StringBuilder(),
    span_at: 0,
    predicates: 0,
  }
  let rules : Array[CRule] = []
  let stopped = try {
    if form.rules.is_empty() {
      raise checker.stop("query/empty-query", "The query has no pattern.", None)
    }
    for rule in form.rules {
      let span = checker.next_span()
      if rules.length() >= limits.patterns {
        raise checker.stop(
          "query/pattern-limit", "The number of patterns exceeds the compile limit.", span,
        )
      }
      if rules.length() > 0 {
        checker.text.write_string("\n")
      }
      let grouped = !rule.predicates.is_empty()
      if grouped {
        checker.text.write_string("(")
      }
      let first_site = checker.site_names.length()
      let root = checker.pattern(rule.pattern, 1, [])
      for a in first_site..<checker.site_names.length() {
        for b in (a + 1)..<checker.site_names.length() {
          if checker.site_names[a] == checker.site_names[b] &&
            !exclusive(checker.site_paths[a], checker.site_paths[b]) {
            checker.report(
              "query/duplicate-capture",
              "@\{checker.site_names[b]} is captured twice in one alternative.",
              span,
            )
          }
        }
      }
      let predicates = []
      for predicate in rule.predicates {
        if checker.predicate(predicate, first_site) is Some(compiled) {
          predicates.push(compiled)
        }
      }
      if grouped {
        checker.text.write_string(")")
      }
      rules.push({ root, predicates })
    }
    false
  } catch {
    CheckStop => true
  }
  if stopped || !checker.diagnostics.is_empty() {
    return Err(ReadOnlyArray::from_array(checker.diagnostics))
  }
  Ok({
    language_version,
    schema_id: schema.id,
    schema_version: schema.version,
    pattern_count: rules.length(),
    capture_names: ReadOnlyArray::from_array(checker.site_names),
    rules: ReadOnlyArray::from_array(rules),
    nodes: ReadOnlyArray::from_array(checker.nodes),
    text: checker.text.to_string(),
  })
}

///|
/// Parses and checks version 1 query text against `schema`.
pub fn compile(
  source : String,
  schema : Schema,
  namespaces? : ArrayView[(String, String)] = [],
  limits? : CompileLimits = CompileLimits::new(),
) -> Result[QueryPlan, ReadOnlyArray[QueryDiagnostic]] {
  match parse(source, limits~) {
    Ok(form) => compile_form(form, schema, namespaces~, limits~)
    Err(diagnostics) => Err(diagnostics)
  }
}
