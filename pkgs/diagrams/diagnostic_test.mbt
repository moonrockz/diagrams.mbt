///|
test "a diagnostic keeps its code, severity, message and span" {
  let start = @diagrams.Position::{ offset: 4, line: 2, column: 1 }
  let end = @diagrams.Position::{ offset: 9, line: 2, column: 6 }
  let d = @diagrams.Diagnostic::error(
    "mermaid/unknown-statement",
    "unknown statement",
    span=@diagrams.Span::{ start, end },
  )
  assert_eq(d.code, "mermaid/unknown-statement")
  assert_eq(d.severity, @diagrams.Severity::Error)
  assert_eq(d.span.unwrap().start.line, 2)
  assert_eq(d.span.unwrap().end.column, 6)
}

///|
test "a warning has no span when none is given" {
  let d = @diagrams.Diagnostic::warning("link/unresolved", "no target")
  assert_eq(d.severity, @diagrams.Severity::Warning)
  assert_eq(d.span, None)
}
