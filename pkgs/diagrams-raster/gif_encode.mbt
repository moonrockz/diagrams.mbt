///|
/// Append only complete bounded chunks. A failed conversion returns no image.
fn gif_append(
  out : Array[Byte],
  bytes : Bytes,
  start : Int32,
  end : Int32,
  limits : RasterLimits,
) -> Unit raise RasterFailure {
  guard start >= 0 &&
    end >= start &&
    end <= bytes.length() &&
    end - start <= limits.max_output_bytes - out.length() else {
    raise raster_fail(
      "raster/output-limit", "GIF exceeds the encoded byte budget",
    )
  }
  for i in start..<end {
    out.push(bytes[i])
  }
}

///|
/// The pinned encoder writes one global 3:3:2 palette and a fixed loop extension.
/// Validate that contract before assembling independently encoded frame blocks.
fn gif_frame_block(
  encoded : Bytes,
  width : Int32,
  height : Int32,
) -> (Int32, Int32) raise RasterFailure {
  let signature = [b'G', b'I', b'F', b'8', b'9', b'a']
  guard encoded.length() > 801 && encoded[encoded.length() - 1] == b'\x3b' else {
    raise raster_fail(
      "raster/gif-encoding", "GIF encoder returned an incomplete frame",
    )
  }
  for i in 0..<signature.length() {
    guard encoded[i] == signature[i] else {
      raise raster_fail("raster/gif-encoding", "Unexpected GIF encoder header")
    }
  }
  let w = encoded[6].to_int() + (encoded[7].to_int() << 8)
  let h = encoded[8].to_int() + (encoded[9].to_int() << 8)
  guard w == width && h == height && encoded[10] == b'\xf7' else {
    raise raster_fail(
      "raster/gif-encoding", "GIF frame dimensions or palette changed",
    )
  }
  let extension = [
    b'\x21', b'\xff', b'\x0b', b'N', b'E', b'T', b'S', b'C', b'A', b'P', b'E', b'2',
    b'.', b'0', b'\x03', b'\x01', b'\x00', b'\x00', b'\x00',
  ]
  for i in 0..<extension.length() {
    guard encoded[781 + i] == extension[i] else {
      raise raster_fail(
        "raster/gif-encoding", "Unexpected GIF encoder loop extension",
      )
    }
  }
  guard encoded[800] == b'\x21' && encoded[801] == b'\xf9' else {
    raise raster_fail("raster/gif-encoding", "GIF frame has no timing control")
  }
  (800, encoded.length() - 1)
}

///|
/// Frames are rendered and encoded in bounded order; RGBA buffers from earlier
/// frames are released rather than retained for the whole animation.
fn encode_gif_frames(
  width : Int32,
  height : Int32,
  delays : ArrayView[Int32],
  loop_behavior : GifLoop,
  limits : RasterLimits,
  frame : (Int32) -> RasterPixels raise RasterFailure,
) -> Bytes raise RasterFailure {
  guard delays.length() >= 2 && delays.length() <= limits.max_frames else {
    raise raster_fail(
      "raster/frame-limit", "GIF requires at least two bounded frames",
    )
  }
  for delay in delays {
    guard delay >= 1 && delay <= 65535 else {
      raise raster_fail(
        "raster/invalid-delay", "GIF delay is outside the centisecond range",
      )
    }
  }
  if loop_behavior is Repeat(count) && (count < 1 || count > 65535) {
    raise raster_fail(
      "raster/invalid-loop", "GIF repeat count must be between 1 and 65535",
    )
  }
  guard limits.max_output_bytes.to_int64() >=
    782L + delays.length().to_int64() * 20L else {
    raise raster_fail(
      "raster/output-limit", "GIF byte budget cannot hold its headers and frames",
    )
  }
  let pixels = checked_pixels(width, height, limits).to_int64()
  guard delays.length().to_int64() <= limits.max_cumulative_pixels / pixels else {
    raise raster_fail(
      "raster/cumulative-pixel-limit", "GIF exceeds the cumulative pixel budget",
    )
  }
  let out : Array[Byte] = []
  for index in 0..<delays.length() {
    guard delays[index] >= 1 && delays[index] <= 65535 else {
      raise raster_fail(
        "raster/invalid-delay", "GIF delay is outside the centisecond range",
      )
    }
    let rendered = frame(index)
    guard rendered.width == width &&
      rendered.height == height &&
      rendered.data.length().to_int64() == pixels * 4L else {
      raise raster_fail(
        "raster/gif-encoding", "GIF frame pixels do not match the prepared dimensions",
      )
    }
    let encoded = @gif_codec.encode_gif_animation_pure({
      frames: [{ width, height, channels: 4, data: rendered.data, }],
      delays: [delays[index] * 10],
    }) catch {
      _ => raise raster_fail("raster/gif-encoding", "GIF frame encoding failed")
    }
    let (start, end) = gif_frame_block(encoded, width, height)
    if index == 0 {
      gif_append(out, encoded, 0, 781, limits)
      let count = match loop_behavior {
        Forever => Some(0)
        Repeat(count) => Some(count)
        Once => None
      }
      if count is Some(count) {
        guard count >= 0 && count <= 65535 else {
          raise raster_fail(
            "raster/invalid-loop", "GIF loop count exceeds its encoded range",
          )
        }
        let extension = Bytes::from_array([
          b'\x21',
          b'\xff',
          b'\x0b',
          b'N',
          b'E',
          b'T',
          b'S',
          b'C',
          b'A',
          b'P',
          b'E',
          b'2',
          b'.',
          b'0',
          b'\x03',
          b'\x01',
          (count & 255).to_byte(),
          ((count >> 8) & 255).to_byte(),
          b'\x00',
        ])
        gif_append(out, extension, 0, extension.length(), limits)
      }
    } else {
      for i in 0..<781 {
        guard out[i] == encoded[i] else {
          raise raster_fail("raster/gif-encoding", "GIF frame palettes differ")
        }
      }
    }
    gif_append(out, encoded, start, end, limits)
  }
  guard out.length() < limits.max_output_bytes else {
    raise raster_fail(
      "raster/output-limit", "GIF trailer exceeds the byte budget",
    )
  }
  out.push(b'\x3b')
  Bytes::from_array(out)
}

///|
/// Export a source-bound plan through the same generated-SVG conversion path
/// as PNG and JPEG. The selected interval includes an exact final logical view.
pub fn export_gif(
  scene : @svg.Scene,
  plan : @animation.PlaybackPlan,
  options~ : GifOptions = GifOptions::new(),
  fonts? : FontSet,
  limits~ : RasterLimits = RasterLimits::default(),
) -> RasterResult {
  let prepared = GifSampler::new(scene, plan, options~, limits~)
  guard prepared.sampler is Some(sampler) else {
    return { image: None, diagnostics: prepared.diagnostics, }
  }
  try {
    let fonts = fonts.unwrap_or_else(FontSet::default)
    let delays = sampler.times.iter().map(pair => pair.1).to_array()
    let bytes = encode_gif_frames(
      sampler.width,
      sampler.height,
      delays,
      options.loop_behavior,
      limits,
      index => {
        let sampled = sampler.frame(index)
        guard sampled.frame is Some(frame) else {
          raise raster_fail(
            "raster/frame-sampling", "GIF frame sampling failed",
          )
        }
        let source = gif_frame_svg(scene, frame, limits)
        render_rgba(
          source,
          sampler.width,
          sampler.height,
          options.theme,
          fonts,
          options.background,
          limits,
        )
      },
    )
    {
      image: Some({
        bytes,
        media_type: "image/gif",
        width: sampler.width,
        height: sampler.height,
        format: Gif,
      }),
      diagnostics: [],
    }
  } catch {
    error => { image: None, diagnostics: [raster_diagnostic(error)], }
  }
}
