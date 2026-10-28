///|
#cfg(not(platform="windows"))
async fn gallery_fixture(name : String, entries : Array[Json]) -> String {
  let root = "_build/telescope-gallery-" + name
  if @fs.exists(root) {
    @fs.rmdir(root, recursive=true)
  }
  @fs.mkdir(root + "/site/pages", recursive=true)
  @fs.mkdir(root + "/assets", recursive=true)
  @fs.write_file(
    root + "/site/pages/index.html",
    "<h1>Fixture</h1><a href=\"/gallery/\">Gallery</a>",
  )
  @fs.write_file(
    root + "/assets/example.mmd",
    "sequenceDiagram\nA->>B: hello\n",
  )
  @fs.write_file(
    root + "/assets/preview.svg",
    @fs.read_file("assets/examples/01-light.svg").binary(),
  )
  let config : Json = {
    "schema_version": 1,
    "title": "Fixture",
    "description": "Fixture",
    "base_path": "/fixture/",
    "site_url": "https://example.org/fixture/",
    "repo_url": "https://github.com/moonrockz/diagrams.mbt",
    "source_roots": ["site/pages"],
    "packages": [],
    "api": [],
    "gallery": { "manifest": "site/gallery.json", "root": "assets" },
  }
  @fs.write_file(root + "/site/site.json", config.stringify())
  @fs.write_file(
    root + "/site/gallery.json",
    Json::object({ "schema_version": 1, "entries": Json::array(entries) }).stringify(),
  )
  root
}

///|
#cfg(not(platform="windows"))
fn example(preview~ : String = "preview.svg") -> Json {
  {
    "id": "added-example",
    "family": "sequence",
    "title": "Added fixture example",
    "status": "implemented",
    "scope": "Structural illustration only",
    "sources": [{ "path": "example.mmd", "media_type": "text/plain" }],
    "preview": { "path": preview, "media_type": "image/svg+xml" },
  }
}

///|
#cfg(not(platform="windows"))
async fn fixture_problems(root : String) -> Array[@model.Problem] {
  try {
    ignore(@host.build(root, root + "/site/site.json", root + "/built"))
    []
  } catch {
    @model.Invalid(problems) => problems
    error => raise error
  }
}

///|
#cfg(not(platform="windows"))
async test "adding a qualified example needs only the public gallery contract" {
  let root = gallery_fixture("added", [example()])
  assert_eq(fixture_problems(root), [])
  let html = @fs.read_file(root + "/built/gallery/added-example/index.html").text()
  assert_true(html.contains("Added fixture example"))
  assert_eq(
    @fs.read_file(root + "/built/gallery/artifacts/preview.svg").binary(),
    @fs.read_file(root + "/assets/preview.svg").binary(),
  )
}

///|
#cfg(not(platform="windows"))
async test "gallery inputs reject duplicate IDs missing files traversal and escaped symlinks" {
  for
    (name, entries) in [
      ("duplicate", [example(), example()]),
      ("missing", [example(preview="absent.svg")]),
      ("traversal", [example(preview="../outside.svg")]),
    ] {
    let root = gallery_fixture(name, entries)
    assert_false(fixture_problems(root).is_empty())
    assert_false(@fs.exists(root + "/built/index.html"))
  }
  let root = gallery_fixture("symlink", [example(preview="escape.svg")])
  @fs.write_file(root + "/outside.svg", "<svg/>")
  let code = @process.run("ln", [
    "-s",
    "../outside.svg",
    root + "/assets/escape.svg",
  ])
  assert_eq(code, 0)
  assert_false(fixture_problems(root).is_empty())
}
