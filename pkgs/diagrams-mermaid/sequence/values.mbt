///|
/// Project every Mermaid arrow onto independent line and end values.
fn arrow_ends(m : @ast.MessageStatement) -> (@model.LineStyle, @model.Head, @model.Head) {
  let line : @model.LineStyle = if m.arrow.contains("--") { Dotted } else { Solid }
  let mut sender : @model.Head = NoHead
  let mut receiver : @model.Head = NoHead
  match m.arrow {
    "->>" | "-->>" => receiver = Arrow
    "<<->>" | "<<-->>" => { sender = Arrow; receiver = Arrow }
    "->" | "-->" => receiver = OpenArrow
    "-x" | "--x" => receiver = Cross
    "-)" | "--)" => receiver = Async
    "-|\\" | "--|\\" => receiver = HalfArrow(upper=true, filled=true)
    "-|/" | "--|/" => receiver = HalfArrow(upper=false, filled=true)
    "-\\\\" | "--\\\\" => receiver = HalfArrow(upper=true, filled=false)
    "-//" | "--//" => receiver = HalfArrow(upper=false, filled=false)
    "/|-" | "/|--" => sender = HalfArrow(upper=true, filled=true)
    "\\|-" | "\\|--" => sender = HalfArrow(upper=false, filled=true)
    "//-" | "//--" => sender = HalfArrow(upper=true, filled=false)
    "\\\\-" | "\\\\--" => sender = HalfArrow(upper=false, filled=false)
    _ => ()
  }
  if m.central_before { sender = Central(sender) }
  if m.central_after { receiver = Central(receiver) }
  (line, sender, receiver)
}

///|
fn participant_kind(text : String) -> @model.ParticipantKind? {
  match text {
    "participant" => Some(Participant)
    "actor" => Some(Actor)
    "boundary" => Some(Boundary)
    "control" => Some(Control)
    "entity" => Some(Entity)
    "database" => Some(Database)
    "collections" => Some(Collections)
    "queue" => Some(Queue)
    "service" => Some(Service)
    "resource" => Some(Resource)
    "client" => Some(Client)
    _ => None
  }
}

///|
/// Read the scalar type and alias fields of Mermaid's flow-style metadata.
/// JSON strings use JSON escapes; YAML single-quoted and plain scalars are
/// accepted too. Separators inside a quoted scalar are part of its value.
fn metadata_fields(text : String) -> Map[String, String]? {
  let fields = Map([])
  let entries = []
  let mut start = 0
  let mut quote = 0
  let mut escaped = false
  let mut depth = 0
  let mut i = 0
  while i < text.length() {
    let c = text.code_unit_at(i).to_int()
    if quote != 0 {
      if escaped { escaped = false }
      else if c == 92 && quote == 34 { escaped = true }
      else if c == quote {
        if quote == 39 && i + 1 < text.length() && text.code_unit_at(i + 1).to_int() == 39 {
          i += 1
        } else { quote = 0 }
      }
    } else if c == 34 || c == 39 { quote = c }
    else if c == 123 || c == 91 { depth += 1 }
    else if c == 125 || c == 93 { depth -= 1 }
    else if (c == 44 || c == 10) && depth == 0 {
      entries.push(text.view(start_offset=start, end_offset=i).to_owned())
      start = i + 1
    }
    i += 1
  }
  guard quote == 0 && depth == 0 else { return None }
  entries.push(text.view(start_offset=start).to_owned())
  fn scalar(raw : String) -> String? {
    let raw = raw.trim().to_owned()
    if raw.has_prefix("\"") {
      match json_value(raw) { Some(String(s)) => Some(s); _ => None }
    } else if raw.has_prefix("'") && raw.has_suffix("'") && raw.length() >= 2 {
      Some(raw.view(start_offset=1, end_offset=raw.length() - 1).to_owned().replace_all(old="''", new="'"))
    } else if raw != "" && !raw.has_prefix("{") && !raw.has_prefix("[") {
      Some(raw)
    } else { None }
  }
  for entry in entries {
    if entry.trim() == "" { continue }
    guard entry.find(":") is Some(at) else { return None }
    guard scalar(entry.view(end_offset=at).to_owned()) is Some(key) else { return None }
    if key == "type" || key == "alias" {
      guard scalar(entry.view(start_offset=at + 1).to_owned()) is Some(value) else { return None }
      fields[key] = value
    }
  }
  Some(fields)
}

///|
fn participant_metadata(config : String?) -> (@model.ParticipantKind?, String?)? {
  guard config is Some(text) else { return Some((None, None)) }
  guard metadata_fields(text) is Some(fields) else { return None }
  let kind = match fields.get("type") {
    Some(text) => match participant_kind(text) { Some(k) => Some(k); None => return None }
    None => None
  }
  Some((kind, fields.get("alias")))
}

///|
/// Separate the optional leading CSS colour from the box title. Keeping the
/// spelling lets the renderer parse and diagnose the colour in its own layer.
fn box_data(text : String) -> (String, String?) {
  let text = text.trim().to_owned()
  let lower = text.to_lower()
  let mut at = text.length()
  for i = 0; i < text.length(); i = i + 1 {
    if text.code_unit_at(i) == 32 || text.code_unit_at(i) == 9 { at = i; break }
  }
  let colour_function = lower.has_prefix("rgb(") || lower.has_prefix("rgba(") || lower.has_prefix("hsl(") || lower.has_prefix("hsla(")
  if colour_function {
    at = text.find(")").map(i => i + 1).unwrap_or(at)
  }
  let first = text.view(end_offset=at).to_owned()
  if colour_names.contains(first.to_lower()) || first.has_prefix("#") || (colour_function && first.has_suffix(")")) {
    (text.view(start_offset=at).trim().to_owned(), Some(first))
  } else { (text, None) }
}

///|
let colour_names : ReadOnlyArray[String] = [
  "aliceblue", "antiquewhite", "aqua", "aquamarine", "azure", "beige", "bisque", "black",
  "blanchedalmond", "blue", "blueviolet", "brown", "burlywood", "cadetblue", "chartreuse", "chocolate",
  "coral", "cornflowerblue", "cornsilk", "crimson", "cyan", "darkblue", "darkcyan", "darkgoldenrod",
  "darkgray", "darkgreen", "darkgrey", "darkkhaki", "darkmagenta", "darkolivegreen", "darkorange", "darkorchid",
  "darkred", "darksalmon", "darkseagreen", "darkslateblue", "darkslategray", "darkslategrey", "darkturquoise", "darkviolet",
  "deeppink", "deepskyblue", "dimgray", "dimgrey", "dodgerblue", "firebrick", "floralwhite", "forestgreen",
  "fuchsia", "gainsboro", "ghostwhite", "gold", "goldenrod", "gray", "green", "greenyellow",
  "grey", "honeydew", "hotpink", "indianred", "indigo", "ivory", "khaki", "lavender",
  "lavenderblush", "lawngreen", "lemonchiffon", "lightblue", "lightcoral", "lightcyan", "lightgoldenrodyellow", "lightgray",
  "lightgreen", "lightgrey", "lightpink", "lightsalmon", "lightseagreen", "lightskyblue", "lightslategray", "lightslategrey",
  "lightsteelblue", "lightyellow", "lime", "limegreen", "linen", "magenta", "maroon", "mediumaquamarine",
  "mediumblue", "mediumorchid", "mediumpurple", "mediumseagreen", "mediumslateblue", "mediumspringgreen", "mediumturquoise", "mediumvioletred",
  "midnightblue", "mintcream", "mistyrose", "moccasin", "navajowhite", "navy", "oldlace", "olive",
  "olivedrab", "orange", "orangered", "orchid", "palegoldenrod", "palegreen", "paleturquoise", "palevioletred",
  "papayawhip", "peachpuff", "peru", "pink", "plum", "powderblue", "purple", "rebeccapurple",
  "red", "rosybrown", "royalblue", "saddlebrown", "salmon", "sandybrown", "seagreen", "seashell",
  "sienna", "silver", "skyblue", "slateblue", "slategray", "slategrey", "snow", "springgreen",
  "steelblue", "tan", "teal", "thistle", "tomato", "turquoise", "violet", "wheat",
  "white", "whitesmoke", "yellow", "yellowgreen", "transparent", "currentcolor", "accentcolor", "accentcolortext",
  "activetext", "buttonborder", "buttonface", "buttontext", "canvas", "canvastext", "field", "fieldtext",
  "graytext", "highlight", "highlighttext", "linktext", "mark", "marktext", "selecteditem", "selecteditemtext",
  "visitedtext", "activeborder", "activecaption", "appworkspace", "background", "buttonhighlight", "buttonshadow", "captiontext",
  "inactiveborder", "inactivecaption", "inactivecaptiontext", "infobackground", "infotext", "menu", "menutext", "scrollbar",
  "threeddarkshadow", "threedface", "threedhighlight", "threedlightshadow", "threedshadow", "window", "windowframe", "windowtext",
  "inherit", "initial", "unset", "revert", "revert-layer",
]
