///|
/// The normalized traversal text of the shared corpus.
///
/// The MoonBit functions here are the oracle. The Python tests in
/// `apps/python-native/python/tests/test_bpmn_corpus.py` write the same text
/// through the `diagrams_mbt.bpmn` facade. Both compare with the checked-in
/// files in `expected/`. `README.md` describes the format and the rules.
let model_uri : String = "http://www.omg.org/spec/BPMN/20100524/MODEL"

///|
/// `text` in double quotes, with `\`, `"`, LF, CR and TAB escaped.
fn esc(text : String) -> String {
  let buf = StringBuilder()
  buf.write_char('"')
  for c in text {
    match c {
      '\\' => buf.write_string("\\\\")
      '"' => buf.write_string("\\\"")
      '\n' => buf.write_string("\\n")
      '\r' => buf.write_string("\\r")
      '\t' => buf.write_string("\\t")
      _ => buf.write_char(c)
    }
  }
  buf.write_char('"')
  buf.to_string()
}

///|
fn opt(text : String?) -> String {
  match text {
    Some(text) => text
    None => "-"
  }
}

///|
fn name(n : @bpmn.ExpandedName) -> String {
  "{" + n.namespace_uri + "}" + n.local_name
}

///|
fn name_opt(n : @bpmn.ExpandedName?) -> String {
  match n {
    Some(n) => name(n)
    None => "-"
  }
}

///|
fn span(s : @bpmn.Span?) -> String {
  match s {
    Some(s) => "\{s.start}-\{s.end}"
    None => "-"
  }
}

///|
fn position(p : @bpmn.Position) -> String {
  "\{p.line}:\{p.column}:\{p.offset}"
}

///|
fn location(l : @bpmn.Location?) -> String {
  match l {
    Some(l) =>
      opt(l.source_id) + "@" + position(l.start) + "-" + position(l.end)
    None => "-"
  }
}

///|
fn scalar(s : @bpmn.Scalar) -> String {
  let (tag, detail) = match s {
    Text(_) => ("Text", "")
    Identifier(_) => ("Identifier", "")
    Uri(_) => ("Uri", "")
    Boolean(b) => ("Boolean", ":\{b}")
    Integer(_) => ("Integer", "")
    Number(_) => ("Number", "")
    Reference(r) => {
      let kind = match r.kind {
        Id => "Id"
        QName => "QName"
      }
      ("Reference", ":" + kind + "," + esc(r.spelling) + "," + name_opt(r.name))
    }
    Enumeration(e) => ("Enumeration", ":" + name(e.type_id().name()))
    Invalid(raw~, expected~) =>
      ("Invalid", ":" + esc(raw) + "," + name(expected))
  }
  tag + "(" + esc(s.token()) + ")" + detail
}

///|
fn scalar_opt(s : @bpmn.Scalar?) -> String {
  match s {
    Some(s) => scalar(s)
    None => "-"
  }
}

///|
fn category(c : @bpmn.NodeCategory) -> String {
  match c {
    Document => "Document"
    Definitions => "Definitions"
    Process => "Process"
    Activity => "Activity"
    Event => "Event"
    Gateway => "Gateway"
    SequenceFlow => "SequenceFlow"
    Collaboration => "Collaboration"
    Participant => "Participant"
    Lane => "Lane"
    Choreography => "Choreography"
    ChoreographyActivity => "ChoreographyActivity"
    Conversation => "Conversation"
    ConversationLink => "ConversationLink"
    DiagramInterchange => "DiagramInterchange"
    Extension => "Extension"
    Other => "Other"
    Text => "Text"
    Comment => "Comment"
    ProcessingInstruction => "ProcessingInstruction"
  }
}

///|
fn kind(k : @bpmn.Kind?) -> String {
  match k {
    None => "-"
    Some(k) => {
      let class = match k {
        Foreign(_) => "foreign"
        Unknown(_) => "unknown"
        _ => "standard"
      }
      name(k.name()) + "/" + class
    }
  }
}

///|
fn field(f : @bpmn.PathField) -> String {
  match f {
    Named(n) => name(n)
    Text => "Text"
    Comment => "Comment"
    ProcessingInstruction => "ProcessingInstruction"
    Root => "Root"
    Prolog => "Prolog"
    Epilog => "Epilog"
  }
}

///|
fn step(s : @bpmn.PathStep) -> String {
  field(s.field) + "[\{s.index}]@\{s.content_index}"
}

///|
fn steps(path : @bpmn.NodePath) -> String {
  let parts = path.steps().iter().map(step).to_array()
  if parts.is_empty() {
    "(root)"
  } else {
    parts.join("/")
  }
}

///|
fn value(v : @bpmn.NodeValue) -> String {
  match v {
    Document => "Document"
    Element(_) => "Element"
    Text(t) => "Text(" + esc(t) + ")"
    Comment(t) => "Comment(" + esc(t) + ")"
    ProcessingInstruction(target~, data~) =>
      "PI(" + esc(target) + "," + esc(data) + ")"
  }
}

///|
fn ord(node : @bpmn.NodeRef) -> Int32 {
  node.handle().ordinal
}

///|
fn lookup(result : @bpmn.NodeLookup) -> String {
  match result {
    Found(node) => "Found#\{ord(node)}"
    DocumentMismatch => "DocumentMismatch"
    InvalidHandle => "InvalidHandle"
  }
}

///|
fn diagnostic(d : @bpmn.Diagnostic) -> String {
  let severity = match d.severity {
    Error => "Error"
    Warning => "Warning"
  }
  "  diag " +
  d.code +
  " " +
  severity +
  " span=" +
  span(d.span) +
  " loc=" +
  location(d.location) +
  " msg=" +
  esc(d.message)
}

///|
/// Writes `tokens` with at most 16 per line, each line indented by two spaces.
fn tokens(out : Array[String], items : Array[String]) -> Unit {
  let mut i = 0
  while i < items.length() {
    let end = Int32::min(i + 16, items.length())
    out.push("  " + items[i:end].iter().join(" "))
    i = end
  }
}

///|
/// The control rules of the corpus. `skip_rule` skips the children of every
/// ordinal `n` with `n % 5 == 2`; `stop_at` is two thirds of the tree length.
fn skip_rule(node : @bpmn.NodeRef) -> @bpmn.Control {
  if ord(node) % 5 == 2 {
    SkipChildren
  } else {
    Continue
  }
}

///|
fn stop_at(tree : @bpmn.DocumentTree) -> Int32 {
  tree.length() * 2 / 3
}

///|
fn node_lines(
  out : Array[String],
  tree : @bpmn.DocumentTree,
  rebuilt : @bpmn.DocumentTree,
  other : @bpmn.DocumentTree,
) -> Unit {
  @bpmn.walk(tree.root(), node => {
    let parent = match node.parent() {
      Some(p) => ord(p).to_string()
      None => "-"
    }
    let step_text = match node.step() {
      Some(s) => step(s)
      None => "-"
    }
    out.push(
      "#\{ord(node)} d=\{node.depth()} " +
      category(node.category()) +
      " kind=" +
      kind(node.kind()) +
      " id=" +
      opt(node.id()) +
      " parent=" +
      parent +
      " step=" +
      step_text +
      " span=" +
      span(node.span()) +
      " loc=" +
      location(node.location()) +
      " res=" +
      opt(node.resource_id()) +
      " children=\{node.children().length()} value=" +
      value(node.value()),
    )
    if node.element() is Some(element) {
      let bindings = element.bindings.iter().map(p => p.0 + "=" + p.1).join(",")
      out.push(
        "  element kind=" +
        kind(Some(element.kind)) +
        " bindings=[" +
        bindings +
        "] value_type=" +
        name_opt(element.value_type) +
        " text_value=" +
        scalar_opt(element.text_value) +
        " content=" +
        esc(element.content),
      )
    }
    for a in node.attributes() {
      out.push(
        "  attr " +
        name_opt(a.name) +
        " raw=" +
        esc(a.raw_name) +
        " " +
        scalar(a.value) +
        " span=" +
        span(a.span) +
        " loc=" +
        location(a.location()),
      )
    }
    if node.element() is Some(_) {
      out.push(
        "  scalar id=" +
        scalar_opt(node.scalar(@bpmn.ExpandedName::new("", "id"))) +
        " name=" +
        scalar_opt(node.scalar(@bpmn.ExpandedName::new("", "name"))),
      )
    }
    let fields = node.fields()
    for f in fields {
      out.push(
        "  field " +
        field(f.field) +
        " attrs=[" +
        f.attributes.iter().map(a => a.raw_name).join(",") +
        "] children=[" +
        f.children.iter().map(c => ord(c).to_string()).join(",") +
        "]",
      )
    }
    if fields.get(0) is Some(first) {
      let again = match node.field(first.field) {
        Some(f) => f.children.iter().map(c => ord(c).to_string()).join(",")
        None => "absent"
      }
      out.push("  field? " + field(first.field) + " children=[" + again + "]")
    }
    out.push(
      "  children [" +
      node.children().iter().map(c => ord(c).to_string()).join(",") +
      "]",
    )
    out.push("  path " + steps(node.path()) + " depth=\{node.path().depth()}")
    let handle = node.handle()
    out.push(
      "  handle res=" +
      opt(handle.resource_id()) +
      " ord=\{handle.ordinal} same=" +
      lookup(tree.lookup(handle)) +
      " rebuilt=" +
      lookup(rebuilt.lookup(handle)) +
      " other=" +
      lookup(other.lookup(handle)) +
      " resolve=" +
      lookup(node.path().resolve(rebuilt)) +
      " resolve-other=" +
      lookup(node.path().resolve(other)),
    )
    Continue
  })
}

///|
fn enter_token(node : @bpmn.NodeRef) -> String {
  "+\{ord(node)}"
}

///|
fn leave_token(node : @bpmn.NodeRef) -> String {
  "-\{ord(node)}"
}

///|
priv struct ActivityVisitor {
  log : Array[String]
  prune : Bool
}

///|
impl @bpmn.Visitor for ActivityVisitor with fn visit_activity(
  self,
  activity,
  node,
) {
  self.log.push("\{ord(node)}:" + activity.element.kind.local_name())
  if self.prune && ord(node) % 2 == 0 {
    SkipChildren
  } else {
    Continue
  }
}

///|
priv struct FullVisitor {
  log : Array[String]
  stop : Int32
}

///|
fn FullVisitor::family(
  self : FullVisitor,
  family : String,
  node : @bpmn.NodeRef,
  element : @bpmn.Element?,
) -> @bpmn.Control {
  let suffix = match element {
    Some(e) => ":" + e.kind.local_name()
    None => ""
  }
  self.log.push(family + ":\{ord(node)}" + suffix)
  if ord(node) == self.stop {
    Stop
  } else {
    Continue
  }
}

///|
impl @bpmn.Visitor for FullVisitor with fn enter(self, node) {
  self.log.push(enter_token(node))
  skip_rule(node)
}

///|
impl @bpmn.Visitor for FullVisitor with fn leave(self, node) {
  self.log.push(leave_token(node))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_definitions(self, v, node) {
  self.family("definitions", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_process(self, v, node) {
  self.family("process", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_activity(self, v, node) {
  self.family("activity", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_event(self, v, node) {
  self.family("event", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_gateway(self, v, node) {
  self.family("gateway", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_sequence_flow(self, v, node) {
  self.family("sequence_flow", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_collaboration(self, v, node) {
  self.family("collaboration", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_participant(self, v, node) {
  self.family("participant", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_lane(self, v, node) {
  self.family("lane", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_choreography(self, v, node) {
  self.family("choreography", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_choreography_activity(
  self,
  v,
  node,
) {
  self.family("choreography_activity", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_conversation(self, v, node) {
  self.family("conversation", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_conversation_link(
  self,
  v,
  node,
) {
  self.family("conversation_link", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_extension(self, v, node) {
  self.family("extension", node, Some(v.element))
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_document(self, node) {
  self.family("document", node, None)
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_diagram_interchange(self, node) {
  self.family("diagram_interchange", node, node.element())
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_text(self, node) {
  self.family("text", node, None)
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_comment(self, node) {
  self.family("comment", node, None)
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_processing_instruction(
  self,
  node,
) {
  self.family("processing_instruction", node, None)
}

///|
impl @bpmn.Visitor for FullVisitor with fn visit_other(self, node) {
  self.family("other", node, node.element())
}

///|
fn count(children : ArrayView[Int32]) -> Int32 {
  1 + children.iter().fold(init=0, (sum, n) => sum + n)
}

///|
fn traversal_lines(out : Array[String], tree : @bpmn.DocumentTree) -> Unit {
  let root = tree.root()
  let stop = stop_at(tree)
  out.push("walk")
  let log = []
  @bpmn.walk(
    root,
    n => {
      log.push(enter_token(n))
      Continue
    },
    leave=n => log.push(leave_token(n)),
  )
  tokens(out, log)
  out.push("walk-skip")
  let log = []
  @bpmn.walk(
    root,
    n => {
      log.push(enter_token(n))
      skip_rule(n)
    },
    leave=n => log.push(leave_token(n)),
  )
  tokens(out, log)
  out.push("walk-stop at=\{stop}")
  let log = []
  @bpmn.walk(
    root,
    n => {
      log.push(enter_token(n))
      if ord(n) == stop {
        Stop
      } else {
        Continue
      }
    },
    leave=n => log.push(leave_token(n)),
  )
  tokens(out, log)
  let middle = tree.length() / 2
  let subtree = @bpmn.EventReader::new(root)
    .iter()
    .filter_map(e => {
      match e {
        Enter(n) if ord(n) == middle => Some(n)
        _ => None
      }
    })
    .head()
    .unwrap()
  out.push("walk-subtree at=\{middle}")
  let log = []
  @bpmn.walk(
    subtree,
    n => {
      log.push(enter_token(n))
      Continue
    },
    leave=n => log.push(leave_token(n)),
  )
  tokens(out, log)
  out.push("fold")
  let folded = @bpmn.fold(
    root,
    [],
    (acc, n) => {
      acc.push(enter_token(n))
      (acc, skip_rule(n))
    },
    leave=(acc, n) => {
      acc.push(leave_token(n))
      acc
    },
  )
  tokens(out, folded)
  out.push("  result=\{folded.length()}")
  out.push("reduce")
  let log = []
  let reduced = @bpmn.reduce(root, (n, children : ArrayView[Int32]) => {
    log.push("\{ord(n)}:\{children.length()}")
    count(children)
  })
  tokens(out, log)
  out.push("  result=\{reduced}")
  out.push("reduce-pruned-skip")
  let log = []
  let pruned = @bpmn.reduce_pruned(root, skip_rule, (
    n,
    children : ArrayView[Int32],
  ) => {
    log.push("\{ord(n)}:\{children.length()}")
    count(children)
  })
  tokens(out, log)
  out.push("  result=" + pruned.map(n => n.to_string()).unwrap_or("none"))
  out.push("reduce-pruned-stop at=\{stop}")
  let log = []
  let stopped = @bpmn.reduce_pruned(
    root,
    n => {
      log.push(enter_token(n))
      if ord(n) == stop {
        Stop
      } else {
        Continue
      }
    },
    (n, children : ArrayView[Int32]) => {
      log.push("\{ord(n)}:\{children.length()}")
      count(children)
    },
  )
  tokens(out, log)
  out.push("  result=" + stopped.map(n => n.to_string()).unwrap_or("none"))
  out.push("visitor-activity")
  let activity = ActivityVisitor::{ log: [], prune: true, }
  @bpmn.accept(root, activity)
  tokens(out, activity.log)
  out.push("visitor-full stop=\{stop}")
  let full = FullVisitor::{ log: [], stop, }
  @bpmn.accept(root, full)
  tokens(out, full.log)
  out.push("events")
  tokens(
    out,
    @bpmn.EventReader::new(root)
    .iter()
    .map(e => {
      match e {
        Enter(n) => enter_token(n)
        Leave(n) => leave_token(n)
      }
    })
    .to_array(),
  )
  out.push("events-controls stop=\{stop}")
  let reader = @bpmn.EventReader::new(root)
  let log = []
  while reader.next() is Some(event) {
    match event {
      Enter(n) => {
        log.push(enter_token(n))
        if ord(n) == stop {
          reader.stop()
        } else if skip_rule(n) == SkipChildren {
          reader.skip_children()
        }
      }
      Leave(n) => log.push(leave_token(n))
    }
  }
  log.push(if reader.next() is None { "end" } else { "more" })
  tokens(out, log)
  out.push("push stop=\{stop}")
  let log = []
  @bpmn.push_events(
    @bpmn.EventReader::new(root),
    n => {
      log.push(enter_token(n))
      if ord(n) == stop {
        Stop
      } else {
        skip_rule(n)
      }
    },
    leave=n => log.push(leave_token(n)),
  )
  tokens(out, log)
  cursor_lines(out, tree)
}

///|
fn at(cursor : @bpmn.TreeCursor) -> String {
  "\{ord(cursor.node())}:\{cursor.depth()}"
}

///|
fn cursor_lines(out : Array[String], tree : @bpmn.DocumentTree) -> Unit {
  out.push("cursor")
  let cursor = @bpmn.TreeCursor::new(tree.root())
  let log = ["@" + at(cursor)]
  let mut done = false
  while !done {
    if cursor.goto_first_child() {
      log.push("fc>" + at(cursor))
      continue
    }
    log.push("fc!")
    while !done {
      if cursor.goto_next_sibling() {
        log.push("ns>" + at(cursor))
        break
      }
      log.push("ns!")
      if cursor.goto_parent() {
        log.push("p>" + at(cursor))
      } else {
        log.push("p!")
        done = true
      }
    }
  }
  tokens(out, log)
  let mut start = tree.root()
  @bpmn.walk(tree.root(), n => {
    if start == tree.root() && n.depth() >= 2 && n.children().length() >= 2 {
      start = n
      Stop
    } else {
      Continue
    }
  })
  out.push("cursor-subtree at=\{ord(start)}")
  let cursor = @bpmn.TreeCursor::new(start)
  let log = ["@" + at(cursor)]
  for
    pair in [
      ("p", @bpmn.TreeCursor::goto_parent),
      ("ps", @bpmn.TreeCursor::goto_previous_sibling),
      ("ns", @bpmn.TreeCursor::goto_next_sibling),
      ("lc", @bpmn.TreeCursor::goto_last_child),
      ("ps", @bpmn.TreeCursor::goto_previous_sibling),
      ("ns", @bpmn.TreeCursor::goto_next_sibling),
      ("ns", @bpmn.TreeCursor::goto_next_sibling),
      ("fc", @bpmn.TreeCursor::goto_first_child),
      ("p", @bpmn.TreeCursor::goto_parent),
      ("p", @bpmn.TreeCursor::goto_parent),
      ("p", @bpmn.TreeCursor::goto_parent),
    ] {
    let (label, go) = pair
    log.push(label + (if go(cursor) { ">" } else { "!" }) + at(cursor))
  }
  tokens(out, log)
  out.push("  path " + steps(cursor.path()))
}

///|
/// Reads `source` as the corpus does: `corpus:<name>` source identifiers.
fn read_fixture(file : String, source : String) -> @bpmn.ReadResult {
  @bpmn.read(source, source_id="corpus:" + file)
}

///|
/// The normalized text of the fixture `file` (a `.bpmn` name). `files` gives
/// the content of another corpus file, for graph scripts and resources.
pub fn normalize(file : String, files : (String) -> String?) -> String {
  let out = ["fixture " + file]
  let read = read_fixture(file, files(file).unwrap())
  out.push(
    "read document=" +
    (if read.document is Some(_) { "yes" } else { "no" }) +
    " diagnostics=\{read.diagnostics.length()}",
  )
  for d in read.diagnostics {
    out.push(diagnostic(d))
  }
  guard read.document is Some(document) else { return out.join("\n") + "\n" }
  let built = @bpmn.DocumentTree::new(document)
  out.push("tree diagnostics=\{built.diagnostics.length()}")
  for d in built.diagnostics {
    out.push(diagnostic(d))
  }
  guard built.tree is Some(tree) else { return out.join("\n") + "\n" }
  let rebuilt = @bpmn.DocumentTree::new(document).tree.unwrap()
  let other = @bpmn.DocumentTree::new(document, resource_id="corpus:other").tree.unwrap()
  out.push("tree length=\{tree.length()} res=" + opt(tree.resource_id()))
  node_lines(out, tree, rebuilt, other)
  traversal_lines(out, tree)
  let stem = file.view(end_offset=file.length() - 5).to_owned()
  if files(stem + ".graph") is Some(script) {
    graph_lines(out, document, script, files)
  }
  out.join("\n") + "\n"
}

///|
/// The deep fixture: `depth` nested subprocesses around one task.
pub fn deep_source(depth : Int32) -> String {
  let buf = StringBuilder()
  buf.write_string(
    "<b:definitions xmlns:b='\{model_uri}' targetNamespace='urn:deep'><b:process id='P'>",
  )
  for _ in 0..<depth {
    buf.write_string("<b:subProcess>")
  }
  buf.write_string("<b:task id='Deep'/>")
  for _ in 0..<depth {
    buf.write_string("</b:subProcess>")
  }
  buf.write_string("</b:process></b:definitions>")
  buf.to_string()
}

///|
/// The summary of the 10,000-depth tree. Element depth limits are 20,000.
pub fn normalize_deep() -> String {
  let limits = @bpmn.Limits::new(depth=20000)
  let read = @bpmn.read(deep_source(10000), source_id="corpus:deep", limits~)
  let out = ["fixture deep", "read diagnostics=\{read.diagnostics.length()}"]
  let tree = @bpmn.DocumentTree::new(read.document.unwrap(), limits~).tree.unwrap()
  let root = tree.root()
  out.push("tree length=\{tree.length()}")
  let mut enters = 0
  let mut leaves = 0
  let mut deepest = root
  @bpmn.walk(
    root,
    n => {
      enters += 1
      if n.depth() > deepest.depth() {
        deepest = n
      }
      Continue
    },
    leave=_ => leaves += 1,
  )
  out.push(
    "walk enters=\{enters} leaves=\{leaves} deepest=#\{ord(deepest)} depth=\{deepest.depth()} id=" +
    opt(deepest.id()) +
    " path-steps=\{deepest.path().steps().length()}",
  )
  let mut enters = 0
  let mut leaves = 0
  @bpmn.walk(
    root,
    n => {
      enters += 1
      if ord(n) == 5000 {
        SkipChildren
      } else {
        Continue
      }
    },
    leave=_ => leaves += 1,
  )
  out.push("walk-skip at=5000 enters=\{enters} leaves=\{leaves}")
  let mut enters = 0
  let mut leaves = 0
  @bpmn.walk(
    root,
    n => {
      enters += 1
      if n == deepest {
        Stop
      } else {
        Continue
      }
    },
    leave=_ => leaves += 1,
  )
  out.push("walk-stop at=#\{ord(deepest)} enters=\{enters} leaves=\{leaves}")
  let folded = @bpmn.fold(root, 0, (acc, n) => (acc + n.depth(), Continue))
  out.push("fold depth-sum=\{folded}")
  out.push(
    "reduce result=\{@bpmn.reduce(root, (_, c : ArrayView[Int]) => count(c))}",
  )
  let pruned = @bpmn.reduce_pruned(
    root,
    n => if n == deepest { Stop } else { Continue },
    (_, c : ArrayView[Int32]) => count(c),
  )
  out.push(
    "reduce-pruned-stop result=" +
    pruned.map(n => n.to_string()).unwrap_or("none"),
  )
  out.push("events count=\{@bpmn.EventReader::new(root).iter().count()}")
  let visitor = ActivityVisitor::{ log: [], prune: false, }
  @bpmn.accept(root, visitor)
  out.push("visitor-activity count=\{visitor.log.length()}")
  let cursor = @bpmn.TreeCursor::new(root)
  while cursor.goto_first_child() {
    ()
  }
  let bottom = at(cursor)
  let mut ups = 0
  while cursor.goto_parent() {
    ups += 1
  }
  out.push("cursor bottom=" + bottom + " parents=\{ups}")
  out.join("\n") + "\n"
}
