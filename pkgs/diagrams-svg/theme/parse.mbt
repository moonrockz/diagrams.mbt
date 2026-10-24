///|
/// Read CSS named colours, #rgb[a], #rrggbb[aa], rgb() and rgba(). Values that
/// need a viewer context, such as currentColor, are deliberately unresolved.
pub fn parse_color(source : String) -> Color? {
  let s = source.trim().to_owned().to_lower()
  if s == "transparent" { return Some(Color::rgba(0, 0, 0, 0)) }
  if named_colors.get(s) is Some(rgb) { return Some(Color::hex(rgb)) }
  if s.has_prefix("#") {
    let digits = s.view(start_offset=1).to_owned()
    let n = digits.length()
    guard n == 3 || n == 4 || n == 6 || n == 8 else { return None }
    let values : Array[Int] = []
    for c in digits {
      let d = "0123456789abcdef".find(c.to_string())
      guard d is Some(d) else { return None }
      values.push(d)
    }
    let short = n < 5
    let channel = (i : Int) => if short { values[i] * 17 } else { values[i * 2] * 16 + values[i * 2 + 1] }
    let alpha = if n == 4 || n == 8 { (channel(3) * 100 + 127) / 255 } else { 100 }
    return Some(Color::rgba(channel(0), channel(1), channel(2), alpha))
  }
  let rgba = s.has_prefix("rgba(")
  guard (rgba || s.has_prefix("rgb(")) && s.has_suffix(")") else { return None }
  let body = s.view(start_offset=if rgba { 5 } else { 4 }, end_offset=s.length() - 1)
  let comma = body.contains(",")
  let parts = if comma {
    if body.contains("/") { return None }
    body.split(",").map(p => p.trim().to_owned()).to_array()
  } else {
    let sides = body.split("/").to_array()
    if sides.length() > 2 { return None }
    let channels = sides[0].to_owned().replace_all(old="\t", new=" ").replace_all(old="\r", new=" ").replace_all(old="\n", new=" ")
      .split(" ").filter(p => p != "").map(p => p.to_owned()).to_array()
    if channels.length() != 3 { return None }
    if sides.length() == 2 { channels.push(sides[1].trim().to_owned()) }
    channels
  }
  guard parts.length() == 3 || parts.length() == 4 else { return None }
  fn number(s : String, maximum : Double) -> Double? {
    let percent = s.has_suffix("%")
    let raw = if percent { s.view(end_offset=s.length() - 1).to_owned() } else { s }
    // Read decimal CSS numbers, including exponents, without accepting NaN.
    guard raw != "" && raw.iter().all(c => (c >= '0' && c <= '9') || c == '.' || c == '+' || c == '-' || c == 'e') else { return None }
    let n = try @string.parse_double(raw) catch { _ => return None }
    let value = if percent { n * maximum / 100.0 } else { n }
    Some(if value < 0.0 { 0.0 } else if value > maximum { maximum } else { value })
  }
  guard number(parts[0], 255.0) is Some(r) && number(parts[1], 255.0) is Some(g) && number(parts[2], 255.0) is Some(b) else { return None }
  let alpha = if parts.length() == 4 {
    guard number(parts[3], 1.0) is Some(a) else { return None }
    (a * 100.0).round().to_int()
  } else { 100 }
  Some(Color::rgba(r.round().to_int(), g.round().to_int(), b.round().to_int(), alpha))
}

///|
// CSS named-colour values, https://www.w3.org/TR/css-color-4/#named-colors
let named_colors : Map[String, Int] = {
  "aliceblue": 0xf0f8ff,
  "antiquewhite": 0xfaebd7,
  "aqua": 0x00ffff,
  "aquamarine": 0x7fffd4,
  "azure": 0xf0ffff,
  "beige": 0xf5f5dc,
  "bisque": 0xffe4c4,
  "black": 0x000000,
  "blanchedalmond": 0xffebcd,
  "blue": 0x0000ff,
  "blueviolet": 0x8a2be2,
  "brown": 0xa52a2a,
  "burlywood": 0xdeb887,
  "cadetblue": 0x5f9ea0,
  "chartreuse": 0x7fff00,
  "chocolate": 0xd2691e,
  "coral": 0xff7f50,
  "cornflowerblue": 0x6495ed,
  "cornsilk": 0xfff8dc,
  "crimson": 0xdc143c,
  "cyan": 0x00ffff,
  "darkblue": 0x00008b,
  "darkcyan": 0x008b8b,
  "darkgoldenrod": 0xb8860b,
  "darkgray": 0xa9a9a9,
  "darkgreen": 0x006400,
  "darkgrey": 0xa9a9a9,
  "darkkhaki": 0xbdb76b,
  "darkmagenta": 0x8b008b,
  "darkolivegreen": 0x556b2f,
  "darkorange": 0xff8c00,
  "darkorchid": 0x9932cc,
  "darkred": 0x8b0000,
  "darksalmon": 0xe9967a,
  "darkseagreen": 0x8fbc8f,
  "darkslateblue": 0x483d8b,
  "darkslategray": 0x2f4f4f,
  "darkslategrey": 0x2f4f4f,
  "darkturquoise": 0x00ced1,
  "darkviolet": 0x9400d3,
  "deeppink": 0xff1493,
  "deepskyblue": 0x00bfff,
  "dimgray": 0x696969,
  "dimgrey": 0x696969,
  "dodgerblue": 0x1e90ff,
  "firebrick": 0xb22222,
  "floralwhite": 0xfffaf0,
  "forestgreen": 0x228b22,
  "fuchsia": 0xff00ff,
  "gainsboro": 0xdcdcdc,
  "ghostwhite": 0xf8f8ff,
  "gold": 0xffd700,
  "goldenrod": 0xdaa520,
  "gray": 0x808080,
  "green": 0x008000,
  "greenyellow": 0xadff2f,
  "grey": 0x808080,
  "honeydew": 0xf0fff0,
  "hotpink": 0xff69b4,
  "indianred": 0xcd5c5c,
  "indigo": 0x4b0082,
  "ivory": 0xfffff0,
  "khaki": 0xf0e68c,
  "lavender": 0xe6e6fa,
  "lavenderblush": 0xfff0f5,
  "lawngreen": 0x7cfc00,
  "lemonchiffon": 0xfffacd,
  "lightblue": 0xadd8e6,
  "lightcoral": 0xf08080,
  "lightcyan": 0xe0ffff,
  "lightgoldenrodyellow": 0xfafad2,
  "lightgray": 0xd3d3d3,
  "lightgreen": 0x90ee90,
  "lightgrey": 0xd3d3d3,
  "lightpink": 0xffb6c1,
  "lightsalmon": 0xffa07a,
  "lightseagreen": 0x20b2aa,
  "lightskyblue": 0x87cefa,
  "lightslategray": 0x778899,
  "lightslategrey": 0x778899,
  "lightsteelblue": 0xb0c4de,
  "lightyellow": 0xffffe0,
  "lime": 0x00ff00,
  "limegreen": 0x32cd32,
  "linen": 0xfaf0e6,
  "magenta": 0xff00ff,
  "maroon": 0x800000,
  "mediumaquamarine": 0x66cdaa,
  "mediumblue": 0x0000cd,
  "mediumorchid": 0xba55d3,
  "mediumpurple": 0x9370db,
  "mediumseagreen": 0x3cb371,
  "mediumslateblue": 0x7b68ee,
  "mediumspringgreen": 0x00fa9a,
  "mediumturquoise": 0x48d1cc,
  "mediumvioletred": 0xc71585,
  "midnightblue": 0x191970,
  "mintcream": 0xf5fffa,
  "mistyrose": 0xffe4e1,
  "moccasin": 0xffe4b5,
  "navajowhite": 0xffdead,
  "navy": 0x000080,
  "oldlace": 0xfdf5e6,
  "olive": 0x808000,
  "olivedrab": 0x6b8e23,
  "orange": 0xffa500,
  "orangered": 0xff4500,
  "orchid": 0xda70d6,
  "palegoldenrod": 0xeee8aa,
  "palegreen": 0x98fb98,
  "paleturquoise": 0xafeeee,
  "palevioletred": 0xdb7093,
  "papayawhip": 0xffefd5,
  "peachpuff": 0xffdab9,
  "peru": 0xcd853f,
  "pink": 0xffc0cb,
  "plum": 0xdda0dd,
  "powderblue": 0xb0e0e6,
  "purple": 0x800080,
  "rebeccapurple": 0x663399,
  "red": 0xff0000,
  "rosybrown": 0xbc8f8f,
  "royalblue": 0x4169e1,
  "saddlebrown": 0x8b4513,
  "salmon": 0xfa8072,
  "sandybrown": 0xf4a460,
  "seagreen": 0x2e8b57,
  "seashell": 0xfff5ee,
  "sienna": 0xa0522d,
  "silver": 0xc0c0c0,
  "skyblue": 0x87ceeb,
  "slateblue": 0x6a5acd,
  "slategray": 0x708090,
  "slategrey": 0x708090,
  "snow": 0xfffafa,
  "springgreen": 0x00ff7f,
  "steelblue": 0x4682b4,
  "tan": 0xd2b48c,
  "teal": 0x008080,
  "thistle": 0xd8bfd8,
  "tomato": 0xff6347,
  "turquoise": 0x40e0d0,
  "violet": 0xee82ee,
  "wheat": 0xf5deb3,
  "white": 0xffffff,
  "whitesmoke": 0xf5f5f5,
  "yellow": 0xffff00,
  "yellowgreen": 0x9acd32,
}
