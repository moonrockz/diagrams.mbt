///|
/// The tokens of `node` that are not whitespace or line breaks.
fn significant(node : @cst.Node) -> Array[@cst.Token] {
  node.tokens().filter(t => t.kind != Whitespace && t.kind != Newline)
}

///|
fn texts_of(tokens : Array[@cst.Token], kind : @cst.TokenKind) -> Array[String] {
  tokens.filter(t => t.kind == kind).map(t => t.text)
}

///|
fn first_text(tokens : Array[@cst.Token]) -> String {
  match tokens.iter().find_first(t => t.kind == Text) {
    Some(t) => t.text
    None => ""
  }
}

///|
fn has_keyword(tokens : Array[@cst.Token], word : String) -> Bool {
  tokens.iter().any(t => t.kind == Keyword && t.text.to_lower() == word)
}

///|
fn trim(s : String) -> String {
  s.trim(chars=" \t\r\n").to_owned()
}

///|
fn frame_kind(word : String) -> FrameKind? {
  match word {
    "loop" => Some(Loop)
    "rect" => Some(Rect)
    "opt" => Some(Opt)
    "alt" => Some(Alt)
    "par" => Some(Par)
    "par_over" => Some(ParOver)
    "critical" => Some(Critical)
    "break" => Some(Break)
    _ => None
  }
}

///|
/// The statement of one CST statement node, or `None` for a node that is not
/// a statement, such as an error node.
fn statement(source : String, node : @cst.Node) -> Statement? {
  let tokens = significant(node)
  guard tokens.last() is Some(last) else { return None }
  let span = @cst.span(source, tokens[0].offset, last.offset + last.text.length())
  let names = texts_of(tokens, Identifier)
  let kind : StatementKind = match node.kind {
    Participant => {
      let keyword : ParticipantKeyword = if has_keyword(tokens, "actor") {
        Actor
      } else {
        Participant
      }
      let config = match tokens.iter().find_first(t => t.kind == Config) {
        Some(t) => Some(trim(t.text))
        None => None
      }
      let label = if has_keyword(tokens, "as") {
        Some(first_text(tokens))
      } else {
        None
      }
      Participant({
        created: has_keyword(tokens, "create"),
        keyword,
        id: names[0],
        config,
        label,
      })
    }
    Destroy => Destroy(names[0])
    Activate => Activate(names[0])
    Deactivate => Deactivate(names[0])
    Message => {
      let arrow_at = match tokens.search_by(t => t.kind == Arrow) {
        Some(i) => i
        None => return None
      }
      let mut activation : Activation? = None
      let mut before = false
      let mut after = false
      for i, t in tokens {
        if t.kind == Modifier {
          if i < arrow_at {
            before = true
          } else if t.text == "()" {
            after = true
          } else {
            activation = Some(if t.text == "+" { Activate } else { Deactivate })
          }
        }
      }
      Message({
        sender: names[0],
        arrow: tokens[arrow_at].text,
        receiver: names[1],
        text: first_text(tokens),
        activation,
        central_before: before,
        central_after: after,
      })
    }
    Note => {
      let placement : Placement = if has_keyword(tokens, "over") {
        Over
      } else if has_keyword(tokens, "left of") {
        LeftOf
      } else {
        RightOf
      }
      Note({
        placement,
        participants: ReadOnlyArray::from_array(names),
        text: first_text(tokens),
      })
    }
    Link | Links | Properties | Details => {
      let kind : LinkKind = match node.kind {
        Link => Link
        Links => Links
        Properties => Properties
        _ => Details
      }
      Link({ kind, participant: names[0], text: first_text(tokens) })
    }
    Title => Title(first_text(tokens))
    AccTitle => AccTitle(first_text(tokens))
    AccDescr => AccDescr(trim(first_text(tokens)))
    Autonumber => {
      let numbers = texts_of(tokens, Number)
      if has_keyword(tokens, "off") {
        Autonumber(Off)
      } else {
        Autonumber(On(start=numbers.get(0), step=numbers.get(1)))
      }
    }
    Block => {
      let parts = node.nodes()
      guard parts.length() > 0 && parts[0].kind == BlockStart else { return None }
      let opener = significant(parts[0])
      let word = opener[0].text.to_lower()
      let sections : Array[(String, Array[Statement])] = [(first_text(opener), [])]
      for part in parts[1:] {
        match part.kind {
          Section => sections.push((first_text(significant(part)), []))
          BlockEnd => ()
          _ =>
            if statement(source, part) is Some(s) {
              sections[sections.length() - 1].1.push(s)
            }
        }
      }
      if word == "box" {
        Box({
          label: sections[0].0,
          statements: ReadOnlyArray::from_array(sections[0].1),
        })
      } else {
        guard frame_kind(word) is Some(kind) else { return None }
        Frame({
          kind,
          sections: ReadOnlyArray::from_array(
            sections.map(s => {
              label: s.0,
              statements: ReadOnlyArray::from_array(s.1),
            }),
          ),
        })
      }
    }
    _ => return None
  }
  Some({ kind, span })
}

///|
/// The typed AST of a lossless syntax tree. Error nodes are not in the AST,
/// because the parser already reported them. A tree without the
/// `sequenceDiagram` header gives `None`.
pub fn lower(tree : @cst.Node) -> Diagram? {
  let source = tree.text()
  let nodes = tree.nodes()
  guard nodes.iter().any(n => n.kind == Header) else { return None }
  let statements = []
  for node in nodes {
    if statement(source, node) is Some(s) {
      statements.push(s)
    }
  }
  let front_matter = match
    tree.tokens().iter().find_first(t => t.kind == FrontMatter) {
    Some(t) => Some(t.text)
    None => None
  }
  let directives = texts_of(tree.tokens(), Directive)
  Some(Diagram::new(statements, front_matter?, directives~))
}
