///|
/// An exact XML Schema numeric token. It is never converted through a host float.
pub struct ExactNumber { token : String } derive(Eq, Debug)

///|
pub extend ExactNumber with Eq::{equal, not_equal}

///|
pub extend ExactNumber with @debug.Debug::{to_repr}

///|
fn digits(s : String, start : Int) -> Int {
  let mut i = start
  while unit(s,i) >= 48 && unit(s,i) <= 57 { i += 1 }
  i
}

///|
pub fn ExactNumber::parse(token : String) -> ExactNumber? {
  if token == "INF" || token == "-INF" || token == "NaN" { return Some({ token, }) }
  let mut i = if unit(token,0) == 43 || unit(token,0) == 45 { 1 } else { 0 }
  let begin = i
  i = digits(token,i)
  let whole = i-begin
  let mut fraction = 0
  if unit(token,i) == 46 { i += 1; let begin=i; i=digits(token,i); fraction=i-begin }
  if whole + fraction == 0 { return None }
  if unit(token,i) == 69 || unit(token,i) == 101 {
    i += 1
    if unit(token,i) == 43 || unit(token,i) == 45 { i += 1 }
    let begin=i; i=digits(token,i)
    if i == begin { return None }
  }
  if i == token.length() { Some({ token, }) } else { None }
}

///|
pub fn ExactNumber::is_finite(self : ExactNumber) -> Bool { self.token != "INF" && self.token != "-INF" && self.token != "NaN" }

///|
pub struct ExactInteger { token : String } derive(Eq, Debug)

///|
pub extend ExactInteger with Eq::{equal, not_equal}

///|
pub extend ExactInteger with @debug.Debug::{to_repr}

///|
pub fn ExactInteger::parse(token : String) -> ExactInteger? {
  let begin = if unit(token,0) == 43 || unit(token,0) == 45 { 1 } else { 0 }
  if begin < token.length() && digits(token,begin) == token.length() { Some({ token, }) } else { None }
}

///|
pub(all) enum ReferenceKind { Id; QName } derive(Eq, Debug)

///|
pub extend ReferenceKind with Eq::{equal, not_equal}

///|
pub extend ReferenceKind with @debug.Debug::{to_repr}

///|
/// Namespace identity and original spelling are separate. A missing name marks
/// an unresolved namespace binding, not a missing external target document.
pub struct Reference { kind : ReferenceKind; spelling : String; name : ExpandedName? } derive(Debug)

///|
pub extend Reference with @debug.Debug::{to_repr}

///|
pub fn Reference::new(name : ExpandedName, kind? : ReferenceKind = QName) -> Reference { { kind, spelling: name.local_name, name: Some(name) } }

///|
fn xml_trim(value : String) -> String {
  let mut start = 0; let mut end = value.length()
  while start < end && space(unit(value,start)) { start += 1 }
  while end > start && space(unit(value,end-1)) { end -= 1 }
  value[start:end].to_owned()
}

///|
pub fn Reference::parse(spelling : String, bindings? : ArrayView[(String, String)] = [], kind? : ReferenceKind = QName) -> Reference {
  reference_lookup(spelling,kind,prefix => {
    let mut found : String? = None
    for (p,value) in bindings { if p == prefix { found = Some(value) } }
    found
  })
}

///|
fn reference_lookup(spelling : String, kind : ReferenceKind, lookup : (String) -> String?) -> Reference {
  let token = xml_trim(spelling)
  let mut name : ExpandedName? = None
  if kind == Id {
    if ncname(token) { name = Some(ExpandedName::new("",token)) }
  } else if qname(token) is Some((prefix,local_name)) {
    let uri = match lookup(prefix) {
      Some(uri) => Some(uri)
      None => if prefix == "" { Some("") } else if prefix == "xml" { Some("http://www.w3.org/XML/1998/namespace") } else { None }
    }
    name = uri.map(namespace_uri => ExpandedName::{ namespace_uri, local_name })
  }
  { kind, spelling, name }
}

///|
pub impl Eq for Reference with equal(a,b) {
  if a.kind != b.kind { return false }
  match (a.name,b.name) { (Some(x),Some(y)) => x == y; (None,None) => a.spelling == b.spelling; _ => false }
}

///|
pub extend Reference with Eq::{equal, not_equal}

///|
/// Invalid scalar spellings remain explicit values for inspection. Writers
/// return a structured failure instead of serializing them as valid fields.
pub(all) enum Scalar {
  Text(String)
  Identifier(String)
  Uri(String)
  Boolean(Bool)
  Integer(ExactInteger)
  Number(ExactNumber)
  Reference(Reference)
  Enumeration(BpmnEnum)
  Invalid(raw~ : String, expected~ : ExpandedName)
} derive(Eq, Debug)

///|
pub extend Scalar with Eq::{equal, not_equal}

///|
pub extend Scalar with @debug.Debug::{to_repr}

///|
pub fn Scalar::token(self : Scalar) -> String {
  match self {
    Text(s) | Identifier(s) | Uri(s) => s
    Boolean(b) => if b { "true" } else { "false" }
    Integer(n) => n.token; Number(n) => n.token; Reference(r) => r.spelling
    Enumeration(e) => e.token(); Invalid(raw~, ..) => raw
  }
}

///|
/// Absence is separate from a present false, empty string, zero or reference.
pub(all) enum Field[T] { Absent; Present(T); InvalidValue(Scalar) } derive(Eq, Debug)

///|
pub extend Field with Eq::{equal, not_equal}

///|
pub extend Field with @debug.Debug::{to_repr}

///|
pub fn[T] Field::value(self : Field[T]) -> T? { match self { Present(v) => Some(v); _ => None } }

///|
pub struct Attribute {
  name : ExpandedName?
  raw_name : String
  value : Scalar
  span : Span?
} derive(Eq, Debug)

///|
pub extend Attribute with Eq::{equal, not_equal}

///|
pub extend Attribute with @debug.Debug::{to_repr}

///|
pub fn Attribute::new(name : ExpandedName, value : Scalar) -> Attribute {
  let prefix = namespace_prefix(name.namespace_uri)
  { name: Some(name), raw_name: if prefix == "" { name.local_name } else { prefix+":"+name.local_name }, value, span: None }
}

///|
fn collapse_space(token : String) -> String {
  let out=StringBuilder(); let mut pending=false; let mut any=false
  for c in token {
    if space(c.to_int()) { pending=any } else {
      if pending { out.write_string(" ") }; out.write_char(c); any=true; pending=false
    }
  }
  out.to_string()
}

///|
fn int32_token(token : String) -> Bool {
  let negative=unit(token,0) == 45
  let mut start=if negative || unit(token,0) == 43 { 1 } else { 0 }
  while start < token.length()-1 && unit(token,start) == 48 { start += 1 }
  let size=token.length()-start
  let bound = if negative { "2147483648" } else { "2147483647" }
  size < 10 || (size == 10 && token[start:].to_owned() <= bound)
}

///|
fn primitive_scalar(expected : ExpandedName, token : String) -> Scalar {
  let invalid = () => Scalar::Invalid(raw=token, expected~)
  match expected.local_name {
    "boolean" => match xml_trim(token) { "true" | "1" => Boolean(true); "false" | "0" => Boolean(false); _ => invalid() }
    "QName" => Reference(Reference::parse(token))
    "IDREF" => Reference(Reference::parse(token,kind=Id))
    "ID" => if ncname(xml_trim(token)) { Identifier(xml_trim(token)) } else { invalid() }
    "integer" | "int" | "long" | "short" | "byte" | "unsignedInt" | "nonNegativeInteger" | "positiveInteger" => {
      let value = xml_trim(token)
      match ExactInteger::parse(value) { Some(n) => if expected.local_name == "int" && !int32_token(value) { invalid() } else { Integer(n) }; None => invalid() }
    }
    "double" | "float" | "decimal" => match ExactNumber::parse(xml_trim(token)) {
      Some(n) => if expected.local_name == "decimal" && (!n.is_finite() || n.token.contains("e") || n.token.contains("E")) { invalid() } else { Number(n) }
      None => invalid()
    }
    "anyURI" => Uri(collapse_space(token))
    "token" => Text(collapse_space(token))
    _ => Text(token)
  }
}

///|
fn parse_scalar(expected : ExpandedName, token : String, bindings : ArrayView[(String,String)]) -> Scalar {
  parse_scalar_lookup(expected,token,prefix => {
    let mut found : String? = None
    for (p,value) in bindings { if p == prefix { found = Some(value) } }
    found
  })
}

///|
fn parse_scalar_lookup(expected : ExpandedName, token : String, lookup : (String) -> String?) -> Scalar {
  let mut current = expected
  for _ in 0..<(schema_types.length()+1) {
    if current.namespace_uri == "http://www.w3.org/2001/XMLSchema" {
      let value = primitive_scalar(current,token)
      return match value { Reference(r) => Reference(reference_lookup(token,r.kind,lookup)); _ => value }
    }
    guard schema_type(current) is Some(t) else { return Text(token) }
    let enum_token = if !t.union_members.is_empty() || t.base == Some(ExpandedName::new("http://www.w3.org/2001/XMLSchema","token")) { collapse_space(token) } else { token }
    if parse_schema_enum(t.id,enum_token) is Some(value) { return Enumeration(value) }
    if !t.enum_values.is_empty() || !t.union_members.is_empty() { return Invalid(raw=token, expected~) }
    guard t.base is Some(base) else { return Text(token) }
    current = base
  }
  Invalid(raw=token, expected~)
}
