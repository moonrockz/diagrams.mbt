///|
fn obj(members : Array[(String, Json)]) -> Json {
  Json::object({
    "object": Json::array(
      members.map(m => Json::array([Json::string(m.0), m.1])),
    ),
  })
}

///|
fn arr(items : Array[Json]) -> Json {
  Json::object({ "array": Json::array(items) })
}

///|
fn str(text : String) -> Json {
  Json::object({ "string": Json::string(text) })
}

///|
fn num(lexeme : String) -> Json {
  Json::object({ "number": Json::string(lexeme) })
}

///|
fn boolean(value : Bool) -> Json {
  Json::object({ "boolean": Json::boolean(value) })
}

///|
fn null() -> Json {
  Json::object({ "null": Json::boolean(true) })
}

///|
/// The data of a tree in the normalized shape of the reference driver.
fn normalize(tree : @data_tree.DataTree) -> Json {
  let nodes : Map[String, @data_tree.Node] = Map([])
  for node in tree.nodes {
    nodes[node.id] = node
  }
  fn shape(id : String) -> Json {
    let node = nodes[id]
    match node.value {
      Object(members) =>
        obj(
          members
          .iter()
          .map(m => {
            (
              match m.key {
                Name(name) => name
                Index(i) => i.to_string()
              },
              shape(m.value),
            )
          })
          .to_array(),
        )
      Array(members) => arr(members.iter().map(m => shape(m.value)).to_array())
      Text(text) => str(text)
      Number(lexeme) => num(lexeme)
      Boolean(value) => boolean(value)
      Null => null()
    }
  }
  shape(tree.root)
}

///|
test "the reader and converter agree with the pinned YAML reference" {
  for case in profile_cases {
    let (name, source, expected, title) = case
    let result = @yaml.read(@envelope.scan(source))
    guard result.document is Some(document) else {
      fail("\{name} does not read")
    }
    let conversion = @yaml.to_data_tree(document)
    match expected {
      None =>
        assert_true(
          conversion.tree is None,
          msg="\{name} is refused upstream but converts here",
        )
      Some(data) => {
        guard conversion.tree is Some(tree) else {
          fail("\{name} is accepted upstream but refused here")
        }
        assert_eq(normalize(tree), data, msg="\{name} data")
        assert_eq(tree.title, title, msg="\{name} title")
      }
    }
  }
}

///|
test "every profile case reproduces its source and round-trips" {
  for case in profile_cases {
    let (name, source, _, _) = case
    let scan = @envelope.scan(source)
    let result = @yaml.read(scan)
    assert_eq(scan.document(result.nodes).text(), source, msg=name)
    guard result.document is Some(document) else { continue }
    let body = match @yaml.print_body(document) {
      Ok(body) => body
      Err(diagnostics) =>
        fail("\{name}: \{diagnostics.iter().map(d => d.message).join("; ")}")
    }
    let again = @yaml.read(@envelope.scan("@startyaml\n" + body + "@endyaml\n"))
    guard again.document is Some(back) else {
      fail("\{name}: canonical text does not read")
    }
    assert_true(
      back.lines.length() == document.lines.length() &&
      back.lines
      .iter()
      .zip(document.lines.iter())
      .all(p => p.0.logical_equal(p.1)),
      msg="\{name}: canonical text changes the lines",
    )
    assert_eq(@yaml.print_body(back).unwrap(), body, msg="\{name}: unstable")
    let before = @yaml.to_data_tree(document).tree.map(normalize)
    let after = @yaml.to_data_tree(back).tree.map(normalize)
    assert_eq(before, after, msg="\{name}: canonical text changes the data")
  }
}
