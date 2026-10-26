///|
pub struct Limits {
  source : Int32
  output : Int32
  nodes : Int32
  edges : Int32
  alignments : Int32
  depth : Int32
  diagnostics : Int32
  work : Int32
} derive(Eq, Debug)

///|
pub fn Limits::new(
  source~ : Int32 = 16777216,
  output~ : Int32 = 16777216,
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  alignments~ : Int32 = 10000,
  depth~ : Int32 = 256,
  diagnostics~ : Int32 = 256,
  work~ : Int32 = 1000000,
) -> Limits {
  { source, output, nodes, edges, alignments, depth, diagnostics, work, }
}

///|
pub struct ReadResult {
  tree : @cst.Node
  ast : @ast.Diagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "architecture/syntax", "architecture/header", "architecture/source-limit", "architecture/output-limit",
  "architecture/node-limit", "architecture/edge-limit", "architecture/alignment-limit",
  "architecture/work-limit", "architecture/diagnostic-limit", "architecture/metadata-option",
]

///|
pub fn trim(value : String) -> String {
  let mut a = 0
  let mut b = value.length()
  while a < b && [9, 10, 13, 32].contains(value.code_unit_at(a).to_int()) {
    a += 1
  }
  while b > a && [9, 10, 13, 32].contains(value.code_unit_at(b - 1).to_int()) {
    b -= 1
  }
  value[a:b].to_owned()
}

///|
priv struct Cursor {
  text : String
  mut at : Int32
  mut valid : Bool
}

///|
fn code(c : Cursor) -> Int32 {
  if c.at < c.text.length() {
    c.text.code_unit_at(c.at).to_int()
  } else {
    0
  }
}

///|
fn skip(c : Cursor) -> Unit {
  while [9, 32].contains(code(c)) {
    c.at += 1
  }
}

///|
fn take(c : Cursor, value : String) -> Bool {
  skip(c)
  if c.text[c.at:].has_prefix(value) {
    c.at += value.length()
    true
  } else {
    false
  }
}

///|
fn id(c : Cursor) -> String {
  skip(c)
  let start = c.at
  let mut last = 0
  while c.at < c.text.length() {
    let n = code(c)
    if (n >= 48 && n <= 57) ||
      (n >= 65 && n <= 90) ||
      (n >= 97 && n <= 122) ||
      n == 95 ||
      (n == 45 && c.at > start) {
      c.at += 1
      last = n
    } else {
      break
    }
  }
  let name = c.text[start:c.at].to_owned()
  if c.at == start ||
    last == 45 ||
    [
      "L", "R", "T", "B", "group", "service", "junction", "align", "row", "column",
      "in", "architecture-beta",
    ].contains(name) {
    c.valid = false
  }
  name
}

///|
fn delimited(c : Cursor, open : Int32, close : Int32) -> String? {
  skip(c)
  if code(c) != open {
    return None
  }
  c.at += 1
  let start = c.at
  let mut quote = 0
  let mut escaped = false
  while c.at < c.text.length() {
    let n = code(c)
    if escaped {
      escaped = false
      c.at += 1
      continue
    }
    if n == 92 && quote != 0 {
      escaped = true
      c.at += 1
      continue
    }
    if n == 34 || n == 39 {
      if quote == n {
        quote = 0
      } else if quote == 0 {
        quote = n
      }
    }
    if n == close && quote == 0 {
      let value = c.text[start:c.at].to_owned()
      c.at += 1
      if value == "" {
        c.valid = false
      }
      if open == 40 &&
        !value
        .iter()
        .all(ch => {
          let n = ch.to_int()
          (n >= 48 && n <= 57) ||
          (n >= 65 && n <= 90) ||
          (n >= 97 && n <= 122) ||
          [95, 45, 58].contains(n)
        }) {
        c.valid = false
      }
      return Some(unquote(trim(value)))
    }
    if (n == 10 || n == 13 || n == open) && quote == 0 {
      c.valid = false
      return None
    }
    c.at += 1
  }
  c.valid = false
  None
}

///|
pub fn unquote(value : String) -> String {
  if value.length() >= 2 &&
    (
      (value.has_prefix("\"") && value.has_suffix("\"")) ||
      (value.has_prefix("'") && value.has_suffix("'"))
    ) {
    let value = value[1:value.length() - 1]
    let out = StringBuilder()
    let mut i = 0
    while i < value.length() {
      if value.code_unit_at(i).to_int() == 92 && i + 1 < value.length() {
        i += 1
      }
      let n = value.code_unit_at(i).to_int()
      let width = if n >= 55296 && n <= 56319 && i + 1 < value.length() {
        2
      } else {
        1
      }
      out.write_string(value[i:i + width].to_owned())
      i += width
    }
    out.to_string()
  } else {
    value
  }
}

///|
fn quoted(c : Cursor) -> String? {
  skip(c)
  let q = code(c)
  if q != 34 && q != 39 {
    return None
  }
  let start = c.at
  c.at += 1
  let mut escaped = false
  while c.at < c.text.length() {
    let n = code(c)
    c.at += 1
    if escaped {
      escaped = false
    } else if n == 92 {
      escaped = true
    } else if n == q {
      return Some(unquote(c.text[start:c.at].to_owned()))
    }
  }
  c.valid = false
  None
}

///|
fn parent(c : Cursor) -> String? {
  if take(c, "in ") || take(c, "in\t") {
    Some(id(c))
  } else {
    None
  }
}

///|
fn side(c : Cursor) -> @model.Side? {
  skip(c)
  let n = code(c)
  c.at += if n == 0 { 0 } else { 1 }
  match n {
    76 => Some(Left)
    82 => Some(Right)
    84 => Some(Top)
    66 => Some(Bottom)
    _ => {
      c.valid = false
      None
    }
  }
}

///|
fn statement(text : String) -> @ast.StatementKind? {
  let c = Cursor::{ text, at: 0, valid: true, }
  let kind = if take(c, "group ") || take(c, "group\t") {
    let name = id(c)
    let icon = delimited(c, 40, 41)
    let label = delimited(c, 91, 93)
    let p = parent(c)
    Some(@ast.StatementKind::Group(id=name, icon~, label~, parent=p))
  } else if take(c, "service ") || take(c, "service\t") {
    let name = id(c)
    let icon_text = quoted(c)
    let icon = if icon_text == None { delimited(c, 40, 41) } else { None }
    let label = delimited(c, 91, 93)
    let p = parent(c)
    Some(
      @ast.StatementKind::Service(id=name, icon~, icon_text~, label~, parent=p),
    )
  } else if take(c, "junction ") || take(c, "junction\t") {
    let name = id(c)
    let p = parent(c)
    Some(@ast.StatementKind::Junction(id=name, parent=p))
  } else if take(c, "align ") || take(c, "align\t") {
    let axis = if take(c, "row") {
      Some(@model.Axis::Row)
    } else if take(c, "column") {
      Some(@model.Axis::Column)
    } else {
      None
    }
    let members = []
    while c.at < c.text.length() && c.valid {
      skip(c)
      if c.at == c.text.length() {
        break
      }
      members.push(id(c))
    }
    if axis is Some(axis) && members.length() >= 2 {
      Some(
        @ast.StatementKind::Alignment(
          axis~,
          members=ReadOnlyArray::from_array(members[:]),
        ),
      )
    } else {
      None
    }
  } else {
    let lhs = id(c)
    let lhs_group = take(c, "{group}")
    if !take(c, ":") {
      return None
    }
    let lhs_side = side(c)
    let source_head = take(c, "<") || take(c, ">")
    if !take(c, "-") {
      return None
    }
    let label = delimited(c, 91, 93)
    if !take(c, "-") {
      return None
    }
    let target_head = take(c, ">") || take(c, "<")
    let rhs_side = side(c)
    if !take(c, ":") {
      return None
    }
    let rhs = id(c)
    let rhs_group = take(c, "{group}")
    match (lhs_side, rhs_side) {
      (Some(a), Some(b)) =>
        Some(
          @ast.StatementKind::Edge(
            source=@model.Endpoint::new(lhs, a, group=lhs_group),
            target=@model.Endpoint::new(rhs, b, group=rhs_group),
            label~,
            source_head~,
            target_head~,
          ),
        )
      _ => None
    }
  }
  skip(c)
  if !c.valid || c.at != text.length() {
    None
  } else {
    kind
  }
}

///|
pub fn read(source : String, limits~ : Limits = Limits::new()) -> ReadResult {
  let tokens : Array[@cst.Token] = []
  let statements : Array[@ast.Statement] = []
  let diagnostics = []
  let directives = []
  let mut front_matter : String? = None
  let mut header = false
  let mut fatal = false
  let mut nodes = 0
  let mut edges = 0
  let mut alignments = 0
  let mut work = 0
  fn error(code : String, text : String, start : Int32, end : Int32) {
    if diagnostics.length() < limits.diagnostics.max(1) {
      diagnostics.push(
        @diagrams.Diagnostic::error(
          "architecture/" + code,
          text,
          span=@positions.span(source, start, end),
        ),
      )
    } else {
      fatal = true
      diagnostics[diagnostics.length() - 1] = @diagrams.Diagnostic::error(
        "architecture/diagnostic-limit", "Diagnostic budget exhausted",
      )
    }
  }
  if source.length() > limits.source || limits.source < 0 {
    error("source-limit", "Source budget exhausted", 0, 0)
    return {
      tree: @cst.Node::new([{ kind: Error, text: source, offset: 0, }]),
      ast: None,
      diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
    }
  }
  let mut offset = 0
  while offset < source.length() && !fatal {
    let start = offset
    let mut end = offset
    let mut quote = 0
    let mut escaped = false
    let mut first_newline = None
    let mut comment = false
    let mut begin = start
    while begin < source.length() &&
          [9, 32].contains(source.code_unit_at(begin).to_int()) {
      begin += 1
    }
    let plain = ["title ", "title\t", "accTitle", "accDescr", "%%"]
      .iter()
      .any(prefix => source[begin:].has_prefix(prefix))
    while end < source.length() {
      work += 1
      if work > limits.work {
        fatal = true
        break
      }
      let n = source.code_unit_at(end).to_int()
      if n == 10 {
        if first_newline == None {
          first_newline = Some(end)
        }
        if quote == 0 {
          break
        }
      }
      if plain || comment {
        end += 1
        continue
      }
      if n == 37 &&
        end + 1 < source.length() &&
        source.code_unit_at(end + 1).to_int() == 37 &&
        quote == 0 {
        comment = true
        end += 1
        continue
      }
      if escaped {
        escaped = false
      } else if n == 92 && quote != 0 {
        escaped = true
      } else if n == 34 || n == 39 {
        if quote == n {
          quote = 0
        } else if quote == 0 {
          quote = n
        }
      }
      end += 1
    }
    if quote != 0 && end == source.length() {
      if first_newline is Some(newline) {
        end = newline
      }
    }
    let scan_end = end
    let mut text = trim(source[start:end].to_owned())
    let mut token_kind : @cst.TokenKind = Statement
    if text == "---" && !header {
      let mut close = end + 1
      while close < source.length() {
        let mut e = close
        while e < source.length() && source.code_unit_at(e).to_int() != 10 {
          e += 1
        }
        if trim(source[close:e].to_owned()) == "---" {
          end = e
          break
        }
        close = e + 1
      }
      front_matter = Some(source[start:end].to_owned())
      token_kind = FrontMatter
    } else if text.has_prefix("%%{") {
      match source[start:].find("}%%") {
        Some(i) => {
          end = start + i + 3
          directives.push(source[start:end].to_owned())
          token_kind = Directive
        }
        None => {
          error("syntax", "Unterminated directive", start, end)
          token_kind = Error
        }
      }
    } else if text.has_prefix("%%") {
      token_kind = Comment
      statements.push({
        kind: @ast.StatementKind::Comment(text),
        span: @positions.span(source, start, end),
      })
    } else if text == "" {
      token_kind = Whitespace
    } else if !header {
      if text == "architecture-beta" ||
        text.has_prefix("architecture-beta ") ||
        text.has_prefix("architecture-beta\t") {
        header = true
        token_kind = Header
        let suffix = trim(text[17:].to_owned())
        if suffix != "" {
          match statement(suffix) {
            Some(kind) => {
              match kind {
                Group(..) | Service(..) | Junction(..) => nodes += 1
                Edge(..) => edges += 1
                Alignment(..) => alignments += 1
                _ => ()
              }
              statements.push({
                kind,
                span: @positions.span(source, start, end),
              })
            }
            None =>
              error(
                "syntax", "Invalid statement after architecture header", start, end,
              )
          }
        }
      } else {
        error("header", "Expected architecture-beta", start, end)
        token_kind = Error
      }
    } else {
      let mut comment_at = 0
      let mut q = 0
      let mut bracket = 0
      while comment_at + 1 < text.length() {
        let n = text.code_unit_at(comment_at).to_int()
        if n == 34 || n == 39 {
          if q == n {
            q = 0
          } else if q == 0 {
            q = n
          }
        }
        if q == 0 && n == 91 {
          bracket += 1
        }
        if q == 0 && n == 93 {
          bracket -= 1
        }
        if q == 0 && bracket == 0 && text[comment_at:].has_prefix("%%") {
          text = trim(text[:comment_at].to_owned())
          break
        }
        comment_at += 1
      }
      let kind = if text == "title" {
        Some(@ast.StatementKind::Title(""))
      } else if text.has_prefix("title ") || text.has_prefix("title\t") {
        Some(@ast.StatementKind::Title(trim(text[5:].to_owned())))
      } else if text.has_prefix("accTitle:") || text.has_prefix("accTitle :") {
        let i = text.find(":").unwrap()
        Some(@ast.StatementKind::AccTitle(trim(text[i + 1:].to_owned())))
      } else if text.has_prefix("accDescr") {
        if text.contains("{") {
          let open = start + source[start:end].find("{").unwrap()
          match source[open + 1:].find("}") {
            Some(i) => {
              end = open + 1 + i + 1
              Some(
                @ast.StatementKind::AccDescription(
                  trim(source[open + 1:end - 1].to_owned()),
                ),
              )
            }
            None => None
          }
        } else {
          match text.find(":") {
            Some(i) =>
              Some(
                @ast.StatementKind::AccDescription(
                  trim(text[i + 1:].to_owned()),
                ),
              )
            None => None
          }
        }
      } else {
        statement(text)
      }
      match kind {
        Some(kind) => {
          match kind {
            Group(..) | Service(..) | Junction(..) => nodes += 1
            Edge(..) => edges += 1
            Alignment(..) => alignments += 1
            _ => ()
          }
          statements.push({ kind, span: @positions.span(source, start, end), })
        }
        None => {
          error("syntax", "Invalid architecture statement", start, end)
          token_kind = Error
        }
      }
    }
    work += (end - scan_end).max(0)
    if work > limits.work {
      error("work-limit", "Reader work budget exhausted", start, end)
      fatal = true
    }
    if nodes > limits.nodes {
      error("node-limit", "Node budget exhausted", start, end)
      fatal = true
    }
    if edges > limits.edges {
      error("edge-limit", "Edge budget exhausted", start, end)
      fatal = true
    }
    if alignments > limits.alignments {
      error("alignment-limit", "Alignment budget exhausted", start, end)
      fatal = true
    }
    offset = if end < source.length() && source.code_unit_at(end).to_int() == 10 {
      end + 1
    } else {
      end
    }
    tokens.push({
      kind: token_kind,
      text: source[start:offset].to_owned(),
      offset: start,
    })
  }
  if offset < source.length() {
    tokens.push({ kind: Error, text: source[offset:].to_owned(), offset, })
  }
  if !header {
    error("header", "Missing architecture-beta header", 0, 0)
  }
  {
    tree: @cst.Node::new(tokens[:]),
    ast: if fatal || !header {
      None
    } else {
      Some(
        @ast.Diagram::new(
          statements[:],
          front_matter?,
          directives=directives[:],
        ),
      )
    },
    diagnostics: ReadOnlyArray::from_array(diagnostics[:]),
  }
}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend ReadResult with Eq::{equal, not_equal}

///|
pub extend ReadResult with @debug.Debug::{to_repr}
