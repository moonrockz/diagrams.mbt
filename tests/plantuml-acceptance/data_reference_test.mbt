///|
/// The text as the reference normalizes it: each unpaired surrogate becomes
/// `⟨U+XXXX⟩`, so the reference stays valid JSON.
fn reference_text(text : String) -> String {
  let out = StringBuilder()
  let n = text.length()
  let mut i = 0
  while i < n {
    let c = text.code_unit_at(i).to_int()
    let pair = c >= 0xd800 &&
      c <= 0xdbff &&
      i + 1 < n &&
      text.code_unit_at(i + 1).to_int() >= 0xdc00 &&
      text.code_unit_at(i + 1).to_int() <= 0xdfff
    if pair {
      out.write_string(text.view(start_offset=i, end_offset=i + 2).to_owned())
      i += 2
    } else if c >= 0xd800 && c <= 0xdfff {
      out.write_string("⟨U+" + c.to_string(radix=16).to_upper() + "⟩")
      i += 1
    } else {
      out.write_string(text.view(start_offset=i, end_offset=i + 1).to_owned())
      i += 1
    }
  }
  out.to_string()
}

///|
/// The normalized data of a library tree, in the shape of the reference
/// driver: {"object": [[name, value]...]}, {"array": [...]}, {"string": s},
/// {"number": lexeme}, {"boolean": b} or {"null": true}.
fn data_shape(tree : @data_tree.DataTree) -> Json {
  let nodes : Map[String, @data_tree.Node] = Map([])
  for node in tree.nodes {
    nodes[node.id] = node
  }
  fn shape(id : String) -> Json {
    match nodes[id].value {
      Object(members) =>
        Json::object({
          "object": Json::array(
            members
            .iter()
            .map(m => {
              let name = match m.key {
                Name(name) => reference_text(name)
                Index(i) => i.to_string()
              }
              Json::array([Json::string(name), shape(m.value)])
            })
            .to_array(),
          ),
        })
      Array(members) =>
        Json::object({
          "array": Json::array(
            members.iter().map(m => shape(m.value)).to_array(),
          ),
        })
      Text(text) =>
        Json::object({ "string": Json::string(reference_text(text)) })
      Number(lexeme) => Json::object({ "number": Json::string(lexeme) })
      Boolean(value) => Json::object({ "boolean": Json::boolean(value) })
      Null => Json::object({ "null": Json::boolean(true) })
    }
  }
  shape(tree.root)
}

///|
/// The documented upstream projection of a JSON root. PlantUML 1.2026.9
/// draws a scalar root as a one-element array and an empty root container
/// as an array with one empty string. The library model keeps the root as
/// it is. YAML needs no projection here: conversion already applies the
/// pinned duplicate-key policy (last value at the first position).
fn json_root_projection(tree : @data_tree.DataTree, data : Json) -> Json {
  let root = tree.nodes.iter().find_first(n => n.id == tree.root).unwrap()
  match root.value {
    Object(members) | Array(members) if members.is_empty() =>
      Json::object({
        "array": Json::array([Json::object({ "string": Json::string("") })]),
      })
    Object(_) | Array(_) => data
    _ => Json::object({ "array": Json::array([data]) })
  }
}

///|
/// The highlight paths as upstream splits them, or `None` when a selector
/// uses a form that upstream cannot express: a name with `/`, `<` or `>`,
/// or an occurrence number.
fn upstream_paths(selectors : ReadOnlyArray[@data.Selector]) -> Json? {
  let out = []
  for selector in selectors {
    let path = []
    for segment in selector.segments {
      match segment {
        Name(name) => {
          if name.contains("/") || name.contains("<") || name.contains(">") {
            return None
          }
          path.push(Json::string(name))
        }
        Any => path.push(Json::string("*"))
        Deep => path.push(Json::string("**"))
        Occurrence(_, _) => return None
      }
    }
    out.push(
      Json::object({
        "path": Json::array(path),
        "stereotype": match selector.stereotype {
          Some(text) => Json::string("<<" + text + ">>")
          None => Json::null()
        },
      }),
    )
  }
  Some(Json::array(out))
}

///|
/// Read and convert one JSON or YAML source with the library readers.
fn read_data(
  source : String,
) -> (@data_tree.DataTree?, ReadOnlyArray[@data.Selector], String) {
  let scan = @envelope.scan(source)
  match scan.kind {
    Some(Json) => {
      let read = @pjson.read(scan)
      let codes = read.diagnostics.iter().map(d => d.code).collect().join(",")
      match read.document {
        None => (None, [], codes)
        Some(document) => {
          let conversion = @pjson.to_data_tree(document)
          (conversion.tree, document.highlights, codes)
        }
      }
    }
    Some(Yaml) => {
      let read = @pyaml.read(scan)
      let codes = read.diagnostics.iter().map(d => d.code).collect().join(",")
      match read.document {
        None => (None, [], codes)
        Some(document) => {
          let conversion = @pyaml.to_data_tree(document)
          let more = conversion.diagnostics
            .iter()
            .map(d => d.code)
            .collect()
            .join(",")
          (conversion.tree, document.highlights, codes + "," + more)
        }
      }
    }
    _ =>
      (None, [], scan.diagnostics.iter().map(d => d.code).collect().join(","))
  }
}

///|
/// Compare one JSON, YAML or data-envelope fixture with the pinned reference.
fn compare_data(
  fixture : @corpus.Fixture,
  entry : Map[String, Json],
) -> Outcome {
  let status = str(entry.get("status"))
  let data = entry.get("data")
  let native_accept = status == "accepted" && data is Some(Object(_))
  let (tree, selectors, detail) = read_data(fixture.source)
  let category = match expectation(fixture.name) {
    Some((c, _)) => c
    None => if native_accept { "accepted" } else { "native-refusal" }
  }
  match category {
    "native-refusal" | "library-refusal" =>
      return {
        name: fixture.name,
        category,
        agrees: tree is None && (category == "library-refusal") == native_accept,
        detail,
      }
    _ => ()
  }
  guard tree is Some(tree) else {
    return {
      name: fixture.name,
      category,
      agrees: false,
      detail: "refused: " + detail,
    }
  }
  let shape = data_shape(tree)
  let actual = if fixture.source.contains("@startjson") {
    json_root_projection(tree, shape)
  } else {
    shape
  }
  let expected = data.unwrap_or(Json::null())
  let title_ok = tree.title.unwrap_or("") == str(entry.get("title"))
  let paths = upstream_paths(selectors)
  let paths_ok = match paths {
    Some(ours) => Some(ours) == entry.get("highlights")
    None => false
  }
  let same = actual == expected && title_ok && paths_ok
  {
    name: fixture.name,
    category,
    agrees: if category == "divergence" {
      !same
    } else {
      same
    },
    detail: "expected \{expected.stringify()} title=\{str(entry.get("title"))} highlights=\{entry.get("highlights").unwrap_or(Json::null()).stringify()}\nactual   \{actual.stringify()} title=\{tree.title.unwrap_or("")} highlights=\{paths.unwrap_or(Json::null()).stringify()}",
  }
}

///|
test "JSON, YAML and data envelope fixtures agree with PlantUML 1.2026.9" {
  let entries = reference_entries()
  let failures = []
  let mut checked = 0
  for fixture in @corpus.fixtures {
    let kind = kind_of(fixture.name)
    let envelope_data = kind == "envelope" &&
      (
        fixture.source.contains("@startjson") ||
        fixture.source.contains("@startyaml")
      )
    if kind != "json" && kind != "yaml" && !envelope_data {
      continue
    }
    checked += 1
    let outcome = compare_data(fixture, entries[fixture.name])
    if !outcome.agrees {
      failures.push("\{outcome.name} [\{outcome.category}] \{outcome.detail}")
    }
  }
  if !failures.is_empty() {
    fail(failures.join("\n\n"))
  }
  assert_true(checked > 100)
}
