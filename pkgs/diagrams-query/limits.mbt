///|
/// Compilation bounds. `source_units` counts UTF-16 code units of query text.
/// `patterns` counts source rules, `pattern_nodes` node and alternation
/// patterns, `nesting` the deepest pattern nesting and `captures` capture
/// names. `predicates` counts predicates and their operands. `nesting` is at
/// most 1000, which bounds the host stack that compilation uses.
pub struct CompileLimits {
  source_units : Int
  patterns : Int
  pattern_nodes : Int
  nesting : Int
  captures : Int
  predicates : Int
} derive(Eq, Debug)

///|
pub extend CompileLimits with Eq::{equal, not_equal}

///|
pub extend CompileLimits with @debug.Debug::{to_repr}

///|
pub fn CompileLimits::new(
  source_units? : Int = 65536,
  patterns? : Int = 256,
  pattern_nodes? : Int = 4096,
  nesting? : Int = 32,
  captures? : Int = 256,
  predicates? : Int = 1024,
) -> CompileLimits {
  { source_units, patterns, pattern_nodes, nesting, captures, predicates }
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
pub struct ExecutionLimits {
  work : Int
  pending : Int
  results : Int
  output_units : Int
} derive(Eq, Debug)

///|
pub extend ExecutionLimits with Eq::{equal, not_equal}

///|
pub extend ExecutionLimits with @debug.Debug::{to_repr}

///|
pub fn ExecutionLimits::new(
  work? : Int = 10000000,
  pending? : Int = 100000,
  results? : Int = 1000000,
  output_units? : Int = 100000000,
) -> ExecutionLimits {
  { work, pending, results, output_units }
}

///|
fn ExecutionLimits::valid(self : ExecutionLimits) -> Bool {
  self.work > 0 && self.pending > 0 && self.results > 0 && self.output_units > 0
}

///|
/// The execution bound that stopped a cursor.
pub(all) enum QueryLimit {
  Work
  Pending
  Results
  Output
} derive(Eq, Debug)

///|
pub extend QueryLimit with Eq::{equal, not_equal}

///|
pub extend QueryLimit with @debug.Debug::{to_repr}

///|
/// Why a cursor failed. A failure is terminal.
pub(all) enum QueryFailure {
  Limit(QueryLimit)
  IncompatibleSchema(expected~ : String, actual~ : String)
  InvalidRoot
  InvalidLimits
} derive(Eq, Debug)

///|
pub extend QueryFailure with Eq::{equal, not_equal}

///|
pub extend QueryFailure with @debug.Debug::{to_repr}
