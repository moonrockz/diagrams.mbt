///|
/// Explicit bounds for structured-data layout and painting.
pub struct Limits {
  nodes : Int32
  depth : Int32
  work : Int32
  /// The widest value column before text wraps, in SVG units.
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
  width~ : Int32 = 360,
  output_units~ : Int32 = 16777216,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, depth, work, width, output_units, }
}

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
pub fn Rect::contains(
  self : Rect,
  other : Rect,
  tolerance~ : Double = 0.0,
) -> Bool {
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
pub fn Rect::right(self : Rect) -> Double {
  self.x + self.width
}

///|
pub fn Rect::bottom(self : Rect) -> Double {
  self.y + self.height
}

///|
/// The kind of a value, as written in the `data-type` attribute.
pub(all) enum Kind {
  Object
  Array
  String
  Number
  Boolean
  Null
} derive(Eq, Debug)

///|
pub extend Kind with Eq::{equal, not_equal}

///|
pub extend Kind with @debug.Debug::{to_repr}

///|
pub fn Kind::name(self : Kind) -> String {
  match self {
    Object => "object"
    Array => "array"
    String => "string"
    Number => "number"
    Boolean => "boolean"
    Null => "null"
  }
}

///|
pub fn kind_of(value : @model.Value) -> Kind {
  match value {
    Object(_) => Object
    Array(_) => Array
    Text(_) => String
    Number(_) => Number
    Boolean(_) => Boolean
    Null => Null
  }
}

///|
/// The ink of a label. Each scalar kind has its own ink.
pub(all) enum Ink {
  Key
  Index
  Text
  Number
  Boolean
  Null
  /// The summary of a nested container and the mark of an empty one.
  Container
  Title
} derive(Eq, Debug)

///|
pub extend Ink with Eq::{equal, not_equal}

///|
pub extend Ink with @debug.Debug::{to_repr}

///|
/// The theme token of the ink: `text`, `muted` or a family ink.
pub fn Ink::token(self : Ink) -> String {
  match self {
    Key | Title => "text"
    Index | Null | Container => "muted"
    Text => "backend-ink"
    Number => "frontend-ink"
    Boolean => "database-ink"
  }
}

///|
pub fn Ink::color(self : Ink, palette : @theme.Palette) -> @theme.Color {
  match self {
    Key | Title => palette.text
    Index | Null | Container => palette.muted
    Text => palette.backend.ink
    Number => palette.frontend.ink
    Boolean => palette.database.ink
  }
}

///|
/// The ink of a scalar or container value.
pub fn ink_of(kind : Kind) -> Ink {
  match kind {
    Object | Array => Container
    String => Text
    Number => Number
    Boolean => Boolean
    Null => Null
  }
}

///|
/// The visible text of a value. Text and number lexemes are exact. Booleans
/// and null have a mark, so they do not look like text with the same letters.
/// A row of a nested container shows `{…}` or `[…]`, or `{}` or `[]` when the
/// container is empty.
pub fn display_text(value : @model.Value) -> String {
  match value {
    Object(members) => if members.is_empty() { "{}" } else { "{…}" }
    Array(members) => if members.is_empty() { "[]" } else { "[…]" }
    Text(text) => text
    Number(lexeme) => lexeme
    Boolean(true) => "☑ true"
    Boolean(false) => "☐ false"
    Null => "␀ null"
  }
}

///|
/// The background of a highlighted row: the cloud family fill over the
/// box fill.
pub fn highlight_background(palette : @theme.Palette) -> @theme.Color {
  @theme.over(palette.cloud.fill, palette.mask)
}

///|
/// The palette for data views. Each ink that a data label uses gets a shade
/// with 4.5:1 contrast on the box fill and on the highlight background.
pub fn palette(p : @theme.Palette) -> @theme.Palette {
  let backgrounds = [p.mask, highlight_background(p), p.bg]
  fn shade(c : @theme.Color) -> @theme.Color {
    @theme.text_shade(c, backgrounds)
  }
  fn family(f : @theme.FamilyColors) -> @theme.FamilyColors {
    { ..f, ink: shade(f.ink), }
  }
  {
    ..p,
    text: shade(p.text),
    muted: shade(p.muted),
    frontend: family(p.frontend),
    backend: family(p.backend),
    database: family(p.database),
  }
}

///|
/// One measured label. `lines` are the wrapped lines; with the line breaks
/// that wrapping replaced, they give the complete text.
pub struct Label {
  lines : ReadOnlyArray[String]
  box : Rect
  size : Double
  weight : Int32
  ink : Ink
} derive(Eq, Debug)

///|
pub extend Label with Eq::{equal, not_equal}

///|
pub extend Label with @debug.Debug::{to_repr}

///|
/// One member row of a container box.
pub struct Row {
  /// The member identity.
  entry : String
  /// The value node of the member.
  node : String
  kind : Kind
  box : Rect
  /// The member name, or the muted position `[i]` in an array.
  key : Label?
  /// The scalar text, or the summary of a nested container.
  value : Label?
  highlighted : Bool
  /// The start of the connector to a nested container.
  port : Point?
} derive(Eq, Debug)

///|
pub extend Row with Eq::{equal, not_equal}

///|
pub extend Row with @debug.Debug::{to_repr}

///|
/// One box: a container with its rows, or a scalar root.
pub struct Box {
  node : String
  kind : Kind
  box : Rect
  /// The x position of the line between the key and value columns.
  divider : Double?
  rows : ReadOnlyArray[Row]
  /// The value of a scalar root, or the mark of an empty container.
  label : Label?
  highlighted : Bool
  depth : Int32
} derive(Eq, Debug)

///|
pub extend Box with Eq::{equal, not_equal}

///|
pub extend Box with @debug.Debug::{to_repr}

///|
/// A drawn connector from a row to the box of its nested container. The
/// points are the start, the end of the straight part, two curve controls
/// and the end.
pub struct Connector {
  /// The member identity of the row that owns the connector.
  entry : String
  source : String
  target : String
  points : ReadOnlyArray[Point]
} derive(Eq, Debug)

///|
pub extend Connector with Eq::{equal, not_equal}

///|
pub extend Connector with @debug.Debug::{to_repr}

///|
/// The SVG path data of the connector.
pub fn Connector::path(self : Connector) -> String {
  let n = svg_number
  let p = self.points
  guard p.length() == 5 else {
    let out = StringBuilder()
    for i, point in p {
      out.write_string(if i == 0 { "M" } else { " L" })
      out.write_string("\{n(point.x)} \{n(point.y)}")
    }
    return out.to_string()
  }
  let head = "M\{n(p[0].x)} \{n(p[0].y)}"
  let straight = if p[1].x != p[0].x { " H\{n(p[1].x)}" } else { "" }
  head +
  straight +
  " C\{n(p[2].x)} \{n(p[2].y)} \{n(p[3].x)} \{n(p[3].y)} \{n(p[4].x)} \{n(p[4].y)}"
}

///|
/// Sample points along the connector, for checks.
pub fn Connector::samples(
  self : Connector,
  count~ : Int32 = 16,
) -> Array[Point] {
  let p = self.points
  guard p.length() == 5 else { return p.iter().to_array() }
  let out = [p[0], p[1]]
  for i in 1..<=count {
    let t = i.to_double() / count.to_double()
    let s = 1.0 - t
    let a = s * s * s
    let b = 3.0 * s * s * t
    let c = 3.0 * s * t * t
    let d = t * t * t
    out.push({
      x: a * p[1].x + b * p[2].x + c * p[3].x + d * p[4].x,
      y: a * p[1].y + b * p[2].y + c * p[3].y + d * p[4].y,
    })
  }
  out
}

///|
/// The measured geometry of one data view.
pub struct Geometry {
  tree : @model.DataTree
  width : Int32
  height : Int32
  title : Label?
  boxes : ReadOnlyArray[Box]
  connectors : ReadOnlyArray[Connector]
} derive(Eq, Debug)

///|
pub extend Geometry with Eq::{equal, not_equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
pub struct Result {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
/// Canonical coordinates have at most three fractional digits and never use
/// exponent notation.
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
  let digits = "\{if fraction < 100 { "0" } else { "" }}\{if fraction < 10 { "0" } else { "" }}\{fraction}"
  "\{prefix}\{whole}." + digits.trim_end(chars="0").to_owned()
}

///|
pub fn Limits::with_minimum_approach(
  self : Limits,
  minimum_approach : Double,
) -> Limits {
  { ..self, minimum_approach, }
}
