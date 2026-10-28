///|
/// The four supported native diagram kinds.
pub(all) enum Kind {
  Regex
  Ebnf
  Json
  Yaml
  Activity
  State
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{not_equal, equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
/// The marker word of a kind, as in `@start<word>`.
pub fn Kind::word(self : Kind) -> String {
  match self {
    Regex => "regex"
    Ebnf => "ebnf"
    Json => "json"
    Yaml => "yaml"
    Activity | State => "uml"
  }
}

///|
pub fn kind_of_word(word : String) -> Kind? {
  match word {
    "regex" => Some(Regex)
    "ebnf" => Some(Ebnf)
    "json" => Some(Json)
    "yaml" => Some(Yaml)
    "uml" => Some(Activity)
    _ => None
  }
}

///|
/// Explicit positive bounds for reading, writing and conversion.
pub struct Limits {
  source : Int32
  output : Int32
  depth : Int32
  nodes : Int32
  regions : Int32
  edges : Int32
  work : Int32
  diagnostics : Int32
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{not_equal, equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(
  source~ : Int32 = 1048576,
  output~ : Int32 = 4194304,
  depth~ : Int32 = 256,
  nodes~ : Int32 = 100000,
  regions~ : Int32 = 100000,
  edges~ : Int32 = 100000,
  work~ : Int32 = 4000000,
  diagnostics~ : Int32 = 64,
) -> Limits {
  { source, output, depth, nodes, regions, edges, work, diagnostics, }
}

///|
pub fn Limits::valid(self : Limits) -> Bool {
  self.source > 0 &&
  self.output > 0 &&
  self.depth > 0 &&
  self.nodes > 0 &&
  self.regions > 0 &&
  self.edges > 0 &&
  self.work > 0 &&
  self.diagnostics > 0
}

///|
/// One retained presentation or metadata statement. Library themes and
/// options paint the diagram; these values are inert author data.
pub(all) enum Statement {
  Title(String)
  Caption(String)
  Header(String)
  Footer(String)
  Legend(ReadOnlyArray[String])
  /// The text after `skinparam`, or the lines of a `skinparam {}` block.
  Skinparam(ReadOnlyArray[String])
  /// The lines inside a `<style>` block.
  Style(ReadOnlyArray[String])
  Skin(String)
  Scale(String)
  /// A `hide` or `show` command, with its keyword.
  Hide(String)
  /// The text after `!pragma`.
  Pragma(String)
  /// The text after `!option`, such as `useDescriptiveNames true`.
  Option(String)
} derive(Eq, Debug)

///|
pub extend Statement with Eq::{not_equal, equal}

///|
pub extend Statement with @debug.Debug::{to_repr}

///|
/// The canonical text of a metadata statement, one line per entry, without
/// line breaks at the end.
pub fn Statement::lines(self : Statement) -> Array[String] {
  match self {
    Title(text) => ["title " + text]
    Caption(text) => ["caption " + text]
    Header(text) => ["header " + text]
    Footer(text) => ["footer " + text]
    Legend(lines) => {
      let out = ["legend"]
      for line in lines {
        out.push(line)
      }
      out.push("endlegend")
      out
    }
    Skinparam(lines) =>
      if lines.length() == 1 {
        ["skinparam " + lines[0]]
      } else {
        let named = !lines.is_empty() && lines[0].has_suffix("{")
        let out = [if named { "skinparam " + lines[0] } else { "skinparam {" }]
        for i, line in lines {
          if !named || i != 0 {
            out.push("  " + line)
          }
        }
        out.push("}")
        out
      }
    Style(lines) => {
      let out = ["<style>"]
      for line in lines {
        out.push(line)
      }
      out.push("</style>")
      out
    }
    Skin(text) => ["skin " + text]
    Scale(text) => ["scale " + text]
    Hide(text) => [text]
    Pragma(text) => ["!pragma " + text]
    Option(text) => ["!option " + text]
  }
}

///|
/// The role of one source line inside the block.
pub(all) enum Role {
  /// A line for the kind reader.
  Body
  /// A line that belongs to a shared statement, comment or directive node.
  /// Only the first line of a multi-line statement carries the node.
  Statement(@cst.Node)
  /// A continuation line of a multi-line statement.
  Continuation
} derive(Eq, Debug)

///|
pub extend Role with Eq::{not_equal, equal}

///|
pub extend Role with @debug.Debug::{to_repr}

///|
/// One source line between the block markers, without its line break.
pub struct Line {
  number : Int32
  offset : Int32
  text : String
  newline : String
  role : Role
} derive(Eq, Debug)

///|
pub extend Line with Eq::{not_equal, equal}

///|
pub extend Line with @debug.Debug::{to_repr}

///|
/// The tokens of a line as one text token plus its line break.
pub fn Line::tokens(self : Line, kind : @cst.TokenKind) -> Array[@cst.Element] {
  let out : Array[@cst.Element] = []
  if !self.text.is_empty() {
    out.push(Token(@cst.Token::new(kind, self.text, self.offset)))
  }
  if !self.newline.is_empty() {
    out.push(
      Token(
        @cst.Token::new(Newline, self.newline, self.offset + self.text.length()),
      ),
    )
  }
  out
}

///|
/// The scanned envelope of one native block.
pub struct Scan {
  source : String
  kind : Kind?
  name : String?
  /// Nodes before the body: leading trivia and the start marker.
  head : ReadOnlyArray[@cst.Node]
  lines : ReadOnlyArray[Line]
  /// Nodes after the body: the end marker and trailing trivia or text.
  tail : ReadOnlyArray[@cst.Node]
  statements : ReadOnlyArray[Statement]
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
  lines_index : @cst.Lines
}

///|
/// The stable diagnostic codes of envelope scanning.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "plantuml/ambiguous-kind", "plantuml/source-limit", "plantuml/invalid-limits", "plantuml/missing-start-marker",
  "plantuml/unsupported-diagram", "plantuml/missing-end-marker", "plantuml/wrong-end-marker",
  "plantuml/multiple-blocks", "plantuml/text-outside-block", "plantuml/unsupported-directive",
  "plantuml/unsupported-preprocessing", "plantuml/unsupported-statement", "plantuml/unclosed-block",
  "plantuml/unapplied-presentation", "plantuml/diagnostic-limit",
]

///|
priv struct Raw {
  offset : Int32
  text : String
  newline : String
}

///|
fn split_lines(source : String) -> Array[Raw] {
  let out = []
  let mut start = 0
  let mut i = 0
  let n = source.length()
  while i < n {
    let c = source.code_unit_at(i).to_int()
    if c == 10 || c == 13 {
      let width = if c == 13 &&
        i + 1 < n &&
        source.code_unit_at(i + 1).to_int() == 10 {
        2
      } else {
        1
      }
      out.push({
        offset: start,
        text: @cst.slice(source, start, i),
        newline: @cst.slice(source, i, i + width),
      })
      i += width
      start = i
    } else {
      i += 1
    }
  }
  if start < n || n == 0 {
    out.push({ offset: start, text: @cst.slice(source, start, n), newline: "", })
  }
  out
}

///|
fn is_space_unit(c : Int32) -> Bool {
  c == 32 || c == 9 || c == 0xfeff
}

///|
/// `text` without leading and trailing code units up to U+0020, as Java
/// `String.trim` removes them.
pub fn java_trim(text : String) -> String {
  let mut a = 0
  let mut b = text.length()
  while a < b && text.code_unit_at(a).to_int() <= 32 {
    a += 1
  }
  while b > a && text.code_unit_at(b - 1).to_int() <= 32 {
    b -= 1
  }
  @cst.slice(text, a, b)
}

///|
/// `text` without leading and trailing spaces, tabs and byte-order marks.
pub fn trim(text : String) -> String {
  let mut a = 0
  let mut b = text.length()
  while a < b && is_space_unit(text.code_unit_at(a).to_int()) {
    a += 1
  }
  while b > a && is_space_unit(text.code_unit_at(b - 1).to_int()) {
    b -= 1
  }
  @cst.slice(text, a, b)
}

///|
fn has_word(text : String, word : String) -> Bool {
  text == word ||
  (
    text.has_prefix(word) &&
    is_space_unit(text.code_unit_at(word.length()).to_int())
  )
}

///|
fn after_word(text : String, word : String) -> String {
  trim(@cst.slice(text, word.length(), text.length()))
}

///|
/// True when `text` calls a preprocessor function such as `%date()`.
pub fn has_preprocessor_call(text : String) -> Bool {
  let n = text.length()
  let mut i = 0
  while i < n {
    if text.code_unit_at(i).to_int() == 37 {
      let mut j = i + 1
      fn name(c : Int32) -> Bool {
        (c >= 97 && c <= 122) ||
        (c >= 65 && c <= 90) ||
        c == 95 ||
        (c >= 48 && c <= 57)
      }
      while j < n && name(text.code_unit_at(j).to_int()) {
        j += 1
      }
      if j > i + 1 && j < n && text.code_unit_at(j).to_int() == 40 {
        let first = text.code_unit_at(i + 1).to_int()
        if !(first >= 48 && first <= 57) {
          return true
        }
      }
      i = j
    } else {
      i += 1
    }
  }
  false
}

///|
fn marker(text : String, prefix : String) -> (String, String?)? {
  let t = trim(text)
  guard t.has_prefix(prefix) else { return None }
  let rest = @cst.slice(t, prefix.length(), t.length())
  let mut i = 0
  while i < rest.length() {
    let c = rest.code_unit_at(i).to_int()
    if !((c >= 97 && c <= 122) || (c >= 48 && c <= 57)) {
      break
    }
    i += 1
  }
  if i == 0 {
    return None
  }
  let word = @cst.slice(rest, 0, i)
  let tail = trim(@cst.slice(rest, i, rest.length()))
  if i < rest.length() && !is_space_unit(rest.code_unit_at(i).to_int()) {
    return None
  }
  Some((word, if tail.is_empty() { None } else { Some(tail) }))
}

///|
fn is_trivia(text : String) -> Bool {
  let t = trim(text)
  t.is_empty() || t.has_prefix("'")
}

///|
fn trivia_node(
  raw : Raw,
  kind : @cst.TokenKind,
  node? : @cst.NodeKind,
) -> @cst.Node {
  let children : Array[@cst.Element] = []
  if !raw.text.is_empty() {
    children.push(Token(@cst.Token::new(kind, raw.text, raw.offset)))
  }
  if !raw.newline.is_empty() {
    children.push(
      Token(
        @cst.Token::new(Newline, raw.newline, raw.offset + raw.text.length()),
      ),
    )
  }
  @cst.Node::new(
    match node {
      Some(node) => node
      None =>
        if kind == Comment {
          Comment
        } else if kind == Whitespace {
          Blank
        } else {
          Error
        }
    },
    children,
  )
}

///|
/// Scan one native block. Multiple blocks, wrong end markers and text
/// outside the block are errors, never a partial result.
pub fn scan(source : String, limits~ : Limits = Limits::new()) -> Scan {
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let index = @cst.Lines::new(source)
  fn error(code : String, message : String, start : Int32, end : Int32) {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::error(code, message, span=index.span(start, end)),
      )
    }
  }
  fn warning(code : String, message : String, start : Int32, end : Int32) {
    if diagnostics.length() < limits.diagnostics {
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          code,
          message,
          span=index.span(start, end),
        ),
      )
    }
  }
  let empty : Scan = {
    source,
    kind: None,
    name: None,
    head: [],
    lines: [],
    tail: [],
    statements: [],
    diagnostics: [],
    lines_index: index,
  }
  if !limits.valid() {
    return {
      ..empty,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "plantuml/invalid-limits", "PlantUML limits must be positive",
        ),
      ],
    }
  }
  if source.length() > limits.source {
    return {
      ..empty,
      head: [@cst.Node::new(Error, [Token(@cst.Token::new(Error, source, 0))])],
      diagnostics: [
        @diagrams.Diagnostic::error(
          "plantuml/source-limit", "Source limit exceeded",
        ),
      ],
    }
  }
  let raws = split_lines(source)
  let head : Array[@cst.Node] = []
  let mut i = 0
  let mut kind : Kind? = None
  let mut name : String? = None
  let mut in_block_comment = false
  while i < raws.length() {
    let raw = raws[i]
    let t = trim(raw.text)
    if in_block_comment {
      head.push(trivia_node(raw, Comment))
      if t.has_suffix("'/") {
        in_block_comment = false
      }
      i += 1
      continue
    }
    if t.has_prefix("/'") {
      head.push(trivia_node(raw, Comment))
      in_block_comment = !t.has_suffix("'/") || t.length() < 4
      i += 1
      continue
    }
    if t.is_empty() {
      head.push(trivia_node(raw, Whitespace))
      i += 1
      continue
    }
    if marker(raw.text, "@start") is Some((word, label)) {
      head.push(trivia_node(raw, Marker, node=Start))
      match kind_of_word(word) {
        Some(k) => kind = Some(k)
        None =>
          error(
            "plantuml/unsupported-diagram",
            "Unsupported diagram type @start\{word}; expected regex, ebnf, json or yaml",
            raw.offset,
            raw.offset + raw.text.length(),
          )
      }
      name = label
      i += 1
      break
    }
    if t.has_prefix("'") {
      head.push(trivia_node(raw, Comment))
    } else {
      head.push(trivia_node(raw, Error))
      error(
        "plantuml/text-outside-block",
        "Text before the start marker",
        raw.offset,
        raw.offset + raw.text.length(),
      )
    }
    i += 1
  }
  if kind is None && diagnostics.is_empty() {
    error(
      "plantuml/missing-start-marker", "Expected @startregex, @startebnf, @startjson or @startyaml",
      0, 0,
    )
  }
  let body_raws : Array[Raw] = []
  let mut end_index : Int32? = None
  while i < raws.length() {
    if marker(raws[i].text, "@end") is Some(_) {
      end_index = Some(i)
      break
    }
    body_raws.push(raws[i])
    i += 1
  }
  let tail : Array[@cst.Node] = []
  match end_index {
    None =>
      if kind is Some(k) {
        error(
          "plantuml/missing-end-marker",
          "Missing @end\{k.word()}",
          source.length(),
          source.length(),
        )
      }
    Some(e) => {
      let raw = raws[e]
      tail.push(trivia_node(raw, Marker, node=End))
      if marker(raw.text, "@end") is Some((word, extra)) && kind is Some(k) {
        if word != k.word() {
          error(
            "plantuml/wrong-end-marker",
            "Expected @end\{k.word()}, found @end\{word}",
            raw.offset,
            raw.offset + raw.text.length(),
          )
        } else if extra is Some(_) {
          error(
            "plantuml/wrong-end-marker",
            "Unexpected text after @end\{word}",
            raw.offset,
            raw.offset + raw.text.length(),
          )
        }
      }
      let mut j = e + 1
      let mut block = false
      while j < raws.length() {
        let raw = raws[j]
        let t = trim(raw.text)
        if block {
          tail.push(trivia_node(raw, Comment))
          if t.has_suffix("'/") {
            block = false
          }
        } else if t.has_prefix("/'") {
          tail.push(trivia_node(raw, Comment))
          block = !t.has_suffix("'/") || t.length() < 4
        } else if is_trivia(raw.text) {
          tail.push(
            trivia_node(raw, if t.is_empty() { Whitespace } else { Comment }),
          )
        } else {
          tail.push(trivia_node(raw, Error, node=Trailing))
          if marker(raw.text, "@start") is Some(_) {
            error(
              "plantuml/multiple-blocks",
              "A source can contain only one diagram block",
              raw.offset,
              raw.offset + raw.text.length(),
            )
          } else {
            error(
              "plantuml/text-outside-block",
              "Text after the end marker",
              raw.offset,
              raw.offset + raw.text.length(),
            )
          }
        }
        j += 1
      }
    }
  }
  if kind == Some(Activity) {
    let mut state_seen = false
    let mut activity_seen = false
    let mut note = false
    let mut comment = false
    let mut shared_end : String? = None
    let mut action_text = false
    for raw in body_raws {
      let t = trim(raw.text)
      if comment {
        if t.has_suffix("'/") { comment = false }
        continue
      }
      if shared_end is Some(end) {
        if t == end { shared_end = None }
        continue
      }
      if note {
        if t == "end note" || t == "endnote" { note = false }
        continue
      }
      if action_text {
        if t.contains(";") { action_text = false }
        continue
      }
      if t.has_prefix("/'") {
        comment = !t.has_suffix("'/")
        continue
      }
      if t.has_prefix("'") { continue }
      if t == "<style>" { shared_end = Some("</style>"); continue }
      if t.has_prefix("skinparam ") && t.has_suffix("{") { shared_end = Some("}"); continue }
      if t == "legend" || t.has_prefix("legend ") { shared_end = Some("endlegend"); continue }
      if t.has_prefix("note ") || t == "note" || t.has_prefix("floating note") {
        note = !t.contains(":") && !t.has_prefix("note \"" )
        continue
      }
      if t.has_prefix(":") && !t.contains(";") && !t.has_suffix(")") {
        activity_seen = true
        action_text = true
        continue
      }
      if has_word(t.to_lower(), "state") || t.has_prefix("[*]") ||
        t.contains("[H]") || t.contains("[H*]") ||
        (t.contains("-->") && t.has_suffix("[*]")) {
        state_seen = true
      }
      if t == "start" || t == "stop" || t == "end" ||
        t.has_prefix(":") || t.has_prefix("- ") || t.has_prefix("* ") ||
        t.has_prefix("** ") || t.has_prefix("-- ") || t.has_prefix("(*)") ||
        t.has_prefix("(*top)") || has_word(t, "while") ||
        has_word(t, "repeat") || has_word(t, "fork") ||
        (t.has_prefix("if ") && !t.has_prefix("state ")) ||
        (t.has_prefix("|") && !t.has_prefix("||")) {
        activity_seen = true
      }
    }
    if state_seen && activity_seen {
      error("plantuml/ambiguous-kind", "Mixed UML families; use an explicit supported body kind", 0, source.length())
      kind = None
    } else if state_seen {
      kind = Some(State)
    } else if !activity_seen {
      error("plantuml/unsupported-diagram", "Unsupported or ambiguous UML body; use read_body(State, body) for state arrows", 0, source.length())
      kind = None
    }
  }
  let (lines, statements) = classify(
    kind.unwrap_or(Regex),
    body_raws,
    i => index.span(i, i),
    fn(code, message, start, end) {
      if code.has_prefix("!") {
        warning(@cst.slice(code, 1, code.length()), message, start, end)
      } else {
        error(code, message, start, end)
      }
    },
  )
  if diagnostics.length() >= limits.diagnostics {
    diagnostics.push(
      @diagrams.Diagnostic::error(
        "plantuml/diagnostic-limit", "Diagnostic limit reached",
      ),
    )
  }
  {
    source,
    kind,
    name,
    head: ReadOnlyArray::from_array(head),
    lines: ReadOnlyArray::from_array(lines),
    tail: ReadOnlyArray::from_array(tail),
    statements: ReadOnlyArray::from_array(statements),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
    lines_index: index,
  }
}

///|
/// Classify body lines into shared statements and kind body lines. A report
/// code that starts with `!` is a warning.
fn classify(
  kind : Kind,
  raws : Array[Raw],
  _span : (Int32) -> @diagrams.Span,
  report : (String, String, Int32, Int32) -> Unit,
) -> (Array[Line], Array[Statement]) {
  let lines : Array[Line] = []
  let statements : Array[Statement] = []
  let data = kind == Json || kind == Yaml
  let mut data_started = false
  let mut activity_text = 0
  // The pinned JSON and YAML header rules need one space after the word.
  fn word_at(t : String, word : String) -> Bool {
    if data {
      t.has_prefix(word + " ")
    } else {
      has_word(t, word)
    }
  }
  let mut i = 0
  fn line(index : Int32, role : Role) -> Line {
    let raw = raws[index]
    {
      number: index,
      offset: raw.offset,
      text: raw.text,
      newline: raw.newline,
      role,
    }
  }
  fn statement(
    first : Int32,
    last : Int32,
    kind : @cst.NodeKind,
    token : @cst.TokenKind,
  ) -> Unit {
    let children : Array[@cst.Element] = []
    for k in first..<=last {
      let raw = raws[k]
      if !raw.text.is_empty() {
        children.push(Token(@cst.Token::new(token, raw.text, raw.offset)))
      }
      if !raw.newline.is_empty() {
        children.push(
          Token(
            @cst.Token::new(
              Newline,
              raw.newline,
              raw.offset + raw.text.length(),
            ),
          ),
        )
      }
    }
    lines.push(line(first, Statement(@cst.Node::new(kind, children))))
    for k in (first + 1)..<=last {
      lines.push(line(k, Continuation))
    }
  }
  fn whole(index : Int32) -> (Int32, Int32) {
    (raws[index].offset, raws[index].offset + raws[index].text.length())
  }
  fn block_end(start : Int32, close : (String) -> Bool) -> Int32? {
    let mut k = start + 1
    while k < raws.length() {
      if close(trim(raws[k].text)) {
        return Some(k)
      }
      k += 1
    }
    None
  }
  while i < raws.length() {
    let raw = raws[i]
    let t = if data { java_trim(raw.text) } else { trim(raw.text) }
    let (start, end) = whole(i)
    // Activity labels and notes can contain words that otherwise introduce
    // envelope metadata. Keep those lines in their body construct.
    if kind == Activity || kind == State {
      if activity_text != 0 {
        lines.push(line(i, Body))
        if (activity_text == 1 && t.contains(";")) ||
          (activity_text == 2 && (t == "end note" || t == "endnote")) {
          activity_text = 0
        }
        i += 1
        continue
      }
      if (t.has_prefix("note ") || t == "note" || t.has_prefix("floating note")) &&
        !t.contains(":") {
        activity_text = 2
        lines.push(line(i, Body))
        i += 1
        continue
      }
      if (t.has_prefix(":") || (t.has_prefix("#") && t.contains(":"))) &&
        !t.contains(";") &&
        !t.has_suffix(")") {
        activity_text = 1
        lines.push(line(i, Body))
        i += 1
        continue
      }
    }
    // Comments are removed before any diagram reader runs.
    if t.has_prefix("'") {
      statement(i, i, Comment, Comment)
      i += 1
      continue
    }
    if t.has_prefix("/'") {
      let last = if t.length() >= 4 && t.has_suffix("'/") {
        Some(i)
      } else {
        block_end(i, s => s.has_suffix("'/"))
      }
      match last {
        Some(last) => {
          statement(i, last, Comment, Comment)
          i = last + 1
        }
        None => {
          report(
            "plantuml/unclosed-block", "Unclosed block comment", start, end,
          )
          statement(i, raws.length() - 1, Error, Error)
          i = raws.length()
        }
      }
      continue
    }
    if t.has_prefix("!") {
      if has_word(t, "!option") && (!data || !data_started) {
        statements.push(Option(after_word(t, "!option")))
        statement(i, i, Pragma, Directive)
        report(
          "!plantuml/unapplied-presentation", "The option is retained but not applied",
          start, end,
        )
      } else if has_word(t, "!pragma") && (!data || !data_started) {
        statements.push(Pragma(after_word(t, "!pragma")))
        statement(i, i, Pragma, Directive)
        report(
          "!plantuml/unapplied-presentation", "The pragma is retained but not applied",
          start, end,
        )
      } else {
        statement(i, i, Directive, Directive)
        report(
          "plantuml/unsupported-directive", "Preprocessor directives such as includes, definitions and themes are not supported",
          start, end,
        )
      }
      i += 1
      continue
    }
    if has_preprocessor_call(raw.text) {
      statement(i, i, Directive, Directive)
      report(
        "plantuml/unsupported-preprocessing", "Preprocessor function calls are not evaluated",
        start, end,
      )
      i += 1
      continue
    }
    if t == "<style>" {
      match block_end(i, s => s == "</style>") {
        Some(last) => {
          let content = []
          for k in (i + 1)..<last {
            content.push(trim(raws[k].text))
          }
          statements.push(Style(ReadOnlyArray::from_array(content)))
          statement(i, last, Style, Text)
          report(
            "!plantuml/unapplied-presentation", "The style block is retained but library themes paint the diagram",
            start, end,
          )
          i = last + 1
        }
        None => {
          report(
            "plantuml/unclosed-block", "Unclosed <style> block", start, end,
          )
          statement(i, raws.length() - 1, Error, Error)
          i = raws.length()
        }
      }
      continue
    }
    // The pinned reader tests these prefixes before trimming, and counts
    // them as data lines for the header rules.
    if raw.text.has_prefix("#highlight ") && data {
      statement(i, i, Highlight, Text)
      data_started = true
      i += 1
      continue
    }
    if kind == Json && raw.text.has_prefix("#") {
      statement(i, i, Comment, Comment)
      data_started = true
      i += 1
      continue
    }
    let header = !data || !data_started
    if header && t.is_empty() {
      lines.push(line(i, Body))
      i += 1
      continue
    }
    if header && (word_at(t, "title") || (!data && t.has_prefix("title:"))) {
      let text = if t.has_prefix("title:") {
        trim(@cst.slice(t, 6, t.length()))
      } else {
        after_word(t, "title")
      }
      statements.push(Title(text))
      statement(i, i, Title, Text)
      i += 1
      continue
    }
    if !data {
      let simple = [
        ("caption", @cst.NodeKind::Caption),
        ("header", Header),
        ("footer", Footer),
      ]
      let mut matched = false
      for pair in simple {
        if has_word(t, pair.0) {
          let text = after_word(t, pair.0)
          statements.push(
            match pair.1 {
              Caption => Caption(text)
              Header => Header(text)
              _ => Footer(text)
            },
          )
          statement(i, i, pair.1, Text)
          report(
            "!plantuml/unapplied-presentation",
            "The \{pair.0} is retained but not drawn",
            start,
            end,
          )
          matched = true
          break
        }
      }
      if matched {
        i += 1
        continue
      }
      if t == "legend" || has_word(t, "legend") {
        match block_end(i, s => s == "endlegend" || s == "end legend") {
          Some(last) => {
            let content = []
            for k in (i + 1)..<last {
              content.push(trim(raws[k].text))
            }
            statements.push(Legend(ReadOnlyArray::from_array(content)))
            statement(i, last, Legend, Text)
            report(
              "!plantuml/unapplied-presentation", "The legend is retained but not drawn",
              start, end,
            )
            i = last + 1
          }
          None => {
            report("plantuml/unclosed-block", "Unclosed legend", start, end)
            statement(i, raws.length() - 1, Error, Error)
            i = raws.length()
          }
        }
        continue
      }
      for word in ["sprite", "rotate", "page", "minwidth", "mainframe"] {
        if has_word(t, word) && !(kind == State && word == "mainframe") {
          matched = true
        }
      }
      if matched {
        statement(i, i, Error, Error)
        report(
          "plantuml/unsupported-statement", "This presentation command is not supported",
          start, end,
        )
        i += 1
        continue
      }
    }
    if header && word_at(t, "skinparam") {
      let rest = after_word(t, "skinparam")
      if rest.has_suffix("{") {
        match block_end(i, s => s == "}") {
          Some(last) => {
            let content = []
            if rest != "{" {
              content.push(rest)
            }
            for k in (i + 1)..<last {
              content.push(trim(raws[k].text))
            }
            statements.push(Skinparam(ReadOnlyArray::from_array(content)))
            statement(i, last, Skinparam, Text)
            i = last + 1
          }
          None => {
            report(
              "plantuml/unclosed-block", "Unclosed skinparam block", start, end,
            )
            statement(i, raws.length() - 1, Error, Error)
            i = raws.length()
          }
        }
      } else {
        statements.push(Skinparam([rest]))
        statement(i, i, Skinparam, Text)
        i += 1
      }
      report(
        "!plantuml/unapplied-presentation", "The skin parameter is retained but library themes paint the diagram",
        start, end,
      )
      continue
    }
    if header && (word_at(t, "scale") || word_at(t, "skin")) {
      if has_word(t, "scale") {
        statements.push(Scale(after_word(t, "scale")))
        statement(i, i, Scale, Text)
      } else {
        statements.push(Skin(after_word(t, "skin")))
        statement(i, i, Skinparam, Text)
      }
      report(
        "!plantuml/unapplied-presentation", "The presentation setting is retained but not applied",
        start, end,
      )
      i += 1
      continue
    }
    if header && (word_at(t, "hide") || (!data && has_word(t, "show"))) {
      statements.push(Hide(t))
      statement(i, i, Hide, Text)
      report(
        "!plantuml/unapplied-presentation", "The visibility setting is retained but not applied",
        start, end,
      )
      i += 1
      continue
    }
    if data && !t.is_empty() {
      data_started = true
    }
    lines.push(line(i, Body))
    i += 1
  }
  (lines, statements)
}

///|
/// Assemble the lossless document from the scanned envelope and the nodes
/// that a kind reader made for its body lines.
pub fn Scan::document(self : Scan, body : ArrayView[@cst.Node]) -> @cst.Node {
  let children : Array[@cst.Element] = []
  for node in self.head {
    children.push(Node(node))
  }
  for node in body {
    children.push(Node(node))
  }
  for node in self.tail {
    children.push(Node(node))
  }
  @cst.Node::new(Document, children)
}

///|
/// The body nodes for lines with the `Statement` role, and one node per body
/// line made by `make`, in source order.
pub fn Scan::line_nodes(
  self : Scan,
  make : (Line) -> @cst.Node?,
) -> Array[@cst.Node] {
  let out = []
  for line in self.lines {
    match line.role {
      Statement(node) => out.push(node)
      Continuation => ()
      Body => if make(line) is Some(node) { out.push(node) }
    }
  }
  out
}

///|
pub fn Scan::span(self : Scan, start : Int32, end : Int32) -> @diagrams.Span {
  self.lines_index.span(start, end)
}

///|
/// The title of the block, if it has one. The last title wins.
pub fn Scan::title(self : Scan) -> String? {
  let mut title = None
  for statement in self.statements {
    if statement is Title(text) {
      title = Some(text)
    }
  }
  title
}

///|
/// Scan a raw body of an explicit kind, without block markers. Every line is
/// a body line or a shared statement, with offsets into `body`.
pub fn scan_body(
  kind : Kind,
  body : String,
  limits~ : Limits = Limits::new(),
) -> Scan {
  let index = @cst.Lines::new(body)
  if !limits.valid() || body.length() > limits.source {
    return {
      source: body,
      kind: Some(kind),
      name: None,
      head: [],
      lines: [],
      tail: [],
      statements: [],
      diagnostics: [
        @diagrams.Diagnostic::error(
          if limits.valid() {
            "plantuml/source-limit"
          } else {
            "plantuml/invalid-limits"
          },
          "Body exceeds the source limit or limits are invalid",
        ),
      ],
      lines_index: index,
    }
  }
  let diagnostics : Array[@diagrams.Diagnostic] = []
  let (lines, statements) = classify(
    kind,
    split_lines(body),
    i => index.span(i, i),
    fn(code, message, start, end) {
      if diagnostics.length() < limits.diagnostics {
        diagnostics.push(
          if code.has_prefix("!") {
            @diagrams.Diagnostic::warning(
              @cst.slice(code, 1, code.length()),
              message,
              span=index.span(start, end),
            )
          } else {
            @diagrams.Diagnostic::error(
              code,
              message,
              span=index.span(start, end),
            )
          },
        )
      }
    },
  )
  {
    source: body,
    kind: Some(kind),
    name: None,
    head: [],
    lines: ReadOnlyArray::from_array(lines),
    tail: [],
    statements: ReadOnlyArray::from_array(statements),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
    lines_index: index,
  }
}
