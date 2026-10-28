///|
/// Explicit presentation style. Omission preserves intrinsic family geometry.
pub(all) enum ConnectorStyle {
  Elbow
  Rounded
  Curved
} derive(Eq, Debug)

///|
pub(all) enum CrossingMode {
  Bridge
  Plain
} derive(Eq, Debug)

///|
/// Per-call connector budgets. Every candidate and generated segment is charged.
pub struct ConnectorLimits {
  candidates : Int32
  subdivisions : Int32
  segments : Int32
  crossings : Int32
  output_units : Int32
} derive(Eq, Debug)

///|
pub fn ConnectorLimits::new(
  candidates~ : Int32 = 2000000,
  subdivisions~ : Int32 = 200000,
  segments~ : Int32 = 100000,
  crossings~ : Int32 = 10000,
  output_units~ : Int32 = 16777216,
) -> ConnectorLimits {
  { candidates, subdivisions, segments, crossings, output_units, }
}

///|
pub struct ConnectorOptions {
  style : ConnectorStyle?
  crossing : CrossingMode
  minimum_approach : Double
  corner_radius : Double
  bridge_radius : Double
  style_supplied_bpmn : Bool
  limits : ConnectorLimits
} derive(Eq, Debug)

///|
pub fn ConnectorOptions::new(
  style? : ConnectorStyle,
  crossing~ : CrossingMode = Bridge,
  minimum_approach~ : Double = 24.0,
  corner_radius~ : Double = 8.0,
  bridge_radius~ : Double = 5.0,
  style_supplied_bpmn~ : Bool = false,
  limits~ : ConnectorLimits = ConnectorLimits::new(),
) -> ConnectorOptions {
  {
    style,
    crossing,
    minimum_approach,
    corner_radius,
    bridge_radius,
    style_supplied_bpmn,
    limits,
  }
}

///|
pub(all) struct ConnectorPoint {
  x : Double
  y : Double
} derive(Eq, Debug)

///|
/// Absolute SVG commands. Source route points remain separate from these values.
pub(all) enum ConnectorCommand {
  Move(ConnectorPoint)
  Line(ConnectorPoint)
  Quadratic(ConnectorPoint, ConnectorPoint)
  Cubic(ConnectorPoint, ConnectorPoint, ConnectorPoint)
} derive(Eq, Debug)

///|
pub struct ConnectorPath {
  commands : ReadOnlyArray[ConnectorCommand]
} derive(Eq, Debug)

///|
fn cn(value : Double) -> String {
  @swimlane_layout.svg_number(value)
}

///|
fn cp(p : ConnectorPoint) -> String {
  "\{cn(p.x)} \{cn(p.y)}"
}

///|
pub fn ConnectorPath::svg(self : ConnectorPath) -> String {
  let out = StringBuilder()
  for i, command in self.commands {
    if i > 0 {
      out.write_string(" ")
    }
    match command {
      Move(p) => out.write_string("M" + cp(p))
      Line(p) => out.write_string("L" + cp(p))
      Quadratic(c, p) => out.write_string("Q" + cp(c) + " " + cp(p))
      Cubic(a, b, p) =>
        out.write_string("C" + cp(a) + " " + cp(b) + " " + cp(p))
    }
  }
  out.to_string()
}

///|
fn clerp(a : ConnectorPoint, b : ConnectorPoint, t : Double) -> ConnectorPoint {
  { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, }
}

///|
fn cdist(a : ConnectorPoint, b : ConnectorPoint) -> Double {
  ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).sqrt()
}

///|
fn cend(command : ConnectorCommand) -> ConnectorPoint {
  match command {
    Move(p) | Line(p) | Quadratic(_, p) | Cubic(_, _, p) => p
  }
}

///|
fn cpoint(
  start : ConnectorPoint,
  command : ConnectorCommand,
  t : Double,
) -> ConnectorPoint {
  match command {
    Move(p) => p
    Line(p) => clerp(start, p, t)
    Quadratic(c, p) => clerp(clerp(start, c, t), clerp(c, p, t), t)
    Cubic(a, b, p) =>
      clerp(
        clerp(clerp(start, a, t), clerp(a, b, t), t),
        clerp(clerp(a, b, t), clerp(b, p, t), t),
        t,
      )
  }
}

///|
fn csplit(
  start : ConnectorPoint,
  command : ConnectorCommand,
  t : Double,
) -> (ConnectorCommand, ConnectorCommand) {
  match command {
    Move(p) => (Move(p), Move(p))
    Line(p) => (Line(clerp(start, p, t)), Line(p))
    Quadratic(c, p) => {
      let a = clerp(start, c, t)
      let b = clerp(c, p, t)
      let m = clerp(a, b, t)
      (Quadratic(a, m), Quadratic(b, p))
    }
    Cubic(a, b, p) => {
      let x = clerp(start, a, t)
      let y = clerp(a, b, t)
      let z = clerp(b, p, t)
      let u = clerp(x, y, t)
      let v = clerp(y, z, t)
      let m = clerp(u, v, t)
      (Cubic(x, u, m), Cubic(v, z, p))
    }
  }
}

///|
fn cslice(
  start : ConnectorPoint,
  command : ConnectorCommand,
  a : Double,
  b : Double,
) -> ConnectorCommand {
  let (left, _) = csplit(start, command, b)
  if a <= 0.0 {
    left
  } else {
    csplit(start, left, a / b).1
  }
}

///|
/// Read the renderer's absolute path dialect. No author markup is interpreted.
pub fn ConnectorPath::parse(source : String) -> ConnectorPath? {
  let tokens : Array[String] = []
  let token = StringBuilder()
  fn flush() -> Unit {
    let s = token.to_string()
    if s != "" {
      tokens.push(s)
      token.reset()
    }
  }
  for c in source {
    if "MLHVQC".contains(c.to_string()) {
      flush()
      tokens.push(c.to_string())
    } else if c == ' ' || c == ',' || c == '\n' || c == '\t' {
      flush()
    } else if c == '-' &&
      token.to_string() != "" &&
      !token.to_string().has_suffix("e") &&
      !token.to_string().has_suffix("E") {
      flush()
      token.write_char(c)
    } else {
      token.write_char(c)
    }
  }
  flush()
  let commands : Array[ConnectorCommand] = []
  let mut i = 0
  let mut current : ConnectorPoint = { x: 0.0, y: 0.0, }
  while i < tokens.length() {
    let op = tokens[i]
    i += 1
    let count = match op {
      "M" | "L" => 2
      "H" | "V" => 1
      "Q" => 4
      "C" => 6
      _ => return None
    }
    if count > tokens.length() - i {
      return None
    }
    let numbers : Array[Double] = []
    for j in 0..<count {
      let number = @string.parse_double(tokens[i + j]) catch {
        _ => return None
      }
      if number != number || number.abs() > 1000000000.0 {
        return None
      }
      numbers.push(number)
    }
    i += count
    let p : ConnectorPoint = match op {
      "H" => { x: numbers[0], y: current.y, }
      "V" => { x: current.x, y: numbers[0], }
      _ => { x: numbers[count - 2], y: numbers[count - 1], }
    }
    commands.push(
      match op {
        "M" => Move(p)
        "Q" => Quadratic({ x: numbers[0], y: numbers[1], }, p)
        "C" =>
          Cubic(
            { x: numbers[0], y: numbers[1], },
            { x: numbers[2], y: numbers[3], },
            p,
          )
        _ => Line(p)
      },
    )
    current = p
  }
  if commands.is_empty() || !(commands[0] is Move(_)) {
    None
  } else {
    Some({ commands: ReadOnlyArray::from_array(commands), })
  }
}

///|
fn cterminal(
  path : ConnectorPath,
  minimum : Double,
  end_marker : Bool,
) -> ConnectorPath {
  if !end_marker || path.commands.length() < 2 {
    return path
  }
  let commands = path.commands.iter().to_array()
  let last = commands[commands.length() - 1]
  let terminal = minimum.max(14.0)
  match last {
    Cubic(a, b, end) => {
      let length = cdist(b, end)
      if length < 0.001 {
        return path
      }
      let entry = clerp(end, b, terminal / length)
      let control = clerp(end, b, (terminal + 8.0) / length)
      commands[commands.length() - 1] = Cubic(a, control, entry)
      commands.push(Line(end))
    }
    Quadratic(b, end) => {
      let length = cdist(b, end)
      if length < 0.001 {
        return path
      }
      let entry = clerp(end, b, terminal / length)
      commands[commands.length() - 1] = Quadratic(b, entry)
      commands.push(Line(end))
    }
    _ => return path
  }
  { commands: ReadOnlyArray::from_array(commands), }
}

///|
fn cstyle(
  path : ConnectorPath,
  options : ConnectorOptions,
  start_marker : Bool,
  end_marker : Bool,
  scale~ : Double = 1.0,
) -> ConnectorPath {
  guard options.style is Some(style) else { return path }
  let points : Array[ConnectorPoint] = []
  for command in path.commands {
    match command {
      Move(p) | Line(p) => points.push(p)
      Quadratic(c, p) => {
        points.push(c)
        points.push(p)
      }
      Cubic(a, b, p) => {
        points.push(a)
        points.push(b)
        points.push(p)
      }
    }
  }
  if points.length() < 3 {
    return path
  }
  let out : Array[ConnectorCommand] = [Move(points[0])]
  for i in 1..<(points.length() - 1) {
    let a = points[i - 1]
    let b = points[i]
    let c = points[i + 1]
    let before = cdist(a, b)
    let after = cdist(b, c)
    if before < 0.001 || after < 0.001 {
      continue
    }
    if style == Elbow {
      out.push(Line(b))
      continue
    }
    let reserve_before = if i == 1 && start_marker {
      options.minimum_approach.max(14.0)
    } else {
      0.0
    }
    let reserve_after = if i == points.length() - 2 && end_marker {
      options.minimum_approach.max(14.0)
    } else {
      0.0
    }
    let radius = if style == Rounded {
      options.corner_radius
    } else {
      before.min(after) * 0.5
    }
    let cut = (radius * scale)
      .min(before * 0.5)
      .min(after * 0.5)
      .min((before - reserve_before).max(0.0))
      .min((after - reserve_after).max(0.0))
    let entry = clerp(b, a, cut / before)
    let exit = clerp(b, c, cut / after)
    out.push(Line(entry))
    if cut > 0.001 {
      if style == Rounded {
        out.push(Quadratic(b, exit))
      } else {
        out.push(
          Cubic(clerp(entry, b, 0.666667), clerp(exit, b, 0.666667), exit),
        )
      }
    } else {
      out.push(Line(b))
    }
  }
  out.push(Line(points[points.length() - 1]))
  { commands: ReadOnlyArray::from_array(out), }
}

///|
priv struct ConnectorFlat {
  command : Int32
  a : ConnectorPoint
  b : ConnectorPoint
  lo : Double
  hi : Double
}

///|
priv struct ConnectorWork {
  options : ConnectorOptions
  diagnostics : Array[@diagrams.Diagnostic]
  mut candidates : Int32
  mut subdivisions : Int32
  mut segments : Int32
  mut crossings : Int32
  mut failed : Bool
}

///|
fn ConnectorWork::fail(
  self : ConnectorWork,
  code : String,
  message : String,
) -> Unit {
  if !self.failed {
    self.diagnostics.push(@diagrams.Diagnostic::error(code, message))
  }
  self.failed = true
}

///|
fn ConnectorWork::charge(self : ConnectorWork, kind : Int32) -> Bool {
  if self.failed {
    return false
  }
  let limit = self.options.limits
  let exceeded = match kind {
    0 =>
      if self.candidates >= limit.candidates {
        true
      } else {
        self.candidates += 1
        false
      }
    1 =>
      if self.subdivisions >= limit.subdivisions {
        true
      } else {
        self.subdivisions += 1
        false
      }
    2 =>
      if self.segments >= limit.segments {
        true
      } else {
        self.segments += 1
        false
      }
    _ =>
      if self.crossings >= limit.crossings {
        true
      } else {
        self.crossings += 1
        false
      }
  }
  if exceeded {
    self.fail("connector/limit", "Connector processing budget exhausted")
  }
  !self.failed
}

///|
fn cflatten(path : ConnectorPath, work : ConnectorWork) -> Array[ConnectorFlat] {
  let out : Array[ConnectorFlat] = []
  let mut start : ConnectorPoint = { x: 0.0, y: 0.0, }
  for index, command in path.commands {
    if command is Move(p) {
      start = p
      continue
    }
    fn split(lo : Double, hi : Double, depth : Int32) -> Unit {
      if !work.charge(1) {
        return
      }
      let a = cpoint(start, command, lo)
      let b = cpoint(start, command, hi)
      let middle = cpoint(start, command, (lo + hi) * 0.5)
      let q1 = cpoint(start, command, lo + (hi - lo) * 0.25)
      let q3 = cpoint(start, command, lo + (hi - lo) * 0.75)
      let error = cdist(middle, clerp(a, b, 0.5))
        .max(cdist(q1, clerp(a, b, 0.25)))
        .max(cdist(q3, clerp(a, b, 0.75)))
      if error > 0.05 {
        if depth >= 16 {
          work.fail(
            "connector/limit", "Connector subdivision tolerance exceeded its depth budget",
          )
          return
        }
        split(lo, (lo + hi) * 0.5, depth + 1)
        split((lo + hi) * 0.5, hi, depth + 1)
      } else if work.charge(2) {
        out.push({ command: index, a, b, lo, hi, })
      }
    }
    split(0.0, 1.0, 0)
    start = cend(command)
  }
  out
}

///|
fn ccross(a : ConnectorPoint, b : ConnectorPoint) -> Double {
  a.x * b.y - a.y * b.x
}

///|
fn csub(a : ConnectorPoint, b : ConnectorPoint) -> ConnectorPoint {
  { x: a.x - b.x, y: a.y - b.y, }
}

///|
priv struct ConnectorHop {
  command : Int32
  lo : Double
  hi : Double
  radius : Double
  flip : Bool
}

///|
fn ctangent(
  start : ConnectorPoint,
  command : ConnectorCommand,
  t : Double,
) -> ConnectorPoint {
  match command {
    Move(_) => { x: 0.0, y: 0.0, }
    Line(p) => csub(p, start)
    Quadratic(c, p) => clerp(csub(c, start), csub(p, c), t)
    Cubic(a, b, p) =>
      clerp(
        clerp(csub(a, start), csub(b, a), t),
        clerp(csub(b, a), csub(p, b), t),
        t,
      )
  }
}

///|
fn cbridge(
  start : ConnectorPoint,
  command : ConnectorCommand,
  hop : ConnectorHop,
) -> (ConnectorPoint, ReadOnlyArray[ConnectorCommand]) {
  let a = cpoint(start, command, hop.lo)
  let b = cpoint(start, command, hop.hi)
  fn unit(t : Double) -> ConnectorPoint {
    let direction = ctangent(start, command, t)
    let length = cdist({ x: 0.0, y: 0.0, }, direction)
    if length < 0.000001 {
      let delta = csub(b, a)
      let length = cdist(a, b)
      { x: delta.x / length, y: delta.y / length, }
    } else {
      { x: direction.x / length, y: direction.y / length, }
    }
  }
  let center = (hop.lo + hop.hi) * 0.5
  let middle = cpoint(start, command, center)
  let first = unit(hop.lo)
  let tangent = unit(center)
  let last = unit(hop.hi)
  let sign = if hop.flip { -1.0 } else { 1.0 }
  let peak : ConnectorPoint = {
    x: middle.x + tangent.y * hop.radius * sign,
    y: middle.y - tangent.x * hop.radius * sign,
  }
  let control = hop.radius * 0.5
  (
    a,
    [
      Cubic(
        { x: a.x + first.x * control, y: a.y + first.y * control, },
        { x: peak.x - tangent.x * control, y: peak.y - tangent.y * control, },
        peak,
      ),
      Cubic(
        { x: peak.x + tangent.x * control, y: peak.y + tangent.y * control, },
        { x: b.x - last.x * control, y: b.y - last.y * control, },
        b,
      ),
    ],
  )
}

///|
priv struct ConnectorDrawing {
  identity : String
  original : String
  path : ConnectorPath
  source : String
  target : String
  family : String
  start_marker : Bool
  end_marker : Bool
  hops : Array[ConnectorHop]
  holes : Array[(ConnectorPoint, Double)]
  key : Int32
}

///|
fn capply_hops(
  drawing : ConnectorDrawing,
  work : ConnectorWork,
) -> (ConnectorPath, Array[Int32])? {
  let hops = drawing.hops.copy()
  hops.sort_by((a, b) => {
    let order = a.command.compare(b.command)
    if order == 0 {
      a.lo.compare(b.lo)
    } else {
      order
    }
  })
  let commands : Array[ConnectorCommand] = []
  let bridges : Array[Int32] = []
  for index, command in drawing.path.commands {
    if !work.charge(2) {
      return None
    }
    if command is Move(_) {
      commands.push(command)
      continue
    }
    let start = cend(drawing.path.commands[index - 1])
    let mut previous = 0.0
    for hop in hops {
      if !work.charge(0) {
        return None
      }
      if hop.command != index {
        continue
      }
      commands.push(cslice(start, command, previous, hop.lo))
      for curve in cbridge(start, command, hop).1 {
        bridges.push(commands.length())
        commands.push(curve)
      }
      previous = hop.hi
    }
    if previous < 1.0 {
      commands.push(cslice(start, command, previous, 1.0))
    }
  }
  Some(({ commands: ReadOnlyArray::from_array(commands), }, bridges))
}

///|
priv struct ConnectorProtection {
  box : ConnectorObstacle
  endpoint_attachment : Bool
  masked_connection : String?
}

///|
fn cexempt(
  drawing : ConnectorDrawing,
  protection : ConnectorProtection,
) -> Bool {
  if protection.masked_connection == Some(drawing.identity) {
    return true
  }
  protection.endpoint_attachment &&
  protection.box.owner != "" &&
  (
    protection.box.owner == drawing.source ||
    protection.box.owner == drawing.target
  )
}

///|
fn cattr(attrs : ReadOnlyArray[(String, String)], name : String) -> String? {
  for (key, value) in attrs {
    if key == name {
      return Some(value)
    }
  }
  None
}

///|
fn connector_options_valid(options : ConnectorOptions) -> Bool {
  fn finite(x : Double) -> Bool {
    x == x && x.abs() <= 1000000.0
  }
  finite(options.minimum_approach) &&
  options.minimum_approach >= 0.0 &&
  finite(options.corner_radius) &&
  options.corner_radius > 0.0 &&
  finite(options.bridge_radius) &&
  options.bridge_radius > 0.0 &&
  options.limits.candidates >= 0 &&
  options.limits.subdivisions >= 0 &&
  options.limits.segments >= 0 &&
  options.limits.crossings >= 0 &&
  options.limits.output_units >= 0
}

///|
/// Resolve generated visible connectors once, before ID scoping. Layout data is
/// never mutated. Borders, lifelines, symbols and trace copies are excluded.
fn finalize_connectors(
  root : @writer.Node,
  options : ConnectorOptions,
  diagnostics : Array[@diagrams.Diagnostic],
  obstacles~ : ArrayView[ConnectorObstacle] = [],
  viewport? : (Double, Double, Double, Double),
  resource_prefix~ : String = "",
  supplied~ : Bool = false,
  labels~ : ArrayView[(String, ConnectorObstacle)] = [],
) -> @writer.Node? {
  let work : ConnectorWork = {
    options,
    diagnostics,
    candidates: 0,
    subdivisions: 0,
    segments: 0,
    crossings: 0,
    failed: false,
  }
  if !connector_options_valid(options) {
    work.fail(
      "connector/invalid-option", "Connector distances must be finite and non-negative; radii and budgets must be valid",
    )
    return None
  }
  fn default_viewport() -> (Double, Double, Double, Double)? {
    guard root is Element(_, attrs, _) else { return None }
    guard cattr(attrs, "width") is Some(w) && cattr(attrs, "height") is Some(h) else {
      return None
    }
    let width = @string.parse_double(w) catch { _ => return None }
    let height = @string.parse_double(h) catch { _ => return None }
    Some((0.0, 0.0, width, height))
  }
  let viewport = match viewport {
    Some(value) => Some(value)
    None => default_viewport()
  }
  let protections : Array[ConnectorProtection] = []
  for box in obstacles {
    protections.push({
      box,
      endpoint_attachment: true,
      masked_connection: None,
    })
  }
  for (connection, box) in labels {
    protections.push({
      box,
      endpoint_attachment: false,
      masked_connection: if connection == "" {
        None
      } else {
        Some(connection)
      },
    })
  }
  let drawings : Array[ConnectorDrawing] = []
  fn collect(
    node : @writer.Node,
    parent : String,
    source : String,
    target : String,
    identity : String,
  ) -> Unit {
    guard node is Element(name, attrs, children) else { return }
    let identity = cattr(attrs, "data-state-id").unwrap_or(identity)
    let identity = cattr(attrs, "data-connector").unwrap_or(
      cattr(attrs, "data-flowchart-id").unwrap_or(
        cattr(attrs, "data-swimlane-id").unwrap_or(
          cattr(attrs, "data-id").unwrap_or(
            cattr(attrs, "data-member").unwrap_or(
              cattr(attrs, "data-index").unwrap_or(identity),
            ),
          ),
        ),
      ),
    )
    let class = cattr(attrs, "class").unwrap_or("")
    let source = cattr(attrs, "data-from").unwrap_or(
      cattr(attrs, "data-source").unwrap_or(source),
    )
    let target = cattr(attrs, "data-to").unwrap_or(
      cattr(attrs, "data-target").unwrap_or(target),
    )
    let parent = if class != "" { class } else { parent }
    let visible = name == "path" &&
      (
        class == "m-line" ||
        class == "bpmn-connector" ||
        class == "architecture-path" ||
        class.has_prefix("rr-connector ") ||
        class == "data-connector" ||
        class == "swimlane-connector" ||
        class == "flowchart-connector" ||
        class == "state-connector"
      )
    if visible {
      if cattr(attrs, "d") is Some(original) {
        if ConnectorPath::parse(original) is Some(path) {
          let start_marker = cattr(attrs, "marker-start") is Some(_)
          let end_marker = cattr(attrs, "marker-end") is Some(_)
          if supplied &&
            options.style_supplied_bpmn &&
            path.commands.length() > 1 {
            let terminal = options.minimum_approach.max(14.0)
            let first = path.commands[1]
            let last = path.commands[path.commands.length() - 1]
            if (
                start_marker &&
                (
                  !(first is Line(_)) ||
                  cdist(cend(path.commands[0]), cend(first)) < terminal
                )
              ) ||
              (
                end_marker &&
                (
                  !(last is Line(_)) ||
                  cdist(
                    cend(path.commands[path.commands.length() - 2]),
                    cend(last),
                  ) <
                  terminal
                )
              ) {
              work.fail(
                "connector/routing-conflict", "Supplied BPMN path lacks a safe marked approach",
              )
              return
            }
          }
          drawings.push({
            identity: if identity == "" {
              "connector-\{drawings.length()}"
            } else {
              identity
            },
            original,
            path: cstyle(
              cterminal(path, options.minimum_approach, end_marker),
              options,
              start_marker,
              end_marker,
            ),
            source,
            target,
            family: cattr(attrs, "data-owner").unwrap_or(""),
            start_marker,
            end_marker,
            hops: [],
            holes: [],
            key: drawings.length(),
          })
        } else {
          work.fail(
            "connector/routing-conflict", "Unsupported generated connector path",
          )
        }
      }
    }
    if name != "defs" {
      for child in children {
        collect(child, parent, source, target, identity)
      }
    }
  }
  collect(root, "", "", "", "")
  if options.style is Some(style) && style != Elbow {
    for index, drawing in drawings {
      let original = ConnectorPath::parse(drawing.original).unwrap()
      let baseline = cflatten(original, work)
      let mut scale = 1.0
      for attempt in 0..<12 {
        let candidate = cstyle(
          cterminal(original, options.minimum_approach, drawing.end_marker),
          options,
          drawing.start_marker,
          drawing.end_marker,
          scale~,
        )
        let flat = cflatten(candidate, work)
        let mut blocked = false
        for protection in protections {
          let box = protection.box
          if cexempt(drawing, protection) {
            continue
          }
          let mut existing = false
          for segment in baseline {
            if !work.charge(0) {
              return None
            }
            if cintersects(segment.a, segment.b, box) {
              existing = true
              break
            }
          }
          if existing && !(supplied && options.style_supplied_bpmn) {
            continue
          }
          for segment in flat {
            if !work.charge(0) {
              return None
            }
            if cintersects(segment.a, segment.b, box) {
              blocked = true
              break
            }
          }
          if blocked {
            break
          }
        }
        if !blocked {
          drawings[index] = { ..drawing, path: candidate, }
          break
        }
        if attempt == 11 {
          work.fail(
            "connector/routing-conflict",
            "Requested connector curve has no safe corridor: " +
            drawing.identity,
          )
          return None
        }
        scale *= 0.5
      }
    }
  }
  let flats = drawings.map(d => cflatten(d.path, work))
  let preview_flats = flats.copy()
  let extents : Array[(Double, Double, Double, Double)] = []
  for flat in flats {
    let mut left = 1000000000.0
    let mut top = 1000000000.0
    let mut right = -1000000000.0
    let mut bottom = -1000000000.0
    for segment in flat {
      if !work.charge(0) {
        return None
      }
      for p in [segment.a, segment.b] {
        left = left.min(p.x)
        top = top.min(p.y)
        right = right.max(p.x)
        bottom = bottom.max(p.y)
      }
    }
    extents.push((left, top, right, bottom))
  }
  if options.crossing == Bridge {
    for i in 0..<drawings.length() {
      for j in 0..<i {
        if !work.charge(0) {
          return None
        }
        let a = extents[i]
        let b = extents[j]
        if a.2 < b.0 || b.2 < a.0 || a.3 < b.1 || b.3 < a.1 {
          continue
        }
        let over = drawings[i]
        let under = drawings[j]
        let seen : Array[ConnectorPoint] = []
        if over.family != "" && over.family == under.family {
          continue
        }
        for a in flats[i] {
          for b in flats[j] {
            if !work.charge(0) {
              return None
            }
            let r = csub(a.b, a.a)
            let s = csub(b.b, b.a)
            let denominator = ccross(r, s)
            if denominator.abs() < 0.000001 {
              let same_semantics = (
                  over.source != "" &&
                  (over.source == under.source || over.source == under.target)
                ) ||
                (
                  over.target != "" &&
                  (over.target == under.source || over.target == under.target)
                )
              if !same_semantics && ccross(csub(b.a, a.a), r).abs() < 0.000001 {
                let overlap = if r.x.abs() > r.y.abs() {
                  a.a.x.min(a.b.x).max(b.a.x.min(b.b.x)) <
                  a.a.x.max(a.b.x).min(b.a.x.max(b.b.x)) - 0.01
                } else {
                  a.a.y.min(a.b.y).max(b.a.y.min(b.b.y)) <
                  a.a.y.max(a.b.y).min(b.a.y.max(b.b.y)) - 0.01
                }
                if overlap {
                  work.fail(
                    "connector/routing-conflict",
                    "Unrelated connector segments overlap: \{over.original} / \{under.original}",
                  )
                  return None
                }
              }
              continue
            }
            let delta = csub(b.a, a.a)
            let t = ccross(delta, s) / denominator
            let u = ccross(delta, r) / denominator
            if t < -0.000001 || t > 1.000001 || u < -0.000001 || u > 1.000001 {
              continue
            }
            let point = clerp(a.a, a.b, t)
            let ends = [
              cend(over.path.commands[0]),
              cend(over.path.commands[over.path.commands.length() - 1]),
              cend(under.path.commands[0]),
              cend(under.path.commands[under.path.commands.length() - 1]),
            ]
            if ends.iter().any(p => cdist(p, point) < 0.5) {
              continue
            }
            let shared = (
                over.source != "" &&
                (over.source == under.source || over.source == under.target)
              ) ||
              (
                over.target != "" &&
                (over.target == under.source || over.target == under.target)
              )
            if shared &&
              ends
              .iter()
              .any(p => {
                cdist(p, point) <=
                options.minimum_approach.max(14.0) +
                8.0 +
                15.0 +
                options.bridge_radius * 2.0 +
                4.0
              }) {
              continue
            }
            if seen.iter().any(p => cdist(p, point) < 0.5) {
              continue
            }
            seen.push(point)
            fn candidate(
              drawing : ConnectorDrawing,
              segment : ConnectorFlat,
              fraction : Double,
            ) -> (ConnectorHop, Array[(Int32, ConnectorHop)])? {
              let command = drawing.path.commands[segment.command]
              let start = cend(drawing.path.commands[segment.command - 1])
              let at = segment.lo + (segment.hi - segment.lo) * fraction
              let chord = cdist(segment.a, segment.b) /
                (segment.hi - segment.lo)
              if chord < 0.0001 {
                return None
              }
              let mut radius = options.bridge_radius
                .min(at * chord * 0.45)
                .min((1.0 - at) * chord * 0.45)
              for prior in drawing.hops {
                if !work.charge(0) {
                  return None
                }
                if prior.command != segment.command {
                  continue
                }
                let center = (prior.lo + prior.hi) * 0.5
                radius = radius.min((at - center).abs() * chord * 0.45)
              }
              if radius < 2.0 {
                return None
              }
              let lo = (at - radius / chord).max(0.0)
              let hi = (at + radius / chord).min(1.0)
              let adjustments : Array[(Int32, ConnectorHop)] = []
              for index, prior in drawing.hops {
                if !work.charge(0) {
                  return None
                }
                if prior.command != segment.command {
                  continue
                }
                let center = (prior.lo + prior.hi) * 0.5
                let allowed = (at - center).abs() * chord * 0.45
                if allowed < 2.0 {
                  return None
                }
                if prior.radius > allowed {
                  let half = (prior.hi - prior.lo) *
                    0.5 *
                    allowed /
                    prior.radius
                  adjustments.push(
                    (
                      index,
                      {
                        ..prior,
                        lo: center - half,
                        hi: center + half,
                        radius: allowed,
                      },
                    ),
                  )
                }
              }
              let before = cpoint(start, command, lo)
              let after = cpoint(start, command, hi)
              if (
                  segment.command == 1 &&
                  drawing.start_marker &&
                  cdist(start, before) < options.minimum_approach
                ) ||
                (
                  segment.command == drawing.path.commands.length() - 1 &&
                  drawing.end_marker &&
                  cdist(after, cend(command)) < options.minimum_approach
                ) {
                return None
              }
              Some(
                (
                  { command: segment.command, lo, hi, radius, flip: false, },
                  adjustments,
                ),
              )
            }
            fn fit_underpass(
              drawing : ConnectorDrawing,
              pair : (ConnectorHop, Array[(Int32, ConnectorHop)]),
            ) -> (ConnectorHop, Array[(Int32, ConnectorHop)])? {
              let (hop, adjustments) = pair
              let start = cend(drawing.path.commands[0])
              let end = cend(
                drawing.path.commands[drawing.path.commands.length() - 1],
              )
              let first = if drawing.start_marker {
                options.minimum_approach.max(14.0)
              } else {
                2.0
              }
              let last = if drawing.end_marker {
                options.minimum_approach.max(14.0)
              } else {
                2.0
              }
              let available = (cdist(start, point) - first).min(
                cdist(end, point) - last,
              )
              let radius = hop.radius.min((available - 2.5) / 1.5)
              if radius < 2.0 {
                return None
              }
              let center = (hop.lo + hop.hi) * 0.5
              let half = (hop.hi - hop.lo) * 0.5 * radius / hop.radius
              Some(
                (
                  { ..hop, lo: center - half, hi: center + half, radius, },
                  adjustments,
                ),
              )
            }
            let preferred = candidate(over, a, t).bind(pair => {
              fit_underpass(under, pair)
            })
            let (owner, beneath, hop, adjustments) = match preferred {
              Some((hop, adjustments)) => (over, under, hop, adjustments)
              None =>
                match
                  candidate(under, b, u).bind(pair => fit_underpass(over, pair)) {
                  Some((hop, adjustments)) => (under, over, hop, adjustments)
                  None => {
                    work.fail(
                      "connector/routing-conflict",
                      "No safe bridge at \{cp(point)} on \{over.original} crossing \{under.original}",
                    )
                    return None
                  }
                }
            }
            let mut hop = hop
            // Bound the hop against every third routed connector before it is
            // committed. Reducing a radius retains a real arch, never an elbow.
            for attempt in 0..<24 {
              let start = cend(owner.path.commands[hop.command - 1])
              let command = owner.path.commands[hop.command]
              let (entry, curves) = cbridge(start, command, hop)
              let bridge_path : ConnectorPath = {
                commands: ReadOnlyArray::from_array([Move(entry), ..curves]),
              }
              let pieces = cflatten(bridge_path, work)
              let mut conflict = false
              for piece in pieces {
                if viewport is Some((x, y, width, height)) &&
                  [piece.a, piece.b]
                  .iter()
                  .any(p => {
                    p.x < x - 0.05 ||
                    p.y < y - 0.05 ||
                    p.x > x + width + 0.05 ||
                    p.y > y + height + 0.05
                  }) {
                  conflict = true
                  break
                }
                for protection in protections {
                  if !work.charge(0) {
                    return None
                  }
                  if cexempt(owner, protection) {
                    continue
                  }
                  if cintersects(piece.a, piece.b, protection.box) {
                    conflict = true
                    break
                  }
                }
                if conflict {
                  break
                }
              }
              for k in 0..<drawings.length() {
                if conflict {
                  break
                }
                if k == owner.key {
                  continue
                }
                if !work.charge(0) {
                  return None
                }
                let bounds = extents[k]
                if point.x + hop.radius * 2.0 < bounds.0 ||
                  point.x - hop.radius * 2.0 > bounds.2 ||
                  point.y + hop.radius * 2.0 < bounds.1 ||
                  point.y - hop.radius * 2.0 > bounds.3 {
                  continue
                }
                for a in pieces {
                  for b in preview_flats[k] {
                    if !work.charge(0) {
                      return None
                    }
                    let r = csub(a.b, a.a)
                    let u = csub(b.b, b.a)
                    let denominator = ccross(r, u)
                    if denominator.abs() < 0.000001 {
                      continue
                    }
                    let delta = csub(b.a, a.a)
                    let t = ccross(delta, u) / denominator
                    let v = ccross(delta, r) / denominator
                    if t < -0.000001 ||
                      t > 1.000001 ||
                      v < -0.000001 ||
                      v > 1.000001 {
                      continue
                    }
                    let crossing = clerp(a.a, a.b, t)
                    let intended = k == beneath.key &&
                      cdist(point, crossing) <= hop.radius * 1.5 + 1.0
                    if !intended &&
                      !drawings[k].holes
                      .iter()
                      .any(h => cdist(h.0, crossing) <= h.1 - 1.5) {
                      conflict = true
                      break
                    }
                  }
                  if conflict {
                    break
                  }
                }
                if conflict {
                  break
                }
              }
              if !conflict {
                break
              }
              if !hop.flip {
                hop = { ..hop, flip: true, }
                continue
              }
              let radius = (hop.radius * 0.65).max(2.0)
              if radius >= hop.radius {
                work.fail(
                  "connector/routing-conflict", "Bridge has no safe corridor past a third connector",
                )
                return None
              }
              if attempt == 23 {
                work.fail(
                  "connector/limit", "Bridge corridor refinement budget exhausted",
                )
                return None
              }
              let center = (hop.lo + hop.hi) * 0.5
              let half = (hop.hi - hop.lo) * 0.5 * radius / hop.radius
              hop = {
                ..hop,
                lo: center - half,
                hi: center + half,
                radius,
                flip: false,
              }
            }
            if !work.charge(3) {
              return None
            }
            for (index, adjusted) in adjustments {
              owner.hops[index] = adjusted
            }
            owner.hops.push(hop)
            beneath.holes.push((point, hop.radius * 1.5 + 2.5))
            guard capply_hops(owner, work) is Some((preview, _)) else {
              return None
            }
            preview_flats[owner.key] = cflatten(preview, work)
            let mut left = 1000000000.0
            let mut top = 1000000000.0
            let mut right = -1000000000.0
            let mut bottom = -1000000000.0
            for segment in preview_flats[owner.key] {
              if !work.charge(0) {
                return None
              }
              for p in [segment.a, segment.b] {
                left = left.min(p.x)
                top = top.min(p.y)
                right = right.max(p.x)
                bottom = bottom.max(p.y)
              }
            }
            extents[owner.key] = (left, top, right, bottom)
          }
        }
      }
    }
  }
  if work.failed {
    return None
  }
  let defs : Array[@writer.Node] = []
  let resolved = Map([])
  let final_segments : Array[Array[ConnectorFlat]] = []
  let bridge_commands : Array[Array[Int32]] = []
  for drawing in drawings {
    guard capply_hops(drawing, work) is Some((resolved_path, bridges)) else {
      return None
    }
    let commands = resolved_path.commands
    let original = ConnectorPath::parse(drawing.original).unwrap()
    let original_flat = cflatten(original, work)
    let final_flat = cflatten(resolved_path, work)
    final_segments.push(final_flat)
    bridge_commands.push(bridges)
    for segment in final_flat {
      if viewport is Some((x, y, width, height)) &&
        [segment.a, segment.b]
        .iter()
        .any(p => {
          p.x < x - 0.05 ||
          p.y < y - 0.05 ||
          p.x > x + width + 0.05 ||
          p.y > y + height + 0.05
        }) {
        work.fail(
          "connector/routing-conflict",
          "Connector outside viewport: " +
          drawing.identity +
          " " +
          @debug.to_string((segment.a, segment.b, viewport)),
        )
        return None
      }
      let command = resolved_path.commands[segment.command]
      if original.commands.contains(command) &&
        !(supplied && options.style_supplied_bpmn) {
        continue
      }
      for protection in protections {
        let obstacle = protection.box
        if !work.charge(0) {
          return None
        }
        if cexempt(drawing, protection) {
          continue
        }
        if !cintersects(segment.a, segment.b, obstacle) {
          continue
        }
        // Existing masked labels may sit on their original path. They do not
        // grant an exemption to a newly inserted bridge.
        let bridge = command is Cubic(_, _, _) && !drawing.hops.is_empty()
        let mut existing = false
        if !bridge && !(supplied && options.style_supplied_bpmn) {
          for segment in original_flat {
            if !work.charge(0) {
              return None
            }
            if cintersects(segment.a, segment.b, obstacle) {
              existing = true
              break
            }
          }
        }
        if bridge || !existing {
          work.fail(
            "connector/routing-conflict",
            "Styled connector intersects protected content: " +
            drawing.identity +
            " / " +
            obstacle.owner,
          )
          return None
        }
      }
    }
    for _ in commands {
      if !work.charge(2) {
        return None
      }
    }
    let final_path = if drawing.hops.is_empty() &&
      drawing.path == ConnectorPath::parse(drawing.original).unwrap() {
      drawing.original
    } else {
      resolved_path.svg()
    }
    let mask = if drawing.holes.is_empty() {
      None
    } else {
      let id = resource_prefix + "connector-underpass-\{drawing.key}"
      let (x, y, width, height) = viewport.unwrap_or(
        (-1000000.0, -1000000.0, 2000000.0, 2000000.0),
      )
      let bounds = [
        ("x", cn(x)),
        ("y", cn(y)),
        ("width", cn(width)),
        ("height", cn(height)),
      ]
      let children = [
        @writer.element("rect", attrs=[..bounds, ("fill", "white")]),
      ]
      for (point, radius) in drawing.holes {
        children.push(
          @writer.element("circle", attrs=[
            ("cx", cn(point.x)),
            ("cy", cn(point.y)),
            ("r", cn(radius)),
            ("fill", "black"),
          ]),
        )
      }
      defs.push(
        @writer.element(
          "mask",
          attrs=[("id", id), ("maskUnits", "userSpaceOnUse"), ..bounds],
          children~,
        ),
      )
      Some("url(#\{id})")
    }
    resolved[drawing.key] = (final_path, mask)
  }
  // A bridge is new geometry. It may not introduce an unmasked crossing with
  // a third connection that did not intersect the original routed line.
  for i in 0..<drawings.length() {
    if bridge_commands[i].is_empty() {
      continue
    }
    for j in 0..<drawings.length() {
      if i == j {
        continue
      }
      for a in final_segments[i] {
        if !bridge_commands[i].contains(a.command) {
          continue
        }
        for b in final_segments[j] {
          if !work.charge(0) {
            return None
          }
          if a.a.x.max(a.b.x) < b.a.x.min(b.b.x) ||
            b.a.x.max(b.b.x) < a.a.x.min(a.b.x) ||
            a.a.y.max(a.b.y) < b.a.y.min(b.b.y) ||
            b.a.y.max(b.b.y) < a.a.y.min(a.b.y) {
            continue
          }
          let r = csub(a.b, a.a)
          let u = csub(b.b, b.a)
          let denominator = ccross(r, u)
          if denominator.abs() < 0.000001 {
            continue
          }
          let delta = csub(b.a, a.a)
          let t = ccross(delta, u) / denominator
          let v = ccross(delta, r) / denominator
          if t < -0.000001 || t > 1.000001 || v < -0.000001 || v > 1.000001 {
            continue
          }
          let point = clerp(a.a, a.b, t)
          let hidden = drawings[i].holes
            .iter()
            .concat(drawings[j].holes.iter())
            .any(h => cdist(h.0, point) <= h.1 - 1.5)
          if hidden {
            continue
          }
          let over = drawings[i]
          let under = drawings[j]
          let shared = (
              over.source != "" &&
              (over.source == under.source || over.source == under.target)
            ) ||
            (
              over.target != "" &&
              (over.target == under.source || over.target == under.target)
            )
          let ends = [
            cend(over.path.commands[0]),
            cend(over.path.commands[over.path.commands.length() - 1]),
            cend(under.path.commands[0]),
            cend(under.path.commands[under.path.commands.length() - 1]),
          ]
          if shared && ends.iter().any(p => cdist(p, point) < 0.5) {
            continue
          }
          work.fail(
            "connector/routing-conflict",
            "Bridge intersects another connector without an underpass: " +
            over.identity +
            " / " +
            under.identity,
          )
          return None
        }
      }
    }
  }
  let mut ordinal = 0
  fn rewrite(node : @writer.Node, parent : String) -> @writer.Node {
    guard node is Element(name, attrs, children) else { return node }
    let class = cattr(attrs, "class").unwrap_or("")
    let parent = if class != "" { class } else { parent }
    let visible = name == "path" &&
      (
        class == "m-line" ||
        class == "bpmn-connector" ||
        class == "architecture-path" ||
        class.has_prefix("rr-connector ") ||
        class == "data-connector" ||
        class == "swimlane-connector" ||
        class == "flowchart-connector" ||
        class == "state-connector"
      )
    let new_attrs = attrs.iter().to_array()
    if visible {
      let key = ordinal
      ordinal += 1
      if resolved.get(key) is Some((final_path, mask)) {
        for i in 0..<new_attrs.length() {
          if new_attrs[i].0 == "d" {
            new_attrs[i] = ("d", final_path)
          }
        }
        new_attrs.push(("data-connector-id", drawings[key].identity))
        new_attrs.push(("data-connector-source", drawings[key].source))
        new_attrs.push(("data-connector-target", drawings[key].target))
        new_attrs.push(("data-connector-route", drawings[key].original))
        new_attrs.push(("data-connector-key", key.to_string()))
        if mask is Some(mask) {
          new_attrs.push(("mask", mask))
        }
      }
    }
    if name == "path" && class.has_prefix("rr-trace-path ") {
      if cattr(attrs, "d") is Some(original) {
        for drawing in drawings {
          if drawing.original != original {
            continue
          }
          if cattr(attrs, "data-target") is Some(target) &&
            target != drawing.identity {
            continue
          }
          let (final_path, mask) = resolved[drawing.key]
          for i in 0..<new_attrs.length() {
            if new_attrs[i].0 == "d" {
              new_attrs[i] = ("d", final_path)
            }
          }
          if mask is Some(mask) {
            new_attrs.push(("mask", mask))
          }
          break
        }
      }
    }
    let new_children = if name == "defs" {
      children.iter().to_array()
    } else {
      children.map(c => rewrite(c, parent)).iter().to_array()
    }
    if name == "svg" {
      new_attrs.push(("data-connector-options", @debug.to_string(options)))
    }
    if name == "svg" && !defs.is_empty() {
      new_children.push(@writer.element("defs", children=defs))
    }
    @writer.element(name, attrs=new_attrs, children=new_children)
  }
  let result = rewrite(root, "")
  if @writer.to_string(result).length() > options.limits.output_units {
    work.fail("connector/limit", "Connector SVG output budget exhausted")
    None
  } else {
    Some(result)
  }
}

///|
pub extend ConnectorStyle with Eq::{equal, not_equal}

///|
pub extend ConnectorStyle with @debug.Debug::{to_repr}

///|
pub extend CrossingMode with Eq::{equal, not_equal}

///|
pub extend CrossingMode with @debug.Debug::{to_repr}

///|
pub extend ConnectorLimits with Eq::{equal, not_equal}

///|
pub extend ConnectorLimits with @debug.Debug::{to_repr}

///|
pub extend ConnectorOptions with Eq::{equal, not_equal}

///|
pub extend ConnectorOptions with @debug.Debug::{to_repr}

///|
pub extend ConnectorPoint with Eq::{equal, not_equal}

///|
pub extend ConnectorPoint with @debug.Debug::{to_repr}

///|
pub extend ConnectorCommand with Eq::{equal, not_equal}

///|
pub extend ConnectorCommand with @debug.Debug::{to_repr}

///|
pub extend ConnectorPath with Eq::{equal, not_equal}

///|
pub extend ConnectorPath with @debug.Debug::{to_repr}
