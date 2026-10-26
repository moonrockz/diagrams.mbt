///|
/// Characters that the reader gives a meaning outside a character set.
fn special(c : String) -> Bool {
  [
    "^", "$", "|", "[", "(", ")", "*", "+", "?", "{", ".", "\\",
  ].contains(c)
}

///|
priv struct Writer {
  out : StringBuilder
  limit : Int
  mut used : Int
  mut failure : String?
}

///|
fn Writer::write(self : Writer, text : String) -> Unit {
  if self.failure is Some(_) {
    return
  }
  if text.length() > self.limit - self.used {
    self.failure = Some("regex/limit")
    return
  }
  self.used += text.length()
  self.out.write_string(text)
}

///|
fn Writer::unrepresentable(self : Writer, message : String) -> Unit {
  if self.failure is None {
    self.failure = Some("regex/unrepresentable:" + message)
  }
}

///|
fn set_char(c : String) -> String {
  if c == "]" || c == "\\" || c == "-" || c == "^" {
    "\\" + c
  } else {
    c
  }
}

///|
fn class_text(kind : @model.ClassKind) -> String {
  match kind {
    Any => "."
    Shorthand(c) => "\\" + c.to_string()
    Property(name) => "\\p{" + name + "}"
    CodePoint(spelling) => spelling
    Posix(name) => "[[:" + name + ":]]"
  }
}

///|
fn anchor_text(kind : @model.AnchorKind) -> String {
  match kind {
    LineStart => "^"
    LineEnd => "$"
    InputStart => "\\A"
    InputEndBeforeNewline => "\\Z"
    InputEnd => "\\z"
    PreviousMatchEnd => "\\G"
    WordBoundary => "\\b"
    NonWordBoundary => "\\B"
  }
}

///|
/// A spelling that the reader reads back as `bounds`, or `None`.
fn bounds_text(bounds : @model.Bounds) -> String? {
  let canonical = @model.Bounds::new(
    bounds.min,
    max?=bounds.max,
    reluctant=bounds.reluctant,
  )
  if bounds.spelling == canonical.spelling {
    return Some(canonical.spelling)
  }
  match tokenize("a" + bounds.spelling, 0) {
    Ok([_, { lex: Quantifier(read), .. }]) if read == bounds => Some(bounds.spelling)
    _ => None
  }
}

///|
priv enum Job {
  Expr(Expr, Int)
  Text(String)
}

///|
/// Write a pattern from typed values. An expression that the reader cannot
/// read back to the same value gives a diagnostic instead of text.
pub fn print_pattern(
  expr : Expr,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  let w = Writer::{ out: StringBuilder(), limit: limits.output, used: 0, failure: None }
  // Contexts: 0 = alternative, 1 = concatenation item, 2 = quantified operand.
  let jobs : Array[Job] = [Expr(expr, 0)]
  let mut work = 0
  while jobs.pop() is Some(job) && w.failure is None {
    work += 1
    if work > limits.work {
      w.failure = Some("regex/limit")
      break
    }
    match job {
      Text(text) => w.write(text)
      Expr(e, context) =>
        match e {
          Char(c, escaped, _) => {
            let u = if c.is_empty() { 0 } else { c.code_unit_at(0).to_int() }
            let alphanumeric = is_letter_unit(u) || (u >= 48 && u <= 57)
            if code_point(c, 0).1 != c.length() || c.is_empty() {
              w.unrepresentable("a character holds one code point")
            } else if escaped {
              if alphanumeric {
                w.unrepresentable("an escaped letter or digit has another meaning")
              } else {
                w.write("\\" + c)
              }
            } else if special(c) {
              w.unrepresentable("an operator character must be escaped")
            } else {
              w.write(c)
            }
          }
          Class(kind, _) => w.write(class_text(kind))
          Backreference(n, _) =>
            if n.length() == 1 && n != "0" {
              w.write("\\" + n)
            } else {
              w.unrepresentable("a backreference has one digit from 1 to 9")
            }
          Set(negated, items, _) => {
            if items.is_empty() {
              w.unrepresentable("a character set needs an item")
            }
            w.write(if negated { "[^" } else { "[" })
            for i, item in items {
              match item {
                Char(c) =>
                  w.write(
                    if i == 0 && !negated && c == "^" {
                      "\\^"
                    } else {
                      set_char(c)
                    },
                  )
                Range(a, b) => w.write(set_char(a) + "-" + set_char(b))
                Escape(e) => w.write(e)
              }
            }
            w.write("]")
          }
          Anchor(kind, _) => w.write(anchor_text(kind))
          Concat(items) => {
            if items.length() < 2 {
              w.unrepresentable("a concatenation needs two items")
            }
            if context == 2 {
              w.unrepresentable("a quantified concatenation needs a group")
            }
            for i in 0..<items.length() {
              let item = items[items.length() - 1 - i]
              if item is (Concat(_) | Alt(_)) {
                w.unrepresentable("a nested sequence or choice needs a group")
              }
              jobs.push(Expr(item, 1))
            }
          }
          Alt(items) => {
            if items.length() < 2 {
              w.unrepresentable("an alternation needs two alternatives")
            }
            if context != 0 {
              w.unrepresentable("a choice inside a sequence needs a group")
            }
            for i in 0..<items.length() {
              let item = items[items.length() - 1 - i]
              if item is Alt(_) {
                w.unrepresentable("a nested choice needs a group")
              }
              jobs.push(Expr(item, 0))
              if i < items.length() - 1 {
                jobs.push(Text("|"))
              }
            }
          }
          Group(kind, inner, _) => {
            let open = match kind {
              Capturing => "("
              NonCapturing => "(?:"
              Named(name) => {
                if name.is_empty() ||
                  !name.iter().all(c => is_name_char(c.to_int())) {
                  w.unrepresentable("a group name has letters only")
                }
                "(?<" + name + ">"
              }
            }
            w.write(open)
            jobs.push(Text(")"))
            jobs.push(Expr(inner, 0))
          }
          Look(look, positive, inner, _) => {
            w.write(
              match (look, positive) {
                (Ahead, true) => "(?="
                (Ahead, false) => "(?!"
                (Behind, true) => "(?<="
                (Behind, false) => "(?<!"
              },
            )
            jobs.push(Text(")"))
            jobs.push(Expr(inner, 0))
          }
          Quantified(inner, bounds, _) =>
            match bounds_text(bounds) {
              None => w.unrepresentable("the quantifier spelling is invalid")
              Some(text) => {
                // `x*?` reads as one reluctant quantifier, not two.
                if text.has_prefix("?") &&
                  inner is Quantified(_, { reluctant: false, .. }, _) {
                  w.unrepresentable("an optional quantifier after a greedy quantifier reads as reluctant")
                }
                jobs.push(Text(text))
                jobs.push(Expr(inner, 2))
              }
            }
        }
    }
  }
  match w.failure {
    None => {
      let text = w.out.to_string()
      // A body line must not read as a comment, directive or statement.
      let leading = text.has_prefix("'") ||
        text.has_prefix("!") ||
        text.has_prefix("/'") ||
        text.has_prefix("@") ||
        text.has_prefix(" ") ||
        text.has_prefix("\t") ||
        text.has_suffix(" ") ||
        text.has_suffix("\t") ||
        @envelope.has_preprocessor_call(text)
      let first = text.split(" ").next().map(s => s.to_owned()).unwrap_or("")
      let statement = [
        "title", "caption", "header", "footer", "legend", "skinparam", "skin", "scale",
        "hide", "show", "sprite", "rotate", "page", "minwidth", "mainframe", "<style>",
      ].contains(first) ||
        text.has_prefix("title:")
      if text.is_empty() {
        Err([
          @diagrams.Diagnostic::error(
            "regex/unrepresentable", "An empty pattern cannot be written",
          ),
        ])
      } else if leading || statement {
        Err([
          @diagrams.Diagnostic::error(
            "regex/unrepresentable", "The pattern text would read as a comment, directive or statement",
          ),
        ])
      } else {
        Ok(text)
      }
    }
    Some(code) =>
      if code.has_prefix("regex/unrepresentable:") {
        Err([
          @diagrams.Diagnostic::error(
            "regex/unrepresentable",
            "Cannot write the pattern: " + @cst.slice(code, 22, code.length()),
          ),
        ])
      } else {
        Err([@diagrams.Diagnostic::error(code, "Regex output limit exceeded")])
      }
  }
}

///|
/// The canonical body of a regex document: one pattern line with a line break.
pub fn print_body(
  document : Document,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  match print_pattern(document.pattern, limits~) {
    Ok(text) => Ok(text + "\n")
    Err(e) => Err(e)
  }
}
