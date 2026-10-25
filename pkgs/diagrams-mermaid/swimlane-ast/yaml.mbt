///|
priv enum YamlAction { Value(Json,Int,Int,String); Text(String) }
///|
fn yaml_string(value : String) -> String {
 let out=StringBuilder(); out.write_char('"')
 for c in value {
  match c {
   '"' => out.write_string("\\u0022")
   '{' => out.write_string("\\u007b")
   '}' => out.write_string("\\u007d")
   '\\' => out.write_string("\\\\")
   '\n' => out.write_string("\\n")
   '\r' => out.write_string("\\r")
   '\t' => out.write_string("\\t")
   _ => if c.to_int() < 32 || c.to_int() == 8232 || c.to_int() == 8233 {
    let encoded=Json(c.to_string()).stringify()
    out.write_string(encoded[1:encoded.length()-1].to_owned())
   } else { out.write_char(c) }
  }
 }
 out.write_char('"'); out.to_string()
}
///|
/// Write typed metadata as block YAML, because the pinned native shape-data
/// lexer closes at the first unquoted '}'. An explicit stack bounds traversal.
pub fn canonical_yaml(value : Json, depth_limit? : Int = 256, work_limit? : Int = 1000000, output_limit? : Int = 16777216) -> String? {
 let stack=[YamlAction::Value(value,0,0,"")]; let out=StringBuilder(); let mut work=0; let mut output=0
 while stack.pop() is Some(action) {
  match action {
   Text(text) => {
    if text.length() > work_limit-work || text.length() > output_limit-output { return None }
    work+=text.length(); output+=text.length(); out.write_string(text)
   }
   Value(value,depth,indent,prefix) => {
    if depth > depth_limit || work >= work_limit { return None }; work+=1
    let spaces=" ".repeat(indent)
    match value {
     Object(fields) if !fields.is_empty() => {
      if fields.length() > work_limit-work { return None }
      let keys=fields.keys().to_array(); keys.sort_by((a,b) => a.lexical_compare(b))
      let child_indent=if prefix == "" { indent } else { indent+2 }
      for i=keys.length()-1; i>=0; i=i-1 {
       let key=keys[i]
       if key.length() > work_limit-work { return None }
       stack.push(Value(fields.get(key).unwrap(),depth+1,child_indent,yaml_string(key)+": "))
      }
      if prefix != "" { stack.push(Text(spaces+prefix.trim_end().to_owned()+"\n")) }
     }
     Array(values) if !values.is_empty() => {
      if values.length() > work_limit-work { return None }
      let child_indent=if prefix == "" { indent } else { indent+2 }
      for i=values.length()-1; i>=0; i=i-1 { stack.push(Value(values[i],depth+1,child_indent,"- ")) }
      if prefix != "" { stack.push(Text(spaces+prefix.trim_end().to_owned()+"\n")) }
     }
     _ => {
      let scalar=match value {
       Object(_) => "!!map"
       Array(_) => "[]"
       String(text) => { if text.length() > work_limit-work { return None }; yaml_string(text) }
       Number(number,..) if number.is_nan() => ".nan"
       Number(number,..) if number.is_pos_inf() => ".inf"
       Number(number,..) if number.is_neg_inf() => "-.inf"
       _ => value.stringify()
      }
      stack.push(Text(spaces+prefix+scalar+"\n"))
     }
    }
   }
  }
 }
 Some(out.to_string())
}
