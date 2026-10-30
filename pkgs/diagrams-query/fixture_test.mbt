///|
/// A small file-system tree, independent of BPMN, for the generic core.
/// Kinds: dir, file, link and the extension namespace urn:x. Categories:
/// container, leaf. Fields: entry, meta (no namespace) and urn:x names.
struct FsNode {
  kind : String
  ns : String
  category : String
  field : String
  attrs : Array[(String, String)]
  text : String?
  children : Array[Int]
  parent : Int?
  depth : Int
}

///|
struct FsTree {
  nodes : Array[FsNode]
  schema : @query.Schema
}

///|
let fs_schema : @query.Schema = @query.Schema::new(
  id="test/fs",
  version=1,
  kinds=[
    @query.Name::new("", "dir"),
    @query.Name::new("", "file"),
    @query.Name::new("", "link"),
  ],
  categories=["container", "leaf"],
  fields=[@query.Name::new("", "entry"), @query.Name::new("", "meta")],
  reserved_namespaces=[""],
  open_extensions=true,
  scalar_tags=["text", "number"],
  extra_fields=["size"],
)

///|
fn FsTree::new() -> FsTree {
  { nodes: [], schema: fs_schema }
}

///|
/// Adds a node and returns its index. The root has no parent.
fn FsTree::add(
  self : FsTree,
  kind : String,
  parent? : Int,
  field? : String = "entry",
  attrs? : Array[(String, String)] = [],
  text? : String,
  ns? : String = "",
) -> Int {
  let id = self.nodes.length()
  let depth = match parent {
    Some(p) => self.nodes[p].depth + 1
    None => 0
  }
  let category = if kind == "dir" { "container" } else { "leaf" }
  self.nodes.push({
    kind,
    ns,
    category,
    field,
    attrs,
    text,
    children: [],
    parent,
    depth,
  })
  if parent is Some(p) {
    self.nodes[p].children.push(id)
  }
  id
}

///|
impl @query.QueryTree for FsTree with schema(self) {
  self.schema
}

///|
impl @query.QueryTree for FsTree with root(_self) {
  0
}

///|
impl @query.QueryTree for FsTree with node_count(self) {
  self.nodes.length()
}

///|
impl @query.QueryTree for FsTree with kind(self, node) {
  Some(@query.Name::new(self.nodes[node].ns, self.nodes[node].kind))
}

///|
impl @query.QueryTree for FsTree with category(self, node) {
  self.nodes[node].category
}

///|
impl @query.QueryTree for FsTree with children(self, node) {
  self.nodes[node].children[:]
}

///|
impl @query.QueryTree for FsTree with field(self, node) {
  match self.nodes[node].parent {
    Some(_) => Some(@query.Name::new("", self.nodes[node].field))
    None => None
  }
}

///|
impl @query.QueryTree for FsTree with attribute(self, node, name) {
  if name.namespace_uri != "" {
    return None
  }
  self.nodes[node].attrs
  .iter()
  .find_first(a => a.0 == name.local_name)
  .map(a => @query.ScalarValue::{ tag: "text", text: a.1 })
}

///|
impl @query.QueryTree for FsTree with text(self, node) {
  self.nodes[node].text
}

///|
impl @query.QueryTree for FsTree with extra(self, node, name) {
  if name == "size" {
    self.nodes[node].text.map(t => @query.ScalarValue::{
      tag: "number",
      text: t.length().to_string(),
    })
  } else {
    None
  }
}

///|
impl @query.QueryTree for FsTree with location(_self, _node) {
  None
}

///|
impl @query.QueryTree for FsTree with path(self, node) {
  let steps = []
  let mut at = node
  while self.nodes[at].parent is Some(parent) {
    let position = self.nodes[parent].children.search(at).unwrap()
    let mut index = 0
    for i in 0..<position {
      if self.nodes[self.nodes[parent].children[i]].field == self.nodes[at].field {
        index += 1
      }
    }
    steps.push(@query.QueryPathStep::{
      field: @query.Name::new("", self.nodes[at].field),
      index,
      position,
    })
    at = parent
  }
  steps.rev_in_place()
  ReadOnlyArray::from_array(steps)
}

///|
impl @query.QueryTree for FsTree with depth(self, node) {
  self.nodes[node].depth
}

///|
/// root dir 0
///   dir 1 (name=src)
///     file 2 (name=a.mbt, text "abc")
///     file 3 (name="", text "")
///     link 4 (target=a.mbt) in field meta
///   file 5 (no name)
///   dir 6 (name=docs)
///     file 7 (name=readme)
fn sample() -> FsTree {
  let t = FsTree::new()
  let root = t.add("dir", attrs=[("name", "root")])
  let src = t.add("dir", parent=root, attrs=[("name", "src")])
  t.add("file", parent=src, attrs=[("name", "a.mbt")], text="abc") |> ignore
  t.add("file", parent=src, attrs=[("name", "")], text="") |> ignore
  t.add("link", parent=src, field="meta", attrs=[("target", "a.mbt")]) |> ignore
  t.add("file", parent=root) |> ignore
  let docs = t.add("dir", parent=root, attrs=[("name", "docs")])
  t.add("file", parent=docs, attrs=[("name", "readme")]) |> ignore
  t
}

///|
fn plan(text : String) -> @query.QueryPlan {
  match @query.compile(text, fs_schema, namespaces=[("x", "urn:x")]) {
    Ok(plan) => plan
    Err(diagnostics) => abort("compile failed: \{diagnostics[0].code} \{diagnostics[0].message}")
  }
}

///|
/// One line per match: pattern index then `name=node` for each capture.
fn rows(result : @query.QueryResult) -> String {
  let lines = result.matches.map(m => {
    let captures = m.captures.map(c => "\{c.name}=\{c.node}")
    "\{m.pattern}: \{captures.iter().join(" ")}"
  })
  let outcome = match result.outcome {
    Complete => "complete"
    Stopped => "stopped"
    Failed(f) => "failed \{f.to_repr()}"
    Running => "running"
  }
  lines.iter().join("\n") + "\n" + outcome
}

///|
fn run(text : String, tree? : FsTree = sample()) -> String {
  rows(plan(text).collect(tree))
}

///|
fn codes(text : String) -> String {
  match @query.compile(text, fs_schema, namespaces=[("x", "urn:x")]) {
    Ok(_) => "ok"
    Err(diagnostics) => diagnostics.iter().map(d => d.code).join(" ")
  }
}
