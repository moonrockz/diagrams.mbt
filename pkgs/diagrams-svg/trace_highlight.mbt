///|
/// The visibility and style of one static trace highlight channel. A missing
/// colour selects the theme default for the channel.
pub struct ChannelStyle {
  visible : Bool
  color : @theme.Color?
  width : Double
  dashed : Bool
} derive(Eq, Debug)

///|
pub extend ChannelStyle with Eq::{equal, not_equal}

///|
pub extend ChannelStyle with @debug.Debug::{to_repr}

///|
pub fn ChannelStyle::new(
  visible? : Bool = true,
  color? : @theme.Color,
  width? : Double = 3.0,
  dashed? : Bool = false,
) -> ChannelStyle {
  { visible, color, width, dashed }
}

///|
/// A hidden channel.
pub fn ChannelStyle::hidden() -> ChannelStyle {
  { visible: false, color: None, width: 3.0, dashed: false }
}

///|
/// A per-render request to draw supplied trace evidence on a regex or EBNF
/// diagram. Each channel is independent: matched paths, non-matched paths,
/// the taken path or prefix, and failure points. `attempts` selects attempt
/// identities; `None` selects every attempt. The request never changes the
/// diagram model, its source or its geometry.
pub struct TraceHighlight {
  trace : @railroad_trace.Trace
  attempts : ReadOnlyArray[String]?
  matched : ChannelStyle
  not_matched : ChannelStyle
  taken : ChannelStyle
  failure : ChannelStyle
  limits : @railroad_trace.TraceLimits
} derive(Eq, Debug)

///|
pub extend TraceHighlight with Eq::{equal, not_equal}

///|
pub extend TraceHighlight with @debug.Debug::{to_repr}

///|
pub fn TraceHighlight::new(
  trace : @railroad_trace.Trace,
  attempts? : ArrayView[String],
  matched? : ChannelStyle = ChannelStyle::new(),
  not_matched? : ChannelStyle = ChannelStyle::new(dashed=true),
  taken? : ChannelStyle = ChannelStyle::hidden(),
  failure? : ChannelStyle = ChannelStyle::new(),
  limits? : @railroad_trace.TraceLimits = @railroad_trace.TraceLimits::new(),
) -> TraceHighlight {
  {
    trace,
    attempts: attempts.map(a => ReadOnlyArray::from_array(a)),
    matched,
    not_matched,
    taken,
    failure,
    limits,
  }
}
