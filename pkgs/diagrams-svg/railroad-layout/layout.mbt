///|
let radius : Double = 10.0

///|
let gap : Double = 20.0

///|
let vertical : Double = 12.0

///|
let frame_pad : Double = 14.0

///|
let label_size : Double = 13.0

///|
let small_size : Double = 11.0

///|
let wrap_units : Int = 40

///|
fn cut(text : String, start : Int, end : Int) -> String {
  text.view(start_offset=start, end_offset=end).to_owned()
}

///|
fn text_width(text : String, size : Double, weight : Int) -> Double {
  let metrics = @metrics.FontMetrics::from_defaults(
    profile=Monospace,
    font_size=size.to_int(),
    font_weight=weight,
  )
  metrics.measure(text).width.to_double()
}

///|
/// Split text into display lines at line breaks and at a fixed number of
/// code points. The joined lines keep every character in order.
fn wrap_lines(text : String) -> Array[String] {
  let out = []
  for part in text.split("\n") {
    let line = part.to_owned()
    let mut start = 0
    let mut count = 0
    let mut i = 0
    while i < line.length() {
      let c = line.code_unit_at(i).to_int()
      let w = if c >= 0xd800 && c <= 0xdbff && i + 1 < line.length() { 2 } else { 1 }
      if count == wrap_units {
        out.push(cut(line, start, i))
        start = i
        count = 0
      }
      i += w
      count += 1
    }
    out.push(cut(line, start, line.length()))
  }
  out
}

///|
fn make_label(
  text : String,
  owner : String,
  center : Double,
  top : Double,
  size? : Double = label_size,
  weight? : Int = 400,
) -> Label {
  let lines = wrap_lines(text)
  let mut width = 0.0
  for line in lines {
    width = Double::max(width, text_width(line, size, weight))
  }
  let height = lines.length().to_double() * (size + 4.0)
  {
    lines: ReadOnlyArray::from_array(lines),
    x: center,
    size,
    weight,
    box: { x: center - width / 2.0, y: top, width, height },
    owner,
  }
}

///|
fn label_extent(text : String, size : Double, weight : Int) -> (Double, Double) {
  let lines = wrap_lines(text)
  let mut width = 0.0
  for line in lines {
    width = Double::max(width, text_width(line, size, weight))
  }
  (width, lines.length().to_double() * (size + 4.0))
}

///|
priv enum View {
  Leaf(Shape, String, Array[String], Array[String])
  Seq(ReadOnlyArray[String])
  Alt(ReadOnlyArray[String])
  Wrap(String, Bool, Bool, String?)
  Group(String, String)
  Look(String, String)
  Excl(String, String)
}

///|
fn anchor_label(kind : @regex.AnchorKind) -> String {
  match kind {
    LineStart => "^ line start"
    LineEnd => "$ line end"
    InputStart => "\\A input start"
    InputEndBeforeNewline => "\\Z input end"
    InputEnd => "\\z input end"
    PreviousMatchEnd => "\\G match end"
    WordBoundary => "\\b word boundary"
    NonWordBoundary => "\\B not word boundary"
  }
}

///|
fn set_label(negated : Bool, items : ReadOnlyArray[@regex.SetItem]) -> String {
  let out = StringBuilder()
  out.write_string(if negated { "none of " } else { "one of " })
  for i, item in items {
    if i > 0 {
      out.write_char(' ')
    }
    match item {
      Char(c) => out.write_string(c)
      Range(a, b) => out.write_string(a + "-" + b)
      Escape(e) => out.write_string(e)
    }
  }
  out.to_string()
}

///|
priv struct Frag {
  w : Double
  up : Double
  down : Double
}

///|
priv struct Ctx {
  topology : @trace.Topology
  views : Map[String, View]
  frags : Map[String, Frag]
  points : Map[String, Point]
  terms : Array[TermBox]
  frames : Array[Frame]
  wires : Map[String, Wire]
  limits : Limits
  diagnostics : Array[@diagrams.Diagnostic]
  mut work : Int
  mut failed : Bool
}

///|
fn Ctx::charge(self : Ctx, units : Int) -> Bool {
  if self.failed {
    return false
  }
  if units > self.limits.work - self.work {
    self.failed = true
    self.diagnostics.push(
      @diagrams.Diagnostic::error(
        "railroad/layout-limit", "Railroad layout work limit exceeded",
      ),
    )
    return false
  }
  self.work += units
  true
}

///|
fn Ctx::wire(
  self : Ctx,
  owner : String,
  role : @trace.ConnectorRole,
  points : Array[Point],
  label? : Label,
) -> Unit {
  guard self.topology.connector_of(owner, role) is Some(connector) else {
    self.failed = true
    self.diagnostics.push(
      @diagrams.Diagnostic::error(
        "railroad/binding-mismatch", "A layout connector has no topology connector",
      ),
    )
    return
  }
  // Remove repeated points so every segment has a positive length.
  let clean : Array[Point] = []
  for p in points {
    if clean.last() is Some(q) && q.x == p.x && q.y == p.y {
      continue
    }
    clean.push(p)
  }
  self.wires[connector.id] = {
    connector,
    points: ReadOnlyArray::from_array(clean),
    label,
  }
}

///|
fn Ctx::entry_of(self : Ctx, id : String) -> Point {
  self.points.get(self.topology.entry(id).unwrap_or("")).unwrap_or({ x: 0.0, y: 0.0 })
}

///|
fn Ctx::exit_of(self : Ctx, id : String) -> Point {
  self.points.get(self.topology.exit(id).unwrap_or("")).unwrap_or({ x: 0.0, y: 0.0 })
}

///|
fn Ctx::set_point(self : Ctx, id : String, side : String, x : Double, y : Double) -> Unit {
  self.points[@trace.point_id(id, side)] = { x, y }
}

///|
fn leaf_extent(shape : Shape, text : String, above : Array[String], below : Array[String]) -> Frag {
  if shape == Dot {
    return { w: 24.0, up: 8.0, down: 8.0 }
  }
  let (tw, th) = label_extent(text, label_size, if shape == Square { 600 } else { 400 })
  let mut w = Double::max(tw + 20.0, 28.0)
  let mut up = (th + 10.0) / 2.0
  let mut down = up
  for note in above {
    let (nw, nh) = label_extent(note, small_size, 400)
    w = Double::max(w, nw + 8.0)
    up += nh + 4.0
  }
  for note in below {
    let (nw, nh) = label_extent(note, small_size, 400)
    w = Double::max(w, nw + 8.0)
    down += nh + 4.0
  }
  { w, up, down }
}

///|
fn Ctx::measure(self : Ctx, id : String, depth : Int) -> Frag {
  if depth > self.limits.depth {
    if !self.failed {
      self.failed = true
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "railroad/layout-limit", "Railroad layout depth limit exceeded",
        ),
      )
    }
    return { w: 0.0, up: 0.0, down: 0.0 }
  }
  if !self.charge(1) {
    return { w: 0.0, up: 0.0, down: 0.0 }
  }
  let frag : Frag = match self.views.get(id) {
    None => { w: 0.0, up: 0.0, down: 0.0 }
    Some(Leaf(shape, text, above, below)) => leaf_extent(shape, text, above, below)
    Some(Seq(items)) => {
      let mut w = 0.0
      let mut up = 0.0
      let mut down = 0.0
      for k, item in items {
        let f = self.measure(item, depth + 1)
        w += f.w + (if k > 0 { gap } else { 0.0 })
        up = Double::max(up, f.up)
        down = Double::max(down, f.down)
      }
      { w, up, down }
    }
    Some(Alt(items)) => {
      let mut w = 0.0
      let mut total = 0.0
      let mut up = 0.0
      for k, item in items {
        let f = self.measure(item, depth + 1)
        w = Double::max(w, f.w)
        if k == 0 {
          up = f.up
          total = f.down
        } else {
          total += vertical + f.up + f.down
        }
      }
      { w: w + 4.0 * radius, up, down: total }
    }
    Some(Wrap(child, bypass, back, label)) => {
      let f = self.measure(child, depth + 1)
      let label_h = match label {
        Some(text) => label_extent(text, small_size, 400).1 + 2.0
        None => 0.0
      }
      let label_w = match label {
        Some(text) => label_extent(text, small_size, 400).0
        None => 0.0
      }
      {
        w: Double::max(f.w, label_w) + 4.0 * radius,
        up: f.up + (if bypass { vertical } else { 0.0 }),
        down: f.down + (if back { vertical } else { 0.0 }) + label_h,
      }
    }
    Some(Group(child, label)) => {
      let f = self.measure(child, depth + 1)
      let (lw, lh) = label_extent(label, small_size, 400)
      {
        w: Double::max(f.w, lw) + 2.0 * frame_pad,
        up: f.up + frame_pad + lh,
        down: f.down + frame_pad,
      }
    }
    Some(Look(child, label)) => {
      let f = self.measure(child, depth + 1)
      let (lw, _) = label_extent(label, small_size, 400)
      {
        w: Double::max(f.w, lw) + 2.0 * frame_pad,
        up: 10.0,
        down: 10.0 + frame_pad + f.up + f.down + frame_pad,
      }
    }
    Some(Excl(left, excluded)) => {
      let l = self.measure(left, depth + 1)
      let e = self.measure(excluded, depth + 1)
      let (lw, lh) = label_extent("except", small_size, 400)
      let frame_w = Double::max(e.w, lw) + 2.0 * frame_pad
      {
        w: Double::max(l.w, frame_w),
        up: l.up,
        down: l.down + vertical + lh + frame_pad + e.up + e.down + frame_pad,
      }
    }
  }
  self.frags[id] = frag
  frag
}

///|
fn Ctx::place(self : Ctx, id : String, x : Double, y : Double) -> Unit {
  if self.failed || !self.charge(1) {
    return
  }
  let frag = self.frags.get(id).unwrap_or({ w: 0.0, up: 0.0, down: 0.0 })
  match self.views.get(id) {
    None => ()
    Some(Leaf(shape, text, above, below)) => {
      guard self.topology.term(id) is Some(term) else { return }
      let mut top = y - frag.up
      let notes = []
      for note in above {
        let label = make_label(note, id, x + frag.w / 2.0, top, size=small_size)
        notes.push(label)
        top += label.box.height + 4.0
      }
      let (_, th) = if shape == Dot {
        (0.0, 16.0)
      } else {
        label_extent(text, label_size, 0)
      }
      let box_h = if shape == Dot { 16.0 } else { th + 10.0 }
      let rect : Rect = { x, y: y - box_h / 2.0, width: frag.w, height: box_h }
      let label = make_label(
        text,
        id,
        x + frag.w / 2.0,
        y - box_h / 2.0 + 5.0,
        weight=if shape == Square { 600 } else { 400 },
      )
      let mut bottom = y + box_h / 2.0 + 4.0
      for note in below {
        let label = make_label(note, id, x + frag.w / 2.0, bottom, size=small_size)
        notes.push(label)
        bottom += label.box.height + 4.0
      }
      self.points[term.entry] = { x, y }
      self.points[term.exit] = { x: x + frag.w, y }
      self.terms.push({
        term,
        shape,
        rect,
        label,
        notes: ReadOnlyArray::from_array(notes),
      })
    }
    Some(Seq(items)) => {
      let mut cursor = x
      for k, item in items {
        let f = self.frags[item]
        if k > 0 {
          cursor += gap
        }
        self.place(item, cursor, y)
        cursor += f.w
      }
      for k in 1..<items.length() {
        let a = self.exit_of(items[k - 1])
        let b = self.entry_of(items[k])
        self.wire(items[k], Gap, [a, b])
      }
    }
    Some(Alt(items)) => {
      self.set_point(id, "in", x, y)
      self.set_point(id, "out", x + frag.w, y)
      let mut baseline = y
      for k, item in items {
        let f = self.frags[item]
        if k > 0 {
          let prev = self.frags[items[k - 1]]
          baseline += prev.down + vertical + f.up
        }
        self.place(item, x + 2.0 * radius, baseline)
        let a = self.entry_of(item)
        let b = self.exit_of(item)
        if k == 0 {
          self.wire(id, Split(k), [{ x, y }, a])
          self.wire(id, Join(k), [b, { x: x + frag.w, y }])
        } else {
          self.wire(id, Split(k), [
            { x, y },
            { x: x + radius, y },
            { x: x + radius, y: baseline },
            a,
          ])
          self.wire(id, Join(k), [
            b,
            { x: x + frag.w - radius, y: baseline },
            { x: x + frag.w - radius, y },
            { x: x + frag.w, y },
          ])
        }
      }
    }
    Some(Wrap(child, bypass, back, text)) => {
      self.set_point(id, "in", x, y)
      self.set_point(id, "out", x + frag.w, y)
      let f = self.frags[child]
      self.place(child, x + 2.0 * radius, y)
      let a = self.entry_of(child)
      let b = self.exit_of(child)
      self.wire(id, Enter, [{ x, y }, a])
      self.wire(id, Leave, [b, { x: x + frag.w, y }])
      if bypass {
        let top = y - f.up - vertical
        self.wire(id, Bypass, [
          { x, y },
          { x: x + radius, y },
          { x: x + radius, y: top },
          { x: x + frag.w - radius, y: top },
          { x: x + frag.w - radius, y },
          { x: x + frag.w, y },
        ])
      }
      if back {
        let bottom = y + f.down + vertical
        let label = text.map(t => {
          make_label(t, id, x + frag.w / 2.0, bottom + 2.0, size=small_size)
        })
        self.wire(
          id,
          Return,
          [
            b,
            { x: x + frag.w - radius, y: b.y },
            { x: x + frag.w - radius, y: bottom },
            { x: x + radius, y: bottom },
            { x: x + radius, y: a.y },
            a,
          ],
          label?,
        )
      } else if text is Some(t) {
        // A count without a loop keeps its label below the term.
        let bottom = y + f.down + 2.0
        let label = make_label(t, id, x + frag.w / 2.0, bottom, size=small_size)
        self.frames.push({
          owner: id,
          role: Group,
          rect: { x: x + radius, y: y - f.up - 4.0, width: frag.w - 2.0 * radius, height: f.up + f.down + 8.0 + label.box.height },
          label,
        })
      }
    }
    Some(Group(child, text)) => {
      self.set_point(id, "in", x, y)
      self.set_point(id, "out", x + frag.w, y)
      let f = self.frags[child]
      let (_, lh) = label_extent(text, small_size, 400)
      let top = y - f.up - frame_pad - lh
      let label = make_label(text, id, x + frag.w / 2.0, top + 2.0, size=small_size)
      self.frames.push({
        owner: id,
        role: Group,
        rect: { x, y: top, width: frag.w, height: frag.up + frag.down },
        label,
      })
      self.place(child, x + frame_pad, y)
      self.wire(id, Enter, [{ x, y }, self.entry_of(child)])
      self.wire(id, Leave, [self.exit_of(child), { x: x + frag.w, y }])
    }
    Some(Look(child, text)) => {
      guard self.topology.term(id) is Some(term) else { return }
      let f = self.frags[child]
      let rect : Rect = { x, y: y - frag.up, width: frag.w, height: frag.up + frag.down }
      let label = make_label(text, id, x + frag.w / 2.0, y - 8.0, size=small_size)
      self.points[term.entry] = { x, y }
      self.points[term.exit] = { x: x + frag.w, y }
      self.terms.push({ term, shape: Lookaround, rect, label, notes: [] })
      let inner = y + 10.0 + frame_pad + f.up
      self.set_point(id, "inner-in", x + 4.0, inner)
      self.set_point(id, "inner-out", x + frag.w - 4.0, inner)
      self.place(child, x + frame_pad, inner)
      self.wire(id, Enter, [{ x: x + 4.0, y: inner }, self.entry_of(child)])
      self.wire(id, Leave, [self.exit_of(child), { x: x + frag.w - 4.0, y: inner }])
    }
    Some(Excl(left, excluded)) => {
      let l = self.frags[left]
      let e = self.frags[excluded]
      self.place(left, x, y)
      let (lw, lh) = label_extent("except", small_size, 400)
      let frame_w = Double::max(e.w, lw) + 2.0 * frame_pad
      let top = y + l.down + vertical
      let height = lh + frame_pad + e.up + e.down + frame_pad
      let label = make_label("except", id, x + frame_w / 2.0, top + 2.0, size=small_size)
      self.frames.push({
        owner: id,
        role: Except,
        rect: { x, y: top, width: frame_w, height },
        label,
      })
      let inner = top + lh + frame_pad + e.up
      self.set_point(id, "except-in", x + 4.0, inner)
      self.set_point(id, "except-out", x + frame_w - 4.0, inner)
      self.place(excluded, x + frame_pad, inner)
      self.wire(id, Enter, [{ x: x + 4.0, y: inner }, self.entry_of(excluded)])
      self.wire(id, Leave, [self.exit_of(excluded), { x: x + frame_w - 4.0, y: inner }])
    }
  }
}

///|
fn regex_views(model : @regex.Regex) -> Map[String, View] {
  let views : Map[String, View] = Map([])
  for node in model.nodes {
    let view : View = match node.kind {
      Literal(text) => Leaf(Pill, text, [], [])
      Class(_) | Backreference(_) => Leaf(Class, node.label(), [], [])
      Set(negated, items) => Leaf(Class, set_label(negated, items), [], [])
      Anchor(kind) => Leaf(Anchor, anchor_label(kind), [], [])
      Sequence(items) => Seq(items)
      Choice(items) => Alt(items)
      Group(kind, child) =>
        Group(
          child,
          match kind {
            Capturing => "group"
            NonCapturing => "non-capturing group"
            Named(name) => "group " + name
          },
        )
      Repeat(bounds, child) => {
        let plain = !bounds.reluctant &&
          (bounds.spelling == "*" || bounds.spelling == "+" || bounds.spelling == "?")
        Wrap(
          child,
          bounds.min == 0,
          bounds.max is None || bounds.max.unwrap_or(0) > 1,
          if plain {
            None
          } else {
            Some(bounds.spelling + (if bounds.reluctant { " reluctant" } else { "" }))
          },
        )
      }
      Assertion(look, positive, child) =>
        Look(
          child,
          match (look, positive) {
            (Ahead, true) => "lookahead ?="
            (Ahead, false) => "negative lookahead ?!"
            (Behind, true) => "lookbehind ?<="
            (Behind, false) => "negative lookbehind ?<!"
          },
        )
    }
    views[node.id] = view
  }
  views
}

///|
fn ebnf_views(grammar : @ebnf.Grammar) -> Map[String, View] {
  let views : Map[String, View] = Map([])
  for node in grammar.nodes {
    let above = node.notes_above.iter().collect()
    let below = node.notes_below.iter().collect()
    let view : View = match node.kind {
      Terminal(text, _) => Leaf(Pill, text, above, below)
      Reference(name, _) => Leaf(Square, name, above, below)
      Special(text) => Leaf(Special, text, above, below)
      Empty => Leaf(Dot, "", above, below)
      Sequence(items) => Seq(items)
      Choice(items) => Alt(items)
      Optional(child) => Wrap(child, true, false, None)
      ZeroOrMore(child) => Wrap(child, true, true, None)
      OneOrMore(child) => Wrap(child, false, true, None)
      Count(count, child) =>
        Wrap(child, count == "0", count != "0" && count != "1", Some(count + "\u{d7}"))
      Exclusion(left, excluded) => Excl(left, excluded)
    }
    views[node.id] = view
  }
  views
}

///|
priv struct Row {
  items : Array[String]
  mut up : Double
  mut down : Double
  mut width : Double
}

///|
/// Lay out a regex or grammar railroad. Rules stay in source order; each
/// drawn connector of the topology gets one wire.
pub fn layout(model : Model, limits? : Limits = Limits::new()) -> Result {
  fn failed(code : String, message : String) -> Result {
    { geometry: None, diagnostics: [@diagrams.Diagnostic::error(code, message)] }
  }
  if limits.nodes <= 0 ||
    limits.depth <= 0 ||
    limits.work <= 0 ||
    limits.width <= 0 ||
    limits.output_units <= 0 {
    return failed("railroad/layout-limit", "Railroad limits must be positive")
  }
  let built = match model {
    Regex(m) =>
      @trace.Topology::regex(
        m,
        limits=@regex.Limits::new(nodes=limits.nodes, depth=limits.depth, work=limits.work),
      )
    Ebnf(g) =>
      @trace.Topology::ebnf(
        g,
        limits=@ebnf.Limits::new(nodes=limits.nodes, depth=limits.depth, work=limits.work),
      )
  }
  guard built.topology is Some(topology) else {
    return { geometry: None, diagnostics: built.diagnostics }
  }
  let ctx = Ctx::{
    topology,
    views: match model {
      Regex(m) => regex_views(m)
      Ebnf(g) => ebnf_views(g)
    },
    frags: Map([]),
    points: Map([]),
    terms: [],
    frames: [],
    wires: Map([]),
    limits,
    diagnostics: [],
    work: 0,
    failed: false,
  }
  let margin = 20.0
  let mut y = margin
  let mut width = 0.0
  let title_text = match model {
    Regex(m) => m.title
    Ebnf(g) => g.title
  }
  // Width is fixed after the content is known; place the title afterwards.
  if title_text is Some(t) {
    let (_, h) = label_extent(t, 16.0, 700)
    y += h + 12.0
  }
  let tracks : Array[TrackBox] = []
  let notes : Array[NoteBox] = []
  let bodies : Map[String, String?] = Map([])
  let rule_notes : Map[String, (String?, String?)] = Map([])
  let order : Array[(String, String?)] = []
  match model {
    Regex(m) => {
      bodies[m.id] = Some(m.root)
      order.push((m.id, None))
    }
    Ebnf(g) =>
      for item in g.items {
        match item {
          Rule(rule) => {
            bodies[rule.id] = rule.body
            rule_notes[rule.id] = (rule.note_above, rule.note_below)
            order.push((rule.id, None))
          }
          Note(id, text) => order.push((id, Some(text)))
        }
      }
  }
  let track_index : Map[String, @trace.Track] = Map([])
  for track in topology.tracks {
    track_index[track.id] = track
  }
  for entry in order {
    if ctx.failed {
      break
    }
    match entry {
      (id, Some(text)) => {
        let (w, h) = label_extent(text, small_size, 400)
        let rect : Rect = { x: margin, y, width: w + 20.0, height: h + 12.0 }
        let label = make_label(text, id, margin + rect.width / 2.0, y + 6.0, size=small_size)
        notes.push({ id, rect, label })
        width = Double::max(width, rect.x + rect.width)
        y += rect.height + 24.0
      }
      (id, None) => {
        guard track_index.get(id) is Some(track) else { continue }
        let track_notes = []
        let (above, below) = rule_notes.get(id).unwrap_or((None, None))
        if above is Some(text) {
          let label = make_label(text, id, margin, y, size=small_size)
          let shifted = { ..label, x: margin + label.box.width / 2.0, box: { ..label.box, x: margin } }
          track_notes.push(shifted)
          y += label.box.height + 4.0
        }
        let name = make_label(
          if model is Regex(_) { "pattern" } else { track.name },
          id,
          margin,
          y,
          size=14.0,
          weight=700,
        )
        let name = { ..name, x: margin + name.box.width / 2.0, box: { ..name.box, x: margin } }
        y += name.box.height + 6.0
        if below is Some(text) {
          let label = make_label(text, id, margin, y, size=small_size)
          let shifted = { ..label, x: margin + label.box.width / 2.0, box: { ..label.box, x: margin } }
          track_notes.push(shifted)
          y += label.box.height + 4.0
        }
        let x0 = margin + 10.0
        match bodies.get(id).unwrap_or(None) {
          None => {
            let by = y + 10.0
            let start : Point = { x: x0, y: by }
            let end : Point = { x: x0 + 2.0 * gap, y: by }
            ctx.points[track.start] = start
            ctx.points[track.end] = end
            ctx.wire(id, Empty, [start, end])
            tracks.push({ track, label: name, start, end, notes: ReadOnlyArray::from_array(track_notes) })
            width = Double::max(width, end.x + 10.0)
            y = by + 10.0 + 24.0
          }
          Some(body) => {
            // Measure every node of this track.
            let _ = ctx.measure(body, 0)
            // A top-level sequence wider than the limit continues on new rows.
            let rows : Array[Row] = []
            match ctx.views.get(body) {
              Some(Seq(items)) => {
                let mut row : Row = { items: [], up: 0.0, down: 0.0, width: 0.0 }
                for item in items {
                  let f = ctx.frags[item]
                  let extra = if row.items.is_empty() { f.w } else { gap + f.w }
                  if !row.items.is_empty() &&
                    row.width + extra > limits.width.to_double() {
                    rows.push(row)
                    row = { items: [], up: 0.0, down: 0.0, width: 0.0 }
                  }
                  row.items.push(item)
                  row.width += if row.items.length() == 1 { f.w } else { gap + f.w }
                  row.up = Double::max(row.up, f.up)
                  row.down = Double::max(row.down, f.down)
                }
                rows.push(row)
              }
              _ => ()
            }
            let body_x = x0 + gap
            let mut by = y + (if rows.length() > 1 {
              rows[0].up
            } else {
              ctx.frags[body].up
            })
            let start : Point = { x: x0, y: by }
            ctx.points[track.start] = start
            let mut last_x = 0.0
            let mut bottom = 0.0
            if rows.length() > 1 {
              for r, row in rows {
                if r > 0 {
                  by += rows[r - 1].down + 2.0 * vertical + row.up
                }
                let mut cursor = body_x
                for k, item in row.items {
                  if k > 0 {
                    cursor += gap
                  }
                  ctx.place(item, cursor, by)
                  cursor += ctx.frags[item].w
                }
                last_x = Double::max(last_x, cursor)
                bottom = by + row.down
              }
              let items = match ctx.views.get(body) {
                Some(Seq(items)) => items
                _ => []
              }
              let first_of_row : Map[String, Bool] = Map([])
              for r, row in rows {
                if r > 0 {
                  first_of_row[row.items[0]] = true
                }
              }
              for k in 1..<items.length() {
                let a = ctx.exit_of(items[k - 1])
                let b = ctx.entry_of(items[k])
                if first_of_row.contains(items[k]) {
                  let mid = a.y + ctx.frags[items[k - 1]].down + vertical
                  let turn = Double::max(a.x, last_x) + radius
                  ctx.wire(items[k], Gap, [
                    a,
                    { x: turn, y: a.y },
                    { x: turn, y: mid },
                    { x: body_x - radius, y: mid },
                    { x: body_x - radius, y: b.y },
                    b,
                  ])
                } else {
                  ctx.wire(items[k], Gap, [a, b])
                }
              }
              ctx.diagnostics.push(
                @diagrams.Diagnostic::warning(
                  "railroad/continued",
                  "Rule '\{track.name}' continues on \{rows.length()} rows to stay within the width limit",
                ),
              )
            } else {
              ctx.place(body, body_x, by)
              last_x = body_x + ctx.frags[body].w
              bottom = by + ctx.frags[body].down
            }
            let exit = ctx.exit_of(body)
            let end : Point = { x: Double::max(last_x, exit.x) + gap, y: exit.y }
            ctx.points[track.end] = end
            ctx.wire(id, Start, [start, ctx.entry_of(body)])
            ctx.wire(id, End, [exit, end])
            tracks.push({ track, label: name, start, end, notes: ReadOnlyArray::from_array(track_notes) })
            for t in ctx.terms {
              width = Double::max(width, t.rect.x + t.rect.width)
            }
            width = Double::max(width, end.x + 10.0)
            width = Double::max(width, name.box.x + name.box.width)
            y = bottom + 24.0
          }
        }
      }
    }
  }
  if ctx.failed {
    return { geometry: None, diagnostics: ReadOnlyArray::from_array(ctx.diagnostics) }
  }
  for f in ctx.frames {
    width = Double::max(width, f.rect.x + f.rect.width)
  }
  for w in ctx.wires.values() {
    for p in w.points {
      width = Double::max(width, p.x)
      y = Double::max(y, p.y + 24.0)
    }
  }
  let content_width = width + margin
  let total_width = match title_text {
    Some(t) => Double::max(content_width, label_extent(t, 16.0, 700).0 + 2.0 * margin)
    None => content_width
  }
  let title = title_text.map(t => {
    make_label(t, "title", total_width / 2.0, margin, size=16.0, weight=700)
  })
  // Wires in topology order, so output order is deterministic.
  let wires = []
  for connector in topology.connectors {
    match ctx.wires.get(connector.id) {
      Some(w) => wires.push(w)
      None =>
        return failed(
          "railroad/binding-mismatch",
          "Connector '\{connector.id}' has no drawn wire",
        )
    }
  }
  {
    geometry: Some({
      topology,
      width: total_width.ceil(),
      height: (y - 24.0 + margin).ceil(),
      title,
      tracks: ReadOnlyArray::from_array(tracks),
      terms: ReadOnlyArray::from_array(ctx.terms),
      frames: ReadOnlyArray::from_array(ctx.frames),
      wires: ReadOnlyArray::from_array(wires),
      notes: ReadOnlyArray::from_array(notes),
      point_index: ctx.points,
    }),
    diagnostics: ReadOnlyArray::from_array(ctx.diagnostics),
  }
}
