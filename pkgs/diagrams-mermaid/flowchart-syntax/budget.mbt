///|
/// Reading/printing cap AST declaration and link records. Conversion separately
/// caps normalized distinct elements and expanded connections.
pub fn check_ast(diagram : @ast.Diagram, limits? : @shared.Limits = @shared.Limits::new()) -> ReadOnlyArray[@diagrams.Diagnostic] {
 let mut nodes=0; let mut edges=0; let mut work=0
 for statement in diagram.statements {
  if work >= limits.work { return [@diagrams.Diagnostic::error("flowchart/work-limit","AST traversal work limit exceeded",span=statement.span)] }; work+=1
  let (new_nodes,new_edges)=match statement.kind {
   Nodes(values) => (values.length(),0)
   Subgraph(..) => (1,0)
   Edges(chain) => {
    let mut count=0
    for values in chain.endpoints {
     if work >= limits.work || values.length() > limits.work-work { return [@diagrams.Diagnostic::error("flowchart/work-limit","AST traversal work limit exceeded",span=statement.span)] }
     work+=values.length()
     if count > limits.nodes || values.length() > limits.nodes-count { return [@diagrams.Diagnostic::error("flowchart/node-limit","AST node declaration limit exceeded",span=statement.span)] }
     count+=values.length()
    }
    (count,chain.links.length())
   }
   _ => (0,0)
  }
  if new_nodes < 0 || nodes > limits.nodes || new_nodes > limits.nodes-nodes { return [@diagrams.Diagnostic::error("flowchart/node-limit","AST node declaration limit exceeded",span=statement.span)] }
  if new_edges < 0 || edges > limits.edges || new_edges > limits.edges-edges { return [@diagrams.Diagnostic::error("flowchart/edge-limit","AST link record limit exceeded",span=statement.span)] }
  nodes+=new_nodes; edges+=new_edges
 }
 []
}
