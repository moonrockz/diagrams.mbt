///|
priv struct MetaStats { depth : Int; weight : Int }
///|
priv struct MetaFrame { anchor : Int; mut depth : Int; mut weight : Int }
///|
priv struct MetadataGuard {
 max_depth : Int
 budget : Int
 mut used : Int
 frames : Array[MetaFrame]
 anchors : Map[Int,MetaStats]
 mut failure : String?
 empty_tags : Array[(Int,String)]
 scalars : Array[(Int,Int,String)]
 input : String
 offsets : Array[Int]
}
///|
fn MetadataGuard::charge(self : MetadataGuard, units : Int) -> Bool {
 if self.failure != None { return false }
 if units < 0 || units > self.budget-self.used { self.failure=Some("work-limit"); false }
 else { self.used+=units; true }
}
///|
fn MetadataGuard::accept(self : MetadataGuard, stats : MetaStats, anchor : Int) -> Unit {
 if self.failure != None { return }
 if stats.depth > self.max_depth { self.failure=Some("depth-limit"); return }
 if anchor != 0 { self.anchors[anchor]=stats }
 if self.frames.last() is Some(parent) {
  if stats.depth >= self.max_depth { self.failure=Some("depth-limit"); return }
  parent.depth=parent.depth.max(stats.depth+1)
  if stats.weight > self.budget-parent.weight { self.failure=Some("work-limit"); return }
  parent.weight+=stats.weight
 }
}
///|
impl @yaml_events.MarkedEventReceiver for MetadataGuard with on_event(self,event,marker) {
 if self.failure != None { return }
 match event {
  Scalar(value~,style~,tag~,id~) => {
   if !self.charge(value.length()) { return }
   let explicit_numeric=tag.map(tag => tag.handle+tag.suffix).map(name => name == "tag:yaml.org,2002:int" || name == "tag:yaml.org,2002:float").unwrap_or(false)
   if (style is @yaml_events.TScalarStyle::Plain || explicit_numeric) && value.length() > 0 && [43,45,46,48,49,50,51,52,53,54,55,56,57].contains(ch(value,0)) {
    let resolved=native_number(value)
    if explicit_numeric && resolved == None { self.failure=Some("syntax"); return }
    if tag == None || explicit_numeric {
     let replacement=match resolved { Some(number) if number.is_nan() || (number.is_pos_inf() || number.is_neg_inf()) => value; Some(number) => number.to_string(); None => Json(value).stringify() }
     if replacement != value || !(style is @yaml_events.TScalarStyle::Plain) {
      let start=self.offsets[marker.index]
      let mut length=value.length()
      if style is @yaml_events.TScalarStyle::SingleQuoted || style is @yaml_events.TScalarStyle::DoubleQuoted {
       let quote=ch(self.input,start); let mut end=start+1
       while end < self.input.length() {
        if ch(self.input,end) == quote && !(quote == 34 && escaped(self.input,end)) {
         if quote == 39 && ch(self.input,end+1) == 39 { end+=2; continue }
         break
        }
        end+=width(self.input,end)
       }
       length=end+1-start
      }
      self.scalars.push((marker.index,length,replacement))
     }
    }
   }
   if tag is Some(tag) {
    let name=tag.handle+tag.suffix
    if name == "tag:yaml.org,2002:bool" && !["true","True","TRUE","false","False","FALSE"].contains(value) { self.failure=Some("syntax"); return }
    if name == "tag:yaml.org,2002:int" && (value.contains(".") || value.contains("e") || value.contains("E")) && !value.contains("0x") { self.failure=Some("syntax"); return }
    if name == "tag:yaml.org,2002:float" && (value.contains("0x") || value.contains("0o") || value.contains("0b")) { self.failure=Some("syntax"); return }
    if name == "tag:yaml.org,2002:map" || name == "tag:yaml.org,2002:seq" {
     if value != "" { self.failure=Some("syntax"); return }
     self.empty_tags.push((marker.index,if name.has_suffix("map") { "map" } else { "seq" }))
    } else if !["!","tag:yaml.org,2002:str","tag:yaml.org,2002:null","tag:yaml.org,2002:bool","tag:yaml.org,2002:int","tag:yaml.org,2002:float"].contains(name) { self.failure=Some("syntax"); return }
   }
   if self.charge(1) { self.accept({depth:0,weight:1},id) }
  }
  SequenceStart(id~,tag~) | MappingStart(id~,tag~) => {
   if tag is Some(tag) && !["!","tag:yaml.org,2002:map","tag:yaml.org,2002:seq"].contains(tag.handle+tag.suffix) { self.failure=Some("syntax"); return }
   if !self.charge(1) { return }
   if self.frames.length() > self.max_depth { self.failure=Some("depth-limit"); return }
   self.frames.push({anchor:id,depth:0,weight:1})
  }
  SequenceEnd | MappingEnd => {
   guard self.frames.pop() is Some(frame) else { self.failure=Some("syntax"); return }
   self.accept({depth:frame.depth,weight:frame.weight},frame.anchor)
  }
  Alias(id~) => {
   guard self.anchors.get(id) is Some(stats) else { self.failure=Some("depth-limit"); return }
   if self.charge(1) && self.charge(stats.weight) { self.accept(stats,0) }
  }
  _ => ()
 }
}
///|
/// The alias-free pass validates physical structure without recursive alias
/// weighing. Replacing '*' inside quoted strings/comments changes only values,
/// which are unused by this structural pass. Last-key wins avoids false key
/// collisions introduced by that replacement; the real pass rejects duplicates.
fn metadata_preflight(input : String, context : ParseContext) -> String? {
 let budget=context.limits.metadata_work.min((context.limits.work-context.work).max(0))
 try {
  let mut physical=input.replace_all(old="*",new="X")
  for tag in ["map","seq","str","null","bool","int","float"] { physical=physical.replace_all(old="!!"+tag,new="").replace_all(old="!<tag:yaml.org,2002:"+tag+">",new="") }
  physical=physical.replace_all(old="e",new="q").replace_all(old="E",new="Q")
  let _=@yaml.loads(physical,flavor=@yaml.Flavor::new(depth=context.limits.metadata_depth,duplicates=Last,aliases=false,budget~))
 } catch {
  @yaml.Refused::TooDeep(_) => { context.failure=Some("depth-limit"); return None }
  @yaml.Refused::Exceeded(..) => { context.failure=Some("work-limit"); return None }
  _ => { context.failure=Some("syntax"); return None }
 }
 let offsets=[0]; let mut units=0
 for c in input { units+=if c.to_int() > 65535 { 2 } else { 1 }; offsets.push(units) }
 let preflight : MetadataGuard={max_depth:context.limits.metadata_depth,budget,used:0,frames:[],anchors:Map([]),failure:None,empty_tags:[],scalars:[],input,offsets}
 try {
  @yaml_events.Parser::Parser(input).load(preflight,false)
 } catch {
  _ => { context.failure=Some("syntax"); return None }
 }
 if preflight.failure is Some(code) { context.failure=Some(code); return None }
 context.work+=preflight.used
 normalize_scalars(input,preflight.empty_tags,preflight.scalars)
}

///|
fn normalize_scalars(input : String, tags : Array[(Int,String)], scalars : Array[(Int,Int,String)]) -> String? {
 let edits : Array[(Int,Int,String)]=[]; let mut lower=0
 let offsets=[0]; let mut units=0
 for c in input { units+=if c.to_int() > 65535 { 2 } else { 1 }; offsets.push(units) }
 for (character_index,kind) in tags {
  if character_index < 0 || character_index >= offsets.length() { return None }
  let offset=offsets[character_index]
  let mut found : (Int,Int)?=None; let mut i=lower; let mut quote=0; let mut comment=false
  while i < offset {
   let c=ch(input,i)
   if c == 10 || c == 13 { comment=false }
   if !comment {
    if quote == 0 && c == 35 && (i == 0 || is_space(ch(input,i-1))) { comment=true }
    if c == 34 && !(quote == 34 && escaped(input,i)) { if quote == 34 { quote=0 } else if quote == 0 { quote=34 } }
    if c == 39 { if quote == 39 { if ch(input,i+1) == 39 { i+=2; continue }; quote=0 } else if quote == 0 { quote=39 } }
    if quote == 0 && !comment {
     for token in ["!!"+kind,"!<tag:yaml.org,2002:"+kind+">"] {
      if input[i:].has_prefix(token) && (i == 0 || is_space(ch(input,i-1)) || [58,45,91,44].contains(ch(input,i-1))) {
       let end=i+token.length()
       if end <= offset && (end == input.length() || is_space(ch(input,end)) || [10,13,44,93,125].contains(ch(input,end))) { found=Some((i,end)) }
      }
     }
    }
   }
   i+=width(input,i)
  }
  guard found is Some((start,end)) else { return None }
  edits.push((start,end,if kind == "map" { "{}" } else { "[]" })); lower=offset
 }
 for (character_index,length,replacement) in scalars {
  if character_index < 0 || character_index >= offsets.length() { return None }
  let start=offsets[character_index]; let end=start+length
  if end > input.length() { return None }; edits.push((start,end,replacement))
 }
 edits.sort_by((a,b) => a.0.compare(b.0))
 let out=StringBuilder(); let mut consumed=0
 for (start,end,replacement) in edits {
  if start < consumed { return None }
  out.write_string(part(input,consumed,start)); out.write_string(replacement); consumed=end
 }
 out.write_string(part(input,consumed,input.length()))
 Some(out.to_string())
}

///|
/// js-yaml 4.3 JSON_SCHEMA accepts finite numeric literals and explicit
/// infinities/NaN. Unlike MoonYAML's core resolver, overflowing literals remain
/// strings and binary integers are numbers. This scanner also avoids delegating
/// attacker-sized exponent loops to the dependency.
fn native_number(value : String) -> Double? {
 let mut i=0; let mut sign=1.0
 if ch(value,0) == 43 || ch(value,0) == 45 { if ch(value,0) == 45 { sign = -1.0 }; i+=1 }
 let rest=part(value,i,value.length())
 if [".inf",".Inf",".INF"].contains(rest) { return Some(sign*(1.0/0.0)) }
 if i == 0 && [".nan",".NaN",".NAN"].contains(rest) { return Some(0.0/0.0) }
 if rest.length() > 2 && ch(rest,0) == 48 {
  let radix=match ch(rest,1) { 98 => 2; 111 => 8; 120 => 16; _ => 0 }
  if radix != 0 {
   let mut number=0.0
   for j=2; j<rest.length(); j=j+1 {
    let c=ch(rest,j); let digit=if c>=48 && c<=57 { c-48 } else if c>=65 && c<=70 { c-55 } else if c>=97 && c<=102 { c-87 } else { return None }
    if digit>=radix { return None }; number=number*radix.to_double()+digit.to_double()
   }
   return if (number.is_pos_inf() || number.is_neg_inf()) { None } else { Some(sign*number) }
  }
 }
 let start=i
 while ch(value,i)>=48 && ch(value,i)<=57 { i+=1 }
 let whole=i-start
 if ch(value,i) == 46 {
  i+=1; let fraction=i
  while ch(value,i)>=48 && ch(value,i)<=57 { i+=1 }
  if whole == 0 && (start != 0 || i == fraction) { return None }
 } else if whole == 0 { return None }
 if ch(value,i) == 101 || ch(value,i) == 69 {
  i+=1; if ch(value,i) == 43 || ch(value,i) == 45 { i+=1 }
  let exponent=i; while ch(value,i)>=48 && ch(value,i)<=57 { i+=1 }
  if i == exponent { return None }
 }
 if i != value.length() { return None }
 try { let number=@string.parse_double(value[:]); if (number.is_pos_inf() || number.is_neg_inf()) || number.is_nan() { None } else { Some(number) } } catch { _ => None }
}
