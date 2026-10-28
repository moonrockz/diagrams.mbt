///|
/// Pure swimlane geometry has no dependency on BPMN document or geometry types.
pub struct Limits {
  nodes : Int32
  edges : Int32
  depth : Int32
  work : Int32
  output_units : Int32
  minimum_approach : Double
} derive(Eq, Debug)

///|
pub fn Limits::new(
  nodes~ : Int32 = 10000,
  edges~ : Int32 = 50000,
  depth~ : Int32 = 256,
  work~ : Int32 = 1000000,
  output_units~ : Int32 = 16777216,
  minimum_approach~ : Double = 24.0,
) -> Limits {
  { minimum_approach, nodes, edges, depth, work, output_units, }
}

///|
pub(all) struct Point {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
pub(all) struct Rect {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

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
pub(all) enum Kind {
  Lane
  Group
  Node
} derive(Eq, Debug)

///|
pub struct Label {
  text : String
  box : Rect
  size : Double
  weight : Int32
  owner : String
  family : @theme.Family?
} derive(Eq, Debug)

///|
pub struct Shape {
  id : String
  index : Int32
  kind : Kind
  shape : String
  box : Rect
  outline_box : Rect
  label : Label?
  parent : String?
  lane : String?
  expanded : Bool
} derive(Eq, Debug)

///|
pub struct Connection {
  connection : @model.Connection
  index : Int32
  source : String
  target : String
  line : ReadOnlyArray[Point]
  label : Label?
} derive(Eq, Debug)

///|
pub struct Geometry {
  view : @model.Swimlane
  shapes : ReadOnlyArray[Shape]
  connections : ReadOnlyArray[Connection]
  width : Int32
  height : Int32
} derive(Eq, Debug)

///|
pub struct Result {
  geometry : Geometry?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
priv struct Budget {
  limits : Limits
  diagnostics : Array[@diagrams.Diagnostic]
  mut work : Int32
  mut failed : Bool
}

///|
fn Budget::error(self : Budget, code : String, message : String) -> Unit {
  if !self.failed {
    self.diagnostics.push(@diagrams.Diagnostic::error(code, message))
  }
  self.failed = true
}

///|
fn Budget::charge(self : Budget, amount : Int32) -> Bool {
  if amount < 0 || amount > self.limits.work - self.work {
    self.error("swimlane/layout-limit", "Swimlane geometry work limit exceeded")
    return false
  }
  self.work += amount
  true
}

///|
/// Canonical coordinates have three fractional digits and never use exponent notation.
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
/// An inert plain-text projection. Source HTML is never inserted into SVG.
pub fn label_text(text : String) -> String {
  let normalized = plain_text(text)
  let out = StringBuilder()
  let mut cursor = 0
  let mut chunk = 0
  fn letter(n : Int32) -> Bool {
    (n >= 65 && n <= 90) || (n >= 97 && n <= 122)
  }
  while cursor < normalized.length() {
    if normalized.code_unit_at(cursor).to_int() != 60 {
      cursor += 1
      continue
    }
    if normalized.view(start_offset=cursor).has_prefix("<!--") {
      if normalized.view(start_offset=cursor + 4).find("-->") is Some(relative) {
        out.write_string(
          normalized.view(start_offset=chunk, end_offset=cursor).to_owned(),
        )
        cursor += 4 + relative + 3
        chunk = cursor
        continue
      } else {
        cursor = normalized.length()
        continue
      }
    }
    let mut name = cursor + 1
    if name < normalized.length() &&
      normalized.code_unit_at(name).to_int() == 47 {
      name += 1
    }
    if name >= normalized.length() ||
      (
        !letter(normalized.code_unit_at(name).to_int()) &&
        !normalized.view(start_offset=cursor).has_prefix("<!--")
      ) {
      cursor += 1
      continue
    }
    let mut end = name
    let mut quote = 0
    let mut closed = false
    let mut restart = false
    while end < normalized.length() {
      let u = normalized.code_unit_at(end).to_int()
      if quote != 0 {
        if u == quote {
          quote = 0
        }
      } else if u == 34 || u == 39 {
        quote = u
      } else if u == 62 {
        closed = true
        end += 1
        break
      } else if u == 60 {
        restart = true
        break
      }
      end += 1
    }
    if closed {
      out.write_string(
        normalized.view(start_offset=chunk, end_offset=cursor).to_owned(),
      )
      cursor = end
      chunk = end
    } else if restart {
      cursor = end
    } else {
      cursor = normalized.length()
    }
  }
  out.write_string(normalized.view(start_offset=chunk).to_owned())
  out
  .to_string()
  .replace_all(old="&lt;", new="<")
  .replace_all(old="&gt;", new=">")
  .replace_all(old="&quot;", new="\"")
  .replace_all(old="&amp;", new="&")
}

///|
fn plain_text(text : String) -> String {
  text
  .replace_all(old="<br/>", new="\n")
  .replace_all(old="<br />", new="\n")
  .replace_all(old="<br>", new="\n")
  .replace_all(old="\r\n", new="\n")
  .replace_all(old="\r", new="\n")
}

///|
fn measure(
  text : String,
  size~ : Int32 = 13,
  weight~ : Int32 = 400,
) -> (Double, Double) {
  let metrics = @metrics.FontMetrics::from_defaults(
    profile=Monospace,
    font_size=size,
    font_weight=weight,
  )
  let mut width = 0
  for line in text.split("\n") {
    width = Int32::max(width, metrics.measure(line.to_owned()).width)
  }
  (
    width.to_double(),
    text.split("\n").count().to_double() * (size + 4).to_double(),
  )
}

///|
fn make_label(
  text : String,
  owner : String,
  box : Rect,
  header : Bool,
  family : @theme.Family?,
) -> Label? {
  let text = plain_text(text)
  if text.is_empty() {
    return None
  }
  let (width, height) = measure(text, weight=if header { 700 } else { 400 })
  let r : Rect = if header {
    { x: box.x + 16.0, y: box.y + 12.0, width, height, }
  } else {
    {
      x: box.x + (box.width - width) / 2.0,
      y: box.y + (box.height - height) / 2.0,
      width,
      height,
    }
  }
  Some({
    text,
    owner,
    box: r,
    size: 13.0,
    weight: if header {
      700
    } else {
      400
    },
    family,
  })
}

///|
pub fn family(shape : String) -> @theme.Family {
  match shape {
    "diamond" | "hexagon" | "tri" | "flip-tri" | "notch-pent" => Cloud
    "cylinder" | "h-cyl" | "lin-cyl" | "win-pane" | "bow-rect" => Database
    "circle"
    | "doublecircle"
    | "sm-circ"
    | "fr-circ"
    | "f-circ"
    | "cross-circ" => MessageBus
    "doc" | "docs" | "lin-doc" | "tag-doc" | "flag" => Frontend
    "brace" | "brace-r" | "braces" | "text" => External
    _ => Backend
  }
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
pub extend Label with Eq::{equal, not_equal}

///|
pub extend Label with @debug.Debug::{to_repr}

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
pub extend Result with Eq::{equal, not_equal}

///|
pub extend Result with @debug.Debug::{to_repr}

///|
/// Preserve palette hues while making ink readable on opaque canvas and fills.
pub fn palette(p : @theme.Palette) -> @theme.Palette {
  fn shade(c : @theme.FamilyColors) -> @theme.FamilyColors {
    { ..c, ink: @theme.text_shade(c.ink, [p.bg, @theme.over(c.fill, p.bg)]), }
  }
  {
    ..p,
    frontend: shade(p.frontend),
    backend: shade(p.backend),
    database: shade(p.database),
    cloud: shade(p.cloud),
    security: shade(p.security),
    messagebus: shade(p.messagebus),
    external: shade(p.external),
  }
}

///|
/// Label kind selects presentation projection explicitly. Plain labels keep
/// operators and formatting-like punctuation; source metadata remains inert.
pub fn project_label(text : String, kind : @model.LabelKind) -> String {
  match kind {
    Text => plain_text(text)
    Html => label_text(text)
    Markdown => {
      let mut text = label_text(text)
      for marker in ["**", "__", "`", "*", "_"] {
        text = strip_pairs(text, marker)
      }
      text
    }
  }
}

///|
fn strip_pairs(text : String, marker : String) -> String {
  let out = StringBuilder()
  let mut cursor = 0
  while cursor < text.length() {
    let tail = text.view(start_offset=cursor)
    guard tail.find(marker) is Some(relative) else {
      out.write_string(tail.to_owned())
      break
    }
    let open = cursor + relative
    let start = open + marker.length()
    guard text.view(start_offset=start).find(marker) is Some(relative_end) else {
      out.write_string(tail.to_owned())
      break
    }
    let end = start + relative_end
    let content = text.view(start_offset=start, end_offset=end)
    if end == start ||
      content.has_prefix(" ") ||
      content.has_suffix(" ") ||
      content.has_prefix("\n") ||
      content.has_suffix("\n") {
      out.write_string(
        text.view(start_offset=cursor, end_offset=start).to_owned(),
      )
      cursor = start
    } else {
      out.write_string(
        text.view(start_offset=cursor, end_offset=open).to_owned(),
      )
      out.write_string(content.to_owned())
      cursor = end + marker.length()
    }
  }
  out.to_string()
}

///|
/// Retain resource limits while selecting the marked terminal reservation.
pub fn Limits::with_minimum_approach(
  self : Limits,
  minimum_approach : Double,
) -> Limits {
  { ..self, minimum_approach, }
}
