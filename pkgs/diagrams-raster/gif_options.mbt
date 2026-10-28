///|
/// GIF uses an explicit logical interval. Full samples a finite plan's complete
/// duration, or one period of an illustrative plan.
pub(all) enum GifInterval {
  Full
  Interval(start_ms~ : Int64, end_ms~ : Int64)
} derive(Eq, Debug)

///|
pub extend GifInterval with Eq::{equal, not_equal}

///|
pub extend GifInterval with @debug.Debug::{to_repr}

///|
/// Repeat is the number of additional plays after the first, from 1 to 65535.
/// Once omits the Netscape extension; Forever writes its zero loop count.
pub(all) enum GifLoop {
  Once
  Forever
  Repeat(Int32)
} derive(Eq, Debug)

///|
pub extend GifLoop with Eq::{equal, not_equal}

///|
pub extend GifLoop with @debug.Debug::{to_repr}

///|
/// GIF composites onto an opaque background. Frame rate ranges from 1 to 100.
/// Sampling includes the exact final logical view with one final frame hold.
/// Delays are rounded deterministically to centiseconds, with a 10ms minimum.
pub(all) struct GifOptions {
  size : RasterSize
  background : Rgba
  theme : ExportTheme
  interval : GifInterval
  frame_rate : Int32
  loop_behavior : GifLoop
} derive(Eq, Debug)

///|
pub extend GifOptions with Eq::{equal, not_equal}

///|
pub extend GifOptions with @debug.Debug::{to_repr}

///|
pub fn GifOptions::new(
  size~ : RasterSize = Original,
  background~ : Rgba = { red: 255, green: 255, blue: 255, alpha: 255, },
  theme~ : ExportTheme = Light,
  interval~ : GifInterval = Full,
  frame_rate~ : Int32 = 10,
  loop_behavior~ : GifLoop = Once,
) -> GifOptions {
  { size, background, theme, interval, frame_rate, loop_behavior, }
}

///|
fn gif_times(
  duration : Int64,
  options : GifOptions,
  limits : RasterLimits,
) -> Array[(Int64, Int32)] raise GifError {
  guard options.frame_rate >= 1 && options.frame_rate <= 100 else {
    raise GifInvalid("GIF frame rate must be between 1 and 100")
  }
  match options.loop_behavior {
    Repeat(count) if count < 1 || count > 65535 =>
      raise GifInvalid("GIF repeat count must be between 1 and 65535")
    _ => ()
  }
  guard options.background.alpha == 255 &&
    [options.background.red, options.background.green, options.background.blue].all(value => {
        value >= 0 && value <= 255
      },
    ) else {
    raise GifInvalid("GIF background must be an opaque RGB color")
  }
  let (start, end) = match options.interval {
    Full => (0L, duration)
    Interval(start_ms~, end_ms~) => (start_ms, end_ms)
  }
  guard start >= 0L && end > start else {
    raise GifInvalid("GIF requires a nonempty nonnegative logical interval")
  }
  guard limits.max_frames >= 2 else {
    raise GifInvalid("GIF frame budget must allow at least two frames")
  }
  let elapsed = end - start
  let fps = options.frame_rate.to_int64()
  // This guard bounds the later multiplication and the endpoint-inclusive count.
  guard elapsed <= (limits.max_frames.to_int64() - 1L) * 1000L / fps else {
    raise GifInvalid("GIF frame budget exhausted")
  }
  let intervals = (elapsed * fps + 999L) / 1000L
  guard intervals + 1L <= limits.max_frames.to_int64() else {
    raise GifInvalid("GIF frame budget exhausted")
  }
  let result : Array[(Int64, Int32)] = []
  for i in 0L..<intervals {
    let at = start + i * 1000L / fps
    let next = start + ((i + 1L) * 1000L / fps).min(elapsed)
    let delay = ((next - at + 5L) / 10L).max(1L).to_int()
    result.push((at, delay))
  }
  let hold = result.last().map(pair => pair.1).unwrap_or(1)
  result.push((end, hold))
  result
}
