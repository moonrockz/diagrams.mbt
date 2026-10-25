///|
pub let max_metadata_depth : Int = 256
///|
pub struct Limits { source : Int; output : Int; nodes : Int; edges : Int; depth : Int; work : Int; diagnostics : Int; metadata_depth : Int; metadata_work : Int } derive(Eq, Debug)
///|
pub fn Limits::new(source? : Int = 16777216, output? : Int = 16777216, nodes? : Int = 10000, edges? : Int = 50000, depth? : Int = 256, work? : Int = 1000000, diagnostics? : Int = 256, metadata_depth? : Int = max_metadata_depth, metadata_work? : Int = 1000000) -> Limits { {source,output,nodes,edges,depth,work,diagnostics,metadata_depth,metadata_work} }
///|
pub struct ReadResult { tree : @cst.Node; ast : @ast.Diagram?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq, Debug)
///|
fn ch(source : String, i : Int) -> Int { if i >= 0 && i < source.length() { source.at(i).to_int() } else { 0 } }
///|
fn width(source : String, i : Int) -> Int {
 if ch(source,i) >= 55296 && ch(source,i) <= 56319 && ch(source,i+1) >= 56320 && ch(source,i+1) <= 57343 { 2 } else { 1 }
}
///|
/// JavaScript lexical whitespace, excluding the CR/LF statement separators.
pub fn is_space(unit : Int) -> Bool { [9,11,12,32,160,5760,8232,8233,8239,8287,12288,65279].contains(unit) || (unit >= 8192 && unit <= 8202) }
///|
pub fn trim_space(source : String) -> String {
 let mut start=0; let mut end=source.length()
 while start < end && (is_space(ch(source,start)) || [10,13].contains(ch(source,start))) { start+=1 }
 while end > start && (is_space(ch(source,end-1)) || [10,13].contains(ch(source,end-1))) { end-=1 }
 source[start:end].to_owned()
}
///|
fn part(source : String, start : Int, end : Int) -> String { source[start:end].to_owned() }
///|
fn trim(source : String) -> String { trim_space(source) }
///|
fn starts(source : String, value : String) -> Bool { source.has_prefix(value) }
///|
fn unquote(value : String) -> String { let value=trim(value); if value.length() >= 2 && starts(value,"\"") && value.has_suffix("\"") { part(value,1,value.length()-1) } else { value } }
///|
fn decode(value : String) -> String { decode_content(unquote(unquote(value))) }
///|
pub fn decode_content(value : String) -> String { let out=StringBuilder(); let mut i=0
 while i < value.length() {
  if ch(value,i) == 35 || ch(value,i) == 38 {
   let mut end=i+1
   while end < value.length() && end-i <= 40 && ch(value,end) != 59 && ch(value,end) != 32 && ch(value,end) != 10 { end+=1 }
   if ch(value,end) == 59 {
    let token=part(value,i+1,end); let mut number=0; let mut numeric=token != ""; let mut begin=0; let mut base=10
    if token.has_prefix("#") { begin=1; if token.has_prefix("#x") || token.has_prefix("#X") { begin=2; base=16 } }
    for at=begin; at<token.length(); at=at+1 {
     let c=ch(token,at); let n=if c >= 48 && c <= 57 { c-48 } else if base == 16 && c >= 65 && c <= 70 { c-55 } else if base == 16 && c >= 97 && c <= 102 { c-87 } else { -1 }
     if n < 0 || n >= base || number > 1114111/base { numeric=false; break }; number=number*base+n
    }
    if numeric && number > 0 && number <= 1114111 && !(number >= 55296 && number <= 57343) { out.write_char(number.unsafe_to_char()); i=end+1; continue }
    if named_entities.get(token) is Some(decoded) { out.write_string(decoded); i=end+1; continue }
    if ch(value,i) == 35 { out.write_char('&'); out.write_string(token); out.write_char(';'); i=end+1; continue }
   }
  }
  let width=if ch(value,i) >= 55296 && ch(value,i) <= 56319 && ch(value,i+1) >= 56320 && ch(value,i+1) <= 57343 { 2 } else { 1 }; out.write_string(part(value,i,i+width)); i+=width
 }
 out.to_string().replace_all(old="<br/>",new="\n").replace_all(old="<br />",new="\n").replace_all(old="<br>",new="\n")
}
///|
fn word_end(source : String, begin : Int) -> Int {
 let mut i=begin
 while i < source.length() { let c=ch(source,i); if source[i:].has_prefix(":::") { break }; if is_space(c) || c == 91 || c == 40 || c == 123 || c == 62 || (c == 38 && (is_space(ch(source,i-1)) || is_space(ch(source,i+1)))) || c == 93 || c == 41 || c == 125 || c == 59 || c == 124 || c == 34 || c == 64 { break }; if (c == 45 || c == 61 || c == 46 || c == 60 || c == 111 || c == 120) && arrow_at(source,i) { break }; i+=width(source,i) }
 i
}
///|
fn arrow_at(source : String, i : Int) -> Bool {
 let c=ch(source,i); let n=ch(source,i+1)
 (c == 45 && (n == 45 || n == 46)) || (c == 46 && n == 45) || (c == 61 && n == 61) || (c == 126 && n == 126) || ((c == 60 || c == 111 || c == 120) && (n == 45 || n == 61))
}
///|
fn skip(source : String, begin : Int) -> Int { let mut i=begin; while is_space(ch(source,i)) { i+=width(source,i) }; i }
///|
fn escaped(source : String, at : Int) -> Bool {
 let mut i=at-1; let mut count=0
 while ch(source,i) == 92 { count+=1; i-=1 }
 count%2 == 1
}
///|
fn closes_label(source : String, begin : Int, closing : Int) -> Bool {
 let mut i=begin
 while i < source.length() {
  let c=ch(source,i)
  if c == closing { return true }
  if c == 91 || c == 40 || c == 123 { return false }
  i+=width(source,i)
 }
 false
}
///|
priv struct ParseContext { limits : Limits; mut failure : String?; mut work : Int }
///|
fn metadata(text : String, context : ParseContext) -> ReadOnlyArray[(String,Json)]? {
 let input=if text.contains("\n") { text+"\n" } else { "{\n"+text+"\n}" }
 guard metadata_preflight(input,context) is Some(normalized) else { if context.failure == None { context.failure=Some("syntax") }; return None }
 let parsed=try {
  Some(@yaml.loads(normalized,flavor=@yaml.Flavor::new(depth=context.limits.metadata_depth,duplicates=Reject,aliases=true,budget=context.limits.metadata_work)))
 } catch {
  @yaml.Refused::TooDeep(_) => { context.failure=Some("depth-limit"); None }
  @yaml.Refused::Exceeded(..) => { context.failure=Some("work-limit"); None }
  _ => { context.failure=Some("syntax"); None }
 }
 guard parsed is Some(parsed) else { return None }
 guard @ast.canonical_json(parsed,depth_limit=context.limits.metadata_depth,work_limit=(context.limits.work-context.work).max(0)) is Some(canonical) else { context.failure=Some("work-limit"); return None }
 context.work+=canonical.length()
 guard parsed is Object(fields) else { context.failure=Some("syntax"); return None }
 let keys=fields.keys().to_array(); keys.sort_by((a,b) => a.lexical_compare(b))
 Some(ReadOnlyArray::from_array(keys.map(key => (key,fields.get(key).unwrap()))[:]))
}
///|
fn shape_data(source : String, begin : Int) -> (String?,Int) {
 let start=begin+2; let mut i=start; let mut quote=0; let mut depth=1; let text=StringBuilder(); let mut run=start
 while i < source.length() && depth > 0 {
  let c=ch(source,i)
  if (c == 34 && !(quote == 34 && escaped(source,i))) || c == 39 { if quote == c { quote=0 } else if quote == 0 { quote=c } }
  if c == 10 && quote == 34 {
   text.write_string(part(source,run,i)); text.write_string("<br/>"); i+=width(source,i)
   while [9,10,13,32].contains(ch(source,i)) { i+=width(source,i) }
   run=i; continue
  }
  if quote == 0 && c == 125 { depth-=1 }
  i+=width(source,i)
 }
 if depth != 0 { (None,i) } else { text.write_string(part(source,run,i-1)); (Some(text.to_string()),i) }
}
///|
fn parse_node(source : String, begin : Int, context : ParseContext) -> (@ast.NodeDecl?,Int) {
 let begin=skip(source,begin); let finish=word_end(source,begin)
 if finish == begin { return (None,begin) }
 let id=part(source,begin,finish); let mut i=skip(source,finish); let mut label : String?=None; let mut shape : String?=None; let mut kind="text"; let raw_data : Array[String]=[]; let mut data : ReadOnlyArray[(String,Json)]=[]
 if ch(source,i) == 64 && ch(source,i+1) == 123 {
  let (value,end)=shape_data(source,i); guard value is Some(value) else { return (None,end) }; raw_data.push(value); i=end
 } else if ch(source,i) == 91 || ch(source,i) == 40 || ch(source,i) == 123 || ch(source,i) == 62 {
  let mut opener=part(source,i,i+1); let mut closer=match ch(source,i) { 91 => "]"; 40 => ")"; 123 => "}"; _ => "]" }
  if ch(source,i) == 91 && ch(source,i+1) == 124 { opener="[|"; closer="]"; shape=Some("rect") }
  else if ch(source,i) == 91 && ch(source,i+1) == 40 { opener="[("; closer=")]"; shape=Some("cylinder") }
  else if ch(source,i) == 91 && ch(source,i+1) == 91 { opener="[["; closer="]]"; shape=Some("subroutine") }
  else if ch(source,i) == 91 && ch(source,i+1) == 47 { opener="[/"; closer="]"; shape=Some("lean-r") }
  else if ch(source,i) == 91 && ch(source,i+1) == 92 { opener="[\\"; closer="]"; shape=Some("lean-l") }
  else if ch(source,i) == 40 && ch(source,i+1) == 45 { opener="(-"; closer="-)"; shape=Some("ellipse") }
  else if ch(source,i) == 40 && ch(source,i+1) == 91 { opener="(["; closer="])"; shape=Some("stadium") }
  else if ch(source,i) == 40 && ch(source,i+1) == 40 && ch(source,i+2) == 40 { opener="((("; closer=")))"; shape=Some("doublecircle") }
  else if ch(source,i) == 40 && ch(source,i+1) == 40 { opener="(("; closer="))"; shape=Some("circle") }
  else if ch(source,i) == 123 && ch(source,i+1) == 123 { opener="{{"; closer="}}"; shape=Some("hexagon") }
  else { shape=Some(match ch(source,i) { 91 => "rect"; 40 => "rounded"; 123 => "diamond"; _ => "odd" }) }
  let start=i+opener.length(); i=start; let mut quote=false
  while i < source.length() { if ch(source,i) == 34 { quote=!quote }; if !quote && source[i:].has_prefix(closer) { break }; i+=width(source,i) }
  if i >= source.length() { return (None,i) }
  let mut raw=part(source,start,i)
  if opener == "[|" {
   if raw.find("|") is Some(split) {
    data=[("property",Json(part(raw,0,split)))]; raw=part(raw,split+1,raw.length())
   } else { return (None,i) }
  }
  if opener == "[/" || opener == "[\\" {
    let suffix=if raw.has_suffix("/") { "/" } else if raw.has_suffix("\\") { "\\" } else { "" }
    shape=Some(if opener == "[/" { if suffix == "\\" { "trap-b" } else { "lean-r" } } else { if suffix == "/" { "trap-t" } else { "lean-l" } })
    if suffix != "" { raw=part(raw,0,raw.length()-1) }
  }
  if raw.has_prefix("\"`") && raw.has_suffix("`\"") { kind="markdown"; raw=part(raw,2,raw.length()-2) } else if raw.contains("<") { kind="html" }
  label=Some(decode(raw)); i+=closer.length()
 }
 i=skip(source,i)
 while source[i:].has_prefix("@{") {
  let (value,end)=shape_data(source,i); guard value is Some(value) else { return (None,end) }
  raw_data.push(value); i=skip(source,end)
 }
 if !raw_data.is_empty() {
  let parsed=metadata(raw_data.join(""),context)
  guard parsed is Some(fields) else { return (None,i) }
  let combined=data.iter().to_array()
  for field in fields {
   combined.push(field)
   if field.0 == "shape" && field.1 is String(value) && value != "" { shape=Some(value) }
   if field.0 == "label" {
    let content=match field.1 {
     String(value) if value != "" => Some(value)
     Number(value,..) if value != 0.0 && !value.is_nan() => Some(field.1.stringify())
     True => Some("true")
     _ => None
    }
    if content is Some(content) {
     label=Some(decode_content(content))
     let label_type=fields.iter().find_first(field => field.0 == "labelType").map(field => field.1)
     kind=match label_type { Some(String("text")) | Some(String("string")) => "text"; _ => "markdown" }
     if content.contains("<") { kind="html" }
    }
   }
  }
  data=ReadOnlyArray::from_array(combined[:])
 }
 let classes=[]
 if source[i:].has_prefix(":::") { i+=3; let start=i; while i < source.length() && !is_space(ch(source,i)) && !arrow_at(source,i) && ch(source,i) != 38 { i+=width(source,i) }; for value in part(source,start,i).split(",") { classes.push(value.to_owned()) } }
 (Some({id,label,label_kind:kind,shape,metadata:data,classes:ReadOnlyArray::from_array(classes[:]),spelling:trim(part(source,begin,i))}),i)
}
///|
fn parse_endpoints(source : String, begin : Int, context : ParseContext) -> (ReadOnlyArray[@ast.NodeDecl]?,Int) {
 let nodes=[]; let mut i=begin
 while true { let (node,end)=parse_node(source,i,context); guard node is Some(node) else { return (None,end) }; nodes.push(node); i=skip(source,end); if ch(source,i) != 38 || !is_space(ch(source,i-1)) || !is_space(ch(source,i+1)) { break }; i+=width(source,i) }
 (Some(ReadOnlyArray::from_array(nodes[:])),i)
}
///|
fn edge_label(raw : String) -> (String,String) {
 let raw=trim(raw)
 if ch(raw,0) == 34 && ch(raw,1) == 96 && ch(raw,raw.length()-2) == 96 && ch(raw,raw.length()-1) == 34 { (decode(part(raw,2,raw.length()-2)),"markdown") }
 else { (decode(raw),if raw.contains("<") { "html" } else { "text" }) }
}
///|
fn valid_arrow(spelling : String) -> Bool {
 let mut start=0; let mut end=spelling.length()
 if [60,111,120].contains(ch(spelling,0)) { start+=1 }
 if [62,111,120].contains(ch(spelling,end-1)) { end-=1 }
 if end <= start { return false }
 let core=part(spelling,start,end)
 if core.has_prefix("~") { return start == 0 && end == spelling.length() && core.length() >= 3 && core.to_array().all(c => c == '~') }
 if core.has_prefix("=") { return core.length() >= (if end == spelling.length() { 3 } else { 2 }) && core.to_array().all(c => c == '=') }
 if core.contains(".") { return core.length() >= 3 && ch(core,0) == 45 && ch(core,core.length()-1) == 45 && core[1:core.length()-1].to_owned().to_array().all(c => c == '.') }
 core.length() >= (if end == spelling.length() { 3 } else { 2 }) && core.to_array().all(c => c == '-')
}
///|
fn parse_link(source : String, begin : Int) -> (@ast.Link?,Int) {
 let mut i=skip(source,begin); let start=i; let mut id : String?=None
 if !arrow_at(source,i) {
   let end=word_end(source,i)
   if ch(source,end) == 64 && arrow_at(source,end+1) { id=Some(part(source,i,end)); i=end+1 } else { return (None,begin) }
 }
 let arrowstart=i; let mut label=""; let mut label_kind="text"; let mut arrowend=i
 while i < source.length() {
   let c=ch(source,i)
   if c == 45 || c == 61 || c == 46 || c == 60 || c == 62 || c == 111 || c == 120 || c == 126 { i+=width(source,i); arrowend=i } else { break }
 }
 if i == arrowstart { return (None,begin) }
 let mut spelling=part(source,arrowstart,arrowend); let mut length_spelling=spelling
 i=skip(source,i)
 if ch(source,i) == 124 {
  i+=width(source,i); let labelstart=i; let mut quote=false
  while i < source.length() { if ch(source,i) == 34 { quote=!quote }; if ch(source,i) == 124 && !quote { break }; i+=width(source,i) }
  if i == source.length() { return (None,i) }; let parsed=edge_label(part(source,labelstart,i)); label=parsed.0; label_kind=parsed.1; i+=width(source,i)
 } else if spelling == "--" || spelling == "==" || spelling == "-." {
  // Mid-link labels use a second terminal arrow segment: A -- text --> B.
  let mut terminal=i
  while terminal < source.length() && !arrow_at(source,terminal) { terminal+=1 }
  if terminal < source.length() {
    let mut end=terminal
    while end < source.length() { let c=ch(source,end); if c == 45 || c == 61 || c == 46 || c == 62 || c == 111 || c == 120 { end+=1 } else { break } }
    let parsed=edge_label(part(source,i,terminal)); label=parsed.0; label_kind=parsed.1; length_spelling=part(source,terminal,end); spelling+=length_spelling; i=end
  }
 }
 if !valid_arrow(spelling) { return (None,i) }
 let first=ch(spelling,0); let last=ch(spelling,spelling.length()-1)
 let source_marker=match first { 60 => "arrow"; 111 => "circle"; 120 => "cross"; _ => "none" }
 let target_marker=match last { 62 => "arrow"; 111 => "circle"; 120 => "cross"; _ => "none" }
 let style=if spelling.contains("~") { "invisible" } else if spelling.contains("=") { "thick" } else if spelling.contains(".") { "dotted" } else { "solid" }
 let mut count=0
 for c in length_spelling.to_array() { if (style == "dotted" && c == '.') || (style == "thick" && c == '=') || (style == "invisible" && c == '~') || (style == "solid" && c == '-') { count+=1 } }
 let length=if style == "dotted" { count.max(1) } else if style == "invisible" || (source_marker == "none" && target_marker == "none") { (count-2).max(1) } else { (count-1).max(1) }
 (Some({spelling:part(source,start,i),label,label_kind,id,source_marker,target_marker,style,length}),skip(source,i))
}
///|
fn parse_statement(text : String, context : ParseContext) -> @ast.StatementKind? {
 let mut separator=0
 while separator < text.length() && !is_space(ch(text,separator)) { separator+=1 }
 let text=if is_space(ch(text,separator)) && ch(text,separator) != 32 { part(text,0,separator)+" "+part(text,separator+1,text.length()) } else { text }

 if text == "end" { return Some(End) }
 if text.has_prefix("%%") { return Some(Comment(text)) }
 if text == "subgraph" { return Some(Subgraph(id="",label="")) }
 if text.has_prefix("subgraph ") {
  let value=trim(part(text,9,text.length()))
  if value.has_prefix("\"") { return Some(Subgraph(id="",label=decode(value))) }
  let end=word_end(value,0)
  if end == 0 { return None }; let id=part(value,0,end); let rest=trim(part(value,end,value.length()))
  let label=if rest.has_prefix("[") && rest.has_suffix("]") { decode(part(rest,1,rest.length()-1)) } else if rest == "" { decode(id) } else { decode(value) }
  let id=if rest != "" && !rest.has_prefix("[") { "" } else { id }
  return Some(Subgraph(id~,label~))
 }
 if text.has_prefix("accDescr {") { return Some(AccDescription(trim(part(text,10,text.length()-1)))) }
 for keyword in ["direction","title","accTitle","accDescr"] {
  if text.has_prefix(keyword+" ") || text.has_prefix(keyword+":") {
   let value=trim(part(text,keyword.length()+1,text.length()))
   return Some(match keyword { "direction" => Direction(value); "title" => Title(value); "accTitle" => AccTitle(value); _ => AccDescription(value) })
  }
 }
 for keyword in ["classDef","class","style","linkStyle","click"] {
  if text.has_prefix(keyword+" ") { let value=trim(part(text,keyword.length()+1,text.length())); if !value.to_array().any(c => is_space(c.to_int())) { return None }; return Some(Metadata(keyword~,text=value)) }
 }
 let (nodes,end)=parse_endpoints(text,0,context); guard nodes is Some(nodes) else { return None }
 if end == text.length() { return Some(Nodes(nodes)) }
 let endpoints=[nodes]; let links=[]; let mut i=end
 while i < text.length() {
  let (link,next)=parse_link(text,i); guard link is Some(link) else { return None }
  let (nodes,end)=parse_endpoints(text,next,context); guard nodes is Some(nodes) else { return None }
  links.push(link); endpoints.push(nodes); i=end
 }
 Some(Edges({endpoints:ReadOnlyArray::from_array(endpoints[:]),links:ReadOnlyArray::from_array(links[:])}))
}
///|
pub fn read(source : String, limits? : Limits = Limits::new()) -> ReadResult {
 let context={limits,failure:None,work:0}; let tokens : Array[@cst.Token]=[]; let statements : Array[@ast.Statement]=[]; let diagnostics=[]; let groups=[]; let directives=[]; let mut front : String?=None; let mut limited=false; let mut header=false; let mut direction : String?=None; let mut i=0; let mut work=0
 if source.length() > limits.source || source.length() > limits.work || limits.source < 0 || limits.work < 0 || limits.nodes < 0 || limits.edges < 0 || limits.depth < 0 {
  let code=if source.length() > limits.source || limits.source < 0 { "swimlane/source-limit" } else { "swimlane/work-limit" }
  return {tree:@cst.Node::new([{kind:Error,text:source,offset:0}]),ast:None,diagnostics:[@diagrams.Diagnostic::error(code,"Input processing limit exceeded")]}
 }
 if limits.metadata_depth < 1 || limits.metadata_depth > max_metadata_depth {
  return {tree:@cst.Node::new([{kind:Error,text:source,offset:0}]),ast:None,diagnostics:[@diagrams.Diagnostic::error("swimlane/depth-limit","metadata_depth must be between 1 and 256")]}
 }
 if limits.metadata_work < 1 {
  return {tree:@cst.Node::new([{kind:Error,text:source,offset:0}]),ast:None,diagnostics:[@diagrams.Diagnostic::error("swimlane/work-limit","metadata_work must be positive")]}
 }
 let line_starts=[0]
 let mut line_offset=0
 while line_offset < source.length() {
  if ch(source,line_offset) == 13 { if ch(source,line_offset+1) == 10 { line_offset+=1 }; line_starts.push(line_offset+1) }
  else if ch(source,line_offset) == 10 { line_starts.push(line_offset+1) }
  line_offset+=1
 }
 fn position(offset : Int) -> @diagrams.Position {
  let mut low=0; let mut high=line_starts.length()
  while low+1 < high { let middle=low+(high-low)/2; if line_starts[middle] <= offset { low=middle } else { high=middle } }
  {offset,line:low+1,column:offset-line_starts[low]+1}
 }
 fn span(start : Int, end : Int) -> @diagrams.Span { {start:position(start),end:position(end)} }
 fn report(code : String, message : String, start : Int, end : Int) {
  let diagnostic=@diagrams.Diagnostic::error("swimlane/"+code,message,span=span(start,end))
  if code.has_suffix("-limit") { limited=true; if diagnostics.length() >= limits.diagnostics.max(1) { diagnostics[diagnostics.length()-1]=diagnostic; return } }
  if diagnostics.length() < limits.diagnostics.max(1) { diagnostics.push(diagnostic) }
 }
 if source.length() > limits.source || limits.source < 0 { report("source-limit","Source limit exceeded",0,source.length()); return {tree:@cst.Node::new([{kind:Error,text:source,offset:0}]),ast:None,diagnostics:ReadOnlyArray::from_array(diagnostics[:])} }
 while i < source.length() {
  work+=1; if work > limits.work { report("work-limit","Parser work limit exceeded",i,source.length()); tokens.push({kind:Error,text:part(source,i,source.length()),offset:i}); break }
  let start=i
  if is_space(ch(source,i)) || ch(source,i) == 10 || ch(source,i) == 13 || ch(source,i) == 59 { i+=width(source,i); tokens.push({kind:Whitespace,text:part(source,start,i),offset:start}); continue }
  if !header && front == None && source[i:].has_prefix("---") {
   i+=3; while i < source.length() { if (ch(source,i-1) == 10 || ch(source,i-1) == 13) && source[i:].has_prefix("---") { i+=3; break }; i+=width(source,i) }; let text=part(source,start,i); front=Some(text); tokens.push({kind:FrontMatter,text,offset:start}); continue
  }
  if source[i:].has_prefix("%%{") {
   i+=3; while i < source.length() && !source[i:].has_prefix("}%%") { i+=width(source,i) }; if i < source.length() { i+=3 } else { report("directive","Unclosed directive",start,i) }; let text=part(source,start,i); directives.push(text); tokens.push({kind:Directive,text,offset:start}); continue
  }
  let comment=source[i:].has_prefix("%%"); let mut quote=0; let mut brace=0; let mut bracket=0; let mut pipe=false; let mut shapedata=false
  while i < source.length() {
   let c=ch(source,i)
  if (c == 34 || (c == 39 && shapedata)) && !(shapedata && quote == 34 && escaped(source,i)) && !comment { if quote == c { quote=0 } else if quote == 0 { quote=c } }
   if quote == 0 && !comment { if c == 123 && !shapedata { brace+=1; if ch(source,i-1) == 64 { shapedata=true } }; if c == 125 { brace-=1; if brace == 0 { shapedata=false } }; if !shapedata && (c == 91 || c == 40) { bracket+=1 }; if !shapedata && (c == 93 || c == 41) { bracket-=1 }; if c == 124 && bracket == 0 && brace == 0 { pipe=!pipe } }
   if (c == 10 || c == 13) && (brace <= 0 || (!shapedata && !source[start:].has_prefix("accDescr") && quote == 0)) {
    if quote == 0 && !pipe {
     let closing=if brace > 0 { 125 } else if source[start:i].contains("[") { 93 } else { 41 }
     if (brace <= 0 && bracket <= 0) || !closes_label(source,i+1,closing) { break }
    }
    if quote != 0 || pipe {
     // Unterminated quotes recover on a line boundary.
     let mut closing=i+1
     let closing_character=if pipe { 124 } else { quote }
     while closing < source.length() && ch(source,closing) != closing_character { closing+=1 }
     if closing == source.length() { break }
    }
   }
   if c == 59 && quote == 0 && !pipe && brace <= 0 && bracket <= 0 && !source[start:].has_prefix("accTitle") && !source[start:].has_prefix("accDescr") { break }
   if i > start && quote == 0 && !pipe && brace <= 0 && bracket <= 0 && source[i:].has_prefix("%%") { break }
   i+=width(source,i)
  }
  if i == start { i+=width(source,i) }
  let raw=part(source,start,i); work+=raw.length(); if work > limits.work { report("work-limit","Parser work limit exceeded",start,i) }; let text=trim(raw)
  if comment { tokens.push({kind:Comment,text:raw,offset:start}); statements.push({kind:Comment(text),spelling:text,span:span(start,i)}); continue }
  if !header {
   if text.has_prefix("swimlane-beta") && (text.length() == 13 || is_space(ch(text,13))) { header=true; let value=trim(part(text,13,text.length())); if value != "" { direction=Some(value) }; tokens.push({kind:Header,text:raw,offset:start}) }
   else { report("unsupported-header","Expected swimlane-beta header",start,i); tokens.push({kind:Error,text:raw,offset:start}) }
   continue
  }
  context.failure=None; context.work=work
  let statement_kind=parse_statement(text,context); work=context.work
  match statement_kind {
   Some(kind) => {
    match kind {
     Subgraph(..) => { if groups.length() >= limits.depth { report("depth-limit","Subgraph depth limit exceeded",start,i) } else { groups.push((start,i)) } }
     End => if groups.is_empty() { report("unexpected-end","No open subgraph",start,i) } else { let _=groups.pop() }
     _ => ()
    }
    statements.push({kind,spelling:text,span:span(start,i)}); tokens.push({kind:Statement,text:raw,offset:start})
   }
   None => { report(context.failure.unwrap_or("syntax"),"Invalid swimlane statement",start,i); tokens.push({kind:Error,text:raw,offset:start}) }
  }
 }
 for range in groups { report("missing-end","Subgraph has no closing end",range.0,range.1) }
 {tree:@cst.Node::new(tokens[:]),ast:if header && !limited { Some(@ast.Diagram::new(statements[:],direction?,front_matter?=front,directives=directives[:])) } else { None },diagnostics:ReadOnlyArray::from_array(diagnostics[:])}
}

///|
pub extend Limits with Eq::{equal,not_equal}
///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend ReadResult with Eq::{equal,not_equal}
///|
pub extend ReadResult with @debug.Debug::{to_repr}
///|
/// Stable reader findings. Limit findings produce no complete AST.
pub let diagnostic_codes : ReadOnlyArray[String] = ["swimlane/source-limit","swimlane/work-limit","swimlane/depth-limit","swimlane/unsupported-header","swimlane/directive","swimlane/unexpected-end","swimlane/syntax","swimlane/missing-end"]
