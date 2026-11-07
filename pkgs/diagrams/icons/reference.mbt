///|
/// An icon identity. Geometry and provider assets belong to renderers.
#derive(Eq, Debug)
pub struct Reference {
  pack : String
  key : String
}

///|
pub fn Reference::new(pack : String, key : String) -> Reference {
  { pack, key, }
}

///|
pub extend Reference with Eq::{equal, not_equal}

///|
pub extend Reference with @debug.Debug::{to_repr}
