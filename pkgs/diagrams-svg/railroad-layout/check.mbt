///|
pub(all) enum Rule {
  /// A connector crosses a term or label, or two terms overlap.
  Overlap
  /// A label does not fit inside its term with the required padding.
  Fit
  Contrast
  /// A connector does not start or end at its topology point.
  Endpoint
  /// A connector has no length.
  Length
  Limit
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{equal, not_equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
pub struct Finding {
  rule : Rule
  identities : ReadOnlyArray[String]
  message : String
} derive(Eq, Debug)

///|
pub extend Finding with Eq::{equal, not_equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
/// The fill, stroke and text colours of a term shape in one palette. The
/// painter and the checker use the same choice.
pub fn term_colors(
  palette : @theme.Palette,
  shape : Shape,
) -> (@theme.Color, @theme.Color, @theme.Color) {
  let family : @theme.Family = match shape {
    Pill => Frontend
    Square => Database
    Class => Cloud
    Special => MessageBus
    Anchor | Lookaround | Dot => External
  }
  let c = palette.family(family)
  (c.fill, c.stroke, palette.text)
}

///|
/// The four static trace highlight channels.
pub(all) enum Channel {
  Matched
  NotMatched
  Taken
  Failure
} derive(Eq, Debug)

///|
pub extend Channel with Eq::{equal, not_equal}

///|
pub extend Channel with @debug.Debug::{to_repr}

///|
/// The theme colour of a highlight channel.
pub fn channel_color(palette : @theme.Palette, channel : Channel) -> @theme.Color {
  match channel {
    Matched => palette.backend.ink
    NotMatched => palette.messagebus.ink
    Taken => palette.database.ink
    Failure => palette.security.ink
  }
}

///|
fn crosses(a : Point, b : Point, box : Rect) -> Bool {
  let left = box.x + 0.5
  let right = box.x + box.width - 0.5
  let top = box.y + 0.5
  let bottom = box.y + box.height - 0.5
  if left >= right || top >= bottom {
    return false
  }
  let dx = b.x - a.x
  let dy = b.y - a.y
  let mut low = 0.0
  let mut high = 1.0
  for
    pair in [
      (-dx, a.x - left),
      (dx, right - a.x),
      (-dy, a.y - top),
      (dy, bottom - a.y),
    ] {
    let (p, q) = pair
    if p == 0.0 {
      if q < 0.0 {
        return false
      }
    } else {
      let t = q / p
      if p < 0.0 {
        low = Double::max(low, t)
      } else {
        high = Double::min(high, t)
      }
      if low > high {
        return false
      }
    }
  }
  true
}

///|
fn near(a : Point, b : Point) -> Bool {
  (a.x - b.x).abs() < 0.01 && (a.y - b.y).abs() < 0.01
}

///|
/// Check attachment, connector length, crossings, label fit and contrast.
/// `colors` overrides the highlight colours to check, for example caller
/// styles of a trace highlight.
pub fn check(
  geometry : Geometry,
  palette : @theme.Palette,
  work_limit? : Int = 1000000,
  highlight_colors? : ArrayView[@theme.Color] = [],
) -> Array[Finding] {
  let out : Array[Finding] = []
  let mut work = 0
  fn charge(units : Int) -> Bool {
    if units > work_limit - work {
      if out.is_empty() || out[out.length() - 1].rule != Limit {
        out.push({ rule: Limit, identities: [], message: "Legibility check work limit exceeded" })
      }
      return false
    }
    work += units
    true
  }
  for wire in geometry.wires {
    if !charge(1) {
      return out
    }
    let c = wire.connector
    let first = wire.points.get(0)
    let last = wire.points.last()
    match (first, last, geometry.point(c.from), geometry.point(c.to)) {
      (Some(a), Some(b), Some(p), Some(q)) =>
        if !near(a, p) || !near(b, q) {
          out.push({
            rule: Endpoint,
            identities: [c.id],
            message: "Connector \{c.id} is not attached to its points",
          })
        }
      _ =>
        out.push({
          rule: Endpoint,
          identities: [c.id],
          message: "Connector \{c.id} has no points",
        })
    }
    if wire.length() <= 0.0 {
      out.push({
        rule: Length,
        identities: [c.id],
        message: "Connector \{c.id} has no length",
      })
    }
  }
  for term in geometry.terms {
    if !charge(1) {
      return out
    }
    let r = term.rect
    let t = term.term
    match (geometry.point(t.entry), geometry.point(t.exit)) {
      (Some(a), Some(b)) =>
        if (a.x - r.x).abs() > 0.01 ||
          (b.x - (r.x + r.width)).abs() > 0.01 ||
          a.y < r.y ||
          a.y > r.y + r.height {
          out.push({
            rule: Endpoint,
            identities: [t.id],
            message: "Term \{t.id} is not on its entry and exit points",
          })
        }
      _ =>
        out.push({
          rule: Endpoint,
          identities: [t.id],
          message: "Term \{t.id} has no entry or exit point",
        })
    }
    if term.shape != Lookaround && term.shape != Dot {
      let l = term.label.box
      if l.x < r.x + 4.0 - 0.01 ||
        l.x + l.width > r.x + r.width - 4.0 + 0.01 ||
        l.y < r.y + 2.0 - 0.01 ||
        l.y + l.height > r.y + r.height - 2.0 + 0.01 {
        out.push({
          rule: Fit,
          identities: [t.id],
          message: "The label of \{t.id} does not fit inside its term with padding",
        })
      }
      let (fill, _, ink) = term_colors(palette, term.shape)
      let shown = @theme.over(fill, palette.bg)
      if @theme.contrast(ink, shown) < 4.5 {
        out.push({
          rule: Contrast,
          identities: [t.id],
          message: "The label of \{t.id} has insufficient contrast",
        })
      }
    }
  }
  // Crossings: a wire must not pass through a term that it does not belong to.
  for wire in geometry.wires {
    for term in geometry.terms {
      if !charge(wire.points.length()) {
        return out
      }
      let r = term.rect
      let inside = wire.points.iter().all(p => {
        p.x >= r.x && p.x <= r.x + r.width && p.y >= r.y && p.y <= r.y + r.height
      })
      if term.shape == Lookaround && inside {
        continue
      }
      let boxes = [r]
      for note in term.notes {
        boxes.push(note.box)
      }
      let mut hit = false
      for i in 1..<wire.points.length() {
        for b in boxes {
          if crosses(wire.points[i - 1], wire.points[i], b) {
            hit = true
          }
        }
      }
      if hit {
        out.push({
          rule: Overlap,
          identities: [wire.connector.id, term.term.id],
          message: "Connector \{wire.connector.id} crosses \{term.term.id}",
        })
      }
    }
    if wire.label is Some(label) {
      for i in 1..<wire.points.length() {
        if crosses(wire.points[i - 1], wire.points[i], label.box) {
          out.push({
            rule: Overlap,
            identities: [wire.connector.id],
            message: "Connector \{wire.connector.id} crosses its label",
          })
          break
        }
      }
    }
  }
  for i, a in geometry.terms {
    for j in (i + 1)..<geometry.terms.length() {
      if !charge(1) {
        return out
      }
      let b = geometry.terms[j]
      if a.rect.overlaps(b.rect) &&
        !a.rect.contains(b.rect) &&
        !b.rect.contains(a.rect) {
        out.push({
          rule: Overlap,
          identities: [a.term.id, b.term.id],
          message: "Terms \{a.term.id} and \{b.term.id} overlap",
        })
      }
    }
  }
  let channels = [
    channel_color(palette, Matched),
    channel_color(palette, NotMatched),
    channel_color(palette, Taken),
    channel_color(palette, Failure),
  ]
  for color in highlight_colors {
    channels.push(color)
  }
  for color in channels {
    if @theme.contrast(@theme.over(color, palette.bg), palette.bg) < 3.0 {
      out.push({
        rule: Contrast,
        identities: [],
        message: "A trace highlight colour has insufficient contrast with the background",
      })
    }
  }
  out
}
