///|
priv enum JsonAction { Value(Json,Int); Text(String) }
///|
/// Stable, bounded JSON spelling for typed metadata. The explicit stack also
/// handles caller-constructed values without recursive host-stack traversal.
pub fn canonical_json(value : Json, depth_limit? : Int = 256, work_limit? : Int = 1000000, output_limit? : Int = 16777216) -> String? {
 let stack=[JsonAction::Value(value,0)]; let out=StringBuilder(); let mut work=0; let mut output=0
 while stack.pop() is Some(action) {
  match action {
   Text(text) => {
    if text.length() > output_limit-output || text.length() > work_limit-work { return None }
    output+=text.length(); work+=text.length(); out.write_string(text)
   }
   Value(value,depth) => {
    if depth > depth_limit || work >= work_limit { return None }; work+=1
    match value {
     Array(values) => {
      if values.length() > work_limit-work { return None }
      stack.push(Text("]"))
      for i=values.length()-1; i>=0; i=i-1 {
       stack.push(Value(values[i],depth+1))
       if i != 0 { stack.push(Text(",")) }
      }
      stack.push(Text("["))
     }
     Object(fields) => {
      if fields.length() > work_limit-work { return None }
      let keys=fields.keys().to_array(); keys.sort_by((a,b) => a.lexical_compare(b)); stack.push(Text("}"))
      for i=keys.length()-1; i>=0; i=i-1 {
       let key=keys[i]
       if key.length() > work_limit-work { return None }
       stack.push(Value(fields.get(key).unwrap(),depth+1)); stack.push(Text(":")); stack.push(Text(Json(key).stringify()))
       if i != 0 { stack.push(Text(",")) }
      }
      stack.push(Text("{"))
     }
     String(text) => {
      if text.length() > work_limit-work { return None }
      stack.push(Text(value.stringify()))
     }
     _ => stack.push(Text(value.stringify()))
    }
   }
  }
 }
 Some(out.to_string())
}
