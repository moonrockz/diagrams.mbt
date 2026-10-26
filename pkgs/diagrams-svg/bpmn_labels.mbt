///|
fn BpmnPaint::font_name(self : BpmnPaint, name : String) -> String {
  let result = StringBuilder()
  result.write_char('"')
  let mut units = 1
  for c in name {
    let escaped = match c {
      '"' => "\\\""
      '\\' => "\\\\"
      '\n' => "\\a "
      '\r' => "\\d "
      _ => c.to_string()
    }
    if escaped.length() >
      self.limit - self.used - units - 2 - font_stack.length() {
      self.fail("bpmn/render-limit", "Font metadata exceeds the output budget")
      return ""
    }
    units += escaped.length()
    result.write_string(escaped)
  }
  result.write_string("\", " + font_stack)
  result.to_string()
}

///|
fn BpmnPaint::label(
  self : BpmnPaint,
  label : @bpmn_layout.Label,
) -> @writer.Node {
  let box = label.box
  let attrs = [("class", "bpmn-label"), ("data-owner", label.owner)]
  let raw = label.bounds
  let children = []
  let text_children = []
  if raw is Some(r) {
    children.push(
      self.rect(
        r.x.token,
        r.y.token,
        r.width.token,
        r.height.token,
        "none",
        fill=self.paint.color("bg"),
      ),
    )
  } else if label.mask {
    children.push(
      self.rect(
        bn(box.x),
        bn(box.y),
        bn(box.width),
        bn(box.height),
        "none",
        fill=self.paint.color("bg"),
      ),
    )
  }
  let x = box.x + box.width / 2.0
  let lines = label.text.split("\n").to_array()
  let height = lines.length().to_double() * (label.size + 4.0)
  let center_y = box.y + box.height / 2.0
  let family = label.font.name
    .map(name => self.font_name(name))
    .unwrap_or(font_stack)
  let color = label.family
    .map(f => self.paint.color("\{f.name()}-ink"))
    .unwrap_or(self.paint.color("text"))
  for i, line in lines {
    let y = center_y -
      height / 2.0 +
      label.size +
      i.to_double() * (label.size + 4.0)
    let attrs = [
      ("x", bn(x)),
      ("y", bn(y)),
      ("text-anchor", "middle"),
      ("font-family", family),
      ("font-size", label.font.size.map(n => n.token).unwrap_or("13")),
      ("font-weight", label.weight.to_string()),
      ("fill", color),
    ]
    if label.font.italic.unwrap_or(false) {
      attrs.push(("font-style", "italic"))
    }
    if label.font.underline.unwrap_or(false) ||
      label.font.strike_through.unwrap_or(false) {
      attrs.push(
        (
          "text-decoration",
          (if label.font.underline.unwrap_or(false) {
            "underline "
          } else {
            ""
          }) +
          (if label.font.strike_through.unwrap_or(false) {
            "line-through"
          } else {
            ""
          }),
        ),
      )
    }
    text_children.push(
      self.element("text", attrs~, children=[self.text(line.to_owned())]),
    )
  }
  if label.rotation == -90 {
    children.push(
      self.element(
        "g",
        attrs=[
          (
            "transform",
            "rotate(-90 \{bn(box.x+box.width/2.0)} \{bn(box.y+box.height/2.0)})",
          ),
        ],
        children=text_children,
      ),
    )
  } else {
    children.append(text_children)
  }
  self.element("g", attrs~, children~)
}
