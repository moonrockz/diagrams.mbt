///|
/// A normalized semantic tree. Both the pinned PlantUML tiles and the
/// library models normalize to it, so the comparison ignores drawing order
/// quirks and keeps the structure.
priv enum Norm {
  Lit(String)
  Box(String)
  Ref(String)
  Term(String, String)
  Spec(String, String)
  Set(Bool, String)
  Seq(Array[Norm])
  Alt(Array[Norm])
  Opt(Norm)
  Star(Norm)
  Plus(Norm)
  Named(Norm)
  Look(Norm)
  Not(Norm)
  Empty
} derive(Eq, Debug)

///|
fn Norm::text(self : Norm) -> String {
  match self {
    Lit(s) => "'" + s + "'"
    Box(s) => "<" + s + ">"
    Ref(s) => s
    Term(s, n) => "\"" + s + "\"" + n
    Spec(s, n) => "?" + s + "?" + n
    Set(p, s) => (if p { "[" } else { "[^" }) + s + "]"
    Seq(xs) => "(" + xs.map(x => x.text()).join(" ") + ")"
    Alt(xs) => "(" + xs.map(x => x.text()).join(" | ") + ")"
    Opt(x) => "opt " + x.text()
    Star(x) => "star " + x.text()
    Plus(x) => "plus " + x.text()
    Named(x) => "named " + x.text()
    Look(x) => "look " + x.text()
    Not(x) => "not " + x.text()
    Empty => "empty"
  }
}

///|
fn seq(items : Array[Norm]) -> Norm {
  let flat : Array[Norm] = []
  for item in items {
    match item {
      Seq(inner) => for i in inner { flat.push(i) }
      _ => flat.push(item)
    }
  }
  let merged : Array[Norm] = []
  for item in flat {
    match (merged.last(), item) {
      (Some(Lit(a)), Lit(b)) => {
        ignore(merged.pop())
        merged.push(Lit(a + b))
      }
      _ => merged.push(item)
    }
  }
  if merged.length() == 1 {
    merged[0]
  } else {
    Seq(merged)
  }
}

///|
fn alt(items : Array[Norm]) -> Norm {
  let flat : Array[Norm] = []
  for item in items {
    match item {
      Alt(inner) => for i in inner { flat.push(i) }
      _ => flat.push(item)
    }
  }
  // PlantUML 1.2026.9 can reorder flattened alternatives; compare as a set.
  flat.sort_by((a, b) => a.text().compare(b.text()))
  Alt(flat)
}

///|
fn field(o : Map[String, Json], key : String) -> Json? {
  o.get(key)
}

///|
fn str(j : Json?) -> String {
  match j {
    Some(String(s)) => s
    _ => ""
  }
}

///|
fn letter_or_digit(c : Char) -> Bool {
  (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')
}

///|
fn notes(o : Map[String, Json]) -> String {
  let above = str(field(o, "commentAbove"))
  let below = str(field(o, "commentBelow"))
  if above.is_empty() && below.is_empty() {
    ""
  } else {
    "{" + above.trim().to_owned() + "|" + below.trim().to_owned() + "}"
  }
}

///|
fn upstream(j : Json, ebnf : Bool) -> Norm {
  guard j is Object(o) else { return Empty }
  let tiles = () => match field(o, "tiles") {
    Some(Array(xs)) => xs.map(x => upstream(x, ebnf))
    _ => []
  }
  let orig = () => upstream(field(o, "orig").unwrap_or(Json::null()), ebnf)
  match str(field(o, "tile")) {
    "ETileBox" => {
      let v = str(field(o, "value"))
      match str(field(o, "symbol")) {
        "TERMINAL_STRING1" | "TERMINAL_STRING2" =>
          if ebnf {
            Term(v, notes(o))
          } else {
            Lit(v)
          }
        "SPECIAL_SEQUENCE" => Spec(v, notes(o))
        _ =>
          if ebnf {
            Ref(v)
          } else if v.length() == 2 &&
            v.has_prefix("\\") &&
            !letter_or_digit(v.get_char(1).unwrap()) {
            Lit(v.get_char(1).unwrap().to_string())
          } else {
            Box(v)
          }
      }
    }
    "ETileRegexGroup" | "ETileRegexGroupAllBut" => {
      let key = if field(o, "elements2") is Some(_) { "elements2" } else { "elements" }
      let items = match field(o, key) {
        Some(Array(xs)) => xs.map(x => str(Some(x)))
        _ => []
      }
      Set(key == "elements", items.join(" "))
    }
    "ETileConcatenation" => seq(tiles())
    "ETileAlternation" => alt(tiles())
    "ETileZeroOrMore" =>
      match orig() {
        Plus(x) => Star(x)
        x => Star(x)
      }
    "ETileOneOrMore" => Plus(orig())
    "ETileOptional2" => Opt(orig())
    "ETileNamedGroup" => Named(orig())
    "ETileLookAheadOrBehind" => Look(orig())
    "ETileNot" => Not(orig())
    "ETileWithCircles" => orig()
    "ETileEmpty" => Empty
    other => abort("unknown tile " + other)
  }
}

///|
fn regex_norm(model : @regex.Regex) -> Norm {
  let index = @regex.Index::build(model).index.unwrap()
  fn go(id : String) -> Norm {
    let node = index.node(id).unwrap()
    match node.kind {
      Literal(t) => Lit(t)
      Class(_) | Anchor(_) | Backreference(_) =>
        Box(
          match node.kind {
            Class(Posix(name)) => ":" + name + ":"
            _ => node.label()
          },
        )
      Set(negated, items) =>
        Set(
          !negated,
          items
          .iter()
          .map(i => match i {
            Char(c) => c
            Range(a, b) => a + "-" + b
            Escape(e) => e
          })
          .collect()
          .join(" "),
        )
      Sequence(items) => seq(items.iter().map(go).collect())
      Choice(items) => alt(items.iter().map(go).collect())
      Group(Named(_), child) => Named(go(child))
      Group(_, child) => go(child)
      Assertion(_, _, child) => Look(go(child))
      Repeat(bounds, child) => {
        let x = go(child)
        match (bounds.min, bounds.max) {
          (0, None) | (0, Some(0)) => Star(x)
          (1, None) => Plus(x)
          (0, Some(1)) => Opt(x)
          (0, Some(_)) => Opt(Plus(x))
          _ => Plus(x)
        }
      }
    }
  }
  go(model.root)
}

///|
fn ebnf_norm(grammar : @ebnf.Grammar, index : @ebnf.Index, id : String) -> Norm {
  let node = index.node(id).unwrap()
  let n = if node.notes_above.is_empty() && node.notes_below.is_empty() {
    ""
  } else {
    "{" +
    node.notes_above.get(0).unwrap_or("") +
    "|" +
    node.notes_below.get(0).unwrap_or("") +
    "}"
  }
  let go = (child : String) => ebnf_norm(grammar, index, child)
  match node.kind {
    Terminal(t, _) => Term(if t.is_empty() { " " } else { t }, n)
    Reference(name, _) => Ref(name)
    Special(t) => Spec(if t.is_empty() { " " } else { t }, n)
    Empty => Empty
    Sequence(items) => seq(items.iter().map(go).collect())
    Choice(items) => alt(items.iter().map(go).collect())
    Optional(x) => Opt(go(x))
    ZeroOrMore(x) => Star(go(x))
    OneOrMore(x) => Plus(go(x))
    Count(count, x) => if count == "0" { Opt(Plus(go(x))) } else { Plus(go(x)) }
    Exclusion(left, excluded) => seq([go(left), Not(go(excluded))])
  }
}

///|
fn kind_of(name : String) -> String {
  name.split("/").next().unwrap().to_owned()
}

///|
priv struct Outcome {
  name : String
  category : String
  agrees : Bool
  detail : String
}

///|
fn reference_entries() -> Map[String, Map[String, Json]] {
  let out = Map([])
  guard (try Some(@json.parse(@corpus.reference)) catch { _ => None }) is Some(Object(r)) &&
    r.get("fixtures") is Some(Array(entries)) else {
    abort("reference")
  }
  for e in entries {
    guard e is Object(o) else { abort("entry") }
    out[str(o.get("name"))] = o
  }
  out
}

///|
fn expectation(name : String) -> (String, String)? {
  guard (try Some(@json.parse(@corpus.expectations)) catch { _ => None }) is Some(Object(cases)) else { abort("expectations") }
  match cases.get(name) {
    Some(Object(o)) => Some((str(o.get("category")), str(o.get("reason"))))
    _ => None
  }
}

///|
/// Compare one regex, EBNF or envelope fixture with the pinned reference.
fn compare(fixture : @corpus.Fixture, entry : Map[String, Json]) -> Outcome {
  let status = str(entry.get("status"))
  let native_accept = status == "accepted" &&
    !(entry.get("data") is Some(Null) && entry.get("inspection") == Some(Json("data")))
  let read = @plantuml.read(fixture.source)
  let converted = read.document.map(d => @plantuml.to_diagram(d))
  let ours = converted.bind(c => c.diagram)
  let category = match expectation(fixture.name) {
    Some((c, _)) => c
    None => if native_accept { "accepted" } else { "native-refusal" }
  }
  let detail = read.diagnostics.iter().map(d => d.code).collect().join(",")
  match category {
    "native-refusal" | "library-refusal" =>
      return {
        name: fixture.name,
        category,
        agrees: ours is None && (category == "library-refusal") == native_accept,
        detail,
      }
    _ => ()
  }
  guard ours is Some(diagram) else {
    return { name: fixture.name, category, agrees: false, detail: "refused: " + detail }
  }
  let expected = match diagram {
    Regex(_) =>
      match entry.get("regex") {
        Some(Array(stack)) if !stack.is_empty() => Some(upstream(stack[0], false).text())
        _ => None
      }
    Ebnf(_) =>
      match entry.get("ebnf") {
        Some(Array(items)) =>
          Some(
            items
            .map(i => {
              guard i is Object(o) else { return "" }
              match o.get("note") {
                Some(Array(lines)) => "note " + lines.map(l => str(Some(l))).join("\n")
                _ => {
                  let body = match o.get("tile") {
                    Some(Object(_) as tile) => upstream(tile, true).text()
                    _ => "empty-rule"
                  }
                  "\{str(o.get("name"))}{\{str(o.get("above")).trim()}|\{str(o.get("below")).trim()}} = \{body}"
                }
              }
            })
            .join("\n"),
          )
        _ => None
      }
    _ => None
  }
  let actual = match diagram {
    Regex(model) => Some(regex_norm(model).text())
    Ebnf(grammar) => {
      let index = @ebnf.Index::build(grammar).index.unwrap()
      Some(
        grammar.items
        .iter()
        .map(item => match item {
          Note(_, text) => "note " + text
          Rule(rule) =>
            "\{rule.name}{\{rule.note_above.unwrap_or("")}|\{rule.note_below.unwrap_or("")}} = \{rule.body.map(b => ebnf_norm(grammar, index, b).text()).unwrap_or("empty-rule")}"
        })
        .collect()
        .join("\n"),
      )
    }
    _ => None
  }
  let title_ok = match diagram {
    Regex(m) => m.title.unwrap_or("") == str(entry.get("title"))
    Ebnf(g) => g.title.unwrap_or("") == str(entry.get("title"))
    _ => true
  }
  let same = expected == actual && title_ok
  {
    name: fixture.name,
    category,
    agrees: if category == "divergence" { !same } else { same },
    detail: "expected " + expected.unwrap_or("?") + "\nactual   " + actual.unwrap_or("?"),
  }
}

///|
test "regex, EBNF and envelope fixtures agree with PlantUML 1.2026.9" {
  let entries = reference_entries()
  let failures = []
  let mut checked = 0
  for fixture in @corpus.fixtures {
    let kind = kind_of(fixture.name)
    if kind == "json" || kind == "yaml" {
      continue
    }
    let envelope_data = kind == "envelope" &&
      (fixture.source.contains("@startjson") || fixture.source.contains("@startyaml"))
    if envelope_data {
      continue
    }
    checked += 1
    let outcome = compare(fixture, entries[fixture.name])
    if !outcome.agrees {
      failures.push("\{outcome.name} [\{outcome.category}] \{outcome.detail}")
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n\n"))
  }
  assert_true(checked > 100)
}
