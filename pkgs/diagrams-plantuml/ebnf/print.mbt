///|
priv struct Printer {
  limits : @envelope.Limits
  mut used : Int
  mut work : Int
  mut failure : @diagrams.Diagnostic?
}

///|
fn Printer::fail(self : Printer, message : String) -> String {
  if self.failure is None {
    self.failure = Some(
      @diagrams.Diagnostic::error(
        "ebnf/unrepresentable",
        "Cannot write the grammar: " + message,
      ),
    )
  }
  ""
}

///|
fn Printer::charge(self : Printer, text : String) -> String {
  self.work += 1
  if self.work > self.limits.work || text.length() > self.limits.output - self.used {
    if self.failure is None {
      self.failure = Some(
        @diagrams.Diagnostic::error("ebnf/limit", "EBNF output limit exceeded"),
      )
    }
    return ""
  }
  self.used += text.length()
  text
}

///|
fn note_text(p : Printer, text : String) -> String {
  if text.contains("*)") || text.contains("\n") {
    p.fail("a note on a term cannot contain '*)' or a line break")
  } else {
    "(* " + text + " *)"
  }
}

///|
fn leaf(p : Printer, body : String, notes : Notes) -> String {
  let above = notes.above.map(t => note_text(p, t) + " ").unwrap_or("")
  let below = notes.below.map(t => " " + note_text(p, t)).unwrap_or("")
  p.charge(above + body + below)
}

///|
fn valid_name(name : String) -> Bool {
  !name.is_empty() &&
  name.code_unit_at(0).to_int() != 45 &&
  name.iter().all(c => literal_char(c.to_int()))
}

///|
/// Levels: 0 alternation, 1 concatenation, 2 count, 3 primary.
fn expr_text(p : Printer, e : Expr, level : Int, depth : Int) -> String {
  if depth > p.limits.depth {
    return p.fail("the expression is too deep")
  }
  if p.failure is Some(_) {
    return ""
  }
  match e {
    Terminal(text, quote, notes, _) => {
      let q = if quote == Double { "\"" } else { "'" }
      if text.contains(q) {
        return p.fail("a terminal cannot contain its own quote character")
      }
      leaf(p, q + text + q, notes)
    }
    Name(name, notes, _) =>
      if valid_name(name) {
        leaf(p, name, notes)
      } else {
        p.fail("'\{name}' is not a valid rule name")
      }
    Special(text, notes, _) =>
      if text.contains("?") {
        p.fail("a special sequence cannot contain '?'")
      } else {
        leaf(p, "?" + text + "?", notes)
      }
    Concat(items) => {
      if items.length() < 2 {
        return p.fail("a concatenation needs two items")
      }
      let units : Array[String] = []
      for item in items {
        match item {
          Not(excluded, _) => {
            guard units.pop() is Some(left) else {
              return p.fail("an exclusion needs a term on its left")
            }
            units.push("(" + left + " - " + expr_text(p, excluded, 0, depth + 1) + ")")
          }
          Concat(_) => return p.fail("a nested concatenation is not flat")
          _ => units.push(expr_text(p, item, 1, depth + 1))
        }
      }
      let text = units.join(", ")
      if level > 1 {
        "(" + text + ")"
      } else {
        text
      }
    }
    Alt(items) => {
      if items.length() < 2 {
        return p.fail("an alternation needs two alternatives")
      }
      let parts = []
      for item in items {
        match item {
          Alt(_) => return p.fail("a nested alternation is not flat")
          Not(_, _) => return p.fail("an exclusion must follow a term")
          _ => parts.push(expr_text(p, item, 1, depth + 1))
        }
      }
      let text = parts.join(" | ")
      if level > 0 {
        "(" + text + ")"
      } else {
        text
      }
    }
    Optional(inner, _) => "[ " + expr_text(p, inner, 0, depth + 1) + " ]"
    ZeroOrMore(inner, _) => "{ " + expr_text(p, inner, 0, depth + 1) + " }"
    OneOrMore(inner, _) => "{ " + expr_text(p, inner, 0, depth + 1) + " }-"
    Count(count, inner, _) => {
      if !is_decimal(count) {
        return p.fail("a count must be a decimal number")
      }
      let text = count + " * " + expr_text(p, inner, 3, depth + 1)
      if level > 2 {
        "(" + text + ")"
      } else {
        text
      }
    }
    Not(_, _) => p.fail("an exclusion must follow a term")
  }
}

///|
let statement_words : Array[String] = [
  "title", "caption", "header", "footer", "legend", "skinparam", "skin", "scale", "hide",
  "show", "sprite", "rotate", "page", "minwidth", "mainframe",
]

///|
/// The canonical body of an EBNF document: one line per rule and per note
/// line, derived from typed values.
pub fn print_body(
  document : Document,
  limits? : @envelope.Limits = @envelope.Limits::new(),
) -> Result[String, ReadOnlyArray[@diagrams.Diagnostic]] {
  let p = Printer::{ limits, used: 0, work: 0, failure: None }
  let out = StringBuilder()
  for item in document.items {
    match item {
      Note(lines, _) => {
        if lines.is_empty() {
          ignore(p.fail("a note needs a line"))
        }
        for i, line in lines {
          let ends = line.has_suffix("*)")
          if line.contains("\n") || line != @envelope.trim(line) {
            ignore(p.fail("a note line cannot have a line break or outer spaces"))
          }
          if lines.length() == 1 {
            if line.contains("*)") {
              ignore(p.fail("a single-line note cannot contain '*)'"))
            }
            out.write_string(p.charge("(* " + line + " *)\n"))
          } else if i == 0 {
            if ends {
              ignore(p.fail("a note line cannot end with '*)'"))
            }
            out.write_string(p.charge("(* " + line + "\n"))
          } else if i == lines.length() - 1 {
            out.write_string(p.charge(line + " *)\n"))
          } else {
            if ends {
              ignore(p.fail("a note line cannot end with '*)'"))
            }
            out.write_string(p.charge(line + "\n"))
          }
        }
      }
      Rule(rule) => {
        if !valid_name(rule.name) {
          ignore(p.fail("'\{rule.name}' is not a valid rule name"))
        }
        if statement_words.contains(rule.name) {
          ignore(p.fail("a rule named '\{rule.name}' reads as a statement"))
        }
        if rule.above is Some(_) {
          ignore(p.fail("a note above a rule name cannot be written reliably"))
        }
        let below = match rule.below {
          Some(text) => " " + note_text(p, text)
          None => ""
        }
        let body = match rule.body {
          Some(e) => " " + expr_text(p, e, 0, 0)
          None => " "
        }
        let line = rule.name + below + " =" + body + ";"
        if @envelope.has_preprocessor_call(line) {
          ignore(p.fail("the rule text reads as a preprocessor call"))
        }
        out.write_string(p.charge(line + "\n"))
      }
    }
  }
  match p.failure {
    Some(d) => Err([d])
    None => Ok(out.to_string())
  }
}
