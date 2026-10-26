///|
fn lower(value : String) -> String {
  let out = StringBuilder()
  for c in value {
    let n = c.to_int()
    out.write_char(
      if n >= 65 && n <= 90 {
        (n + 32).unsafe_to_char()
      } else {
        c
      },
    )
  }
  out.to_string()
}

///|
fn builtin(key : String) -> Bool {
  ["cloud", "database", "disk", "internet", "server"].contains(key)
}

///|
/// Whether a frozen symbol exists. ZenUML names follow upstream ASCII case folding.
pub fn known(icon : @icon_ref.Reference) -> Bool {
  (icon.pack == "zenuml" && catalog.contains(lower(icon.key))) ||
  (icon.pack == "architecture" && builtin(icon.key))
}

///|
pub fn contains(icon : @icon_ref.Reference) -> Bool {
  known(icon)
}

///|
/// Collision-free local identifier, including the renderer prefix and namespace.
pub fn asset_id(icon : @icon_ref.Reference, id_prefix : String) -> String {
  let out = StringBuilder()
  out.write_string(id_prefix + "-icon")
  for
    value in [
      icon.pack,
      if icon.pack == "zenuml" && catalog.contains(lower(icon.key)) {
        "asset" + catalog[lower(icon.key)].to_string()
      } else {
        lower(icon.key)
      },
    ] {
    out.write_string("-p")
    for c in value {
      out.write_string("-" + c.to_int().to_string())
    }
  }
  out.to_string()
}

///|
fn isolate(node : @writer.Node, prefix : String) -> @writer.Node {
  match node {
    Text(text) => @writer.Node::Text(text)
    Element(tag, attrs, children) =>
      @writer.Node::Element(
        tag,
        attrs.map(a => {
          let value = if a.0 == "id" {
            prefix + "-" + a.1
          } else {
            a.1.replace(old="url(#", new="url(#" + prefix + "-")
          }
          (a.0, value)
        }),
        children.map(child => isolate(child, prefix)),
      )
  }
}

///|
fn architecture_asset(key : String) -> @writer.Node {
  let path = match key {
    "cloud" => "M8 24C0 24 0 12 8 12C10 1 25 1 27 12C35 12 35 24 27 24Z"
    "database" =>
      "M4 7C4 1 28 1 28 7V25C28 31 4 31 4 25ZM4 7C4 13 28 13 28 7M4 16C4 22 28 22 28 16"
    "disk" => "M3 3H26L29 6V29H3ZM8 3V12H24V3M8 29V18H24V29"
    "internet" =>
      "M2 16A14 14 0 1 0 30 16A14 14 0 1 0 2 16M2 16H30M16 2C6 9 6 23 16 30C26 23 26 9 16 2M5 8H27M5 24H27"
    _ => "M4 3H28V11H4ZM4 13H28V21H4ZM4 23H28V31H4ZM8 7H10M8 17H10M8 27H10"
  }
  @writer.Node::Element("symbol", [("viewBox", "0 0 32 32")], [
    @writer.element("path", attrs=[
      ("d", path),
      ("fill", "#e8f0fe"),
      ("stroke", "#234b75"),
      ("stroke-width", "1.5"),
    ]),
  ])
}

///|
/// A trusted compiled definition. Unknown keys never substitute a known symbol.
pub fn definition_node(
  icon : @icon_ref.Reference,
  id_prefix : String,
) -> @writer.Node {
  if !known(icon) {
    return @writer.element("g")
  }
  let id = asset_id(icon, id_prefix)
  let node = if icon.pack == "architecture" {
    architecture_asset(icon.key)
  } else {
    asset(catalog[lower(icon.key)])
  }
  guard node is @writer.Node::Element(tag, attrs, children) else {
    return @writer.element("g")
  }
  let body = isolate(@writer.Node::Element(tag, attrs, children), id)
  guard body is @writer.Node::Element(tag, attrs, children) else {
    return @writer.element("g")
  }
  let children = children.iter().to_array()
  if icon.pack == "zenuml" {
    children.push(
      @writer.element("desc", children=[
        @writer.text(asset_notice(catalog[lower(icon.key)])),
      ]),
    )
  }
  let children = ReadOnlyArray::from_array(children)
  let attrs = attrs.iter().to_array()
  attrs.push(("id", id))
  @writer.Node::Element(tag, ReadOnlyArray::from_array(attrs), children)
}

///|
/// Deduplicate used symbols. No unused catalog asset enters an output.
pub fn definitions(
  icons : ReadOnlyArray[@icon_ref.Reference],
  id_prefix : String,
) -> String {
  let seen : Map[String, Bool] = Map([])
  let out = StringBuilder()
  for icon in icons {
    let id = asset_id(icon, id_prefix)
    if !seen.contains(id) {
      seen[id] = true
      out.write_string(definition(icon, id_prefix))
    }
  }
  out.to_string()
}

///|
/// Paint a square symbol with a white backing plate that preserves asset colours.
pub fn paint_node(
  icon : @icon_ref.Reference,
  id_prefix : String,
  x : Double,
  y : Double,
  size : Double,
) -> @writer.Node {
  let id = asset_id(icon, id_prefix)
  let children = [
    @writer.element("title", children=[@writer.text(icon.pack + ":" + icon.key)]),
    @writer.element("rect", attrs=[
      ("x", x.to_string()),
      ("y", y.to_string()),
      ("width", size.to_string()),
      ("height", size.to_string()),
      ("rx", "2"),
      ("fill", "#ffffff"),
    ]),
  ]
  if known(icon) {
    children.push(
      @writer.element("use", attrs=[
        ("href", "#" + id),
        ("x", x.to_string()),
        ("y", y.to_string()),
        ("width", size.to_string()),
        ("height", size.to_string()),
      ]),
    )
  } else {
    children.push(
      @writer.element("rect", attrs=[
        ("x", x.to_string()),
        ("y", y.to_string()),
        ("width", size.to_string()),
        ("height", size.to_string()),
        ("fill", "none"),
        ("stroke", "#555555"),
      ]),
    )
    children.push(
      @writer.element(
        "text",
        attrs=[
          ("x", (x + size / 2).to_string()),
          ("y", (y + size * 0.7).to_string()),
          ("text-anchor", "middle"),
          ("font-size", (size * 0.65).to_string()),
          ("fill", "#333333"),
        ],
        children=[@writer.text("?")],
      ),
    )
    children.push(
      @writer.element("desc", children=[
        @writer.text("Unresolved icon " + icon.pack + ":" + icon.key),
      ]),
    )
  }
  @writer.element(
    "g",
    attrs=[
      ("role", "img"),
      ("aria-label", icon.pack + ":" + icon.key),
      ("color", "#111827"),
    ],
    children~,
  )
}

///|
pub fn definition(icon : @icon_ref.Reference, id_prefix : String) -> String {
  @writer.to_string(definition_node(icon, id_prefix))
}

///|
pub fn paint(
  icon : @icon_ref.Reference,
  id_prefix : String,
  x : Double,
  y : Double,
  size : Double,
) -> String {
  @writer.to_string(paint_node(icon, id_prefix, x, y, size))
}

///|
/// Complete pinned participant registry in stable lexical order.
pub fn registry_keys() -> ReadOnlyArray[String] {
  let keys = catalog.keys().to_array()
  keys.sort_by((a, b) => a.lexical_compare(b))
  ReadOnlyArray::from_array(keys)
}
