///|
/// The first-slice pure plan names one authored connection and a duration.
pub struct MotionPlan { view_id : String; flow_id : String; duration_ms : Int } derive(Eq, Debug)

///|
pub extend MotionPlan with Eq::{equal, not_equal}

///|
pub extend MotionPlan with @debug.Debug::{to_repr}

///|
pub fn MotionPlan::new(view_id : String, flow_id : String, duration_ms? : Int = 1000) -> MotionPlan? {
  if duration_ms <= 0 { None } else { Some({ view_id, flow_id, duration_ms }) }
}

///|
/// Exact bounded integer progress; no clock or browser state is read.
pub fn MotionPlan::sample(self : MotionPlan, elapsed_ms : Int) -> (Int, Int) {
  (if elapsed_ms < 0 { 0 } else if elapsed_ms > self.duration_ms { self.duration_ms } else { elapsed_ms }, self.duration_ms)
}
