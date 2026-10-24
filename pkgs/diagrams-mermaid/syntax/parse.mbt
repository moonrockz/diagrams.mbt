///|
/// The lossless syntax tree of a source and the syntax diagnostics.
pub struct ParseResult {
  tree : @cst.Node
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Every diagnostic code that the parser gives.
pub let diagnostic_codes : ReadOnlyArray[String] = [
  "mermaid/missing-header", "mermaid/unexpected-header", "mermaid/unknown-statement",
  "mermaid/missing-message-text", "mermaid/invalid-message", "mermaid/invalid-participant",
  "mermaid/invalid-note", "mermaid/invalid-autonumber", "mermaid/invalid-link", "mermaid/invalid-title",
  "mermaid/missing-end", "mermaid/unexpected-end", "mermaid/misplaced-section", "mermaid/invalid-in-box",
  "mermaid/unclosed-directive", "mermaid/unclosed-description",
]

///|
/// An open frame: its keyword, the span of the keyword, and its children.
priv struct Frame {
  keyword : String
  start : Int
  end : Int
  children : Array[@cst.Element]
}

///|
/// True when the section keyword `section` can be in a frame of `keyword`.
fn accepts(keyword : String, section : String) -> Bool {
  match (keyword, section) {
    ("alt", "else") => true
    ("par", "and") | ("par_over", "and") => true
    ("critical", "option") => true
    _ => false
  }
}

///|
/// Take front matter at the start of the source: a `---` line, its body, and
/// a closing `---` line with the same indentation that a line break follows.
fn Scanner::front_matter(self : Scanner, out : Array[@cst.Element]) -> Unit {
  let mut i = 0
  while is_hspace(self.cu(i)) {
    i += 1
  }
  let indent = self.slice(0, i)
  guard self.starts(i, "---") else { return }
  let mut j = i + 3
  while is_hspace(self.cu(j)) {
    j += 1
  }
  guard is_newline(self.cu(j)) else { return }
  let mut line = j
  while line < self.src.length() {
    let next = if self.cu(line) == '\r'.to_int() && self.cu(line + 1) == '\n'.to_int() {
      line + 2
    } else {
      line + 1
    }
    if self.starts(next, "\{indent}---") {
      let mut e = next + indent.length() + 3
      while is_hspace(self.cu(e)) {
        e += 1
      }
      if is_newline(self.cu(e)) {
        out.push(self.token(FrontMatter, 0, e))
        self.pos = e
        return
      }
    }
    line = self.line_end(next)
    if line == next && !is_newline(self.cu(line)) {
      return
    }
  }
}

///|
/// Take trivia at the cursor: spaces, a line break, a semicolon, a directive
/// or a comment. Gives false when the cursor is at a statement.
fn Scanner::trivia(self : Scanner, out : Array[@cst.Element]) -> Bool {
  let i = self.pos
  let c = self.cu(i)
  if self.space(out) {
    true
  } else if c == '\r'.to_int() && self.cu(i + 1) == '\n'.to_int() {
    out.push(self.token(Newline, i, i + 2))
    self.pos = i + 2
    true
  } else if is_newline(c) {
    out.push(self.token(Newline, i, i + 1))
    self.pos = i + 1
    true
  } else if c == ';'.to_int() {
    out.push(self.token(Separator, i, i + 1))
    self.pos = i + 1
    true
  } else if self.starts(i, "%%{") {
    let end = match self.src.view(start_offset=i + 3).find("}%%") {
      Some(k) => i + 3 + k + 3
      None => {
        self.error(
          "mermaid/unclosed-directive", "the directive has no closing `}%%`",
          i,
          i + 3,
        )
        self.src.length()
      }
    }
    out.push(self.token(Directive, i, end))
    self.pos = end
    true
  } else if self.comment_at(i) {
    let end = self.line_end(i)
    out.push(self.token(Comment, i, end))
    self.pos = end
    true
  } else {
    false
  }
}

///|
/// The end of a statement that did not parse: the next semicolon or line
/// break, without the spaces before it.
fn Scanner::error_end(self : Scanner, start : Int) -> Int {
  let mut j = start
  while j < self.src.length() {
    let entity = self.entity_at(j)
    if entity > 0 {
      j += entity
    } else if is_newline(self.cu(j)) || self.cu(j) == ';'.to_int() {
      break
    } else {
      j += 1
    }
  }
  self.trim_back(start, j)
}

///|
/// Parse a Mermaid sequence diagram, as the Mermaid 12.2.0 grammar reads it.
/// The text of the tree is always equal to `source`. A statement that does not
/// parse becomes an error node with a diagnostic, and the parser continues at
/// the next statement.
pub fn parse(source : String) -> ParseResult {
  let s = Scanner::new(source)
  let root : Array[@cst.Element] = []
  let stack : Array[Frame] = []
  let mut header = false
  let mut reported = false
  s.front_matter(root)
  while !s.at_end() {
    let target = match stack.last() {
      Some(f) => f.children
      None => root
    }
    if s.trivia(target) {
      continue
    }
    let start = s.pos
    let tokens = []
    let (kind, event, failed) = s.statement(tokens)
    let node_kind = match failed {
      Some(f) => {
        let end = s.error_end(start)
        s.pos = end
        tokens.clear()
        tokens.push(s.token(Unknown, start, end))
        s.error(f.code, f.message, start, end)
        @cst.NodeKind::Error
      }
      None => kind
    }
    let end = s.pos
    if !header && !reported && !(event is Header) {
      reported = true
      s.error(
        "mermaid/missing-header", "a sequence diagram starts with `sequenceDiagram`",
        start,
        end,
      )
    }
    let in_box = match stack.last() {
      Some(f) => f.keyword == "box"
      None => false
    }
    if in_box &&
      node_kind != Error &&
      node_kind != Participant &&
      node_kind != Destroy &&
      !(event is Close) {
      s.error(
        "mermaid/invalid-in-box", "a box can only have participant declarations",
        start,
        end,
      )
    } else if in_box && node_kind == Participant && s.keyword_at(start, "create") {
      s.error(
        "mermaid/invalid-in-box", "a box can only have participant declarations",
        start,
        end,
      )
    }
    if node_kind == Error {
      target.push(Node(@cst.Node::new(Error, tokens)))
      continue
    }
    match event {
      Header => {
        if header {
          s.error(
            "mermaid/unexpected-header", "a sequence diagram has one `sequenceDiagram` header",
            start,
            end,
          )
          target.push(Node(@cst.Node::new(Error, tokens)))
          continue
        }
        header = true
        target.push(Node(@cst.Node::new(Header, tokens)))
      }
      Plain => target.push(Node(@cst.Node::new(node_kind, tokens)))
      Open(word) =>
        stack.push({
          keyword: word,
          start,
          end: start + word.length(),
          children: [Node(@cst.Node::new(BlockStart, tokens))],
        })
      Section(word) =>
        match stack.last() {
          Some(f) if accepts(f.keyword, word) =>
            f.children.push(Node(@cst.Node::new(Section, tokens)))
          _ => {
            s.error(
              "mermaid/misplaced-section", "`\{word}` can only be in a frame that allows it",
              start,
              end,
            )
            target.push(Node(@cst.Node::new(Error, tokens)))
          }
        }
      Close =>
        match stack.pop() {
          Some(f) => {
            f.children.push(Node(@cst.Node::new(BlockEnd, tokens)))
            let parent = match stack.last() {
              Some(p) => p.children
              None => root
            }
            parent.push(Node(@cst.Node::new(Block, f.children)))
          }
          None => {
            s.error("mermaid/unexpected-end", "this `end` has no open frame", start, end)
            target.push(Node(@cst.Node::new(Error, tokens)))
          }
        }
    }
  }
  while stack.pop() is Some(f) {
    s.error(
      "mermaid/missing-end", "this `\{f.keyword}` has no `end`",
      f.start,
      f.end,
    )
    let parent = match stack.last() {
      Some(p) => p.children
      None => root
    }
    parent.push(Node(@cst.Node::new(Block, f.children)))
  }
  if !header && !reported {
    s.error(
      "mermaid/missing-header", "a sequence diagram starts with `sequenceDiagram`",
      source.length(),
      source.length(),
    )
  }
  {
    tree: @cst.Node::new(Document, root),
    diagnostics: ReadOnlyArray::from_array(s.diagnostics),
  }
}
