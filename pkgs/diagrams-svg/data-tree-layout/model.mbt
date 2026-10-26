///|
/// Explicit bounds for structured-data layout and painting.
pub struct Limits {
  nodes : Int
  depth : Int
  work : Int
  /// The widest value column before text wraps, in SVG units.
  width : Int
  output_units : Int
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(
  nodes? : Int = 10000,
  depth? : Int = 256,
  work? : Int = 1000000,
  width? : Int = 360,
  output_units? : Int = 16777216,
) -> Limits {
  { nodes, depth, work, width, output_units }
}
