///|
/// Bounded attachment policy shared by automatic graph routers. Coordinates are
/// fractions of measured bounds; each adapter projects them onto its real outline.
/// Point profiles try unused cardinal points before spreading a crowded side.
pub struct AttachmentProfile {
  point_preferred : Bool
  extent : Double
  padding : Double
} derive(Eq, Debug)

///|
pub fn attachment_profile(
  shape : String,
  width : Double,
  height : Double,
  side : Int32,
  clearance : Double,
) -> AttachmentProfile {
  let extent = if side == 0 || side == 2 { height } else { width }
  let corner = match shape {
    "rounded" | "state" | "composite" => 12.0.min(width / 4.0).min(height / 2.0)
    "stadium" => height.min(width) / 2.0
    "bpmn-activity" =>
      if side == 0 || side == 2 {
        height * 0.125
      } else {
        width * 0.1
      }
    _ => 0.0
  }
  {
    point_preferred: shape == "diamond" || shape == "choice",
    extent,
    padding: (corner + clearance).max(8.0).min(extent / 4.0),
  }
}

///|
pub fn AttachmentProfile::fraction(
  self : AttachmentProfile,
  rank : Int32,
  count : Int32,
) -> Double {
  if count <= 1 || self.extent <= 0.0 {
    return 0.5
  }
  (
    self.padding +
    (self.extent - 2.0 * self.padding) *
    rank.to_double() /
    (count - 1).to_double()
  ) /
  self.extent
}

///|
/// At most four alternatives, with stable clockwise ties. Constraints reduce
/// the set to the authored side. No endpoint is moved after middle routing.
pub fn AttachmentProfile::sides(
  self : AttachmentProfile,
  preferred : Int32,
  constrained : Bool,
) -> Array[Int32] {
  if constrained || !self.point_preferred {
    return [preferred]
  }
  [preferred, (preferred + 1) % 4, (preferred + 3) % 4, (preferred + 2) % 4]
}

///|
/// Dimensionless route score. An extra crowded point costs 32, a side change
/// costs 4, a bend costs 1, and length is normalized by the measured shape span.
/// Hard feasibility checks always run before this preference cost is used.
pub fn attachment_cost(
  from : Int32,
  to : Int32,
  preferred_from : Int32,
  preferred_to : Int32,
  congestion : Int32,
  bends : Int32,
  length : Double,
  scale : Double,
) -> Double {
  congestion.to_double() * 32.0 +
  (if from == preferred_from { 0.0 } else { 4.0 }) +
  (if to == preferred_to { 0.0 } else { 4.0 }) +
  bends.to_double() +
  length / scale.max(1.0)
}

///|
pub extend AttachmentProfile with Eq::{equal, not_equal}

///|
pub extend AttachmentProfile with @debug.Debug::{to_repr}
