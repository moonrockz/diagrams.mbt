///|
/// How serious a diagnostic is.
pub(all) enum Severity {
  Error
  Warning
  Info
} derive(Eq, Debug)

///|
pub extend Severity with Eq::{not_equal, equal}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
/// A place in a source text. `offset` counts UTF-16 code units from the start.
/// `line` and `column` start at 1, and `column` also counts UTF-16 code units.
pub(all) struct Position {
  offset : Int
  line : Int
  column : Int
} derive(Eq, Debug)

///|
pub extend Position with Eq::{not_equal, equal}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
/// The half-open range from `start` to `end` in a source text.
pub(all) struct Span {
  start : Position
  end : Position
} derive(Eq, Debug)

///|
pub extend Span with Eq::{not_equal, equal}

///|
pub extend Span with @debug.Debug::{to_repr}

///|
/// A problem that a reader, a converter or a renderer found. `code` is stable,
/// for example `mermaid/unknown-statement`. `span` is absent when the problem
/// has no place in a source text.
pub(all) struct Diagnostic {
  code : String
  severity : Severity
  message : String
  span : Span?
} derive(Eq, Debug)

///|
pub extend Diagnostic with Eq::{not_equal, equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
/// An error diagnostic.
pub fn Diagnostic::error(
  code : String,
  message : String,
  span? : Span,
) -> Diagnostic {
  { code, severity: Error, message, span }
}

///|
/// A warning diagnostic.
pub fn Diagnostic::warning(
  code : String,
  message : String,
  span? : Span,
) -> Diagnostic {
  { code, severity: Warning, message, span }
}
