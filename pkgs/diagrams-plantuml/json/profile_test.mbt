///|
fn u(units : Array[Int32]) -> String {
  let out = StringBuilder()
  for unit in units {
    out.write_char(unit.unsafe_to_char())
  }
  out.to_string()
}

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
/// PlantUML 1.2026.9 draws a scalar root as a one-element array and an
/// empty root container as an array with one empty string. The library
/// model keeps the root as it is; apply the upstream projection to compare.
fn upstream_projection(tree : @data_tree.DataTree, data : Json) -> Json {
  let root = tree.nodes.iter().find_first(n => n.id == tree.root).unwrap()
  match root.value {
    Object(members) | Array(members) if members.is_empty() => arr([str("")])
    Object(_) | Array(_) => data
    _ => arr([data])
  }
}

///|
test "the reader agrees with the pinned JSON reference" {
  for case in profile_cases {
    let (name, source, expected, title) = case
    let result = @json.read(@envelope.scan(source))
    match expected {
      None =>
        assert_true(
          result.document is None,
          msg="\{name} is refused upstream but read here",
        )
      Some(data) => {
        guard result.document is Some(document) else {
          fail("\{name} is accepted upstream but refused here")
        }
        let conversion = @json.to_data_tree(document)
        guard conversion.tree is Some(tree) else {
          fail("\{name} does not convert")
        }
        assert_eq(
          upstream_projection(tree, normalize(tree)),
          data,
          msg="\{name} data",
        )
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
    let result = @json.read(scan)
    assert_eq(scan.document(result.nodes).text(), source, msg=name)
    guard result.document is Some(document) else { continue }
    let body = @json.print_body(document).unwrap()
    let again = @json.read(@envelope.scan("@startjson\n" + body + "@endjson\n"))
    guard again.document is Some(back) else {
      fail("\{name}: canonical text does not read")
    }
    assert_true(
      back.value.logical_equal(document.value),
      msg="\{name}: canonical text changes the value",
    )
    assert_eq(@json.print_body(back).unwrap(), body, msg="\{name}: unstable")
  }
}

///|
test "the lone surrogate case keeps one code unit" {
  assert_eq(u([0xd800]).length(), 1)
}
