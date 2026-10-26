///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
pub extend Rect with Eq::{equal, not_equal}

///|
pub extend Rect with @debug.Debug::{to_repr}

///|
pub fn Rect::contains(self : Rect, other : Rect, tolerance? : Double = 0.0) -> Bool {
  other.x >= self.x - tolerance &&
  other.y >= self.y - tolerance &&
  other.x + other.width <= self.x + self.width + tolerance &&
  other.y + other.height <= self.y + self.height + tolerance
}

///|
pub fn Rect::overlaps(self : Rect, other : Rect) -> Bool {
  self.x < other.x + other.width &&
  other.x < self.x + self.width &&
  self.y < other.y + other.height &&
  other.y < self.y + self.height
}

///|
/// Measured text. `x` is the horizontal centre and `box` the text bounds.
pub struct Label {
  lines : ReadOnlyArray[String]
  x : Double
  size : Double
  weight : Int
  box : Rect
  /// The semantic owner: a term, rule, frame or connector identity.
  owner : String
} derive(Eq, Debug)

///|
pub extend Label with Eq::{equal, not_equal}

///|
pub extend Label with @debug.Debug::{to_repr}

///|
/// The visual form of a term.
pub(all) enum Shape {
  /// A consuming terminal or literal.
  Pill
  /// A nonterminal reference.
  Square
  /// A predefined class or set.
  Class
  /// A special sequence.
  Special
  /// A zero-width anchor.
  Anchor
  /// A lookaround frame. The frame is the visit region.
  Lookaround
  /// An empty term.
  Dot
} derive(Eq, Debug)

///|
pub extend Shape with Eq::{equal, not_equal}

///|
pub extend Shape with @debug.Debug::{to_repr}

///|
pub struct TermBox {
  term : @trace.Term
  shape : Shape
  rect : Rect
  label : Label
  notes : ReadOnlyArray[Label]
} derive(Eq, Debug)

///|
pub extend TermBox with Eq::{equal, not_equal}

///|
pub extend TermBox with @debug.Debug::{to_repr}

///|
pub(all) enum FrameRole {
  /// A capturing, named or non-capturing group.
  Group
  /// The constraint region of an exclusion.
  Except
} derive(Eq, Debug)

///|
pub extend FrameRole with Eq::{equal, not_equal}

///|
pub extend FrameRole with @debug.Debug::{to_repr}

///|
pub struct Frame {
  owner : String
  role : FrameRole
  rect : Rect
  label : Label
} derive(Eq, Debug)

///|
pub extend Frame with Eq::{equal, not_equal}

///|
pub extend Frame with @debug.Debug::{to_repr}

///|
/// The drawn path of one connector, as a polyline in its semantic direction.
/// Corners are rounded when painted.
pub struct Wire {
  connector : @trace.Connector
  points : ReadOnlyArray[Point]
  /// A repetition bound or count label of a return path.
  label : Label?
} derive(Eq, Debug)

///|
pub extend Wire with Eq::{equal, not_equal}

///|
pub extend Wire with @debug.Debug::{to_repr}

///|
pub struct TrackBox {
  track : @trace.Track
  label : Label
  start : Point
  end : Point
  notes : ReadOnlyArray[Label]
} derive(Eq, Debug)

///|
pub extend TrackBox with Eq::{equal, not_equal}

///|
pub extend TrackBox with @debug.Debug::{to_repr}

///|
pub struct NoteBox {
  id : String
  rect : Rect
  label : Label
} derive(Eq, Debug)

///|
pub extend NoteBox with Eq::{equal, not_equal}

///|
pub extend NoteBox with @debug.Debug::{to_repr}

///|
/// Deterministic railroad geometry. Every drawn connector of the topology has
/// one wire; every term has one box.
pub struct Geometry {
  topology : @trace.Topology
  width : Double
  height : Double
  title : Label?
  tracks : ReadOnlyArray[TrackBox]
  terms : ReadOnlyArray[TermBox]
  frames : ReadOnlyArray[Frame]
  wires : ReadOnlyArray[Wire]
  notes : ReadOnlyArray[NoteBox]
  priv point_index : Map[String, Point]
}

///|
/// The coordinates of a topology point.
pub fn Geometry::point(self : Geometry, id : String) -> Point? {
  self.point_index.get(id)
}

///|
/// Make geometry from parts, for tests of the legibility checker.
pub fn Geometry::new(
  topology : @trace.Topology,
  width : Double,
  height : Double,
  tracks : ArrayView[TrackBox],
  terms : ArrayView[TermBox],
  frames : ArrayView[Frame],
  wires : ArrayView[Wire],
  notes : ArrayView[NoteBox],
  points : ArrayView[(String, Point)],
  title? : Label,
) -> Geometry {
  {
    topology,
    width,
    height,
    title,
    tracks: ReadOnlyArray::from_array(tracks),
    terms: ReadOnlyArray::from_array(terms),
    frames: ReadOnlyArray::from_array(frames),
    wires: ReadOnlyArray::from_array(wires),
    notes: ReadOnlyArray::from_array(notes),
    point_index: Map::from_array(points.to_owned()),
  }
}

///|
pub fn Geometry::points(self : Geometry) -> Array[(String, Point)] {
  self.point_index.iter().collect()
}

///|
pub struct Result {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// The two railroad source models.
pub(all) enum Model {
  Regex(@regex.Regex)
  Ebnf(@ebnf.Grammar)
} derive(Eq, Debug)

///|
pub extend Model with Eq::{equal, not_equal}

///|
pub extend Model with @debug.Debug::{to_repr}

///|
/// Format a coordinate for SVG with at most three decimals.
pub fn svg_number(value : Double) -> String {
  let scaled = (value * 1000.0).round().to_int64()
  if scaled == 0L {
    return "0"
  }
  let negative = scaled < 0L
  let magnitude = if negative { -scaled } else { scaled }
  let whole = magnitude / 1000L
  let fraction = (magnitude % 1000L).to_int()
  let prefix = if negative { "-" } else { "" }
  if fraction == 0 {
    return "\{prefix}\{whole}"
  }
  let mut digits = (fraction + 1000).to_string()
  digits = cut(digits, 1, digits.length())
  while digits.has_suffix("0") {
    digits = cut(digits, 0, digits.length() - 1)
  }
  "\{prefix}\{whole}.\{digits}"
}

///|
/// The SVG path data of a wire, with rounded corners.
pub fn Wire::path(self : Wire, radius? : Double = 8.0) -> String {
  let p = self.points
  let n = svg_number
  if p.length() == 0 {
    return ""
  }
  let out = StringBuilder()
  out.write_string("M\{n(p[0].x)} \{n(p[0].y)}")
  for i in 1..<p.length() {
    let b = p[i]
    if i + 1 < p.length() {
      let a = p[i - 1]
      let c = p[i + 1]
      let d1 = (b.x - a.x).abs() + (b.y - a.y).abs()
      let d2 = (c.x - b.x).abs() + (c.y - b.y).abs()
      let r = Double::min(radius, Double::min(d1, d2) / 2.0)
      let ux = if d1 == 0.0 { 0.0 } else { (b.x - a.x) / d1 }
      let uy = if d1 == 0.0 { 0.0 } else { (b.y - a.y) / d1 }
      let vx = if d2 == 0.0 { 0.0 } else { (c.x - b.x) / d2 }
      let vy = if d2 == 0.0 { 0.0 } else { (c.y - b.y) / d2 }
      out.write_string(
        " L\{n(b.x - ux * r)} \{n(b.y - uy * r)} Q\{n(b.x)} \{n(b.y)} \{n(b.x + vx * r)} \{n(b.y + vy * r)}",
      )
    } else {
      out.write_string(" L\{n(b.x)} \{n(b.y)}")
    }
  }
  out.to_string()
}

///|
/// The polyline length of a wire.
pub fn Wire::length(self : Wire) -> Double {
  let mut total = 0.0
  for i in 1..<self.points.length() {
    let a = self.points[i - 1]
    let b = self.points[i]
    total += (b.x - a.x).abs() + (b.y - a.y).abs()
  }
  total
}
