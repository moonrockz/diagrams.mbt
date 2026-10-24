///|
fn identifier(text : StringView) -> Bool {
  let body = text.trim_start(chars="_")
  guard body.length() > 0 else { return false }
  let first = body.iter().next().unwrap()
  guard first is ('A'..='Z' | 'a'..='z') || (text.has_prefix("_") && first is ('0'..='9')) else { return false }
  for c in text {
    if !(c is ('A'..='Z' | 'a'..='z' | '0'..='9' | '_')) { return false }
  }
  true
}

///|
/// Smithy 2.0 shape ID ABNF: https://smithy.io/2.0/spec/model.html#shape-id-abnf
/// Smithy absolute shape IDs. Labels require a qualified shape_namespace to avoid
/// treating ordinary text such as `read/write` as a link.
fn shape_target(text : String, qualified~ : Bool) -> String? {
  let parts = text.split("/").to_array()
  guard parts is [shape_namespace, shape] else { return None }
  let ns = shape_namespace.split(".").to_array()
  guard (!qualified || ns.length() >= 2) && ns.iter().all(identifier) else { return None }
  let names = shape.split("$").to_array()
  guard names.length() <= 2 && names.iter().all(identifier) else { return None }
  Some("\{shape_namespace}#\{shape}")
}

///|
fn url_link(url : String) -> @model.Link? {
  if url.has_prefix("smithy:") {
    shape_target(url.view(start_offset=7).to_owned(), qualified=false)
      .map(target => @model.Link::new(Smithy, target))
  } else if url.has_prefix("openrpc:") && url.length() > 8 {
    Some(@model.Link::new(OpenRpc, url.view(start_offset=8).to_owned()))
  } else {
    None
  }
}

///|
fn message_link(label : String) -> @model.Link? {
  shape_target(label, qualified=true).map(target => @model.Link::new(Smithy, target))
}

///|
/// JSON objects keep their source order in `links`. Select the first known
/// scheme, just as a single `link` selects its URL. Unknown schemes stay in AST.
fn statement_link(s : @ast.LinkStatement) -> @model.Link? {
  match s.kind {
    Link => match s.text.find("@") {
      Some(at) => url_link(s.text.view(start_offset=at + 1).trim().to_owned())
      None => None
    }
    Links => {
      let parsed = json_value(s.text)
      guard parsed is Some(Object(fields)) else { return None }
      for _, value in fields {
        if value is String(url) && url_link(url) is Some(link) {
          return Some(link)
        }
      }
      None
    }
    Properties | Details => None
  }
}

///|
fn json_value(text : String) -> Json? {
  try Some(@json.parse(text)) catch { _ => None }
}
