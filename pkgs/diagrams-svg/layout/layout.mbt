///|
let margin = 32

///|
let top = 24

///|
let box_height = 48

///|
let box_padding = 16

///|
let box_min_width = 96

///|
let box_gap = 48

///|
let participant_size = 12

///|
let message_size = 11

///|
let chip_padding = 8

///|
let chip_height = 20

///|
/// The free space between a label chip and each lifeline.
let chip_margin = 16

///|
/// The distance from the lifeline to the end of a message line.
let line_inset = 7

///|
let first_row = 52

///|
let row_height = 48

///|
let bottom_space = 32

///|
fn text_width(content : String, size : Int, weight : Int) -> Int {
  @metrics.FontMetrics::from_defaults(
    profile=Monospace,
    font_size=size,
    font_weight=weight,
  )
  .measure(content)
  .width
}

///|
fn make_label(
  content : String,
  x : Int,
  baseline : Int,
  size : Int,
  weight : Int,
  ink : Ink,
  backdrop : ArrayView[Layer],
  owner : String,
) -> Label {
  let w = text_width(content, size, weight)
  {
    content,
    x,
    baseline,
    size,
    weight,
    box: { x: x - w / 2, y: baseline - size, width: w, height: size + 4 },
    ink,
    backdrop: ReadOnlyArray::from_array(backdrop),
    owner,
  }
}

///|
/// The geometry of `sequence`. Participants are columns in model order. Each
/// message is one row. The gaps between columns grow until each message label
/// fits between the lifelines that it connects.
pub fn layout(sequence : @sequence.Sequence) -> Geometry {
  let parts = sequence.participants.iter().to_array()
  let n = parts.length()
  let mut cycle_index = 0
  let families = parts.map(p => {
    let f = @theme.family_of(p.kind, cycle_index)
    if p.kind == Participant {
      cycle_index += 1
    }
    f
  })
  let widths = parts.map(p => {
    let w = text_width(p.label, participant_size, 600) + 2 * box_padding
    if w > box_min_width {
      w
    } else {
      box_min_width
    }
  })
  let gap_count = if n > 1 { n - 1 } else { 0 }
  let gaps = Array::makei(gap_count, i => widths[i] / 2 + widths[i + 1] / 2 + box_gap)
  let index_of = (id : String) => {
    let mut found = -1
    for i, p in parts {
      if p.id == id {
        found = i
        break
      }
    }
    found
  }
  let messages = []
  for e in sequence.events {
    match e {
      Message(m) => messages.push(m)
    }
  }
  for m in messages {
    let a = index_of(m.sender)
    let b = index_of(m.receiver)
    guard a >= 0 && b >= 0 && a != b else { continue }
    let lo = if a < b { a } else { b }
    let hi = if a < b { b } else { a }
    let chip = text_width(m.label, message_size, 400) + 2 * chip_padding
    let need = chip + 2 * chip_margin
    let mut have = 0
    for i in lo..<hi {
      have += gaps[i]
    }
    if need > have {
      let extra = need - have
      let count = hi - lo
      for i in lo..<hi {
        gaps[i] += extra / count + (if i - lo < extra % count { 1 } else { 0 })
      }
    }
  }
  let centres = []
  let mut x = if n > 0 { margin + widths[0] / 2 } else { margin }
  for i in 0..<n {
    centres.push(x)
    if i < n - 1 {
      x += gaps[i]
    }
  }
  let width = if n > 0 { centres[n - 1] + widths[n - 1] / 2 + margin } else {
    2 * margin
  }
  let boxes = parts.mapi((i, p) => {
    let w = widths[i]
    let c = centres[i]
    {
      id: p.id,
      family: families[i],
      box: { x: c - w / 2, y: top, width: w, height: box_height },
      label: make_label(
        p.label,
        c,
        top + box_height / 2 + 4,
        participant_size,
        600,
        Primary,
        [Mask, Fill(families[i])],
        "participant:\{p.id}",
      ),
      lifeline_x: c,
    }
  })
  let lifeline_top = top + box_height
  let lines = []
  for k, m in messages {
    let a = index_of(m.sender)
    let b = index_of(m.receiver)
    guard a >= 0 && b >= 0 else { continue }
    let y = lifeline_top + first_row + k * row_height
    let dir = if b >= a { 1 } else { -1 }
    let x1 = centres[a] + line_inset * dir
    let x2 = centres[b] - line_inset * dir
    let mid = (centres[a] + centres[b]) / 2
    let chip_w = text_width(m.label, message_size, 400) + 2 * chip_padding
    let chip_y = y - 14 - chip_height / 2
    let family = families[a]
    lines.push({
      index: k,
      sender: m.sender,
      receiver: m.receiver,
      family,
      x1,
      x2,
      y,
      chip: { x: mid - chip_w / 2, y: chip_y, width: chip_w, height: chip_height },
      label: make_label(
        m.label,
        mid,
        chip_y + chip_height / 2 + 4,
        message_size,
        400,
        Accent(family),
        [Mask],
        "message:\{k}",
      ),
    })
  }
  let lifeline_bottom = if lines.length() > 0 {
    lines[lines.length() - 1].y + 36
  } else {
    lifeline_top + 40
  }
  {
    width,
    height: lifeline_bottom + bottom_space,
    lifeline_top,
    lifeline_bottom,
    participants: ReadOnlyArray::from_array(boxes),
    messages: ReadOnlyArray::from_array(lines),
  }
}
