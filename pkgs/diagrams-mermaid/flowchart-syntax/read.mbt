///|
pub struct ReadResult { tree : @cst.Node; ast : @ast.Diagram?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq,Debug)
///|
/// Read one accepted flowchart header through the shared native grammar.
pub fn read(source : String, header? : String = "flowchart", limits? : @shared.Limits = @shared.Limits::new()) -> ReadResult {
 if !["flowchart","graph","flowchart-elk"].contains(header) {
  return {tree:@cst.Node::new([{kind:Error,text:source,offset:0}]),ast:None,diagnostics:[@diagrams.Diagnostic::error("flowchart/unsupported-header","Unsupported flowchart header "+header)]}
 }
 let result=@shared.read(source,header~,limits~,diagnostic_prefix="flowchart",accepted_headers=["flowchart-elk","flowchart","graph"])
 let header=result.tree.children.iter().find_first(token => token.kind == Header).map(token => ["flowchart-elk","flowchart","graph"].iter().find_first(candidate => token.text.trim().has_prefix(candidate)).unwrap()).unwrap_or(header)
 let ast=result.ast.map(value => @ast.Diagram::new(value.statements[:],header~,direction?=value.direction,front_matter?=value.front_matter,directives=value.directives[:]))
 if ast is Some(value) {
  let findings=check_ast(value,limits~)
  if !findings.is_empty() {
   let diagnostics=result.diagnostics.iter().to_array()
   for finding in findings {
    if diagnostics.length() < limits.diagnostics.max(1) { diagnostics.push(finding) } else { diagnostics[diagnostics.length()-1]=finding }
   }
   return {tree:result.tree,ast:None,diagnostics:ReadOnlyArray::from_array(diagnostics)}
  }
 }
 {tree:result.tree,ast,diagnostics:result.diagnostics}
}
///|
pub extend ReadResult with Eq::{equal,not_equal}
///|
pub extend ReadResult with @debug.Debug::{to_repr}
///|
pub let diagnostic_codes : ReadOnlyArray[String] = ReadOnlyArray::from_array([..@shared.diagnostic_codes.iter().map(code => code.replace_all(old="swimlane/",new="flowchart/")).to_array(),"flowchart/node-limit","flowchart/edge-limit"])
