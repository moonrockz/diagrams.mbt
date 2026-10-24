///|
/// One frozen example: its name, the SHA-256 digest of its UTF-8 text from
/// `SHA256SUMS`, and its text.
pub(all) struct Example {
  name : String
  sha256 : String
  source : String
} derive(Eq, Debug)

///|
pub extend Example with Eq::{not_equal, equal}

///|
pub extend Example with @debug.Debug::{to_repr}
