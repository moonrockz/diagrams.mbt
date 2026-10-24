///|
fn field(doc : Json, key : String) -> Json {
  match doc { Object(fields) => fields.get(key).unwrap_or(Json::null()); _ => Json::null() }
}

///|
/// The reference parser normalizes HTML line breaks and wrap prefixes for
/// display. Apply only those display normalizations to our preserved labels.
fn display_text(text : String) -> String {
  let text = text.trim().to_owned()
  let text = if text.has_prefix("wrap:") {
    text.view(start_offset=5).trim().to_owned()
  } else if text.has_prefix("nowrap:") {
    text.view(start_offset=7).trim().to_owned()
  } else { text }
  text.replace_all(old="<br/>", new="<br>").replace_all(old="<br />", new="<br>")
}

///|
fn kind_name(kind : @model.ParticipantKind) -> String {
  match kind {
    Participant => "participant"; Actor => "actor"; Boundary => "boundary";
    Control => "control"; Entity => "entity"; Database => "database";
    Collections => "collections"; Queue => "queue"; Service => "service";
    Resource => "resource"; Client => "client"
  }
}

///|
fn signal(kind : Int, from : Json, to : Json, text : String, central? : Int = 0) -> Json {
  [kind, from, to, display_text(text), central]
}

///|
fn message_type(m : @model.Message) -> Int {
  let dotted = m.line == Dotted
  fn base(head : @model.Head) -> @model.Head { match head { Central(h) => h; _ => head } }
  match (base(m.sender_head), base(m.receiver_head)) {
    (Arrow, Arrow) => if dotted { 34 } else { 33 }
    (NoHead, Arrow) => if dotted { 1 } else { 0 }
    (NoHead, OpenArrow) => if dotted { 6 } else { 5 }
    (NoHead, Cross) => if dotted { 4 } else { 3 }
    (NoHead, Async) => if dotted { 25 } else { 24 }
    (NoHead, HalfArrow(upper~, filled~)) => 41 + (if upper { 0 } else { 1 }) + (if filled { 0 } else { 2 }) + (if dotted { 10 } else { 0 })
    (HalfArrow(upper~, filled~), NoHead) => 45 + (if upper { 0 } else { 1 }) + (if filled { 0 } else { 2 }) + (if dotted { 10 } else { 0 })
    _ => -1
  }
}

///|
fn model_signals(events : ReadOnlyArray[@model.Event]) -> Array[Json] {
  let out = []
  for e in events {
    match e {
      Message(m) => out.push(signal(message_type(m), Json::string(m.sender), Json::string(m.receiver), m.label, central=if m.sender_head is Central(_) { if m.receiver_head is Central(_) { 61 } else { 60 } } else if m.receiver_head is Central(_) { 59 } else { 0 }))
      Frame(f) => {
        let (start, section, end) = match f.kind {
          Loop => (10, -1, 11); Alt => (12, 13, 14); Opt => (15, -1, 16);
          Par => (19, 20, 21); ParOver => (32, 20, 21); Rect => (22, -1, 23);
          Critical => (27, 28, 29); Break => (30, -1, 31)
        }
        for i, s in f.sections {
          out.push(signal(if i == 0 { start } else { section }, Json::null(), Json::null(), if f.kind == Rect { f.colour.unwrap_or("") } else { s.label.unwrap_or("") }))
          out.append(model_signals(s.events))
        }
        out.push(signal(end, Json::null(), Json::null(), ""))
      }
      _ => ()
    }
  }
  out
}

///|
fn reference_signals(doc : Json) -> Array[Json] {
  let out = []
  guard field(doc, "messages") is Array(messages) else { return out }
  for m in messages {
    guard field(m, "type") is Number(n, ..) else { continue }
    let kind = n.to_int()
    // Notes, activations and numbering have focused semantic tests. This
    // independent comparison checks every message and every frame boundary.
    if kind == 2 || kind == 17 || kind == 18 || kind == 26 || kind >= 59 { continue }
    let text = match field(m, "message") { String(s) => s; _ => "" }
    out.push(signal(kind, field(m, "from"), field(m, "to"), text, central=match field(m, "centralConnection") { Number(n, ..) => n.to_int(); _ => 0 }))
  }
  out
}

///|
test "all 38 sequence models match the independent parser's participants messages and frames" {
  assert_eq(@corpus.sequence_references.length(), @corpus.mermaid_12_2_0.length())
  for i, example in @corpus.mermaid_12_2_0 {
    let (name, text) = @corpus.sequence_references[i]
    assert_eq(name, example.name)
    let fixture = @json.parse(text)
    assert_eq(field(fixture, "source_sha256"), Json::string(example.sha256))
    let expected = field(fixture, "model")
    let conversion = @mermaid.to_sequence(@mermaid.read(example.source).ast.unwrap())
    assert_eq(conversion.diagnostics.length(), 0, msg="example \{name}")
    let model = conversion.sequence
    let actual_actors = model.participants.map(p => {
      let actor : Json = [p.id, display_text(p.label), kind_name(p.kind), p.group.map(g => Json::string(g.label)).unwrap_or(Json::null())]
      actor
    }).iter().to_array()
    guard field(expected, "actors") is Array(actors) else { fail("actors \{name}") }
    let expected_actors = actors.map(a => {
      let text = match field(a, "description") { String(s) => s; _ => "" }
      let actor : Json = [field(a, "id"), display_text(text), field(a, "type"), field(a, "box")]
      actor
    })
    assert_eq(actual_actors, expected_actors, msg="participants \{name}")
    assert_eq(model_signals(model.events), reference_signals(expected), msg="messages and frames \{name}: actual=\{Json::array(model_signals(model.events)).stringify()} expected=\{Json::array(reference_signals(expected)).stringify()}")
  }
}
