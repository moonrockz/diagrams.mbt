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
  }
}

///|
fn backdrop_color(p : @theme.Palette, layers : ReadOnlyArray[Layer]) -> @theme.Color {
  let mut c = p.bg
  for layer in layers {
    c = match layer {
      Mask => p.mask
      Fill(f) => @theme.over(p.family(f).fill, c)
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
/// The legibility findings of `geometry` with the colours of `palette`. The
/// check finds overlapping texts and boxes, text that does not fit in its box
/// or chip, text smaller than `min_text_size`, and text with less contrast
/// than `min_contrast`. Lifelines do not count for overlap, because label
/// chips are opaque.
pub fn check(geometry : Geometry, palette : @theme.Palette) -> Array[Finding] {
  let findings = []
  let labels = []
  for p in geometry.participants {
    labels.push(p.label)
  }
  for m in geometry.messages {
    labels.push(m.label)
  }
  for l in labels {
    if l.size < min_text_size {
      findings.push({
        rule: Size,
        message: "\"\{l.content}\" is \{l.size} px; the minimum is \{min_text_size} px",
      })
    }
  }
  for i, a in labels {
    for j in (i + 1)..<labels.length() {
      let b = labels[j]
      if a.box.overlaps(b.box) {
        findings.push({
          rule: Overlap,
          message: "\"\{a.content}\" overlaps \"\{b.content}\"",
        })
      }
    }
    for p in geometry.participants {
      if a.owner != "participant:\{p.id}" && a.box.overlaps(p.box) {
        findings.push({
          rule: Overlap,
          message: "\"\{a.content}\" overlaps the box of \{p.id}",
        })
      }
    }
  }
  for m in geometry.messages {
    for other in geometry.messages {
      if other.index != m.index {
        let lo = if other.x1 < other.x2 { other.x1 } else { other.x2 }
        let w = (other.x2 - other.x1).abs()
        let line = { x: lo, y: other.y - 1, width: w, height: 2 }
        if m.chip.overlaps(line) {
          findings.push({
            rule: Overlap,
            message: "the label of message \{m.index} overlaps message \{other.index}",
          })
        }
      }
    }
  }
  for p in geometry.participants {
    if p.label.box.width + 2 * fit_padding > p.box.width {
      findings.push({
        rule: Fit,
        message: "\"\{p.label.content}\" does not fit in its box",
      })
    }
  }
  for m in geometry.messages {
    if m.label.box.width + 2 * fit_padding > m.chip.width {
      findings.push({
        rule: Fit,
        message: "\"\{m.label.content}\" does not fit in its chip",
      })
    }
  }
  for l in labels {
    let r = @theme.contrast(ink_color(palette, l.ink), backdrop_color(palette, l.backdrop))
    if r < min_contrast {
      findings.push({
        rule: Contrast,
        message: "\"\{l.content}\" has a contrast of \{ratio_text(r)}:1; the minimum is 4.5:1",
      })
    }
  }
  findings
}
