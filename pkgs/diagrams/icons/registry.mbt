///|
/// Upstream participant annotators use ASCII case-insensitive keys.
pub fn normalize_key(key : String) -> String {
  key.to_lower()
}

///|
/// Registry identity lookup without any renderer or asset dependency.
pub fn known(reference : Reference) -> Bool {
  match reference.pack {
    "zenuml" => participant_keys.contains(normalize_key(reference.key))
    "architecture" =>
      ["cloud", "database", "disk", "internet", "server"].contains(
        reference.key,
      )
    _ => false
  }
}
