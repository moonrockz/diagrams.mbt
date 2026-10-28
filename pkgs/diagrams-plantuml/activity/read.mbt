///|
pub struct ReadResult {
  nodes : ReadOnlyArray[@cst.Node]
  document : Document?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "activity/syntax", "activity/ambiguous-dialect", "activity/missing-dialect", "activity/unclosed-control",
  "activity/unexpected-control", "activity/limit", "activity/unresolved-label", "activity/invalid-ast",
  "activity/unapplied-presentation", "activity/external-asset",
]

///|
fn trim(text : String) -> String {
  @envelope.trim(text)
}

///|
fn part(text : String, start : Int32, end : Int32) -> String {
  @cst.slice(text, start, end)
}

///|
fn after(text : String, prefix : String) -> String {
  trim(part(text, prefix.length(), text.length()))
}

///|
fn word(text : String, prefix : String) -> Bool {
  text == prefix ||
  text.has_prefix(prefix + " ") ||
  text.has_prefix(prefix + "(")
}

///|
fn unquote(text : String) -> String {
  let text = trim(text)
  if text.length() >= 2 && text.has_prefix("\"") && text.has_suffix("\"") {
    part(text, 1, text.length() - 1)
    .replace_all(old="\\n", new="\n")
    .replace_all(old="\\\"", new="\"")
    .replace_all(old="\\\\", new="\\")
  } else {
    text
  }
}

///|
fn parens(text : String) -> Array[String] {
  let out = []
  let mut depth = 0
  let mut start = 0
  let mut quote = false
  for i = 0; i < text.length(); i = i + 1 {
    let c = text.code_unit_at(i).to_int()
    if c == 34 {
      quote = !quote
    }
    if !quote {
      if c == 40 {
        if depth == 0 {
          start = i + 1
        }
        depth += 1
      } else if c == 41 && depth > 0 {
        depth -= 1
        if depth == 0 {
          out.push(part(text, start, i))
        }
      }
    }
  }
  out
}

///|
fn argument(text : String, index : Int32) -> String {
  parens(text).get(index).unwrap_or("")
}

///|
fn quoted_end(text : String) -> Int32? {
  let mut escaped = false
  for i = 1; i < text.length(); i = i + 1 {
    let c = text.code_unit_at(i).to_int()
    if c == 34 && !escaped {
      return Some(i)
    }
    escaped = c == 92 && !escaped
  }
  None
}

///|
fn endpoint(text : String) -> Endpoint? {
  let text = trim(text)
  if text == "(*)" || text == "(*top)" {
    Some(Start(text == "(*top)"))
  } else if text.has_prefix("==") && text.has_suffix("===") {
    Some(
      Synchronization(
        trim(text.trim_start(chars="=").trim_end(chars="=").to_owned()),
      ),
    )
  } else if text.has_prefix("\"") {
    guard quoted_end(text) is Some(end) else { return None }
    let tail = trim(part(text, end + 1, text.length()))
    if !tail.is_empty() &&
      !tail.has_prefix("as ") &&
      !tail.has_prefix("<<") &&
      !tail.has_prefix("#") {
      None
    } else {
      let code = if tail.has_prefix("as ") {
        Some(after(tail, "as").split(" ").next().unwrap_or("").to_owned())
      } else {
        None
      }
      let decoration = match code {
        Some(code) => trim(after(tail, "as " + code))
        None => tail
      }
      Some(Action(unquote(part(text, 0, end + 1)), code, decoration))
    }
  } else if !text.is_empty() && !text.contains(" ") {
    Some(Alias(text))
  } else {
    None
  }
}

///|
fn legacy_edge(text : String) -> Kind? {
  let mut quote = false
  let mut a = -1
  let mut b = -1
  for i = 0; i < text.length(); i = i + 1 {
    let c = text.code_unit_at(i).to_int()
    if c == 34 {
      quote = !quote
    }
    if !quote &&
      (
        c == 45 ||
        (
          c == 46 &&
          i + 1 < text.length() &&
          [46, 62, 91].contains(text.code_unit_at(i + 1).to_int())
        )
      ) &&
      a < 0 {
      a = i
    }
    if !quote && c == 62 && a >= 0 {
      b = i + 1
      break
    }
  }
  guard a >= 0 && b > a else { return None }
  let from = trim(part(text, 0, a))
  let arrow = part(text, a, b)
  let mut tail = trim(part(text, b, text.length()))
  let mut label = ""
  if tail.has_prefix("[") {
    guard tail.find("]") is Some(close) else { return None }
    label = part(tail, 1, close)
    tail = trim(part(tail, close + 1, tail.length()))
  }
  guard endpoint(tail) is Some(target) else { return None }
  let source = if from.is_empty() { None } else { endpoint(from) }
  if !from.is_empty() && source == None {
    return None
  }
  Some(Edge(source, arrow, target, label))
}

///|
fn action_end(text : String) -> Int32? {
  for i = 0; i < text.length(); i = i + 1 {
    if text.code_unit_at(i).to_int() == 59 {
      let tail = trim(part(text, i + 1, text.length()))
      if tail.is_empty() ||
        tail.has_prefix("<<") ||
        tail.has_prefix("#") ||
        tail.has_prefix("[[") {
        return Some(i)
      }
    }
  }
  None
}

///|
fn modern(text : String) -> Kind? {
  let lower = text.to_lower()
  if text == "start" {
    Some(Start)
  } else if text == "stop" || text.has_prefix("stop ") {
    Some(Stop)
  } else if text == "end" {
    Some(End)
  } else if word(text, "if") && text.contains("(") {
    Some(If(argument(text, 0), argument(text, 1)))
  } else if text.has_prefix("(") && text.contains("elseif") {
    Some(
      ElseIfIncoming(argument(text, 0), argument(text, 1), argument(text, 2)),
    )
  } else if word(text, "elseif") {
    Some(ElseIf(argument(text, 0), argument(text, 1)))
  } else if word(text, "else") {
    Some(Else(argument(text, 0)))
  } else if lower == "endif" || lower == "end if" {
    Some(EndIf)
  } else if word(text, "switch") {
    Some(Switch(argument(text, 0)))
  } else if word(text, "case") {
    Some(Case(argument(text, 0)))
  } else if text == "endswitch" || text == "end switch" {
    Some(EndSwitch)
  } else if word(text, "while") {
    Some(While(argument(text, 0), argument(text, 1)))
  } else if word(text, "endwhile") {
    Some(EndWhile(argument(text, 0)))
  } else if text.has_prefix("repeat while") || text.has_prefix("repeatwhile") {
    Some(RepeatWhile(argument(text, 0), argument(text, 1), argument(text, 2)))
  } else if word(text, "repeat") {
    Some(Repeat(after(text, "repeat")))
  } else if text.has_prefix("backward:") || text.has_prefix("backward :") {
    Some(
      Backward(
        trim(after(after(text, "backward"), ":").trim_end(chars=";").to_owned()),
      ),
    )
  } else if text == "break" {
    Some(Break)
  } else if text == "fork" {
    Some(Fork)
  } else if text == "fork again" {
    Some(ForkAgain)
  } else if word(text, "end fork") || word(text, "endfork") {
    Some(
      EndFork(false, if text.contains("{") { argument_brace(text) } else { "" }),
    )
  } else if text == "end merge" || text == "endmerge" {
    Some(EndFork(true, ""))
  } else if text == "split" {
    Some(Split)
  } else if text == "split again" {
    Some(SplitAgain)
  } else if text == "end split" || text == "endsplit" {
    Some(EndSplit)
  } else if text == "kill" {
    Some(Kill)
  } else if text == "detach" {
    Some(Detach)
  } else if text.has_prefix("label ") {
    Some(Label(after(text, "label")))
  } else if text.has_prefix("goto ") {
    Some(Goto(after(text, "goto")))
  } else if text.has_prefix("(") && text.has_suffix(")") {
    Some(Connector(argument(text, 0)))
  } else if text.has_prefix("|") && text.contains("|") {
    let pieces = text.split("|").map(s => s.to_owned()).collect()
    if pieces.length() >= 3 {
      let color = if pieces[1].has_prefix("#") { pieces[1] } else { "" }
      let at = if color.is_empty() { 1 } else { 2 }
      if pieces.length() <= at + 1 {
        None
      } else {
        let id = pieces[at]
        let label = trim(pieces[at + 1])
        Some(Lane(id, if label.is_empty() { id } else { label }, color))
      }
    } else {
      None
    }
  } else if (
      word(text, "partition") ||
      word(text, "group") ||
      word(text, "package") ||
      word(text, "rectangle") ||
      word(text, "card")
    ) &&
    text.has_suffix("{") {
    let first = text.split(" ").next().unwrap_or("").to_owned()
    let mut value = trim(part(text, first.length(), text.length() - 1))
    let mut before = ""
    if value.has_prefix("#") {
      let at = value.find(" ").unwrap_or(value.length())
      before = part(value, 0, at)
      value = trim(part(value, at, value.length()))
    }
    let (label, decoration) = if value.has_prefix("\"") &&
      quoted_end(value) is Some(at) {
      (
        unquote(part(value, 0, at + 1)),
        trim(part(value, at + 1, value.length())),
      )
    } else {
      let color = value.find(" #").unwrap_or(value.length())
      let stereo = value.find("<<").unwrap_or(value.length())
      let at = color.min(stereo)
      (trim(part(value, 0, at)), trim(part(value, at, value.length())))
    }
    Some(Group(first, label, before, decoration))
  } else if text == "}" || text == "end group" {
    Some(EndGroup)
  } else if text.has_prefix("->") ||
    text.has_prefix("-[") ||
    text.has_prefix("-->") {
    Some(
      Arrow(
        if text.contains("hidden") {
          "invisible"
        } else if text.contains("dashed") || text.contains("dotted") {
          "dotted"
        } else if text.contains("bold") {
          "thick"
        } else {
          "solid"
        },
        text.trim_end(chars=";").to_owned(),
      ),
    )
  } else if text.has_prefix("<<") ||
    text.has_prefix("#") ||
    text.has_prefix("link ") ||
    text.has_prefix("-<") {
    Some(Presentation(text))
  } else {
    None
  }
}

///|
fn argument_brace(text : String) -> String {
  match (text.find("{"), text.find("}")) {
    (Some(a), Some(b)) if b > a => part(text, a + 1, b)
    _ => ""
  }
}

///|
/// Read the activity lines of an already scanned envelope. `dialect` is
/// required for body-only calls; full blocks can select it from statements.
pub fn read(
  scan : @envelope.Scan,
  limits~ : @envelope.Limits = @envelope.Limits::new(),
  dialect? : Dialect,
) -> ReadResult {
  let nodes = scan.line_nodes(line => {
    Some(@cst.Node::new(Data, line.tokens(Text)))
  })
  let diagnostics = scan.diagnostics.iter().collect()
  let items : Array[Statement] = []
  let mut chosen = dialect
  let stack : Array[(String, @diagrams.Span)] = []
  let mut work = 0
  let mut i = 0
  let mut modern_seen = false
  let mut legacy_seen = false
  fn error(code : String, message : String, span : @diagrams.Span?) {
    if diagnostics.length() < limits.diagnostics.max(1) {
      diagnostics.push(@diagrams.Diagnostic::error(code, message, span?))
    }
  }
  fn emit(kind : Kind, span : @diagrams.Span) {
    if items.length() >= limits.nodes {
      error("activity/limit", "Statement limit exceeded", Some(span))
      return
    }
    let open = match kind {
      If(_, _) | LegacyIf(_) | LegacyDecision(_, _, _, _) => Some("if")
      While(_, _) => Some("while")
      Repeat(_) => Some("repeat")
      Fork => Some("fork")
      Split => Some("split")
      Switch(_) => Some("switch")
      Group(_, _, _, _) => Some("group")
      _ => None
    }
    let close = match kind {
      EndIf => Some("if")
      EndWhile(_) => Some("while")
      RepeatWhile(_, _, _) => Some("repeat")
      EndFork(_, _) => Some("fork")
      EndSplit => Some("split")
      EndSwitch => Some("switch")
      EndGroup => Some("group")
      _ => None
    }
    if open is Some(name) {
      if stack.length() >= limits.depth {
        error("activity/limit", "Control nesting limit exceeded", Some(span))
      } else {
        stack.push((name, span))
      }
    }
    if close is Some(name) {
      match stack.last() {
        Some((expected, _)) if expected == name => ignore(stack.pop())
        _ =>
          error(
            "activity/unexpected-control",
            "Unexpected closing " + name,
            Some(span),
          )
      }
    }
    items.push(Statement::new(kind, span~))
  }
  while i < scan.lines.length() {
    let line = scan.lines[i]
    i += 1
    work += line.text.length() + 1
    if work > limits.work {
      error(
        "activity/limit",
        "Activity work limit exceeded",
        Some(scan.span(line.offset, line.offset)),
      )
      break
    }
    if line.role != @envelope.Role::Body {
      continue
    }
    let mut text = trim(line.text)
    if text.is_empty() || text.has_prefix("'") {
      continue
    }
    let begin = line.offset
    let mut end = line.offset + line.text.length()
    let span = scan.span(begin, end)
    if text.has_prefix("note ") ||
      text == "note" ||
      text.has_prefix("floating note") {
      let placement = if text.has_prefix("floating note") {
        "floating"
      } else if text.contains("left") {
        "left"
      } else if text.contains("top") {
        "top"
      } else if text.contains("bottom") {
        "bottom"
      } else {
        "right"
      }
      let mut note = ""
      let mut note_alias : String? = None
      if text.find(":") is Some(colon) {
        note = trim(part(text, colon + 1, text.length()))
      } else {
        if text.find(" as ") is Some(at) {
          note_alias = Some(trim(part(text, at + 4, text.length())))
        }
        let out = []
        let mut closed = false
        while i < scan.lines.length() {
          let next = scan.lines[i]
          i += 1
          end = next.offset + next.text.length()
          if trim(next.text) == "end note" || trim(next.text) == "endnote" {
            closed = true
            break
          }
          out.push(next.text)
        }
        note = out.join("\n")
        if !closed {
          error("activity/syntax", "Unclosed note", Some(span))
        }
      }
      let header = if text.find(":") is Some(at) {
        trim(part(text, 0, at))
      } else {
        text
      }
      let decoration = if header.find("#") is Some(at) {
        trim(part(header, at, header.length()))
      } else {
        ""
      }
      if header.contains("on link") {
        emit(NoteOnLink(note, decoration), scan.span(begin, end))
      } else {
        emit(
          Note(placement, note, note_alias, decoration),
          scan.span(begin, end),
        )
      }
      continue
    }
    if text.has_prefix("#") && text.contains(":(") && text.has_suffix(")") {
      modern_seen = true
      let at = text.find(":").unwrap()
      emit(Connector(argument(part(text, at + 1, text.length()), 0)), span)
      continue
    }
    if text.has_prefix(":") || (text.has_prefix("#") && text.contains(":")) {
      modern_seen = true
      let mut decoration = ""
      if !text.has_prefix(":") {
        let colon = text.find(":").unwrap()
        decoration = part(text, 0, colon)
        text = part(text, colon, text.length())
      }
      let indent = line.text.length() - line.text.trim_start().length()
      let mut content = after(text, ":")
      let mut terminator = ";"
      let mut ended = false
      while true {
        if action_end(content) is Some(at) {
          let trailing = trim(part(content, at + 1, content.length()))
          content = part(content, 0, at)
          if !trailing.is_empty() {
            if trailing.has_prefix("<<") ||
              trailing.has_prefix("#") ||
              trailing.has_prefix("[[") {
              decoration = "after:" + trailing
            } else {
              error(
                "activity/syntax",
                "Unexpected text after activity action",
                Some(span),
              )
            }
          }
          ended = true
          break
        }
        if !content.contains("\n") &&
          ["]", "}", "/", "|", ">", "<"].iter().any(s => content.has_suffix(s)) {
          terminator = part(content, content.length() - 1, content.length())
          content = part(content, 0, content.length() - 1)
          ended = true
          break
        }
        if i >= scan.lines.length() {
          break
        }
        let next = scan.lines[i]
        let candidate = trim(next.text)
        if [
            "start", "stop", "endif", "endwhile", "end fork", "end split", "}", "else",
          ].contains(candidate) ||
          candidate.has_prefix("if (") {
          break
        }
        i += 1
        end = next.offset + next.text.length()
        let leading = next.text.length() - next.text.trim_start().length()
        content = content +
          "\n" +
          part(next.text, indent.min(leading), next.text.length())
      }
      if !ended {
        error("activity/syntax", "Unterminated activity action", Some(span))
      }
      emit(Action(trim(content), terminator, decoration), scan.span(begin, end))
      continue
    }
    if text.has_prefix("-<") {
      modern_seen = true
      let value = part(text, 1, text.length())
      let suffix = value.find("<<")
      let label = match suffix {
        Some(at) => trim(part(value, 0, at))
        None => value
      }
      let decoration = match suffix {
        Some(at) => "after:" + part(value, at, value.length())
        None => ""
      }
      emit(Action(label, ";", decoration), span)
      continue
    }
    if (modern_seen && !legacy_seen) &&
      modern(text) is Some(Arrow(style, value)) {
      let mut value = value
      if value.find(">") is Some(at) &&
        !trim(part(value, at + 1, value.length())).is_empty() &&
        !text.has_suffix(";") {
        while i < scan.lines.length() {
          let next = scan.lines[i]
          let candidate = trim(next.text)
          if candidate.has_prefix(":") || modern(candidate) != None {
            break
          }
          i += 1
          end = next.offset + next.text.length()
          value = value + "\n" + next.text
          if value.has_suffix(";") {
            value = value.trim_end(chars=";").to_owned()
            break
          }
        }
      }
      emit(Arrow(style, value), scan.span(begin, end))
      continue
    }
    if text.has_prefix("-") || text.has_prefix("*") {
      let mut depth = 0
      while depth < text.length() &&
            [42, 45].contains(text.code_unit_at(depth).to_int()) {
        depth += 1
      }
      if depth < text.length() && text.code_unit_at(depth).to_int() == 32 {
        modern_seen = true
        emit(ActionList(trim(part(text, depth, text.length())), depth), span)
        continue
      }
    }
    let mut quote_count = 0
    for unit in text.to_array() {
      if unit == '"' {
        quote_count += 1
      }
    }
    if quote_count % 2 == 1 {
      while i < scan.lines.length() {
        let next = scan.lines[i]
        i += 1
        text = text + "\n" + next.text
        end = next.offset + next.text.length()
        for unit in next.text.to_array() {
          if unit == '"' {
            quote_count += 1
          }
        }
        if quote_count % 2 == 0 {
          break
        }
      }
    }
    if text.to_lower().find("if \"") is Some(position) && position > 0 {
      let prefix = part(text, 0, position)
      if legacy_edge(prefix + "\"__decision\"")
        is Some(Edge(from, arrow, _, label)) {
        let condition = after(part(text, position, text.length()), "if")
        let condition = if condition.to_lower().has_suffix("then") {
          trim(part(condition, 0, condition.length() - 4))
        } else {
          condition
        }
        legacy_seen = true
        emit(
          LegacyDecision(from, arrow, unquote(condition), label),
          scan.span(begin, end),
        )
        continue
      }
    }
    if legacy_edge(text) is Some(edge) {
      legacy_seen = true
      emit(edge, scan.span(begin, end))
      continue
    }
    let lower = text.to_lower()
    if lower.has_prefix("if \"") || lower.has_prefix("if\"") {
      legacy_seen = true
      let condition_text = after(text, "if")
      let condition_text = if condition_text.to_lower().has_suffix("then") {
        trim(part(condition_text, 0, condition_text.length() - 4))
      } else {
        condition_text
      }
      emit(LegacyIf(unquote(condition_text)), span)
      continue
    }
    if modern(text) is Some(kind) {
      if (match kind {
          Start
          | Stop
          | End
          | Action(_, _, _)
          | Connector(_)
          | While(_, _)
          | Repeat(_)
          | Fork
          | Split
          | Lane(_, _, _) => true
          _ => false
        }) {
        modern_seen = true
      }
      emit(kind, span)
    } else {
      error(
        "activity/syntax",
        "Unknown activity statement: " + text,
        Some(span),
      )
    }
  }
  for (name, span) in stack {
    error("activity/unclosed-control", "Unclosed " + name, Some(span))
  }
  if chosen == None {
    if modern_seen && legacy_seen {
      error(
        "activity/ambiguous-dialect",
        "Mixed activity dialects require an explicit supported grammar",
        None,
      )
    } else if modern_seen {
      chosen = Some(Modern)
    } else if legacy_seen {
      chosen = Some(Legacy)
    }
  }
  if chosen == None {
    error(
      "plantuml/unsupported-diagram",
      "The UML block is not an activity diagram",
      None,
    )
  }
  if (chosen == Some(Modern) && legacy_seen) ||
    (chosen == Some(Legacy) && modern_seen) {
    error(
      "activity/ambiguous-dialect",
      "Statements do not match the selected activity dialect",
      None,
    )
  }
  {
    nodes: ReadOnlyArray::from_array(nodes),
    document: chosen.map(dialect => {
      Document::new(
        dialect,
        items[:],
        name?=scan.name,
        statements=scan.statements[:],
      )
    }),
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
