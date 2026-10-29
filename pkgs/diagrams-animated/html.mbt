///|
/// Offline playback over a pure scene and a validated source-bound plan. The
/// earlier first-flow plan remains a compatible optional input.
pub struct AnimatedRenderer {
  plan : @animation.MotionPlan?
  playback : @animation.PlaybackPlan?
  svg : @svg.SvgRenderer
  limits : @animation.Limits
  query_limits : @animation.Limits
  sequence_view_id : String?
  output_units : Int32
  raster_fonts : @raster.FontSet?
}

///|
pub fn AnimatedRenderer::new(
  plan? : @animation.MotionPlan,
  playback? : @animation.PlaybackPlan,
  svg~ : @svg.SvgRenderer = @svg.SvgRenderer::new(),
  limits~ : @animation.Limits = @animation.Limits::new(),
  query_limits~ : @animation.Limits = @animation.Limits::new(),
  sequence_view_id? : String,
  output_units~ : Int32 = 33554432,
  raster_fonts? : @raster.FontSet,
) -> AnimatedRenderer {
  { plan, playback, svg, limits, query_limits, sequence_view_id, output_units, raster_fonts, }
}

///|
pub impl @render.Renderer for AnimatedRenderer with fn render(self, diagram) {
  fn failed(code : String, message : String) -> @render.Rendered {
    @render.Rendered::failed("text/html", [
      @diagrams.Diagnostic::error(code, message),
    ])
  }
  if self.plan != None && self.playback != None {
    return failed("animation/invalid-plan", "Supply one playback plan")
  }
  if !self.limits.valid() || !self.query_limits.valid() {
    return failed(
      "animation/plan-limit", "Animation and query limits must be valid",
    )
  }
  let budget = HtmlBudget::{ limit: self.output_units, used: 0, failed: false, }
  if self.output_units <= 0 ||
    !budget.reserve(player_source.length() + player_style.length() + 10000) {
    return failed("animation/render-limit", "HTML output limit is too small")
  }
  let view_id = self.sequence_view_id.unwrap_or_else(() => {
    self.playback.map(p => p.view_id).unwrap_or("sequence")
  })
  let result = self.svg.scene(
    diagram,
    sequence_view_id=view_id,
    limits=self.limits,
    output_units=self.output_units,
  )
  guard result.scene is Some(scene) else {
    return @render.Rendered::failed("text/html", result.diagnostics)
  }
  let planned = match self.playback {
    Some(plan) => {
      if !plan.matches(scene.catalog) {
        return failed(
          "animation/plan-mismatch", "Plan and scene name different source diagrams",
        )
      }
      Some(plan)
    }
    None => None
  }
  let plan = match planned {
    Some(plan) => plan
    None => {
      let planned = match self.plan {
        Some(legacy) => {
          if !(diagram is Bpmn(_)) || legacy.view_id != scene.catalog.view_id {
            return failed(
              "animation/plan-mismatch", "The legacy plan must name this BPMN view",
            )
          }
          guard scene.catalog.flow(legacy.flow_id) is Some(occurrence) else {
            return failed(
              "animation/plan-mismatch", "Legacy plan names no visible connection",
            )
          }
          let finite = @animation.PlaybackPlan::scenario(
            scene.catalog,
            Step(occurrence.key, legacy.duration_ms.to_int64()),
            limits=self.limits,
          )
          guard finite.plan is Some(finite) else {
            return @render.Rendered::failed("text/html", finite.diagnostics)
          }
          finite.repeating()
        }
        None =>
          @animation.PlaybackPlan::illustrative(
            scene.catalog,
            limits=self.limits,
          )
      }
      guard planned.plan is Some(plan) else {
        return @render.Rendered::failed("text/html", planned.diagnostics)
      }
      plan
    }
  }
  if !budget.reserve(scene.display_svg.length()) {
    return failed(
      "animation/render-limit", "Display SVG exceeds the HTML output limit",
    )
  }
  let font_subset = self.raster_fonts.unwrap_or_else(@raster.FontSet::default).subset_for_svg(scene.canonical_svg)
  let font_result = font_subset.fonts.map(fonts => fonts.export_data())
  let font_data = font_result.bind(result => result.data).unwrap_or(Json(null))
  let gif_result = @raster.gif_export_data(scene, plan)
  let raster_errors = font_subset.diagnostics.iter().map(d => d.code + ": " + d.message).to_array()
  if font_result is Some(result) { raster_errors.append(result.diagnostics.iter().map(d => d.code + ": " + d.message).to_array()) }
  let data = playback_data(
    scene,
    plan,
    self.query_limits,
    self.limits.steps,
    budget,
    font_data,
    gif_result.data.unwrap_or(Json(null)),
    raster_errors.join("; "),
    gif_result.diagnostics.iter().map(d => d.code + ": " + d.message).to_array().join("; "),
  )
  if budget.failed {
    return failed(
      "animation/render-limit", "Embedded playback data exceeds the HTML output limit",
    )
  }
  let encoded = safe_script_json(data)
  let explanation = match (diagram, plan.mode) {
    (State(_), Illustrative) =>
      "State structure illustration. Each authored transition and visible state is shown in a finite ordered period. Guards, actions and history are descriptive data; no active state configuration is inferred."
    (State(_), Finite) =>
      "Supplied state scenario. Selected transitions and node visits follow caller timing. Guards and actions are not evaluated, history is not restored and no state machine is executed."
    (Regex(_) | Ebnf(_), Illustrative) =>
      "Illustrative structure. The walk visits every term and connector in drawing order; no input is matched or parsed."
    (Regex(_) | Ebnf(_), Finite) =>
      "Explicit scenario. Selected terms and connectors illustrate the supplied order; no input is matched or parsed."
    (DataTree(_), Illustrative) =>
      "Illustrative hierarchy. Rows and boxes are visited in order; values are not evaluated."
    (DataTree(_), Finite) =>
      "Explicit scenario. Selected rows, boxes and connectors illustrate the supplied order."
    (_, Illustrative) =>
      "Illustrative flow. Conditions, events and gateway synchronization are not evaluated."
    (_, Finite) =>
      "Explicit scenario. Selected connections illustrate the supplied order; no process execution is inferred."
  }
  let export_form =
    #|<form class="diagram-viewer__raster" data-control="raster-form" aria-label="Image export options" hidden>
    #|<label>Format <select data-control="raster-format"><option value="png">PNG</option><option value="jpeg">JPEG</option><option value="gif">Animated GIF</option></select></label>
    #|<output data-control="raster-size" aria-label="Export dimensions"></output>
    #|<label>Width in pixels, blank for source size <input data-control="raster-width" type="number" min="1" max="16384" step="1"></label>
    #|<label>Background <input data-control="raster-background" type="color" value="#ffffff"></label>
    #|<label><input data-control="raster-transparent" type="checkbox" checked> Transparent PNG background</label>
    #|<label>JPEG quality <input data-control="raster-quality" type="number" min="1" max="100" step="1" value="90" disabled></label>
    #|<fieldset class="diagram-viewer__gif-options" data-control="gif-options" disabled hidden><legend>Animation interval and timing</legend>
    #|<label>Start, milliseconds <input data-control="gif-start" type="number" min="0" step="1" placeholder="0"></label>
    #|<label>End, milliseconds, blank for full plan <input data-control="gif-end" type="number" min="1" step="1"></label>
    #|<label>Frames per second <input data-control="gif-rate" type="number" min="1" max="100" step="1" value="10"></label>
    #|<label>Loop <select data-control="gif-loop"><option value="once">Once</option><option value="forever">Forever</option><option value="repeat">Repeat</option></select></label>
    #|<label>Additional plays for Repeat <input data-control="gif-repeats" type="number" min="1" max="65535" value="2" step="1"></label>
    #|</fieldset><div class="diagram-viewer__export-actions"><button type="submit" data-control="raster-export">Download PNG</button><button type="button" data-control="raster-cancel" hidden>Cancel export</button></div>
    #|</form><p class="diagram-viewer__status" data-control="raster-status" role="status" aria-live="polite"></p>
  let html = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>Diagram flow illustration</title><style>\{player_style}</style></head><body>\n<main class=\"diagram-viewer\" data-diagram-viewer aria-label=\"Diagram flow viewer\">\n<header class=\"diagram-viewer__header\"><h1>Diagram player</h1><p>\{explanation}</p></header>\n<div class=\"diagram-canvas diagram-viewer__viewport\"><div class=\"diagram-viewer__content\">\{scene.display_svg}</div></div>\n<section class=\"motion-controls diagram-viewer__playback\" aria-label=\"Playback controls\">\n<button type=\"button\" data-control=\"play\" aria-pressed=\"false\">Play</button>\n<button type=\"button\" data-control=\"restart\">Restart</button>\n<button type=\"button\" data-control=\"step\">Step</button>\n<label>Speed <select data-control=\"speed\" aria-label=\"Playback speed\"><option value=\"0.25\">0.25×</option><option value=\"0.5\">0.5×</option><option value=\"1\" selected>1×</option><option value=\"1.5\">1.5×</option><option value=\"2\">2×</option><option value=\"4\">4×</option></select></label>\n<label class=\"diagram-viewer__timeline\">Position <input data-control=\"seek\" aria-label=\"Playback position\" type=\"range\" min=\"0\" max=\"\{plan.duration_ms}\" value=\"0\" step=\"1\"></label>\n<output data-control=\"position\">0 / \{plan.duration_ms} ms</output>\n</section>\n<fieldset class=\"diagram-viewer__exploration\"><legend>Structural exploration</legend>\n<label>From <select data-control=\"from\" aria-label=\"Route from\"></select></label>\n<label>To <select data-control=\"to\" aria-label=\"Route to\"></select></label>\n<label><input data-control=\"messages\" type=\"checkbox\">Include message flows</label>\n<label><input data-control=\"undirected\" type=\"checkbox\">Include unheaded connections</label>\n<button type=\"button\" data-control=\"route\">Show route</button>\n<label>Connection <select data-control=\"connection\" aria-label=\"Select a diagram connection\"></select></label>\n<button type=\"button\" data-control=\"show-connection\">Show connection</button>\n<label>Direction <select data-control=\"direction\" aria-label=\"Reachability direction\"><option value=\"forward\">Downstream</option><option value=\"reverse\">Upstream</option><option value=\"both\">Both directions</option></select></label>\n<button type=\"button\" data-control=\"reach\">Show reachability</button>\n<button type=\"button\" data-control=\"clear\">Reset view</button>\n</fieldset>\n<p class=\"diagram-viewer__status\" data-control=\"status\" role=\"status\" aria-live=\"polite\">Paused</p>\n<section class=\"diagram-viewer__export\" aria-label=\"Export diagram\"><h2>Export</h2><button type=\"button\" data-control=\"download\">Download SVG</button>\n\{export_form}</section>\n<script type=\"application/json\" data-motion-data>\{encoded}</script>\n<script>\{player_source}</script>\n</main></body></html>\n"
  if html.length() > self.output_units {
    return failed("animation/render-limit", "HTML output limit exceeded")
  }
  @render.Rendered::ok(html, "text/html", diagnostics=result.diagnostics)
}

///|
pub extend AnimatedRenderer with @render.Renderer::{render}
