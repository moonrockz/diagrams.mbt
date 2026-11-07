///|
/// Compilation bounds. `source_units` counts UTF-16 code units of query text.
/// `patterns` counts source rules, `pattern_nodes` node and alternation
/// patterns, `nesting` the deepest pattern nesting and `captures` capture
/// names. `predicates` counts predicates and their operands. `nesting` is at
/// most 1000, which bounds the host stack that compilation uses.
#derive(Eq, Debug)
pub struct CompileLimits {
  source_units : Int32
  patterns : Int32
  pattern_nodes : Int32
  nesting : Int32
  captures : Int32
  predicates : Int32
}

///|
pub extend CompileLimits with Eq::{equal, not_equal}

///|
pub extend CompileLimits with @debug.Debug::{to_repr}

///|
pub fn CompileLimits::new(
  source_units~ : Int32 = 65536,
  patterns~ : Int32 = 256,
  pattern_nodes~ : Int32 = 4096,
  nesting~ : Int32 = 32,
  captures~ : Int32 = 256,
  predicates~ : Int32 = 1024,
) -> CompileLimits {
  { source_units, patterns, pattern_nodes, nesting, captures, predicates, }
}

///|
fn CompileLimits::valid(self : CompileLimits) -> Bool {
  self.source_units > 0 &&
  self.patterns > 0 &&
  self.pattern_nodes > 0 &&
  self.nesting > 0 &&
  self.nesting <= 1000 &&
  self.captures > 0 &&
  self.predicates > 0
}

///|
/// Execution bounds, cumulative over all batches of one cursor. `work` counts
/// inspected candidate nodes and matching steps, `pending` the open partial
/// matches, `results` the delivered matches and `output_units` the projected
/// output (UTF-16 code units of projected text, plus one for each value).
#derive(Eq, Debug)
pub struct ExecutionLimits {
  work : Int32
  pending : Int32
  results : Int32
  output_units : Int32
}

///|
pub extend ExecutionLimits with Eq::{equal, not_equal}

///|
pub extend ExecutionLimits with @debug.Debug::{to_repr}

///|
pub fn ExecutionLimits::new(
  work~ : Int32 = 10000000,
  pending~ : Int32 = 100000,
  results~ : Int32 = 1000000,
  output_units~ : Int32 = 100000000,
) -> ExecutionLimits {
  { work, pending, results, output_units, }
}

///|
fn ExecutionLimits::valid(self : ExecutionLimits) -> Bool {
  self.work > 0 && self.pending > 0 && self.results > 0 && self.output_units > 0
}

///|
/// The execution bound that stopped a cursor.
#derive(Eq, Debug)
pub(all) enum QueryLimit {
  Work
  Pending
  Results
  Output
}

///|
pub extend QueryLimit with Eq::{equal, not_equal}

///|
pub extend QueryLimit with @debug.Debug::{to_repr}

///|
/// Why a cursor failed. A failure is terminal.
#derive(Eq, Debug)
pub(all) enum QueryFailure {
  Limit(QueryLimit)
  IncompatibleSchema(expected~ : String, actual~ : String)
  InvalidRoot
  InvalidLimits
}

///|
pub extend QueryFailure with Eq::{equal, not_equal}

///|
pub extend QueryFailure with @debug.Debug::{to_repr}
