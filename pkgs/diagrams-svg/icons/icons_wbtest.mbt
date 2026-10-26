///|
test "every frozen registry key paints its registered standalone vector" {
  assert_eq(catalog.length(), 523)
  for key in catalog.keys() {
    let reference = @icon_ref.Reference::new("zenuml", key)
    assert_true(known(reference))
    let definition = definition(reference, "prefix")
    let image = paint(reference, "prefix", 0.0, 0.0, 32.0)
    assert_true(definition.contains("<symbol"))
    assert_true(
      definition.contains("id=\"" + asset_id(reference, "prefix") + "\""),
    )
    assert_true(
      image.contains("href=\"#" + asset_id(reference, "prefix") + "\""),
    )
    assert_false(definition.contains("<script"))
    assert_false(definition.contains("<style"))
    assert_false(definition.contains("url(#i"))
  }
}

///|
test "namespaces case rules aliases unknowns and repeated assets stay distinct" {
  let actor = @icon_ref.Reference::new("zenuml", "Actor")
  assert_true(known(actor))
  assert_eq(
    definition(actor, "one"),
    definition(@icon_ref.Reference::new("zenuml", "actor"), "one"),
  )
  assert_true(definition(actor, "one") != definition(actor, "two"))
  assert_eq(definitions([actor, actor], "one"), definition(actor, "one"))
  assert_false(known(@icon_ref.Reference::new("architecture", "Actor")))
  let unknown = @icon_ref.Reference::new("zenuml", "<missing>")
  let output = paint(unknown, "", 0.0, 0.0, 32.0)
  assert_true(output.contains("&lt;missing&gt;"))
  assert_false(output.contains("<missing>"))
  assert_false(output.contains("href="))
  for key in ["cloud", "database", "disk", "internet", "server"] {
    assert_true(known(@icon_ref.Reference::new("architecture", key)))
  }
}

///|
test "share alike asset retains its explicit author and licence on export" {
  let vector = definition(
    @icon_ref.Reference::new("zenuml", "externalsystem"),
    "credits",
  )
  assert_true(vector.contains("Paul mackenzie"))
  assert_true(vector.contains("CC-BY-SA-4.0"))
  assert_true(
    vector.contains("https://creativecommons.org/licenses/by-sa/4.0/"),
  )
  assert_true(vector.contains("Normalization preserves geometry"))
}
