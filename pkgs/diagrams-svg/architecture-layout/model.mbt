///|
pub struct Limits {
  nodes : Int32
  edges : Int32
  depth : Int32
  work : Int32
  coordinate : Int32
  output_units : Int32
  minimum_approach : Double
} derive(Eq, Debug)

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
  coordinate~ : Int32 = 10000000,
  output_units~ : Int32 = 16777216,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, edges, depth, work, coordinate, output_units, }
}

///|
pub(all) struct Point {
  x : Int32
  y : Int32
} derive(Eq, Debug)

///|
pub(all) struct Rect {
  x : Int32
  y : Int32
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub fn Rect::contains(self : Rect, other : Rect) -> Bool {
  other.x >= self.x &&
  other.y >= self.y &&
  other.x + other.width <= self.x + self.width &&
  other.y + other.height <= self.y + self.height
}

///|
pub fn Rect::overlaps(self : Rect, other : Rect) -> Bool {
  self.x < other.x + other.width &&
  other.x < self.x + self.width &&
  self.y < other.y + other.height &&
  other.y < self.y + self.height
}

///|
pub(all) enum Kind {
  Group
  Service
  Junction
} derive(Eq, Debug)

///|
pub(all) struct Shape {
  id : String
  kind : Kind
  box : Rect
  label : String
  parent : String?
  font_size : Int32
  header_height : Int32
} derive(Eq, Debug)

///|
pub(all) struct Connection {
  connection : @model.Connection
  points : ReadOnlyArray[Point]
  label_box : Rect?
} derive(Eq, Debug)

///|
pub(all) struct Geometry {
  model : @model.Architecture
  shapes : ReadOnlyArray[Shape]
  connections : ReadOnlyArray[Connection]
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub(all) struct LayoutResult {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub struct Finding {
  code : String
  message : String
  element : String
} derive(Eq, Debug)

///|
pub fn measure(text : String, size~ : Int32 = 13) -> Int32 {
  let mut width = 0
  let mut maximum = 0
  for ch in text {
    if ch == '\n' {
      maximum = maximum.max(width)
      width = 0
    } else {
      width += if ch.to_int() > 255 { size } else { (size * 8 + 9) / 10 }
    }
  }
  maximum.max(width)
}

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub extend Rect with Eq::{equal, not_equal}

///|
pub extend Rect with @debug.Debug::{to_repr}

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub extend Shape with Eq::{equal, not_equal}

///|
pub extend Shape with @debug.Debug::{to_repr}

///|
pub extend Connection with Eq::{equal, not_equal}

///|
pub extend Connection with @debug.Debug::{to_repr}

///|
pub extend Geometry with Eq::{equal, not_equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
/// Retain resource limits while selecting the marked terminal reservation.
pub fn Limits::with_minimum_approach(
  self : Limits,
  minimum_approach : Double,
) -> Limits {
  { ..self, minimum_approach, }
}
