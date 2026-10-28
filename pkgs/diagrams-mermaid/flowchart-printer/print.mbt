///|
pub struct Printed { output : String?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] }
///|
pub fn print(diagram : @ast.Diagram, limits? : @syntax.Limits = @syntax.Limits::new()) -> Printed {
 if !["flowchart","graph","flowchart-elk"].contains(diagram.header) {
  return {output:None,diagnostics:[@diagrams.Diagnostic::error("flowchart/invalid-ast","Unsupported flowchart header")]}
 }
 let findings=@budget.check_ast(diagram,limits~)
 if !findings.is_empty() { return {output:None,diagnostics:findings} }
 let result=@shared.print(diagram.shared(),header=diagram.header,diagnostic_prefix="flowchart",limits~)
 {output:result.output,diagnostics:result.diagnostics}
}
