///|
/// One final visible connector and its untouched original route. Identities refer
/// to source connections, message indices or hierarchy/grammar occurrences.
pub struct ResolvedConnector {
  id : String
  source : String
  target : String
  route : ConnectorPath
  path : ConnectorPath
  mask : String?
} derive(Eq, Debug)

///|
pub struct ConnectorGeometry {
  paths : ReadOnlyArray[ResolvedConnector]
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
/// A protected outline or label rectangle. `owner` can identify an endpoint
/// whose attachment is intentional. Use an empty owner for unrelated content.
pub(all) struct ConnectorObstacle {
  owner : String
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Eq, Debug)

///|
/// Inspect a rendered artifact. This accepts only this renderer's generated SVG,
/// not general XML. Original routes and final geometry are immutable values.
pub fn inspect_connectors(
  canonical_svg : String,
) -> ReadOnlyArray[ResolvedConnector] {
  let paths = []
  for line in canonical_svg.split("\n") {
    let tag = line.trim_start().to_owned()
    if !tag.has_prefix("<path ") {
      continue
    }
    if scene_attribute(tag, "data-connector-route") is Some(route) &&
      scene_attribute(tag, "d") is Some(path) &&
      ConnectorPath::parse(route) is Some(route) &&
      ConnectorPath::parse(path) is Some(path) {
      paths.push({
        id: scene_attribute(tag, "data-connector-id").unwrap_or(""),
        source: scene_attribute(tag, "data-connector-source").unwrap_or(""),
        target: scene_attribute(tag, "data-connector-target").unwrap_or(""),
        route,
        path,
        mask: scene_attribute(tag, "mask"),
      })
    }
  }
  ReadOnlyArray::from_array(paths)
}

///|
/// Render and inspect in one layout pass. Diagnostics include refused styling.
pub fn SvgRenderer::connector_geometry(
  self : SvgRenderer,
  diagram : @render.Diagram,
) -> ConnectorGeometry {
  let result = self.render(diagram)
  {
    paths: result.output.map(inspect_connectors).unwrap_or([]),
    diagnostics: result.diagnostics,
  }
}

///|
fn cintersects(
  a : ConnectorPoint,
  b : ConnectorPoint,
  box : ConnectorObstacle,
) -> Bool {
  let dx = b.x - a.x
  let dy = b.y - a.y
  let mut lo = 0.0
  let mut hi = 1.0
  for
    (p, q) in [
      (-dx, a.x - box.x),
      (dx, box.x + box.width - a.x),
      (-dy, a.y - box.y),
      (dy, box.y + box.height - a.y),
    ] {
    if p.abs() < 0.0000001 {
      if q <= 0.001 {
        return false
      }
    } else {
      let t = q / p
      if p < 0.0 {
        lo = lo.max(t)
      } else {
        hi = hi.min(t)
      }
      if lo >= hi {
        return false
      }
    }
  }
  hi > 0.001 && lo < 0.999
}

///|
/// Check the actual flattened curves, including every bridge. Underpass masks
/// exempt no shape or label. Intentional endpoint attachment is owner-scoped.
/// Work exhaustion is an error and never a successful incomplete check.
pub fn check_connectors(
  paths : ArrayView[ResolvedConnector],
  obstacles : ArrayView[ConnectorObstacle],
  width~ : Double,
  height~ : Double,
  limits~ : ConnectorLimits = ConnectorLimits::new(),
) -> ReadOnlyArray[@diagrams.Diagnostic] {
  let diagnostics = []
  let work : ConnectorWork = {
    options: ConnectorOptions::new(limits~),
    diagnostics,
    candidates: 0,
    subdivisions: 0,
    segments: 0,
    crossings: 0,
    failed: false,
  }
  for connector in paths {
    let flat = cflatten(connector.path, work)
    for segment in flat {
      if !work.charge(0) {
        return ReadOnlyArray::from_array(diagnostics)
      }
      if [segment.a, segment.b]
        .iter()
        .any(p => p.x < 0.0 || p.y < 0.0 || p.x > width || p.y > height) {
        diagnostics.push(
          @diagrams.Diagnostic::error(
            "connector/routing-conflict",
            "Connector outside viewport: " + connector.id,
          ),
        )
        break
      }
      for obstacle in obstacles {
        if !work.charge(0) {
          return ReadOnlyArray::from_array(diagnostics)
        }
        if obstacle.owner != "" &&
          (
            obstacle.owner == connector.source ||
            obstacle.owner == connector.target
          ) {
          continue
        }
        if cintersects(segment.a, segment.b, obstacle) {
          diagnostics.push(
            @diagrams.Diagnostic::error(
              "connector/routing-conflict",
              "Connector intersects protected content: " +
              connector.id +
              " / " +
              obstacle.owner,
            ),
          )
          break
        }
      }
    }
  }
  ReadOnlyArray::from_array(diagnostics)
}

///|
pub extend ResolvedConnector with Eq::{equal, not_equal}

///|
pub extend ResolvedConnector with @debug.Debug::{to_repr}

///|
pub extend ConnectorGeometry with Eq::{equal, not_equal}

///|
pub extend ConnectorGeometry with @debug.Debug::{to_repr}

///|
pub extend ConnectorObstacle with Eq::{equal, not_equal}

///|
pub extend ConnectorObstacle with @debug.Debug::{to_repr}

///|
/// Construct immutable absolute geometry, refusing invalid numeric coordinates.
pub fn ConnectorPath::new(
  commands : ArrayView[ConnectorCommand],
) -> ConnectorPath? {
  if commands.is_empty() || !(commands[0] is Move(_)) {
    return None
  }
  fn finite(p : ConnectorPoint) -> Bool {
    p.x == p.x &&
    p.y == p.y &&
    p.x.abs() <= 1000000000.0 &&
    p.y.abs() <= 1000000000.0
  }
  for command in commands {
    let valid = match command {
      Move(p) | Line(p) => finite(p)
      Quadratic(c, p) => finite(c) && finite(p)
      Cubic(a, b, p) => finite(a) && finite(b) && finite(p)
    }
    if !valid {
      return None
    }
  }
  Some({ commands: ReadOnlyArray::from_array(commands), })
}
