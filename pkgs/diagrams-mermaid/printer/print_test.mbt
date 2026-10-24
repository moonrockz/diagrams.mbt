///|
fn ast_of(source : String) -> @ast.Diagram {
  @ast.lower(@syntax.parse(source).tree).unwrap()
}

///|
fn canonical(source : String) -> String {
  @printer.print(ast_of(source))
}

///|
test "the printer writes canonical Mermaid" {
  assert_eq(
    canonical("%% c\nsequenceDiagram\nparticipant  A\n actor B   as Bob\nA  ->>  B :hi there\n"),
    "sequenceDiagram\n  participant A\n  actor B as Bob\n  A->>B: hi there\n",
  )
}

///|
test "each statement has one canonical spelling" {
  let source =
    #|SEQUENCEDIAGRAM
    #|Create Actor D@{"type": "database"} AS Store
    #|destroy D
    #|Activate A
    #|deactivate A
    #|A ->>+ B : go
    #|B()-->>()A:back
    #|NOTE OVER A , B : both
    #|note right of A: one
    #|LINK A: Docs @ https://example.com
    #|links A: {}
    #|title: Login
    #|accTitle : Short
    #|accDescr {
    #|  Two
    #|  lines
    #|}
    #|autonumber 10 5
    #|autonumber off
  assert_eq(
    canonical(source),
    (
      #|sequenceDiagram
      #|  create actor D@{ "type": "database" } as Store
      #|  destroy D
      #|  activate A
      #|  deactivate A
      #|  A->>+B: go
      #|  B()-->>()A: back
      #|  note over A,B: both
      #|  note right of A: one
      #|  link A: Docs @ https://example.com
      #|  links A: {}
      #|  title Login
      #|  accTitle: Short
      #|  accDescr {
      #|Two
      #|  lines
      #|  }
      #|  autonumber 10 5
      #|  autonumber off
      #|
    ),
  )
}

///|
test "frames are indented two spaces for each level" {
  assert_eq(
    canonical("sequenceDiagram\nalt sick\nB->>A: no\nelse\nloop daily\nB->>A: yes\nend\nend\nbox Group\nparticipant C\nend\n"),
    (
      #|sequenceDiagram
      #|  alt sick
      #|    B->>A: no
      #|  else
      #|    loop daily
      #|      B->>A: yes
      #|    end
      #|  end
      #|  box Group
      #|    participant C
      #|  end
      #|
    ),
  )
}

///|
test "front matter and directives come before the header" {
  assert_eq(
    canonical("---\ntitle: T\n---\nsequenceDiagram\n%%{init: {\"wrap\": true}}%%\nA->>B: x\n"),
    "---\ntitle: T\n---\n%%{init: {\"wrap\": true}}%%\nsequenceDiagram\n  A->>B: x\n",
  )
}

///|
test "reading the printed text gives the same AST, and printing again gives the same text" {
  let d = ast_of("sequenceDiagram\nactor C as Client\nloop poll\nC->>API: GET /forecast\nAPI-->>C: 200\nend\nnote over C: done\n")
  let text = @printer.print(d)
  let again = ast_of(text)
  assert_eq(again, d)
  assert_eq(@printer.print(again), text)
}

///|
test "a deactivation after an arrow that ends with a dash keeps its meaning" {
  for arrow in ["/|-", "\\|-", "//-", "\\\\-"] {
    let d = ast_of("sequenceDiagram\nA\{arrow} -B: done\n")
    let text = @printer.print(d)
    assert_eq(ast_of(text), d, msg="\{arrow}: \{text}")
  }
}

///|
test "a description with a lone carriage return keeps the multi-line form" {
  let d = ast_of("sequenceDiagram\naccDescr {one\rtwo}\n")
  let text = @printer.print(d)
  assert_eq(ast_of(text), d, msg=text)
}

///|
test "every arrow with every modifier obeys the read-print-read law" {
  let forms = [
    ("", ""),
    ("", "+"),
    ("", "-"),
    ("", "()"),
    ("()", ""),
    ("()", "()"),
  ]
  for arrow in @syntax.arrows {
    for form in forms {
      let source = "sequenceDiagram\nA \{form.0} \{arrow} \{form.1} B: x\n"
      let d = ast_of(source)
      let text = @printer.print(d)
      assert_eq(ast_of(text), d, msg="\{source} printed as \{text}")
    }
  }
}
