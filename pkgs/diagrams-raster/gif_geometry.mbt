///|
/// GIF motion samples the final measured connector, including bridge curves.
/// Segment subdivision is bounded and independent of a browser clock or DOM.
suberror GifError {
  GifInvalid(String)
} derive(Debug)

///|
pub extend GifError with @debug.Debug::{to_repr}

///|
priv struct GifSegment {
  a : @svg.ConnectorPoint
  b : @svg.ConnectorPoint
  length : Double
}

///|
priv struct GifPath {
  segments : ReadOnlyArray[GifSegment]
  length : Double
  first : @svg.ConnectorPoint
}

///|
fn gif_distance(a : @svg.ConnectorPoint, b : @svg.ConnectorPoint) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn gif_lerp(
  a : @svg.ConnectorPoint,
  b : @svg.ConnectorPoint,
  t : Double,
) -> @svg.ConnectorPoint {
  { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, }
}

///|
fn gif_curve(
  start : @svg.ConnectorPoint,
  command : @svg.ConnectorCommand,
  t : Double,
) -> @svg.ConnectorPoint {
  match command {
    Move(p) => p
    Line(p) => gif_lerp(start, p, t)
    Quadratic(control, end) =>
      gif_lerp(gif_lerp(start, control, t), gif_lerp(control, end, t), t)
    Cubic(a, b, end) => {
      let ab = gif_lerp(a, b, t)
      gif_lerp(
        gif_lerp(gif_lerp(start, a, t), ab, t),
        gif_lerp(ab, gif_lerp(b, end, t), t),
        t,
      )
    }
  }
}

///|
fn gif_path(
  path : @svg.ConnectorPath,
  max_segments : Int32,
) -> GifPath raise GifError {
  guard max_segments > 0 else {
    raise GifInvalid("Invalid path segment budget")
  }
  let segments : Array[GifSegment] = []
  let mut start : @svg.ConnectorPoint = { x: 0.0, y: 0.0, }
  let mut first = start
  let mut total = 0.0
  let mut seen = false
  for command in path.commands {
    if command is Move(p) {
      start = p
      if !seen {
        first = p
        seen = true
      }
      continue
    }
    fn split(lo : Double, hi : Double, depth : Int32) -> Unit raise GifError {
      let a = gif_curve(start, command, lo)
      let b = gif_curve(start, command, hi)
      let mut error = 0.0
      for fraction in [0.25, 0.5, 0.75] {
        error = error.max(
          gif_distance(
            gif_curve(start, command, lo + (hi - lo) * fraction),
            gif_lerp(a, b, fraction),
          ),
        )
      }
      if error > 0.025 {
        guard depth < 16 else {
          raise GifInvalid("Connector subdivision depth exhausted")
        }
        split(lo, (lo + hi) * 0.5, depth + 1)
        split((lo + hi) * 0.5, hi, depth + 1)
      } else {
        guard segments.length() < max_segments else {
          raise GifInvalid("Connector segment budget exhausted")
        }
        let length = gif_distance(a, b)
        total += length
        segments.push({ a, b, length, })
      }
    }
    split(0.0, 1.0, 0)
    start = gif_curve(start, command, 1.0)
  }
  guard seen else { raise GifInvalid("Connector has no starting point") }
  { segments: ReadOnlyArray::from_array(segments), length: total, first, }
}

///|
fn GifPath::point(self : GifPath, progress : Double) -> @svg.ConnectorPoint {
  if progress <= 0.0 {
    return self.first
  }
  if progress >= 1.0 {
    return self.segments.last().map(s => s.b).unwrap_or(self.first)
  }
  let mut remaining = self.length * progress.max(0.0).min(1.0)
  for segment in self.segments {
    if segment.length > 0.0 && remaining <= segment.length {
      return gif_lerp(segment.a, segment.b, remaining / segment.length)
    }
    remaining -= segment.length
  }
  self.segments.last().map(s => s.b).unwrap_or(self.first)
}
