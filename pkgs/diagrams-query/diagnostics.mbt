///|
/// A half-open range of query source text.
pub struct QuerySpan {
  start : QueryPosition
  end : QueryPosition
} derive(Eq, Debug)

///|
pub extend QuerySpan with Eq::{equal, not_equal}

///|
pub extend QuerySpan with @debug.Debug::{to_repr}

///|
pub(all) enum Severity {
  Error
  Warning
} derive(Eq, Debug)

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
/// A compile or input diagnostic. `span` is present for query text and absent
/// for forms built in code.
pub struct QueryDiagnostic {
  code : String
  severity : Severity
  message : String
  span : QuerySpan?
} derive(Eq, Debug)

///|
pub extend QueryDiagnostic with Eq::{equal, not_equal}

///|
pub extend QueryDiagnostic with @debug.Debug::{to_repr}

///|
/// Every diagnostic code that compilation and projection can give.
pub let query_diagnostic_codes : ReadOnlyArray[String] = [
  "query/syntax", "query/unterminated-string", "query/invalid-string", "query/invalid-name",
  "query/empty-query", "query/unsupported-quantifier", "query/unsupported-anchor",
  "query/unsupported-directive", "query/unsupported-regex", "query/unsupported-anonymous-node",
  "query/unsupported-grouping", "query/unknown-kind", "query/unknown-category", "query/unknown-field",
  "query/unbound-prefix", "query/invalid-namespace-map", "query/unknown-predicate", "query/predicate-arity",
  "query/unknown-capture", "query/duplicate-capture", "query/source-limit", "query/pattern-limit",
  "query/nesting-limit", "query/capture-limit", "query/invalid-limits", "query/unknown-projection-field",
  "query/projection-limit",
]

///|
fn error(code : String, message : String, span : QuerySpan?) -> QueryDiagnostic {
  { code, severity: Error, message, span }
}

///|
/// Maps UTF-16 offsets of a source text to lines and columns. CRLF, LF and
/// CR each count as one line break.
priv struct LineMap {
  starts : Array[Int]
}

///|
fn LineMap::new(source : String) -> LineMap {
  let starts = [0]
  let mut i = 0
  while i < source.length() {
    let unit = source.code_unit_at_int(i)
    if unit == '\r' {
      if i + 1 < source.length() && source.code_unit_at_int(i + 1) == '\n' {
        i += 1
      }
      starts.push(i + 1)
    } else if unit == '\n' {
      starts.push(i + 1)
    }
    i += 1
  }
  { starts, }
}

///|
fn LineMap::position(self : LineMap, offset : Int) -> QueryPosition {
  // The last line start at or before offset.
  let mut low = 0
  let mut high = self.starts.length() - 1
  while low < high {
    let middle = (low + high + 1) / 2
    if self.starts[middle] <= offset {
      low = middle
    } else {
      high = middle - 1
    }
  }
  { offset, line: low + 1, column: offset - self.starts[low] + 1 }
}

///|
fn LineMap::span(self : LineMap, start : Int, end : Int) -> QuerySpan {
  { start: self.position(start), end: self.position(end) }
}
