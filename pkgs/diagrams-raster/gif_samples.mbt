///|
/// A connection token follows its final path in the element's own coordinates.
/// A visit identifies a real bound node rather than inventing a connector.
pub(all) enum GifTarget {
  Connection(
    id~ : String,
    path~ : String,
    mask~ : String?,
    point~ : @svg.ConnectorPoint
  )
  Visit(@svg.NodeBindingKind)
}

///|
pub struct GifOccurrence {
  occurrence : @animation.Active
  target : GifTarget
}

///|
/// The pure plan sample is retained alongside the measured drawing targets.
pub struct GifFrameSample {
  time_ms : Int64
  delay_centiseconds : Int32
  sample : @animation.Sample
  occurrences : ReadOnlyArray[GifOccurrence]
}

///|
pub struct GifFrameResult {
  frame : GifFrameSample?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
/// Validated, immutable sampling state. Frame queries do not mutate a scene,
/// a plan or another frame, and do not read a wall clock.
pub struct GifSampler {
  frame_count : Int32
  width : Int32
  height : Int32
  options : GifOptions
  priv scene : @svg.Scene
  priv plan : @animation.PlaybackPlan
  priv times : ReadOnlyArray[(Int64, Int32)]
  priv paths : Map[String, (@svg.PathBinding, GifPath)]
  priv nodes : Map[String, @svg.NodeBindingKind]
}

///|
pub struct GifSamplerResult {
  sampler : GifSampler?
  diagnostics : ReadOnlyArray[RasterDiagnostic]
}

///|
fn gif_diagnostic(
  code : String,
  message : String,
  source_id : String,
) -> ReadOnlyArray[RasterDiagnostic] {
  [{ code, message, source_id: Some(source_id), }]
}

///|
/// Validate source identity, the logical interval and bounded path work.
pub fn GifSampler::new(
  scene : @svg.Scene,
  plan : @animation.PlaybackPlan,
  options~ : GifOptions = GifOptions::new(),
  limits~ : RasterLimits = RasterLimits::default(),
) -> GifSamplerResult {
  if !plan.matches(scene.catalog) {
    return {
      sampler: None,
      diagnostics: gif_diagnostic(
        "raster/plan-mismatch",
        "GIF plan and scene name different source diagrams",
        scene.catalog.view_id,
      ),
    }
  }
  try {
    validate_raster_limits(limits)
    guard plan.duration_ms > 0L && !plan.steps.is_empty() else {
      raise GifInvalid(
        "GIF playback needs a positive duration and at least one occurrence",
      )
    }
    guard scene.display_svg.length() <= limits.max_source_units else {
      raise GifInvalid("GIF scene exceeds the source budget")
    }
    if plan.mode == Finite &&
      options.interval is Interval(end_ms~, ..) &&
      end_ms > plan.duration_ms {
      raise GifInvalid("GIF interval exceeds the finite playback plan")
    }
    let (width, height) = still_dimensions(
      scene.canonical_svg,
      options.size,
      limits,
    )
    let pixels = width.to_int64() * height.to_int64()
    let times = gif_times(plan.duration_ms, options, limits, pixels~)
    guard limits.max_svg_nodes > 0 &&
      scene.paths.length() <= limits.max_svg_nodes &&
      scene.nodes.length() <= limits.max_svg_nodes else {
      raise GifInvalid("GIF scene binding budget exhausted")
    }
    let paths : Map[String, (@svg.PathBinding, GifPath)] = Map([])
    let mut remaining = limits.max_svg_nodes
    for binding in scene.paths {
      guard @svg.ConnectorPath::parse(binding.path) is Some(path) else {
        raise GifInvalid("Malformed bound connector path: " + binding.id)
      }
      let geometry = gif_path(path, remaining.min(8192))
      remaining -= geometry.segments.length()
      paths[binding.occurrence.key] = (binding, geometry)
    }
    let nodes : Map[String, @svg.NodeBindingKind] = Map([])
    for binding in scene.nodes {
      nodes[binding.endpoint] = binding.kind
    }
    let sampler = GifSampler::{
      frame_count: times.length(),
      width,
      height,
      options,
      scene,
      plan,
      times: ReadOnlyArray::from_array(times),
      paths,
      nodes,
    }
    { sampler: Some(sampler), diagnostics: [], }
  } catch {
    GifInvalid(message) =>
      {
        sampler: None,
        diagnostics: gif_diagnostic(
          "raster/gif-options",
          message,
          scene.catalog.view_id,
        ),
      }
    RasterInvalid(code, message, source_id) =>
      {
        sampler: None,
        diagnostics: [
          {
            code,
            message,
            source_id: Some(source_id.unwrap_or(scene.catalog.view_id)),
          },
        ],
      }
    error =>
      {
        sampler: None,
        diagnostics: gif_diagnostic(
          "raster/gif-preparation",
          error.to_string(),
          scene.catalog.view_id,
        ),
      }
  }
}

///|
/// Sample one logical frame, including repeated and concurrent occurrences.
pub fn GifSampler::frame(self : GifSampler, index : Int32) -> GifFrameResult {
  if index < 0 || index >= self.frame_count {
    return {
      frame: None,
      diagnostics: gif_diagnostic(
        "raster/frame-index",
        "GIF frame index is outside the prepared interval",
        self.scene.catalog.view_id,
      ),
    }
  }
  let (time_ms, delay_centiseconds) = self.times[index]
  let sample = self.plan.sample_at(time_ms)
  let occurrences = []
  for occurrence in sample.active {
    let target = if occurrence.visit {
      guard self.nodes.get(occurrence.key) is Some(kind) else {
        return {
          frame: None,
          diagnostics: gif_diagnostic(
            "raster/missing-binding",
            "GIF visit has no visible node: " + occurrence.key,
            self.scene.catalog.view_id,
          ),
        }
      }
      GifTarget::Visit(kind)
    } else {
      guard self.paths.get(occurrence.key) is Some((binding, geometry)) else {
        return {
          frame: None,
          diagnostics: gif_diagnostic(
            "raster/missing-binding",
            "GIF occurrence has no visible path: " + occurrence.key,
            self.scene.catalog.view_id,
          ),
        }
      }
      let progress = occurrence.numerator.to_double() /
        occurrence.denominator.to_double()
      let point = geometry.point(
        if occurrence.reversed {
          1.0 - progress
        } else {
          progress
        },
      )
      GifTarget::Connection(
        id=binding.id,
        path=binding.path,
        mask=binding.mask,
        point~,
      )
    }
    occurrences.push(GifOccurrence::{ occurrence, target, })
  }
  {
    frame: Some({
      time_ms,
      delay_centiseconds,
      sample,
      occurrences: ReadOnlyArray::from_array(occurrences),
    }),
    diagnostics: [],
  }
}
