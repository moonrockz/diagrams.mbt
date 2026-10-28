///|
pub struct Printed { output : String?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq, Debug)
///|
/// Character entities prevent labels from acquiring Mermaid syntax on reread.
fn quoted(value : String, kind : String, metadata? : Bool = false) -> String {
 let out=StringBuilder(); out.write_char('"')
 if kind == "markdown" { out.write_char((96).unsafe_to_char()) }
 for c in value {
  match c {
   '"' => out.write_string("#quot;")
   '#' => out.write_string("#35;")
   '&' => out.write_string("#amp;")
   '<' if kind != "html" => out.write_string("#lt;")
   '>' if kind != "html" => out.write_string("#gt;")
   '\\' => out.write_string("#92;")
   '\n' if kind == "html" => out.write_string("<br/>")
   '\n' if metadata => out.write_string("\\n")
   '\r' if metadata => out.write_string("\\r")
   '\t' if metadata => out.write_string("\\t")
   _ => out.write_char(c)
  }
 }
 if kind == "markdown" { out.write_char((96).unsafe_to_char()) }
 out.write_char('"'); out.to_string()
}
///|
priv struct PrintContext { limits : @syntax.Limits; mut failed : Bool }
///|
fn metadata_text(value : Json, context : PrintContext) -> String {
 match @ast.canonical_json(value,depth_limit=context.limits.metadata_depth,work_limit=context.limits.work,output_limit=context.limits.output) {
  Some(text) => text
  None => { context.failed=true; "" }
 }
}
///|
fn node_text(node : @ast.NodeDecl, context : PrintContext) -> String {
 let out=StringBuilder(); out.write_string(node.id)
 let shape=node.shape.unwrap_or("rect")
 let modern=(node.shape == None && node.label != None) || (node.shape != None && node.label == None) || node.metadata.iter().any(data => data.0 != "property") || !["rect","rounded","stadium","cylinder","ellipse","circle","doublecircle","diamond","hexagon","subroutine","odd","lean-r","lean-l","trap-t","trap-b"].contains(shape)
 let property=node.metadata.iter().find_first(data => data.0 == "property").map(data => match data.1 { String(value) => value; _ => "" })
 if modern {
  let fields : Map[String,Json]=Map([])
  for data in node.metadata { if data.0 != "property" { fields[data.0]=data.1 } }
  if node.shape is Some(shape) { fields["shape"]=Json(shape) }
  if node.label is Some(label) {
   // Entity escape semantic labels separately from opaque metadata strings.
   let original=fields.get("label")
   let original_label=match original {
    Some(String(value)) if value != "" => Some(@syntax.decode_content(value))
    Some(Number(value,..)) if value != 0.0 && !value.is_nan() => Some(original.unwrap().stringify())
    Some(True) => Some("true")
    _ => None
   }
   if original_label != Some(label) {
    let escaped=StringBuilder()
    for c in label {
     match c {
      '#' => escaped.write_string("#35;")
      '&' => escaped.write_string("#amp;")
      '<' if node.label_kind != "html" => escaped.write_string("#lt;")
      '>' if node.label_kind != "html" => escaped.write_string("#gt;")
      '\n' if node.label_kind == "html" => escaped.write_string("<br/>")
      _ => escaped.write_char(c)
     }
    }
    fields["label"]=Json(escaped.to_string())
   }
   fields["labelType"]=Json(if node.label_kind == "markdown" { "markdown" } else { "text" })
  }
  match @ast.canonical_yaml(Json(fields),depth_limit=context.limits.metadata_depth,work_limit=context.limits.work,output_limit=context.limits.output) {
   Some(text) => out.write_string("@{\n"+text+"}")
   None => context.failed=true
  }
 } else if node.label != None || node.shape != None {
  let label=quoted(node.label.unwrap_or(node.id),node.label_kind)
  if property is Some(property) { out.write_string("[|"+property+"|"+label+"]") }
  else {
   let (left,right)=match shape { "rounded" => ("(",")"); "stadium" => ("([","])"); "cylinder" => ("[(",")]"); "ellipse" => ("(-","-)"); "circle" => ("((", "))"); "doublecircle" => ("(((", ")))"); "diamond" => ("{","}"); "hexagon" => ("{{","}}"); "subroutine" => ("[[","]]"); "odd" => (">","]"); "lean-r" => ("[/","/]"); "lean-l" => ("[\\","\\]"); "trap-b" => ("[/","\\]"); "trap-t" => ("[\\","/]"); _ => ("[","]") }
   out.write_string(left+label+right)
  }
 }
 if !node.classes.is_empty() { out.write_string(":::"+node.classes.iter().to_array().join(",")) }
 out.to_string()
}
///|
fn link_text(link : @ast.Link) -> String {
 let left=match link.source_marker { "arrow" => "<"; "circle" => "o"; "cross" => "x"; _ => "" }
 let right=match link.target_marker { "arrow" => ">"; "circle" => "o"; "cross" => "x"; _ => "" }
 let out=StringBuilder()
 if link.id is Some(id) { out.write_string(id+"@") }
 out.write_string(left)
 let length=link.length.max(1)
 if link.style == "dotted" { out.write_char('-'); for i=0; i<length; i=i+1 { out.write_char('.') }; out.write_char('-') }
 else {
  let count=if link.style == "invisible" || (left == "" && right == "") { length+2 } else { length+1 }
  let unit=match link.style { "thick" => '='; "invisible" => '~'; _ => '-' }
  for i=0; i<count; i=i+1 { out.write_char(unit) }
 }
 out.write_string(right)
 if link.label != "" { out.write_char('|'); out.write_string(quoted(link.label,link.label_kind)); out.write_char('|') }
 out.to_string()
}
///|
fn statement_text(kind : @ast.StatementKind, context : PrintContext) -> String {
 match kind {
  Nodes(nodes) => nodes.iter().map(node => node_text(node,context)).to_array().join(" & ")
  Edges(chain) => {
   let out=StringBuilder()
   if !chain.endpoints.is_empty() { out.write_string(chain.endpoints[0].iter().map(node => node_text(node,context)).to_array().join(" & ")) }
   for i,link in chain.links { out.write_string(" "+link_text(link)+" "); if i+1 < chain.endpoints.length() { out.write_string(chain.endpoints[i+1].iter().map(node => node_text(node,context)).to_array().join(" & ")) } }
   out.to_string()
  }
  Subgraph(id~,label~) => if id == "" { if label == "" { "subgraph" } else { "subgraph "+quoted(label,"text",metadata=true) } } else { "subgraph "+id+" ["+quoted(label,"text",metadata=true)+"]" }
  End => "end"
  Direction(direction) => "direction "+direction
  Title(value) => "title "+value
  AccTitle(value) => "accTitle: "+value
  AccDescription(value) => if value.contains("\n") || value.contains("\r") { "accDescr {\n"+value+"\n}" } else { "accDescr: "+value }
  Metadata(keyword~,text~) => keyword+" "+text
  Comment(value) => value
 }
}
///|
pub fn print(diagram : @ast.Diagram, limits? : @syntax.Limits = @syntax.Limits::new(), header? : String = "swimlane-beta", diagnostic_prefix? : String = "swimlane") -> Printed {
 let context={limits,failed:false}; let out=StringBuilder(); let mut length=0; let mut failed=false; let mut depth=0; let mut work=0
 fn charge(units : Int) -> Bool { if failed || units < 0 || units > limits.work-work { failed=true; false } else { work+=units; true } }
 fn node_budget(node : @ast.NodeDecl) -> Bool {
  if !charge(node.id.length()) || !charge(node.label.map(value => value.length()).unwrap_or(0)) || !charge(node.shape.map(value => value.length()).unwrap_or(0)) || !charge(node.metadata.length()) || !charge(node.classes.length()) { return false }
  for pair in node.metadata { if !charge(pair.0.length()) || !charge(metadata_text(pair.1,context).length()) { return false } }
  for name in node.classes { if !charge(name.length()) { return false } }; true
 }
 fn statement_budget(kind : @ast.StatementKind) -> Bool {
  match kind {
   Nodes(nodes) => { if !charge(nodes.length()) { return false }; for node in nodes { if !node_budget(node) { return false } }; true }
   Edges(chain) => {
    if chain.endpoints.is_empty() || chain.links.length() != chain.endpoints.length()-1 || !charge(chain.endpoints.length()) || !charge(chain.links.length()) { failed=true; return false }
    for nodes in chain.endpoints { if !charge(nodes.length()) { return false }; for node in nodes { if !node_budget(node) { return false } } }
    for link in chain.links { if !charge(link.length) || !charge(link.label.length()) || !charge(link.id.map(value => value.length()).unwrap_or(0)) { return false } }; true
   }
   Subgraph(id~,label~) => charge(id.length()) && charge(label.length())
   Direction(value) | Title(value) | AccTitle(value) | AccDescription(value) | Comment(value) => charge(value.length())
   Metadata(keyword~,text~) => charge(keyword.length()) && charge(text.length())
   End => true
  }
 }
 fn write(text : String) { if text.length() > limits.output-length || text.length() > limits.work-work { failed=true } else if !failed { length+=text.length(); work+=text.length(); out.write_string(text) } }
 if diagram.front_matter is Some(front) { write(front); write("\n") }
 for directive in diagram.directives { write(directive); write("\n") }
 write(header); if diagram.direction is Some(direction) { write(" "+direction) }; write("\n")
 for statement in diagram.statements {
  work+=1; if work > limits.work || failed { failed=true; break }
  if !statement_budget(statement.kind) { break }
  if statement.kind is End { depth=(depth-1).max(0) }
  for index=0; index<depth; index=index+1 { write("  ") }
  write(statement_text(statement.kind,context)); write("\n")
  if statement.kind is Subgraph(..) { depth+=1; if depth > limits.depth { failed=true; break } }
 }
 if failed || context.failed { {output:None,diagnostics:[@diagrams.Diagnostic::error(diagnostic_prefix+"/print-limit","Printing limit exceeded")]} } else {
  let output=out.to_string()
  let checked=@syntax.read(output,header~,diagnostic_prefix~,limits=@syntax.Limits::new(source=limits.source,output=limits.output,nodes=limits.nodes,edges=limits.edges,depth=limits.depth,work=(limits.work-work).max(0),diagnostics=limits.diagnostics,metadata_depth=limits.metadata_depth,metadata_work=limits.metadata_work))
  if checked.diagnostics.iter().any(d => d.severity == @diagrams.Severity::Error) || checked.ast != Some(diagram) {
   let code=if checked.diagnostics.iter().any(d => d.code.has_suffix("-limit")) { diagnostic_prefix+"/print-limit" } else { diagnostic_prefix+"/invalid-ast" }
   let mut detail="Typed values cannot be written as an equivalent native diagram within the limits"
   if checked.ast is Some(actual) {
    if actual.statements.length() != diagram.statements.length() { detail+=" (statement count)" }
    else { for i,statement in actual.statements { if statement != diagram.statements[i] { detail+=" (statement "+i.to_string()+": "+statement.spelling+")"; break } } }
   } else if !checked.diagnostics.is_empty() { detail+=" ("+checked.diagnostics[0].message+")" }
   {output:None,diagnostics:[@diagrams.Diagnostic::error(code,detail)]}
  } else { {output:Some(output),diagnostics:[]} }
 }
}
///|
pub extend Printed with Eq::{equal,not_equal}
///|
pub extend Printed with @debug.Debug::{to_repr}

///|
pub let diagnostic_codes : ReadOnlyArray[String] = ["swimlane/print-limit","swimlane/invalid-ast"]
