///|
fn field(value : Json, name : String, fallback : Json) -> Json {
  match value { Object(fields) => fields.get(name).unwrap_or(fallback); _ => fallback }
}

///|
fn text(value : Json) -> String raise {
  guard value is String(value) else { raise Failure("Expected a string export option") }
  value
}

///|
fn integer(value : Json) -> Int raise {
  let n = match value { Number(value, ..) => value; String(value) => @string.parse_double(value); _ => raise Failure("Expected an integer export option") }
  guard n >= 0.0 && n <= 2147483647.0 && n.floor() == n else { raise Failure("Export option is outside the integer range") }
  n.to_int()
}

///|
fn scalar(value : Json) -> Double raise {
  match value { Number(value, ..) => value; String(value) => @string.parse_double(value); _ => raise Failure("Expected a numeric export option") }
}

///|
fn logical(value : Json) -> Int64 raise {
  let n = scalar(value)
  guard n >= 0.0 && n <= 9007199254740991.0 && n.floor() == n else { raise Failure("Export interval must use exact nonnegative integer milliseconds") }
  n.to_int64()
}

///|
fn color(value : Json, format : String) -> @raster.Rgba raise {
  if value is Null { return if format == "png" { @raster.Rgba::transparent() } else { @raster.Rgba::white() } }
  let s = text(value)
  guard s.length() == 7 && s.has_prefix("#") else { raise Failure("Background must be an RGB hex color") }
  fn digit(i : Int) -> Int raise {
    let c = s.code_unit_at(i).to_int()
    if c >= 48 && c <= 57 { c - 48 } else if c >= 65 && c <= 70 { c - 55 } else if c >= 97 && c <= 102 { c - 87 } else { raise Failure("Invalid RGB background") }
  }
  @raster.Rgba::new(digit(1) * 16 + digit(2), digit(3) * 16 + digit(4), digit(5) * 16 + digit(6))
}

///|
fn size(options : Json) -> @raster.RasterSize raise {
  let width = field(options, "width", Json(null))
  let height = field(options, "height", Json(null))
  let scale = field(options, "scale", Json(null))
  if !(scale is Null) {
    guard width is Null && height is Null else { raise Failure("Choose scale or dimensions") }
    return Scale(scalar(scale))
  }
  match (width, height) { (Null, Null) => Original; (width, Null) => Width(integer(width)); (Null, height) => Height(integer(height)); (width, height) => Fit(integer(width), integer(height)) }
}

///|
fn convert(request : String) -> String {
  try {
    let data = @json.parse(request)
    let options = field(data, "options", Json::object(Map([])))
    let format = text(field(data, "format", Json("png")))
    let source = text(field(data, "svg", Json("")))
    let animation = field(data, "animation", Json(null))
    if format == "gif" && text(field(animation, "canonical", Json(null))) != source {
      raise Failure("GIF scene and supplied canonical SVG differ")
    }
    let theme = match text(field(options, "theme", Json("light"))) { "light" => @raster.ExportTheme::Light; "dark" => Dark; _ => raise Failure("Choose an explicit light or dark export theme") }
    let fonts = @raster.FontSet::from_export_data(field(data, "fonts", Json(null)))
    guard fonts.fonts is Some(fonts) else { raise Failure(fonts.diagnostics.iter().map(d => d.code + ": " + d.message).to_array().join("; ")) }
    let converter = @raster.Rasterizer::new(fonts)
    let background = color(field(options, "background", Json(null)), format)
    let size = size(options)
    let result = match format {
      "png" => converter.rasterize(source, options=@raster.StillOptions::new(size~, background~, theme~))
      "jpeg" => converter.rasterize(source, options=@raster.StillOptions::new(format=Jpeg(quality=integer(field(options, "quality", Json(90)))), size~, background~, theme~))
      "gif" => {
        let frame_rate = integer(field(options, "frameRate", Json(10)))
        let loop_value = field(options, "loop", Json("once"))
        let loop_behavior = match loop_value { String("once") => @raster.GifLoop::Once; String("forever") => Forever; value => Repeat(integer(value)) }
        let interval = field(options, "interval", Json(null))
        let interval = if interval is Null { @raster.GifInterval::Full } else {
          Interval(start_ms=logical(field(interval, "start", Json(0))), end_ms=logical(field(interval, "end", Json(0))))
        }
        let options = @raster.GifOptions::new(size~, background~, theme~, frame_rate~, loop_behavior~, interval~)
        let plan = field(data, "plan", Json(null))
        if plan is Null { converter.export_gif_data(field(data, "animation", Json(null)), options~) } else { converter.export_gif_data(field(data, "animation", Json(null)), plan~, options~) }
      }
      _ => raise Failure("Choose PNG, JPEG or GIF")
    }
    match result.image {
      Some(image) => Json({ "bytes": Json(@base64.encode(image.bytes)), "mediaType": Json(image.media_type), "width": Json(image.width), "height": Json(image.height) }).stringify()
      None => Json({ "error": Json(result.diagnostics.iter().map(d => d.code + ": " + d.message).to_array().join("; ")) }).stringify()
    }
  } catch { error => Json({ "error": Json(error.to_string()) }).stringify() }
}

///|
extern "js" fn install(convert : (String) -> String) =
  #| function(convert) {
  #|   self.onmessage = event => {
  #|     try { self.postMessage(JSON.parse(convert(JSON.stringify(event.data)))); }
  #|     catch (error) { self.postMessage({error: String(error?.message || error)}); }
  #|   };
  #| }

///|
fn main { install(convert) }
