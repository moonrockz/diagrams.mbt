///|
/// Explicit bounds for railroad layout and painting.
pub struct Limits {
  nodes : Int32
  depth : Int32
  work : Int32
  /// The widest track before it continues on a new row, in SVG units.
  width : Int32
  output_units : Int32
  minimum_approach : Double
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
  width~ : Int32 = 1200,
  output_units~ : Int32 = 16777216,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, depth, work, width, output_units, }
}

///|
pub fn Limits::with_minimum_approach(
  self : Limits,
  minimum_approach : Double,
) -> Limits {
  { ..self, minimum_approach, }
}
