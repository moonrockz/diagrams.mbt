///|
pub struct Input { name : String; sha256 : String; source : String } derive(Eq, Debug)

///|
pub extend Input with Eq::{equal, not_equal}

///|
pub extend Input with @debug.Debug::{to_repr}
