///|
/// A native flowchart header and its shared flowchart-grammar statements.
pub struct Diagram {
 header : String
 direction : String?
 front_matter : String?
 directives : ReadOnlyArray[String]
 statements : ReadOnlyArray[@shared.Statement]
} derive(Eq, Debug)
///|
pub fn Diagram::new(statements : ArrayView[@shared.Statement], header? : String = "flowchart", direction? : String, front_matter? : String, directives? : ArrayView[String] = []) -> Diagram {
 {header,direction,front_matter,directives:ReadOnlyArray::from_array(directives),statements:ReadOnlyArray::from_array(statements)}
}
///|
pub fn Diagram::shared(self : Diagram) -> @shared.Diagram {
 @shared.Diagram::new(self.statements[:],direction?=self.direction,front_matter?=self.front_matter,directives=self.directives[:])
}
///|
pub extend Diagram with Eq::{equal,not_equal}
///|
pub extend Diagram with @debug.Debug::{to_repr}
