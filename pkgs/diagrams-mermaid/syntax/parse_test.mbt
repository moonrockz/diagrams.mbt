///|
fn kinds(tree : @cst.Node) -> Array[@cst.NodeKind] {
  tree.nodes().map(n => n.kind)
}

///|
/// The tokens of `node` that are not whitespace or line breaks.
fn sig(node : @cst.Node) -> Array[(@cst.TokenKind, String)] {
  node
  .tokens()
  .filter(t => t.kind != Whitespace && t.kind != Newline)
  .map(t => (t.kind, t.text))
}

///|
/// The first statement after the header of `body`.
fn first(body : String) -> @cst.Node {
  @syntax.parse("sequenceDiagram\n\{body}\n").tree.nodes()[1]
}

///|
fn codes(source : String) -> Array[String] {
  @syntax.parse(source).diagnostics.map(d => d.code).iter().to_array()
}

///|
fn clean(body : String) -> Bool {
  let source = "sequenceDiagram\n\{body}\n"
  let r = @syntax.parse(source)
  r.tree.text() == source && r.diagnostics.length() == 0
}

// Source reproduction

///|
test "the syntax tree text equals the source" {
  let source = "sequenceDiagram\n  participant A\n  actor B as Bob\n  A->>B: hello\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds(result.tree), [Header, Participant, Participant, Message])
}

///|
test "the syntax tree keeps comments, blank lines and CRLF line endings" {
  let source = "%% top\r\nsequenceDiagram\r\n\r\n  %% note\r\n  A ->> B : hi  \r\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds(result.tree), [Header, Message])
  let comments = result.tree.tokens().filter(t => t.kind == Comment)
  assert_eq(comments.map(t => t.text), ["%% top", "%% note"])
}

///|
test "a lone carriage return ends a line" {
  let source = "sequenceDiagram\rA->>B: one\rB->>A: two"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(kinds(result.tree), [Header, Message, Message])
  assert_eq(result.diagnostics.length(), 0)
}

///|
test "a source without a final newline reproduces exactly" {
  let source = "sequenceDiagram\nA->>B: hi"
  assert_eq(@syntax.parse(source).tree.text(), source)
}

///|
test "front matter and directives are trivia" {
  let source = "---\nconfig:\n  theme: dark\n---\n%%{init: {\"theme\": \"forest\",\n \"wrap\": true}}%%\nsequenceDiagram\nA->>B: hi\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  assert_eq(kinds(result.tree), [Header, Message])
  let kinds_of_tokens = result.tree.tokens().map(t => t.kind)
  assert_true(kinds_of_tokens.contains(FrontMatter))
  assert_true(kinds_of_tokens.contains(Directive))
}

///|
test "a column counts a non-BMP character as two UTF-16 code units" {
  let source = "sequenceDiagram\nA->>B: 😀; frob\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  let span = result.diagnostics[0].span.unwrap()
  assert_eq(span.start.line, 2)
  assert_eq(span.start.column, 12)
}

// Statements

///|
test "participant forms" {
  assert_eq(sig(first("participant A")), [(Keyword, "participant"), (Identifier, "A")])
  assert_eq(sig(first("Participant Alice Smith")), [
    (Keyword, "Participant"),
    (Identifier, "Alice Smith"),
  ])
  assert_eq(sig(first("participant A as Alice<br/>Johnson")), [
    (Keyword, "participant"),
    (Identifier, "A"),
    (Keyword, "as"),
    (Text, "Alice<br/>Johnson"),
  ])
  assert_eq(sig(first("actor DB@{ \"type\": \"database\" } as User Database")), [
    (Keyword, "actor"),
    (Identifier, "DB"),
    (ConfigOpen, "@{"),
    (Config, " \"type\": \"database\" "),
    (ConfigClose, "}"),
    (Keyword, "as"),
    (Text, "User Database"),
  ])
  assert_eq(sig(first("create actor D as Donald")), [
    (Keyword, "create"),
    (Keyword, "actor"),
    (Identifier, "D"),
    (Keyword, "as"),
    (Text, "Donald"),
  ])
  assert_eq(first("participant A").kind, Participant)
}

///|
test "destroy, activate and deactivate" {
  assert_eq(first("destroy Carl").kind, Destroy)
  assert_eq(first("activate John").kind, Activate)
  assert_eq(sig(first("deactivate John")), [(Keyword, "deactivate"), (Identifier, "John")])
}

///|
let all_arrows : Array[String] = [
  "->>", "<<->>", "-->>", "<<-->>", "->", "-->", "-x", "--x", "-)", "--)", "--|\\",
  "--|/", "--\\\\", "--//", "/|--", "\\|--", "//--", "\\\\--", "-|\\", "-|/", "-\\\\",
  "-//", "/|-", "\\|-", "//-", "\\\\-",
]

///|
test "every arrow of the Mermaid 12.2.0 grammar" {
  for arrow in all_arrows {
    let node = first("Alice\{arrow}Bob: hi")
    assert_eq(node.kind, Message, msg=arrow)
    assert_eq(
      sig(node),
      [(Identifier, "Alice"), (Arrow, arrow), (Identifier, "Bob"), (Colon, ":"), (Text, "hi")],
      msg=arrow,
    )
  }
}

///|
test "activation and central connection modifiers" {
  assert_eq(sig(first("A->>+B: x"))[2], (Modifier, "+"))
  assert_eq(sig(first("B-->>-A: x"))[2], (Modifier, "-"))
  assert_eq(sig(first("A->>()B: x"))[2], (Modifier, "()"))
  assert_eq(sig(first("A()->>B: x"))[1], (Modifier, "()"))
  assert_eq(sig(first("Alice ->>+ John: Did you?")), [
    (Identifier, "Alice"),
    (Arrow, "->>"),
    (Modifier, "+"),
    (Identifier, "John"),
    (Colon, ":"),
    (Text, "Did you?"),
  ])
}

///|
test "participant names can have spaces and single dashes" {
  assert_eq(sig(first("My Service->>Other-Thing: x"))[0], (Identifier, "My Service"))
  assert_eq(sig(first("My Service->>Other-Thing: x"))[2], (Identifier, "Other-Thing"))
}

///|
test "notes" {
  assert_eq(sig(first("Note right of John: Text in note")), [
    (Keyword, "Note"),
    (Keyword, "right of"),
    (Identifier, "John"),
    (Colon, ":"),
    (Text, "Text in note"),
  ])
  assert_eq(sig(first("note over Alice,John: A typical interaction")), [
    (Keyword, "note"),
    (Keyword, "over"),
    (Identifier, "Alice"),
    (Comma, ","),
    (Identifier, "John"),
    (Colon, ":"),
    (Text, "A typical interaction"),
  ])
  assert_eq(first("note left of A: x").kind, Note)
}

///|
test "links, properties and details" {
  assert_eq(sig(first("link Alice: Dashboard @ https://dashboard.contoso.com/alice")), [
    (Keyword, "link"),
    (Identifier, "Alice"),
    (Colon, ":"),
    (Text, "Dashboard @ https://dashboard.contoso.com/alice"),
  ])
  assert_eq(first("links Alice: {\"Wiki\": \"https://wiki.contoso.com/alice\"}").kind, Links)
  assert_eq(first("properties Alice: {\"class\": \"internal\"}").kind, Properties)
  assert_eq(first("details Alice: {}").kind, Details)
}

///|
test "titles and accessibility text" {
  assert_eq(sig(first("title Login flow")), [(Keyword, "title"), (Text, "Login flow")])
  assert_eq(sig(first("title: Login flow")), [(Keyword, "title"), (Colon, ":"), (Text, "Login flow")])
  assert_eq(sig(first("accTitle: The login; # flow")), [
    (Keyword, "accTitle"),
    (Colon, ":"),
    (Text, "The login; # flow"),
  ])
  assert_eq(first("accDescr: A description").kind, AccDescr)
  let multi = first("accDescr {\n  Line one\n  Line two\n}")
  assert_eq(multi.kind, AccDescr)
  assert_eq(sig(multi)[1], (OpenBrace, "{"))
  assert_eq(sig(multi)[3], (CloseBrace, "}"))
}

///|
test "autonumber forms" {
  assert_eq(sig(first("autonumber")), [(Keyword, "autonumber")])
  assert_eq(sig(first("autonumber 10")), [(Keyword, "autonumber"), (Number, "10")])
  assert_eq(sig(first("autonumber 10 5")), [
    (Keyword, "autonumber"),
    (Number, "10"),
    (Number, "5"),
  ])
  assert_eq(sig(first("autonumber off")), [(Keyword, "autonumber"), (Keyword, "off")])
}

///|
test "a semicolon separates statements on one line" {
  let tree = @syntax.parse("sequenceDiagram\nA->>B: one; B->>A: two\n").tree
  assert_eq(kinds(tree), [Header, Message, Message])
  assert_true(tree.tokens().iter().any(t => t.kind == Separator))
}

///|
test "a hash starts a comment, but an entity code is text" {
  let node = first("A->>B: hi # a comment")
  assert_eq(sig(node).last(), Some((Text, "hi")))
  assert_true(clean("A->>B: hi # a comment"))
  assert_eq(sig(first("A->>B: I #9829; you #infin; times more!")).last(), Some(
    (Text, "I #9829; you #infin; times more!"),
  ))
}

///|
test "blocks nest and keep their statements" {
  let tree = @syntax.parse(
    "sequenceDiagram\nalt is sick\n  B->>A: no\nelse is well\n  loop daily\n    B->>A: yes\n  end\nend\n",
  ).tree
  assert_eq(kinds(tree), [Header, Block])
  let alt = tree.nodes()[1]
  assert_eq(kinds(alt), [BlockStart, Message, Section, Block, BlockEnd])
  assert_eq(sig(alt.nodes()[0]), [(Keyword, "alt"), (Text, "is sick")])
  assert_eq(kinds(alt.nodes()[3]), [BlockStart, Message, BlockEnd])
}

///|
test "every block keyword" {
  for opener in ["loop x", "rect rgb(191, 223, 255)", "opt x", "break x", "critical x", "par x", "par_over x"] {
    assert_true(clean("\{opener}\nA->>B: m\nend"), msg=opener)
  }
  assert_true(clean("par a\nA->>B: m\nand b\nA->>C: n\nend"))
  assert_true(clean("critical a\nA->>B: m\noption b\nA->>C: n\nend"))
  assert_true(clean("box Purple Alice & John\nparticipant A\nparticipant J\nend"))
}

///|
test "keywords are case-insensitive, and a keyword inside a name is a name" {
  assert_true(clean("PARTICIPANT A\nLOOP x\nA->>Endpoint: m\nEND"))
  assert_eq(sig(first("Endpoint->>B: m"))[0], (Identifier, "Endpoint"))
}

///|
test "every documented construct reads without diagnostics" {
  assert_true(clean("participant Alice@{ \"type\" : \"boundary\" }"))
  assert_true(clean("participant API@{ \"type\": \"boundary\", \"alias\": \"Public API\" }"))
  assert_true(clean("Alice->John: Hello John,<br/>how are you?"))
  assert_true(clean("Bob->>Alice: Not so good :("))
  assert_true(clean("A->>B:"))
  assert_true(clean("A->>B: wrap:a long text"))
}

// Diagnostics

///|
test "an unknown statement gives a diagnostic at its line" {
  let source = "sequenceDiagram\nA->>B: hi\nfrobnicate A\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 1)
  let d = result.diagnostics[0]
  assert_eq(d.code, "mermaid/unknown-statement")
  assert_eq(d.severity, @diagrams.Severity::Error)
  let span = d.span.unwrap()
  assert_eq(span.start, { offset: 26, line: 3, column: 1 })
  assert_eq(span.end, { offset: 38, line: 3, column: 13 })
}

///|
test "statements after a bad statement still parse" {
  let source = "sequenceDiagram\nA->>B: one\n?? bad\nA->>B: two\n!! bad\nA->>B: three\n"
  let result = @syntax.parse(source)
  assert_eq(result.diagnostics.length(), 2)
  assert_eq(kinds(result.tree), [Header, Message, Error, Message, Error, Message])
}

///|
test "a source without the header gives a diagnostic" {
  assert_eq(codes("A->>B: hi\n"), ["mermaid/missing-header"])
}

///|
test "an empty or comment-only source gives the missing-header diagnostic at its end" {
  for source in ["", "\n\n", "%% only a comment\n"] {
    let result = @syntax.parse(source)
    assert_eq(result.tree.text(), source)
    let codes = result.diagnostics.map(d => d.code).iter().to_array()
    assert_eq(codes, ["mermaid/missing-header"], msg="source: \{source}")
    assert_eq(result.diagnostics[0].span.unwrap().start.offset, source.length())
  }
}

///|
test "a second header is an error" {
  assert_eq(codes("sequenceDiagram\nsequenceDiagram\n"), ["mermaid/unexpected-header"])
}

///|
test "a message without text is an error" {
  assert_eq(codes("sequenceDiagram\nA->>B\n"), ["mermaid/missing-message-text"])
}

///|
test "a message without a receiver is an error" {
  assert_eq(codes("sequenceDiagram\nA->>: hi\n"), ["mermaid/invalid-message"])
}

///|
test "a bad participant declaration is an error" {
  assert_eq(codes("sequenceDiagram\nparticipant A<B\n"), ["mermaid/invalid-participant"])
  assert_eq(codes("sequenceDiagram\ncreate note\n"), ["mermaid/invalid-participant"])
  assert_eq(codes("sequenceDiagram\nparticipant A@{ \"type\": \"queue\"\n"), [
    "mermaid/invalid-participant",
  ])
}

///|
test "a bad note is an error" {
  assert_eq(codes("sequenceDiagram\nnote A: x\n"), ["mermaid/invalid-note"])
  assert_eq(codes("sequenceDiagram\nnote over A\n"), ["mermaid/invalid-note"])
  assert_eq(codes("sequenceDiagram\nnote left of A,B: x\n"), ["mermaid/invalid-note"])
}

///|
test "a bad autonumber is an error" {
  assert_eq(codes("sequenceDiagram\nautonumber ten\n"), ["mermaid/invalid-autonumber"])
}

///|
test "a link without text is an error" {
  assert_eq(codes("sequenceDiagram\nlink Alice\n"), ["mermaid/invalid-link"])
}

///|
test "a title without text is an error" {
  assert_eq(codes("sequenceDiagram\ntitle:\n"), ["mermaid/invalid-title"])
}

///|
test "a missing frame end is reported at the frame keyword, and the frame keeps what follows" {
  let source = "sequenceDiagram\nloop every minute\nA->>B: ping\nB->>A: pong\n"
  let result = @syntax.parse(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.map(d => d.code).iter().to_array(), ["mermaid/missing-end"])
  let span = result.diagnostics[0].span.unwrap()
  assert_eq((span.start.line, span.start.column, span.end.column), (2, 1, 5))
  let block = result.tree.nodes()[1]
  assert_eq(kinds(block), [BlockStart, Message, Message])
}

///|
test "an end without a frame is an error" {
  assert_eq(codes("sequenceDiagram\nend\n"), ["mermaid/unexpected-end"])
}

///|
test "a section keyword outside its frame is an error" {
  assert_eq(codes("sequenceDiagram\nelse x\n"), ["mermaid/misplaced-section"])
  assert_eq(codes("sequenceDiagram\nloop x\nand y\nend\n"), ["mermaid/misplaced-section"])
  assert_eq(codes("sequenceDiagram\nalt x\noption y\nend\n"), ["mermaid/misplaced-section"])
}

///|
test "a box can only hold participant statements" {
  assert_eq(codes("sequenceDiagram\nbox Group\nA->>B: x\nend\n"), ["mermaid/invalid-in-box"])
}

///|
test "an unclosed directive is an error" {
  assert_eq(codes("%%{init: {\"theme\": \"dark\"}\nsequenceDiagram\n"), [
    "mermaid/unclosed-directive", "mermaid/missing-header",
  ])
}

///|
test "an unclosed multi-line description is an error" {
  assert_eq(codes("sequenceDiagram\naccDescr {\n  text\n"), ["mermaid/unclosed-description"])
}

///|
test "each diagnostic code is listed" {
  assert_eq(@syntax.diagnostic_codes.iter().to_array(), [
    "mermaid/missing-header", "mermaid/unexpected-header", "mermaid/unknown-statement",
    "mermaid/missing-message-text", "mermaid/invalid-message", "mermaid/invalid-participant",
    "mermaid/invalid-note", "mermaid/invalid-autonumber", "mermaid/invalid-link", "mermaid/invalid-title",
    "mermaid/missing-end", "mermaid/unexpected-end", "mermaid/misplaced-section", "mermaid/invalid-in-box",
    "mermaid/unclosed-directive", "mermaid/unclosed-description",
  ])
}
