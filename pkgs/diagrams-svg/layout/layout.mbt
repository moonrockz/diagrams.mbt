///|
let margin = 32

///|
fn clearance(obstacle : Int) -> Int { max(16, obstacle + 8) }

///|
fn frame_name(kind : @sequence.FrameKind) -> String {
  match kind {
    Loop => "loop"; Alt => "alt"; Opt => "opt"; Par => "par"; ParOver => "par over";
    Critical => "critical"; Break => "break"; Rect => "rect"
  }
}

///|
/// Choose the free horizontal interval nearest a preferred centre. Lifelines
/// are intentionally absent from the obstacles; activation bars and group
/// borders are not. The column pass reserves at least one interval that fits.
fn free_x(left : Int, right : Int, width : Int, preferred : Int, obstacles : Array[(Int, Int)]) -> Int {
  let sorted = obstacles.copy()
  sorted.sort_by((a, b) => a.0.compare(b.0))
  let mut cursor = left
  let mut found = left
  let mut distance = 0x3fffffff
  for (a, b) in [..sorted, (right + 8, right + 8)] {
    let end = min(a - 8, right)
    if end - cursor >= width {
      let x = max(cursor, min(preferred - width / 2, end - width))
      let d = (x + width / 2 - preferred).abs()
      if d < distance { found = x; distance = d }
    }
    cursor = max(cursor, b + 8)
  }
  found
}

///|
/// Layout in two passes: measured horizontal constraints, then an event cursor
/// for rows. The result retains every sequence element for a separate painter.
pub fn layout(sequence : @sequence.Sequence) -> Geometry {
  let parts = sequence.participants.iter().to_array()
  let n = parts.length()
  fn index(id : String) -> Int {
    for i, p in parts { if p.id == id { return i } }
    -1
  }
  let mut cycle = 0
  let families = parts.map(p => {
    let kind = p.render_kind()
    let family = @theme.family_of(kind, cycle)
    if kind == Participant { cycle += 1 }
    family
  })
  let widths = parts.map(p => max(96, max(text_width(p.label, 12, 600), participant_sublabel(p).map(s => text_width(s, 11, 400)).unwrap_or(0)) + 32))
  let heights = parts.map(p => max(48, text_height(p.label, 12) + participant_sublabel(p).map(s => text_height(s, 11) + 4).unwrap_or(0) + 24))
  let groups : Array[(@sequence.BoxGroup, Int, Int)] = []
  for i, p in parts {
    if p.group is Some(group) {
      match groups.search_by(g => g.0.id == group.id) {
        Some(j) => { let old = groups[j]; groups[j] = (old.0, old.1, i) }
        None => groups.push((group, i, i))
      }
    }
  }
  for (group, first, last) in groups {
    if first == last { widths[first] = max(widths[first], text_width(group.label, 12, 600) + 32) }
  }
  let depths = Array::make(n, 0)
  let max_depths = Array::make(n, 0)
  let created = Array::make(n, false)
  let all_messages : Array[@sequence.Message] = []
  let all_notes : Array[@sequence.Note] = []
  let mut frame_depth = 0
  let mut header_width = 0
  let mut header_lane = 0
  fn measure(events : ReadOnlyArray[@sequence.Event], depth : Int) -> Unit {
    for e in events {
      match e {
        Message(m) => all_messages.push(m)
        Note(note) => all_notes.push(note)
        Activate(id) => {
          let i = index(id)
          if i >= 0 { depths[i] += 1; max_depths[i] = max(max_depths[i], depths[i]) }
        }
        Deactivate(id) => { let i = index(id); if i >= 0 { depths[i] = max(0, depths[i] - 1) } }
        Create(id) => { let i = index(id); if i >= 0 { created[i] = true } }
        Destroy(id) => { let i = index(id); if i >= 0 { depths[i] = 0 } }
        Frame(f) => {
          frame_depth = max(frame_depth, depth + 1)
          for j, s in f.sections {
            let text = if j == 0 { frame_name(f.kind) + s.label.map(t => " \{t}").unwrap_or("") } else { s.label.unwrap_or("") }
            header_width = max(header_width, text_width(text, 11, 600) + (depth + 1) * 32 + 32)
            if (j > 0 || f.kind != Rect) && (groups.length() > 0 || depths.iter().any(d => d > 0)) {
              header_lane = max(header_lane, text_width(text, 11, 600) + (depth + 1) * 16 + 32)
            }
            measure(s.events, depth + 1)
          }
        }
        Autonumber(_) => ()
      }
    }
  }
  measure(sequence.events, 0)
  let left_clear = Array::make(n, 7)
  let right_clear = Array::makei(n, i => max(7, (max_depths[i] - 1) * 4 + 5))
  for i in 0..<n {
    if created[i] { left_clear[i] = widths[i] / 2 + 8; right_clear[i] = max(right_clear[i], widths[i] / 2 + 8) }
  }
  for (_, first, last) in groups {
    left_clear[first] = max(left_clear[first], widths[first] / 2 + 18)
    right_clear[last] = max(right_clear[last], widths[last] / 2 + 18)
  }
  let left_lanes = left_clear.copy()
  let right_lanes = right_clear.copy()
  let gaps = Array::makei(max(0, n - 1), i => widths[i] / 2 + widths[i + 1] / 2 + 48)
  fn spread(lo : Int, hi : Int, need : Int) -> Unit {
    let mut have = 0
    for i in lo..<hi { have += gaps[i] }
    if need > have && hi > lo {
      let missing = need - have
      for i in lo..<hi { gaps[i] += missing / (hi - lo) + (if i - lo < missing % (hi - lo) { 1 } else { 0 }) }
    }
  }
  for m in all_messages {
    let a = index(m.sender)
    let b = index(m.receiver)
    if a < 0 || b < 0 { continue }
    let (w, _) = chip_size(message_text(m), message_sublabel(m))
    if a == b { right_lanes[a] = max(right_lanes[a], clearance(right_clear[a]) + w + 16) }
    else {
      let lo = min(a, b)
      let hi = max(a, b)
      spread(lo, hi, w + clearance(right_clear[lo]) + clearance(left_clear[hi]))
      let mut blocked = groups.length() > 0
      for i in (lo + 1)..<hi { if max_depths[i] > 0 { blocked = true } }
      if blocked {
        gaps[lo] = max(gaps[lo], w + clearance(right_clear[lo]) + clearance(left_clear[lo + 1]) + 16)
      }
    }
  }
  for note in all_notes {
    let ids = note.participants.iter().map(index).filter(i => i >= 0).to_array()
    if ids.is_empty() { continue }
    let mut lo = ids[0]
    let mut hi = lo
    for i in ids { lo = min(lo, i); hi = max(hi, i) }
    let w = text_width(note.text, 11, 400) + 24
    match note.placement {
      LeftOf => left_lanes[lo] = max(left_lanes[lo], left_clear[lo] + w + 24)
      RightOf => right_lanes[hi] = max(right_lanes[hi], right_clear[hi] + w + 24)
      Over => right_lanes[lo] = max(right_lanes[lo], right_clear[lo] + w + 24)
    }
  }
  for i in 0..<gaps.length() {
    gaps[i] = max(gaps[i], max(right_lanes[i] + left_clear[i + 1], right_clear[i] + left_lanes[i + 1]) + 24)
  }
  for (group, first, last) in groups {
    let w = text_width(group.label, 12, 600)
    spread(first, last, w + 32 - widths[first] / 2 - widths[last] / 2)
    if first < last { gaps[first] = max(gaps[first], w + right_clear[first] + left_clear[first + 1] + 32) }
  }
  let centres = Array::make(n, 0)
  let mut x = margin + frame_depth * 16 + header_lane + (if n > 0 { max(widths[0] / 2, left_lanes[0]) } else { 0 })
  for i in 0..<n { centres[i] = x; if i < n - 1 { x += gaps[i] } }
  let width = max(header_width + margin * 2, if n > 0 { centres[n - 1] + max(widths[n - 1] / 2, right_lanes[n - 1]) + margin + frame_depth * 16 } else { margin * 2 })
  let title_box = sequence.title.map(text => { x: margin, y: 16, width: max(width - margin * 2, text_width(text, 12, 600) + 16), height: text_height(text, 12) + 16 })
  let width = max(width, title_box.map(b => b.x + b.width + margin).unwrap_or(width))
  let title = sequence.title.map(text => make_label(text, width / 2, 24, 12, 600, Primary, [Mask], "title"))
  let group_top = title_box.map(b => b.y + b.height + 16).unwrap_or(24)
  let mut group_header = 0
  for (group, _, _) in groups { group_header = max(group_header, text_height(group.label, 12) + 24) }
  let participant_top = group_top + group_header
  let mut initial_bottom = participant_top
  for i in 0..<n { if !created[i] { initial_bottom = max(initial_bottom, participant_top + heights[i]) } }
  if n == 0 { initial_bottom = participant_top + 48 }
  let obstacles = []
  for i in 0..<n { if max_depths[i] > 0 { obstacles.push((centres[i] - 5, centres[i] + 5 + (max_depths[i] - 1) * 4)) } }
  for (_, first, last) in groups {
    let l = centres[first] - widths[first] / 2 - 16
    let r = centres[last] + widths[last] / 2 + 16
    obstacles.push((l - 1, l + 1)); obstacles.push((r - 1, r + 1))
  }
  let box_y = Array::make(n, participant_top)
  let destruction_y : Array[Int?] = Array::make(n, None)
  let starts : Array[Array[Int]] = Array::makei(n, _ => [])
  let pending_creations : Array[Int] = []
  let messages : Array[MessageLine] = []
  let notes : Array[NoteBox] = []
  let activations : Array[ActivationBar] = []
  let frames : Array[FrameBox] = []
  let mut cursor = initial_bottom + 28
  let mut last_message_y = cursor
  let mut after_message = false
  fn flush_creations() -> Unit {
    for i in pending_creations { box_y[i] = cursor; cursor += heights[i] + 16 }
    pending_creations.clear()
  }
  fn finish_activation(i : Int, end : Int) -> Unit {
    if starts[i].pop() is Some(start) {
      let depth = starts[i].length()
      if end > start { activations.push({ participant: parts[i].id, depth, box: { x: centres[i] - 5 + depth * 4, y: start, width: 10, height: end - start } }) }
    }
  }
  fn walk(events : ReadOnlyArray[@sequence.Event], parent : Int?, level : Int) -> Unit {
    for event in events {
      if !(event is (Create(_) | Message(_))) { flush_creations() }
      match event {
        Message(m) => {
          let a = index(m.sender)
          let b = index(m.receiver)
          if a < 0 || b < 0 { continue }
          let k = messages.length()
          let owner = "message:\{k}"
          let (w, h) = chip_size(message_text(m), message_sublabel(m))
          let dir = if b >= a { 1 } else { -1 }
          let end_offset = (i : Int, right : Bool) => {
            if pending_creations.contains(i) { (if right { 1 } else { -1 }) * (widths[i] / 2) }
            else if starts[i].is_empty() { (if right { 7 } else { -7 }) }
            else { (starts[i].length() - 1) * 4 + (if right { 5 } else { -5 }) }
          }
          let x1 = centres[a] + end_offset(a, dir > 0)
          let x2 = centres[b] + end_offset(b, a == b || dir < 0)
          let y = cursor + h + 4
          for i in pending_creations { box_y[i] = y - heights[i] / 2 }
          let chip_x = if a == b { centres[a] + clearance(right_clear[a]) } else {
            let lo = min(a, b)
            let hi = max(a, b)
            free_x(centres[lo] + clearance(right_clear[lo]), centres[hi] - clearance(left_clear[hi]), w, (centres[a] + centres[b]) / 2, obstacles)
          }
          let chip = { x: chip_x, y: cursor, width: w, height: h }
          let family = families[a]
          let label = make_label(message_text(m), chip.x + w / 2, chip.y + 4, 11, 400, Accent(family), [Mask], owner)
          let sublabel = message_sublabel(m).map(s => make_label(s, chip.x + w / 2, label.box.y + label.box.height + 4, 11, 400, Muted, [Mask], owner))
          let path : Array[Segment] = if a == b {
            let bend = max(x1 + 40, chip.x + chip.width + 8)
            [{ x1, y1: y, x2: bend, y2: y, owner }, { x1: bend, y1: y, x2: bend, y2: y + 28, owner }, { x1: bend, y1: y + 28, x2, y2: y + 28, owner }]
          } else { [{ x1, y1: y, x2, y2: y, owner }] }
          messages.push({ index: k, sender: m.sender, receiver: m.receiver, family, x1, x2, y, chip, label, sublabel, path: ReadOnlyArray::from_array(path), message: m })
          last_message_y = if a == b { y + 28 } else { y }
          cursor = max(cursor + 48, last_message_y + 20)
          for i in pending_creations { cursor = max(cursor, box_y[i] + heights[i] + 16) }
          pending_creations.clear()
          after_message = true
        }
        Note(note) => {
          let ids = note.participants.iter().map(index).filter(i => i >= 0).to_array()
          if ids.is_empty() { continue }
          let mut lo = ids[0]
          let mut hi = lo
          for i in ids { lo = min(lo, i); hi = max(hi, i) }
          let w = text_width(note.text, 11, 400) + 24
          let h = text_height(note.text, 11) + 24
          let label_x = match note.placement {
            LeftOf => centres[lo] - left_clear[lo] - w / 2 - 12
            RightOf => centres[hi] + right_clear[hi] + w / 2 + 12
            Over => centres[lo] + right_clear[lo] + w / 2 + 12
          }
          let text_left = label_x - w / 2
          let text_right = label_x + (w + 1) / 2
          let left = if note.placement == Over { min(text_left, centres[lo] - 12) } else { text_left }
          let right = if note.placement == Over { max(text_right, centres[hi] + 12) } else { text_right }
          let k = notes.length()
          let box = { x: left, y: cursor, width: right - left, height: h }
          notes.push({ index: k, note, box, label: make_label(note.text, label_x, cursor + 12, 11, 400, Primary, [Mask, Fill(External)], "note:\{k}") })
          cursor += h + 20
          after_message = false
        }
        Activate(id) => {
          let i = index(id)
          if i >= 0 { starts[i].push(max(box_y[i] + heights[i], if after_message { last_message_y } else { cursor })); if !after_message { cursor += 16 } }
          after_message = false
        }
        Deactivate(id) => {
          let i = index(id)
          if i >= 0 { finish_activation(i, if after_message { last_message_y } else { cursor }); if !after_message { cursor += 16 } }
          after_message = false
        }
        Create(id) => {
          let i = index(id)
          if i >= 0 { pending_creations.push(i); cursor += heights[i] / 2 + 12 }
          after_message = false
        }
        Destroy(id) => {
          let i = index(id)
          if i >= 0 {
            let y = if after_message { last_message_y } else { cursor }
            destruction_y[i] = Some(y)
            while !starts[i].is_empty() { finish_activation(i, y) }
            if !after_message { cursor += 20 }
          }
          after_message = false
        }
        Autonumber(_) => ()
        Frame(f) => {
          after_message = false
          let k = frames.length()
          let left = margin + level * 16
          let frame_width = width - left * 2
          let y = cursor
          let placeholder : FrameBox = { index: k, parent, kind: f.kind, colour: f.colour, box: { x: left, y, width: frame_width, height: 0 }, header: None, chip: None, sections: [] }
          frames.push(placeholder)
          let header_text = frame_name(f.kind) + f.sections[0].label.map(t => " \{t}").unwrap_or("")
          let header = if f.kind == Rect { None } else { Some(make_label(header_text, left + 16 + text_width(header_text, 11, 600) / 2, y + 12, 11, 600, Primary, [Mask], "frame:\{k}")) }
          let chip = header.map(l => { x: l.box.x - 8, y: l.box.y - 4, width: l.box.width + 16, height: l.box.height + 8 })
          cursor += header.map(l => l.box.height + 28).unwrap_or(16)
          let sections : Array[FrameSection] = []
          for j, section in f.sections {
            let start = cursor
            let divider = if j > 0 { Some(Segment::{ x1: left, y1: cursor, x2: left + frame_width, y2: cursor, owner: "frame:\{k}" }) } else { None }
            let label = if j > 0 { section.label.map(text => make_label(text, left + 16 + text_width(text, 11, 400) / 2, cursor + 12, 11, 400, Primary, [Mask], "section:\{k}:\{j}")) } else { None }
            let chip = label.map(l => { x: l.box.x - 8, y: l.box.y - 4, width: l.box.width + 16, height: l.box.height + 8 })
            if j > 0 { cursor += label.map(l => l.box.height + 28).unwrap_or(20) }
            walk(section.events, Some(k), level + 1)
            flush_creations()
            cursor += 16
            sections.push({ box: { x: left, y: start, width: frame_width, height: cursor - start }, label, chip, divider })
          }
          cursor += 4
          frames[k] = { ..placeholder, box: { ..placeholder.box, height: cursor - y }, header, chip, sections: ReadOnlyArray::from_array(sections) }
          cursor += 16
          after_message = false
        }
      }
    }
  }
  walk(sequence.events, None, 0)
  flush_creations()
  let lifeline_bottom = max(initial_bottom + 40, cursor + 12)
  for i in 0..<n { while !starts[i].is_empty() { finish_activation(i, destruction_y[i].unwrap_or(lifeline_bottom)) } }
  let boxes = parts.mapi((i, p) => {
    let label_h = text_height(p.label, 12)
    let sub_h = participant_sublabel(p).map(s => text_height(s, 11) + 4).unwrap_or(0)
    let label = make_label(p.label, centres[i], box_y[i] + (heights[i] - label_h - sub_h) / 2, 12, 600, Primary, [Mask, Fill(families[i])], "participant:\{p.id}")
    let sublabel = participant_sublabel(p).map(s => make_label(s, centres[i], label.box.y + label.box.height + 4, 11, 400, Muted, [Mask, Fill(families[i])], "participant:\{p.id}"))
    { id: p.id, family: families[i], box: { x: centres[i] - widths[i] / 2, y: box_y[i], width: widths[i], height: heights[i] }, label, lifeline_x: centres[i], lifeline_top: box_y[i] + heights[i], lifeline_bottom: destruction_y[i].unwrap_or(lifeline_bottom), destroyed: destruction_y[i] is Some(_), participant: p, sublabel }
  })
  let group_boxes = groups.map(g => {
    let (group, first, last) = g
    let x = centres[first] - widths[first] / 2 - 16
    let right = centres[last] + widths[last] / 2 + 16
    // Different groups can interleave after implicit participant use. Give
    // each title its first member's own gap, so titles and foreign borders
    // cannot cover one another even when their group extents intersect.
    let centre = if first == last { centres[first] } else { centres[first] + right_clear[first] + 16 + text_width(group.label, 12, 600) / 2 }
    let label = make_label(group.label, centre, group_top + 8, 12, 600, Primary, [Mask], "group:\{group.id}")
    { group, box: { x, y: group_top, width: right - x, height: lifeline_bottom + 12 - group_top }, label, chip: { x: label.box.x - 8, y: label.box.y - 4, width: label.box.width + 16, height: label.box.height + 8 } }
  })
  {
    width, height: lifeline_bottom + 32, lifeline_top: initial_bottom, lifeline_bottom,
    participants: ReadOnlyArray::from_array(boxes), messages: ReadOnlyArray::from_array(messages),
    notes: ReadOnlyArray::from_array(notes), activations: ReadOnlyArray::from_array(activations),
    frames: ReadOnlyArray::from_array(frames), groups: ReadOnlyArray::from_array(group_boxes), title, title_box,
  }
}
