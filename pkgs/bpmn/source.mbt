///|
/// Shared immutable source identity travels with copied elements and attributes.
/// It is excluded from document meaning and never used as an I/O location.
priv struct SourceOrigin { source : String; map : SourceMap } derive(Eq)

///|
impl @debug.Debug for SourceOrigin with to_repr(self) {
  @debug.Repr::Repr(("SourceOrigin",self.map.source_id,self.map.length))
}

///|
pub fn Element::location(self : Element) -> Location? {
  match (self.origin,self.span) { (Some(origin),Some(span)) => origin.map.location(span); _ => None }
}

///|
pub fn Attribute::location(self : Attribute) -> Location? {
  match (self.origin,self.span) { (Some(origin),Some(span)) => origin.map.location(span); _ => None }
}
