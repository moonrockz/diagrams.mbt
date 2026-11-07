///|
/// Lossless source, including malformed and unsupported regions.
#derive(Eq, Debug)
pub struct Node {
  source : String
}

///|
pub fn Node::new(source : String) -> Node {
  { source, }
}

///|
pub fn Node::text(self : Node) -> String {
  self.source
}

///|
pub extend Node with Eq::{equal, not_equal}

///|
pub extend Node with @debug.Debug::{to_repr}
