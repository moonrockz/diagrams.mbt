///|
/// A legibility rule.
pub(all) enum Rule {
  Overlap
  Fit
  Size
  Contrast
} derive(Eq, Debug)

///|
pub extend Rule with Eq::{not_equal, equal}

///|
pub extend Rule with @debug.Debug::{to_repr}

///|
/// One break of a legibility rule.
pub(all) struct Finding {
  rule : Rule
  message : String
} derive(Eq, Debug)

///|
pub extend Finding with Eq::{not_equal, equal}

///|
pub extend Finding with @debug.Debug::{to_repr}

///|
/// The smallest text size, in pixels.
pub let min_text_size = 11

///|
/// The smallest contrast ratio of text against the colour behind it.
pub let min_contrast = 4.5

///|
/// The space that a label needs inside its box or chip, on each side.
let fit_padding = 4

///|
fn ink_color(p : @theme.Palette, ink : Ink) -> @theme.Color {
  match ink {
    Primary => p.text
    Muted => p.muted
    Accent(f) => p.family(f).ink
    Color(c) => c
  }
}

///|
fn backdrop_color(p : @theme.Palette, layers : ReadOnlyArray[Layer]) -> @theme.Color {
  let mut c = p.bg
  for layer in layers {
    c = match layer {
      Mask => p.mask
      Fill(f) => @theme.over(p.family(f).fill, c)
      Tint(tint) => @theme.over(tint, c)
    }
  }
  c
}

///|
fn ratio_text(r : Double) -> String {
  let hundredths = (r * 100.0).round().to_int()
  let frac = hundredths % 100
  "\{hundredths / 100}.\{if frac < 10 { "0" } else { "" }}\{frac}"
}

///|
fn contains(outer : Rect, inner : Rect, padding : Int) -> Bool {
  inner.x >= outer.x + padding && inner.y >= outer.y + padding &&
  inner.x + inner.width <= outer.x + outer.width - padding &&
  inner.y + inner.height <= outer.y + outer.height - padding
}

///|
fn border(box : Rect, owner : String) -> Array[Segment] {
  let right = box.x + box.width
  let bottom = box.y + box.height
  [
    { x1: box.x, y1: box.y, x2: right, y2: box.y, owner },
    { x1: right, y1: box.y, x2: right, y2: bottom, owner },
    { x1: right, y1: bottom, x2: box.x, y2: bottom, owner },
    { x1: box.x, y1: bottom, x2: box.x, y2: box.y, owner },
  ]
}

///|
/// A stroke occupies one pixel on either side of its centre line. Layout
/// paths are axis aligned, including all three segments of a self-message.
fn stroke_box(line : Segment) -> Rect {
  { x: min(line.x1, line.x2) - 1, y: min(line.y1, line.y2) - 1,
    width: (line.x2 - line.x1).abs() + 2, height: (line.y2 - line.y1).abs() + 2 }
}

///|
/// Check every text block and its actual container. Lifelines are the sole
/// excluded lines: opaque label chips may cover them. Frame and group borders,
/// section dividers, message paths, activation bars and lifetime crosses count.
/// Contrast composes background layers in paint order and then the text alpha.
pub fn check(geometry : Geometry, palette : @theme.Palette) -> Array[Finding] {
  let findings : Array[Finding] = []
  let labels : Array[(Label, Rect)] = []
  let blockers : Array[(String, Rect)] = []
  let lines : Array[Segment] = []
  fn add(label : Label?, container : Rect?) -> Unit {
    if label is Some(label) {
      labels.push((label, container.unwrap_or({ x: label.box.x, y: label.box.y, width: 0, height: 0 })))
    }
  }
  for p in geometry.participants {
    labels.push((p.label, p.box))
    if p.sublabel is Some(label) { labels.push((label, p.box)) }
    blockers.push(("participant:\{p.id}", p.box))
    if p.destroyed {
      blockers.push(("destruction:\{p.id}", { x: p.lifeline_x - 6, y: p.lifeline_bottom - 6, width: 12, height: 12 }))
    }
  }
  for m in geometry.messages {
    labels.push((m.label, m.chip))
    blockers.push((m.label.owner, m.chip))
    if m.sublabel is Some(label) { labels.push((label, m.chip)) }
    lines.append(m.path[:])
  }
  for note in geometry.notes {
    labels.push((note.label, note.box))
    blockers.push((note.label.owner, note.box))
  }
  for bar in geometry.activations { blockers.push(("activation:\{bar.participant}:\{bar.depth}", bar.box)) }
  for frame in geometry.frames {
    add(frame.header, frame.chip)
    if frame.header is Some(label) && frame.chip is Some(chip) { blockers.push((label.owner, chip)) }
    lines.append(border(frame.box, "border:frame:\{frame.index}"))
    for section in frame.sections {
      add(section.label, section.chip)
      if section.label is Some(label) && section.chip is Some(chip) { blockers.push((label.owner, chip)) }
      if section.divider is Some(line) { lines.push(line) }
    }
  }
  for group in geometry.groups {
    labels.push((group.label, group.chip))
    blockers.push((group.label.owner, group.chip))
    lines.append(border(group.box, "border:group:\{group.group.id}"))
  }
  add(geometry.title, geometry.title_box)
  if geometry.title is Some(label) && geometry.title_box is Some(box) { blockers.push((label.owner, box)) }
  let canvas : Rect = { x: 0, y: 0, width: geometry.width, height: geometry.height }
  for i, item in labels {
    let (label, container) = item
    if label.size < min_text_size {
      findings.push({ rule: Size, message: "\"\{label.content}\" is \{label.size} px; the minimum is \{min_text_size} px" })
    }
    let measured_width = text_width(label.content, label.size, label.weight)
    let measured_height = text_height(label.content, label.size)
    if measured_width > label.box.width || measured_height > label.box.height ||
      !contains(container, label.box, fit_padding) || !contains(canvas, container, 0) {
      findings.push({ rule: Fit, message: "\"\{label.content}\" does not fit in its container or canvas" })
    }
    for j in (i + 1)..<labels.length() {
      if label.box.overlaps(labels[j].0.box) {
        findings.push({ rule: Overlap, message: "\"\{label.content}\" overlaps \"\{labels[j].0.content}\"" })
      }
    }
    for (owner, box) in blockers {
      if owner != label.owner && label.box.overlaps(box) {
        findings.push({ rule: Overlap, message: "\"\{label.content}\" overlaps \{owner}" })
      }
    }
    for line in lines {
      if line.owner != label.owner && label.box.overlaps(stroke_box(line)) {
        findings.push({ rule: Overlap, message: "\"\{label.content}\" overlaps the line of \{line.owner}" })
      }
    }
    let background = backdrop_color(palette, label.backdrop)
    let foreground = @theme.over(ink_color(palette, label.ink), background)
    let ratio = @theme.contrast(foreground, background)
    if ratio < min_contrast {
      findings.push({ rule: Contrast, message: "\"\{label.content}\" has a contrast of \{ratio_text(ratio)}:1; the minimum is 4.5:1" })
    }
  }
  findings
}
