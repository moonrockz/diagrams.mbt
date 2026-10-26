///|
pub struct Conversion {
  sequence : @model.Sequence?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub extend Conversion with Eq::{equal, not_equal}

///|
pub extend Conversion with @debug.Debug::{to_repr}

///|
fn lower(s : String) -> String {
  @icons.normalize_key(s)
}

///|
fn kind(key : String) -> @model.ParticipantKind {
  match lower(key) {
    "actor" => Actor
    "boundary" => Boundary
    "control" => Control
    "entity" => Entity
    "database" => Database
    "collections" => Collections
    "queue" => Queue
    _ => Participant
  }
}

///|
fn formatted(value : String) -> String {
  let out = StringBuilder()
  let units = value.to_array()
  let mut pending = false
  let mut suppress_space = true
  let mut quote : Char? = None
  let mut escaped = false
  let mut index = 0
  while index < units.length() {
    let c = units[index]
    if quote is Some(delimiter) {
      out.write_char(c)
      if escaped {
        escaped = false
      } else if c == '\\' {
        escaped = true
      } else if c == delimiter {
        if index + 1 < units.length() && units[index + 1] == delimiter {
          // Native CSTRING uses doubled quote delimiters inside a literal.
          index += 1
          out.write_char(units[index])
        } else {
          quote = None
        }
      }
      index += 1
      continue
    }
    if c == ' ' || c == '\t' || c == '\r' || c == '\n' {
      pending = true
      index += 1
      continue
    }
    let punctuation = [',', ';', '.', '(', ')'].contains(c)
    if pending && !punctuation && !suppress_space {
      out.write_char(' ')
    }
    pending = false
    out.write_char(c)
    if c == '"' || c == '\'' || c == '`' {
      quote = Some(c)
    }
    suppress_space = [',', ';', '.', '('].contains(c)
    index += 1
  }
  out.to_string()
}

///|
fn assignment_label(value : String) -> String {
  let words = value.split(" ").filter(s => s != "").to_array()
  words.last().map(s => s.to_owned()).unwrap_or(value)
}

///|
fn creation_label(operation : String) -> String {
  let value = operation.trim().to_owned()
  let value = if value.has_prefix("(") && value.has_suffix(")") {
    value[1:value.length() - 1].to_owned()
  } else {
    value
  }
  "«" +
  (if value.trim() == "" {
    "create"
  } else {
    formatted(value).trim().to_owned()
  }) +
  "»"
}

///|
fn statement_units(kind : @ast.StatementKind) -> Int32 {
  match kind {
    Participant(id~, label~, annotator~) =>
      id.length() +
      label.map(s => s.length()).unwrap_or(0) +
      annotator.map(s => s.length()).unwrap_or(0)
    Call(sender~, receiver~, operation~, assignment~, ..) =>
      sender.map(s => s.length()).unwrap_or(0) +
      receiver.length() +
      operation.length() +
      assignment.map(s => s.length()).unwrap_or(0)
    Async(sender~, receiver~, label~, ..) =>
      sender.length() + receiver.length() + label.length()
    Starter(text)
    | Return(text)
    | Comment(text)
    | Title(text)
    | Metadata(text) => text.length()
    Begin(keyword~, expression~) | Section(keyword~, expression~) =>
      keyword.length() + expression.length()
    End => 0
  }
}

///|
/// Convert explicit native scopes to ordered calls and balanced activations.
pub fn convert(
  diagram : @ast.Diagram,
  limits~ : @syntax.Limits = @syntax.Limits::new(),
) -> Conversion {
  let diagnostics = []
  let participants : Array[@model.Participant] = []
  let ids : Map[String, Int32] = Map([])
  let ends : Map[Int32, Int32] = Map([])
  let stack = []
  let mut title = None
  let mut work = 0
  let mut count = 0
  let mut starter = "_STARTER_"
  let mut failed = false
  let diagnostic_cap = if limits.diagnostics > 0 {
    limits.diagnostics
  } else {
    1
  }
  fn error(code : String, message : String, span : @diagrams.Span?) {
    failed = true
    if diagnostics.length() < diagnostic_cap {
      diagnostics.push(
        @diagrams.Diagnostic::error("zenuml/" + code, message, span?),
      )
    } else {
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "zenuml/diagnostic-limit",
        "Diagnostic limit exceeded",
        span?,
      )
    }
  }
  fn charge(n : Int32) -> Bool {
    if n < 0 || n > limits.work - work {
      error("work-limit", "Conversion work limit exceeded", None)
      false
    } else {
      work += n
      true
    }
  }
  fn ensure(
    id : String,
    label : String?,
    annotator : String?,
    declared : Bool,
    span : @diagrams.Span?,
  ) -> Unit {
    if annotator is Some(key) &&
      !@icons.known(@icons.Reference::new("zenuml", key)) {
      if diagnostics.length() >= diagnostic_cap {
        error("diagnostic-limit", "Diagnostic limit exceeded", span)
        return
      }
      diagnostics.push(
        @diagrams.Diagnostic::warning(
          "zenuml/unknown-annotator",
          "Unknown participant annotator " + key + " on " + id,
          span?,
        ),
      )
    }
    if ids.get(id) is Some(index) {
      if declared {
        let old = participants[index]
        if old.icon != None &&
          old.icon !=
          annotator.map(key => @icons.Reference::new("zenuml", lower(key))) {
          error(
            "participant-conflict",
            "Conflicting participant declaration: " + id,
            None,
          )
        } else {
          participants[index] = @model.Participant::new(
            id,
            label=label.unwrap_or(old.label),
            kind=annotator.map(kind).unwrap_or(old.kind),
            icon?=match annotator {
              Some(key) => Some(@icons.Reference::new("zenuml", lower(key)))
              None => old.icon
            },
          )
        }
      }
    } else {
      if participants.length() >= limits.participants {
        error("participant-limit", "Participant count limit exceeded", None)
        return
      }
      ids[id] = participants.length()
      participants.push(
        @model.Participant::new(
          id,
          label?,
          kind=if id == "_STARTER_" {
            Actor
          } else {
            annotator.map(kind).unwrap_or(Participant)
          },
          icon?=annotator.map(key => @icons.Reference::new("zenuml", lower(key))),
        ),
      )
    }
  }
  fn append(out : Array[@model.Event], event : @model.Event) {
    count += 1
    if count > limits.events {
      error("event-limit", "Converted event count limit exceeded", None)
    } else {
      out.push(event)
    }
  }
  if limits.depth < 0 ||
    limits.depth > 256 ||
    limits.events < 0 ||
    limits.participants < 0 ||
    limits.work < 0 ||
    limits.diagnostics < 1 {
    error("limits", "Invalid conversion limits", None)
    return {
      sequence: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics),
    }
  }
  let mut need_starter = !diagram.statements
    .iter()
    .any(statement => {
      match statement.kind {
        Participant(..) | Call(..) | Async(..) => true
        _ => false
      }
    })
  let mut call_depth = 0
  let nesting : Array[Bool] = []
  for statement in diagram.statements {
    match statement.kind {
      Starter(id) => starter = id
      Call(sender~, scope~, ..) => {
        if sender == None && call_depth == 0 {
          need_starter = true
        }
        if scope {
          nesting.push(true)
          call_depth += 1
        }
      }
      Begin(..) | Section(..) => nesting.push(false)
      End => if nesting.pop() is Some(true) { call_depth -= 1 }
      _ => ()
    }
  }
  if need_starter &&
    starter == "_STARTER_" &&
    diagram.statements
    .iter()
    .any(statement => statement.kind is Participant(id="_STARTER_", ..)) {
    error(
      "starter-collision",
      "Implicit starter identity collides with a declaration",
      None,
    )
  }
  if need_starter && starter == "_STARTER_" {
    ensure(starter, None, Some("actor"), false, None)
  }
  // Resolve declarations first, so aliases and symbols apply to every occurrence.
  for i, statement in diagram.statements {
    if !charge(1 + statement_units(statement.kind)) {
      break
    }
    match statement.kind {
      Participant(id~, label~, annotator~) =>
        ensure(id, label, annotator, true, Some(statement.span))
      Title(value) => title = Some(value)
      Starter(_) => ()
      Begin(..) | Section(..) | Call(scope=true, ..) => {
        stack.push(i)
        if stack.length() > limits.depth {
          error(
            "depth-limit",
            "Conversion depth limit exceeded",
            Some(statement.span),
          )
          break
        }
      }
      End =>
        match stack.pop() {
          Some(begin) => ends[begin] = i
          None => error("nesting", "Unmatched close", Some(statement.span))
        }
      _ => ()
    }
  }
  if stack.length() > 0 {
    error(
      "missing-brace",
      "Unclosed scope",
      Some(diagram.statements[stack[0]].span),
    )
  }
  fn events(
    start : Int32,
    end : Int32,
    caller : String?,
    targets : ArrayView[String],
    depth : Int32,
  ) -> Array[@model.Event] {
    let out = []
    let mut i = start
    let comments : Array[String] = []
    if depth > limits.depth {
      error("depth-limit", "Conversion depth limit exceeded", None)
      return out
    }
    fn note(people : ArrayView[String]) {
      if comments.length() > 0 {
        append(out, Note(@model.Note::new(Over, people, comments.join("\n"))))
        comments.clear()
      }
    }
    while i < end && !failed {
      if !charge(1) {
        break
      }
      let statement = diagram.statements[i]
      match statement.kind {
        Comment(text) => comments.push(text)
        Participant(..) | Title(_) | Starter(_) => comments.clear()
        Metadata(value) => {
          comments.clear()
          if diagnostics.length() < diagnostic_cap {
            diagnostics.push(
              @diagrams.Diagnostic::warning(
                "zenuml/presentation-metadata",
                "Source metadata is retained without changing library rendering: " +
                value,
                span=statement.span,
              ),
            )
          } else {
            error(
              "diagnostic-limit",
              "Diagnostic limit exceeded",
              Some(statement.span),
            )
          }
        }
        Async(sender~, receiver~, label~, reply~) => {
          ensure(sender, None, None, false, Some(statement.span))
          ensure(receiver, None, None, false, Some(statement.span))
          note([sender, receiver])
          append(
            out,
            Message(
              @model.Message::new(
                sender,
                receiver,
                if reply {
                  formatted(label).trim().to_owned()
                } else {
                  label
                },
                line=if reply { Dotted } else { Solid },
                receiver_head=if reply { OpenArrow } else { Async },
              ),
            ),
          )
        }
        Return(label) =>
          match (caller, targets.last()) {
            (Some(from), Some(to)) => {
              note([from, to])
              append(
                out,
                Message(
                  @model.Message::new(
                    from,
                    to,
                    formatted(label).trim().to_owned(),
                    line=Dotted,
                    receiver_head=OpenArrow,
                  ),
                ),
              )
            }
            _ =>
              error(
                "return-target",
                "Return has no enclosing caller",
                Some(statement.span),
              )
          }
        Call(sender~, receiver~, operation~, assignment~, creation~, scope~) => {
          let from = sender.unwrap_or(caller.unwrap_or(starter))
          if from == "_STARTER_" &&
            ids.contains(from) &&
            participants[ids[from]].kind != Actor {
            error(
              "starter-collision",
              "Implicit starter identity collides with a declaration",
              Some(statement.span),
            )
          }
          ensure(from, None, None, false, Some(statement.span))
          ensure(receiver, None, None, false, Some(statement.span))
          note([from, receiver])
          if creation {
            append(out, Create(receiver))
          }
          append(
            out,
            Message(
              @model.Message::new(
                from,
                receiver,
                if creation {
                  creation_label(operation)
                } else {
                  formatted(operation).trim().to_owned()
                },
              ),
            ),
          )
          append(out, Activate(receiver))
          if scope {
            let close = ends.get(i).unwrap_or(end)
            let next = targets.to_owned()
            next.push(from)
            out.append(events(i + 1, close, Some(receiver), next, depth + 1))
            i = close
          }
          if assignment is Some(value) && from != receiver {
            append(
              out,
              Message(
                @model.Message::new(
                  receiver,
                  from,
                  assignment_label(value),
                  line=Dotted,
                  receiver_head=OpenArrow,
                ),
              ),
            )
          }
          append(out, Deactivate(receiver))
        }
        Begin(keyword~, expression~) => {
          let sections : Array[@model.Section] = []
          let close = ends.get(i).unwrap_or(end)
          let role = if keyword == "try" {
            @model.SectionRole::Try
          } else {
            Plain
          }
          let body = if keyword == "par" {
            []
          } else {
            events(i + 1, close, caller, targets, depth + 1)
          }
          if keyword == "par" {
            let mut begin = i + 1
            while begin < close && !failed {
              let mut statement_at = begin
              while statement_at < close &&
                    diagram.statements[statement_at].kind is Comment(_) {
                statement_at += 1
              }
              if statement_at >= close {
                break
              }
              let native = diagram.statements[statement_at].kind
              let mut finish = match native {
                Call(scope=true, ..) | Begin(..) =>
                  ends.get(statement_at).unwrap_or(close) + 1
                _ => statement_at + 1
              }
              let chained = match native {
                Begin(keyword="if", ..) => "alt"
                Begin(keyword="try", ..) => "try"
                _ => ""
              }
              while finish < close && chained != "" {
                let mut look = finish
                while look < close &&
                      diagram.statements[look].kind is Comment(_) {
                  look += 1
                }
                if look >= close {
                  break
                }
                match diagram.statements[look].kind {
                  Section(keyword=section_word, ..) =>
                    if (
                        chained == "alt" &&
                        ["else", "else if"].contains(section_word)
                      ) ||
                      (
                        chained == "try" &&
                        ["catch", "finally"].contains(section_word)
                      ) {
                      finish = ends.get(look).unwrap_or(close) + 1
                    } else {
                      break
                    }
                  _ => break
                }
              }
              let branch = events(begin, finish, caller, targets, depth + 1)
              if !branch.is_empty() {
                sections.push(@model.Section::new(branch))
              }
              begin = finish
            }
            if sections.is_empty() {
              sections.push(@model.Section::new([]))
            }
          } else {
            sections.push(
              @model.Section::new(
                body,
                label?=if expression == "" { None } else { Some(expression) },
                role~,
              ),
            )
          }
          let frame_kind = match keyword {
            "if" => @model.FrameKind::Alt
            "opt" => Opt
            "par" => Par
            "try" => Try
            "break" => Break
            _ => Loop
          }
          let mut next = close + 1
          while next < end {
            let mut look = next
            let section_comments = []
            while look < end {
              match diagram.statements[look].kind {
                Comment(text) => {
                  section_comments.push(text)
                  look += 1
                }
                _ => break
              }
            }
            if look >= end {
              break
            }
            match diagram.statements[look].kind {
              Section(keyword=section_word, expression=label) => {
                let valid = (
                    frame_kind == Alt &&
                    ["else", "else if"].contains(section_word)
                  ) ||
                  (
                    frame_kind == Try &&
                    ["catch", "finally"].contains(section_word)
                  )
                if !valid {
                  break
                }
                let finish = ends.get(look).unwrap_or(end)
                let contents = events(
                  look + 1,
                  finish,
                  caller,
                  targets,
                  depth + 1,
                )
                if !section_comments.is_empty() {
                  contents.insert(
                    0,
                    Note(
                      @model.Note::new(
                        Over,
                        participants.map(p => p.id),
                        section_comments.join("\n"),
                      ),
                    ),
                  )
                }
                sections.push(
                  @model.Section::new(
                    contents,
                    label?=if label == "" { None } else { Some(label) },
                    role=if section_word == "catch" {
                      Catch
                    } else if section_word == "finally" {
                      Finally
                    } else {
                      Plain
                    },
                  ),
                )
                next = finish + 1
              }
              _ => break
            }
          }
          let people = participants.map(p => p.id)
          note(people)
          append(
            out,
            Frame(@model.Frame::new(frame_kind, sections[0], rest=sections[1:])),
          )
          i = next - 1
        }
        Section(..) =>
          error(
            "section",
            "Section has no matching frame",
            Some(statement.span),
          )
        End =>
          error("nesting", "Unexpected closing scope", Some(statement.span))
      }
      i += 1
    }
    out
  }
  let output = if failed {
    []
  } else {
    events(0, diagram.statements.length(), None, [], 0)
  }
  {
    sequence: if failed {
      None
    } else {
      Some(@model.Sequence::new(participants, output, title?))
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
/// Stable diagnostic codes emitted by this processing stage.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "zenuml/depth-limit", "zenuml/diagnostic-limit", "zenuml/event-limit", "zenuml/limits",
  "zenuml/missing-brace", "zenuml/nesting", "zenuml/participant-conflict", "zenuml/participant-limit",
  "zenuml/presentation-metadata", "zenuml/return-target", "zenuml/section", "zenuml/starter-collision",
  "zenuml/unknown-annotator", "zenuml/work-limit",
]
