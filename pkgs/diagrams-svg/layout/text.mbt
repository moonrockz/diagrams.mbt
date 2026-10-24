///|
fn normal_text(text : String) -> String {
  text.replace_all(old="<br/>", new="\n")
    .replace_all(old="<br />", new="\n")
    .replace_all(old="<br>", new="\n")
    .replace_all(old="\r\n", new="\n")
    .replace_all(old="\r", new="\n")
}

///|
fn text_width(content : String, size : Int, weight : Int) -> Int {
  let font = @metrics.FontMetrics::from_defaults(profile=Monospace, font_size=size, font_weight=weight)
  let mut width = 0
  for line in normal_text(content).split("\n") {
    width = max(width, font.measure(line.to_owned()).width)
  }
  width
}

///|
fn text_height(content : String, size : Int) -> Int {
  normal_text(content).split("\n").count() * (size + 4)
}

///|
fn make_label(content : String, x : Int, y : Int, size : Int, weight : Int, ink : Ink, backdrop : ArrayView[Layer], owner : String) -> Label {
  let content = normal_text(content)
  let w = text_width(content, size, weight)
  {
    content, x, baseline: y + size, size, weight,
    box: { x: x - w / 2, y, width: w, height: text_height(content, size) },
    ink, backdrop: ReadOnlyArray::from_array(backdrop), owner,
  }
}

///|
fn message_text(m : @sequence.Message) -> String {
  let label = match m.link {
    Some(link) if link.scheme == Smithy => {
      let slash = link.target.replace_all(old="#", new="/")
      if m.label == slash || m.label == link.target {
        match m.label.find(if m.label == slash { "/" } else { "#" }) {
          Some(i) => m.label.view(start_offset=i + 1).to_owned()
          None => m.label
        }
      } else { m.label }
    }
    _ => m.label
  }
  match m.number {
    Some(number) => "\{number} \{label}"
    None => label
  }
}

///|
fn participant_sublabel(p : @sequence.Participant) -> String? {
  p.properties.bind(props => props.sublabel)
}

///|
fn message_sublabel(m : @sequence.Message) -> String? {
  m.properties.bind(props => props.sublabel)
}

///|
fn chip_size(text : String, sublabel : String?) -> (Int, Int) {
  let width = max(text_width(text, 11, 400), sublabel.map(s => text_width(s, 11, 400)).unwrap_or(0)) + 16
  let height = text_height(text, 11) + sublabel.map(s => text_height(s, 11) + 4).unwrap_or(0) + 8
  (width, height)
}

///|
fn max(a : Int, b : Int) -> Int { if a > b { a } else { b } }

///|
fn min(a : Int, b : Int) -> Int { if a < b { a } else { b } }
