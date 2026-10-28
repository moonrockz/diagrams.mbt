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
) -> AnimatedRenderer {
  { plan, playback, svg, limits, query_limits, sequence_view_id, output_units, }
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
  let data = playback_data(
    scene,
    plan,
    self.query_limits,
    self.limits.steps,
    budget,
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
  let html = "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><title>Diagram flow illustration</title><style>\{player_style}</style></head><body>\n<main data-diagram-viewer aria-label=\"Diagram flow viewer\">\n<p>\{explanation}</p>\n<section class=\"motion-controls\" aria-label=\"Playback controls\">\n<button type=\"button\" data-control=\"play\" aria-pressed=\"false\">Play</button>\n<button type=\"button\" data-control=\"restart\">Restart</button>\n<button type=\"button\" data-control=\"step\">Step</button>\n<label>Speed <select data-control=\"speed\" aria-label=\"Playback speed\"><option value=\"0.25\">0.25×</option><option value=\"0.5\">0.5×</option><option value=\"1\" selected>1×</option><option value=\"1.5\">1.5×</option><option value=\"2\">2×</option><option value=\"4\">4×</option></select></label>\n<label>Position <input data-control=\"seek\" aria-label=\"Playback position\" type=\"range\" min=\"0\" max=\"\{plan.duration_ms}\" value=\"0\" step=\"1\"></label>\n<output data-control=\"position\">0 / \{plan.duration_ms} ms</output>\n<button type=\"button\" data-control=\"download\">Download SVG</button>\n</section>\n<fieldset><legend>Structural exploration</legend>\n<label>From <select data-control=\"from\" aria-label=\"Route from\"></select></label>\n<label>To <select data-control=\"to\" aria-label=\"Route to\"></select></label>\n<label><input data-control=\"messages\" type=\"checkbox\">Include message flows</label>\n<label><input data-control=\"undirected\" type=\"checkbox\">Include unheaded connections</label>\n<button type=\"button\" data-control=\"route\">Show route</button>\n<label>Connection <select data-control=\"connection\" aria-label=\"Select a diagram connection\"></select></label>\n<button type=\"button\" data-control=\"show-connection\">Show connection</button>\n<label>Direction <select data-control=\"direction\" aria-label=\"Reachability direction\"><option value=\"forward\">Downstream</option><option value=\"reverse\">Upstream</option><option value=\"both\">Both directions</option></select></label>\n<button type=\"button\" data-control=\"reach\">Show reachability</button>\n<button type=\"button\" data-control=\"clear\">Reset view</button>\n</fieldset>\n<p data-control=\"status\" role=\"status\" aria-live=\"polite\">Paused</p>\n<div class=\"diagram-canvas\">\{scene.display_svg}</div>\n<script type=\"application/json\" data-motion-data>\{encoded}</script>\n<script>\{player_source}</script>\n</main></body></html>\n"
  if html.length() > self.output_units {
    return failed("animation/render-limit", "HTML output limit exceeded")
  }
  @render.Rendered::ok(html, "text/html", diagnostics=result.diagnostics)
}

///|
pub extend AnimatedRenderer with @render.Renderer::{render}
