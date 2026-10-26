///|
/// The two railroad subject kinds.
pub(all) enum SubjectKind {
  Regex
  Ebnf
} derive(Eq, Debug)

///|
pub extend SubjectKind with Eq::{equal, not_equal}

///|
pub extend SubjectKind with @debug.Debug::{to_repr}

///|
/// The role of one visible term. Terms are visit targets.
pub(all) enum TermKind {
  /// A consuming literal, class, set, terminal string or special sequence.
  Consumed
  /// A grammar nonterminal. It is inspectable and never expands its definition.
  Reference(@ebnf.Resolution)
  /// A zero-width regex anchor such as `^` or `\b`.
  Anchor
  /// A zero-width regex lookaround. Its inner pattern is a constraint region.
  Assertion
  /// An empty grammar term.
  Empty
} derive(Eq, Debug)

///|
pub extend TermKind with Eq::{equal, not_equal}

///|
pub extend TermKind with @debug.Debug::{to_repr}

///|
/// One visible term occurrence. Equal labels in different positions have
/// different identities.
pub struct Term {
  id : String
  kind : TermKind
  label : String
  /// The rule identity for EBNF, or the model identity for regex.
  rule : String
  /// True inside a lookaround or an excluded term, which are not routes.
  constraint : Bool
  entry : String
  exit : String
} derive(Eq, Debug)

///|
pub extend Term with Eq::{equal, not_equal}

///|
pub extend Term with @debug.Debug::{to_repr}

///|
/// The structural role of a drawn connector.
pub(all) enum ConnectorRole {
  /// From a rule or pattern start marker to its body.
  Start
  /// From a body to its end marker.
  End
  /// Between two adjacent terms of a sequence.
  Gap
  /// From a choice junction into alternative `n`.
  Split(Int)
  /// From alternative `n` to the choice junction.
  Join(Int)
  /// Into a group, optional or repeated term, or a constraint region.
  Enter
  /// Out of a group, optional or repeated term, or a constraint region.
  Leave
  /// The skip path of an optional or zero-or-more term.
  Bypass
  /// The loop path of a repeated term, from its exit back to its entry.
  Return
  /// The direct path of a rule that has no body.
  Empty
} derive(Eq, Debug)

///|
pub extend ConnectorRole with Eq::{equal, not_equal}

///|
pub extend ConnectorRole with @debug.Debug::{to_repr}

///|
pub fn ConnectorRole::name(self : ConnectorRole) -> String {
  match self {
    Start => "start"
    End => "end"
    Gap => "gap"
    Split(n) => "split-\{n}"
    Join(n) => "join-\{n}"
    Enter => "enter"
    Leave => "leave"
    Bypass => "bypass"
    Return => "return"
    Empty => "empty"
  }
}

///|
/// One drawn connector between two points, in its semantic direction.
pub struct Connector {
  id : String
  /// The node, rule or model identity that owns this connector.
  owner : String
  role : ConnectorRole
  from : String
  to : String
  rule : String
  constraint : Bool
} derive(Eq, Debug)

///|
pub extend Connector with Eq::{equal, not_equal}

///|
pub extend Connector with @debug.Debug::{to_repr}

///|
/// One rule, or the single pattern of a regex, with its boundary points.
pub struct Track {
  id : String
  name : String
  start : String
  end : String
} derive(Eq, Debug)

///|
pub extend Track with Eq::{equal, not_equal}

///|
pub extend Track with @debug.Debug::{to_repr}

///|
/// The semantic railroad topology of a model: visible terms, points and
/// drawn connectors. External engines map their events to these identities
/// before any SVG or animation exists.
pub struct Topology {
  kind : SubjectKind
  model_id : String
  fingerprint : String
  tracks : ReadOnlyArray[Track]
  terms : ReadOnlyArray[Term]
  connectors : ReadOnlyArray[Connector]
  /// A deterministic, finite drawing walk over every term and connector, in
  /// source order. It illustrates structure; it is not a feasible match.
  walk : ReadOnlyArray[Step]
  priv term_index : Map[String, Int]
  priv connector_index : Map[String, Int]
  priv entries : Map[String, String]
  priv exits : Map[String, String]
  priv outgoing : Map[String, Array[Int]]
  priv points : Map[String, Bool]
}

///|
pub struct TopologyResult {
  topology : Topology?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
}

///|
pub fn Topology::term(self : Topology, id : String) -> Term? {
  self.term_index.get(id).map(i => self.terms[i])
}

///|
pub fn Topology::connector(self : Topology, id : String) -> Connector? {
  self.connector_index.get(id).map(i => self.connectors[i])
}

///|
/// The entry point of a node, rule or model identity.
pub fn Topology::entry(self : Topology, id : String) -> String? {
  self.entries.get(id)
}

///|
/// The exit point of a node, rule or model identity.
pub fn Topology::exit(self : Topology, id : String) -> String? {
  self.exits.get(id)
}

///|
pub fn Topology::has_point(self : Topology, point : String) -> Bool {
  self.points.contains(point)
}

///|
/// The connectors that leave `point`, in drawing order.
pub fn Topology::connectors_from(
  self : Topology,
  point : String,
) -> Array[Connector] {
  self.outgoing.get(point).unwrap_or([]).map(i => self.connectors[i])
}

///|
/// The connector with `role` that `owner` draws, if any.
pub fn Topology::connector_of(
  self : Topology,
  owner : String,
  role : ConnectorRole,
) -> Connector? {
  self.connector_index
  .get(connector_id(owner, role))
  .map(i => self.connectors[i])
}

///|
/// The connector between two points, if one is drawn.
pub fn Topology::connector_between(
  self : Topology,
  from : String,
  to : String,
) -> Connector? {
  for i in self.outgoing.get(from).unwrap_or([]) {
    if self.connectors[i].to == to {
      return Some(self.connectors[i])
    }
  }
  None
}

///|
fn length_prefixed(value : String) -> String {
  "\{value.length()}:\{value}"
}

///|
/// The stable identity of a point. Identities are length-prefixed, so a
/// node identity that contains `:` cannot collide with another point.
pub fn point_id(owner : String, side : String) -> String {
  "p" + length_prefixed(owner) + ":" + side
}

///|
/// The stable identity of the connector that `owner` draws with `role`.
pub fn connector_id(owner : String, role : ConnectorRole) -> String {
  "c" + length_prefixed(owner) + ":" + role.name()
}

///|
priv struct Fingerprint {
  mut hash : UInt64
}

///|
fn Fingerprint::text(self : Fingerprint, value : String) -> Unit {
  let value = length_prefixed(value)
  for i in 0..<value.length() {
    self.hash = (self.hash ^ value.code_unit_at(i).to_int().to_uint64()) *
      1099511628211
  }
}

///|
fn Fingerprint::finish(self : Fingerprint) -> String {
  self.hash.to_string(radix=16)
}

///|
fn regex_fingerprint(model : @regex.Regex) -> String {
  let f = Fingerprint::{ hash: 14695981039346656037 }
  f.text("regex")
  f.text(model.id)
  f.text(model.root)
  for node in model.nodes {
    f.text(node.id)
    f.text(node.label())
    let tag = match node.kind {
      Literal(_) => "literal"
      Class(_) => "class"
      Set(negated, _) => if negated { "nset" } else { "set" }
      Anchor(_) => "anchor"
      Sequence(_) => "sequence"
      Choice(_) => "choice"
      Group(Capturing, _) => "group"
      Group(NonCapturing, _) => "ncgroup"
      Group(Named(_), _) => "named"
      Repeat(bounds, _) =>
        "repeat:\{bounds.min}:\{bounds.max.map(m => m.to_string()).unwrap_or("*")}:\{bounds.reluctant}"
      Assertion(_, _, _) => "assertion"
    }
    f.text(tag)
    for child in node.children() {
      f.text(child)
    }
  }
  f.finish()
}

///|
fn ebnf_fingerprint(grammar : @ebnf.Grammar) -> String {
  let f = Fingerprint::{ hash: 14695981039346656037 }
  f.text("ebnf")
  f.text(grammar.id)
  for item in grammar.items {
    match item {
      Rule(rule) => {
        f.text("rule")
        f.text(rule.id)
        f.text(rule.name)
        f.text(rule.body.unwrap_or(""))
      }
      Note(id, _) => {
        f.text("note")
        f.text(id)
      }
    }
  }
  for node in grammar.nodes {
    f.text(node.id)
    f.text(node.label())
    let tag = match node.kind {
      Terminal(_, Double) => "terminal\""
      Terminal(_, Single) => "terminal'"
      Reference(_, target) => "reference:" + target.unwrap_or("")
      Special(_) => "special"
      Empty => "empty"
      Sequence(_) => "sequence"
      Choice(_) => "choice"
      Optional(_) => "optional"
      ZeroOrMore(_) => "zero"
      OneOrMore(_) => "one"
      Count(_, _) => "count"
      Exclusion(_, _) => "exclusion"
    }
    f.text(tag)
    for child in node.children() {
      f.text(child)
    }
  }
  f.finish()
}

///|
/// The fingerprint of the structure of a subject. A trace for an edited or
/// different model has a different fingerprint, even with equal identities.
pub fn Subject::fingerprint(self : Subject) -> String {
  match self {
    Regex(model) => regex_fingerprint(model)
    Ebnf(grammar, _) => ebnf_fingerprint(grammar)
  }
}

///|
/// The structural shape of one composite node, independent of the model kind.
priv enum Shape {
  Leaf(TermKind)
  /// A lookaround term with its inner constraint region.
  Assertion(String)
  Sequence(ReadOnlyArray[String])
  Choice(ReadOnlyArray[String])
  /// A wrapper with a bypass and/or a return path.
  Wrap(String, Bool, Bool)
  /// An exclusion: the left term stays on the route.
  Exclude(String, String)
}

///|
priv enum Task {
  Emit(String)
  Item(Step)
}

///|
priv struct Builder {
  walk : Array[Step]
  terms : Array[Term]
  connectors : Array[Connector]
  term_index : Map[String, Int]
  connector_index : Map[String, Int]
  entries : Map[String, String]
  exits : Map[String, String]
  outgoing : Map[String, Array[Int]]
  points : Map[String, Bool]
  diagnostics : Array[@diagrams.Diagnostic]
  limit : Int
  mut work : Int
}

///|
fn Builder::charge(self : Builder, units : Int) -> Bool {
  if units > self.limit - self.work {
    if self.diagnostics.is_empty() {
      self.diagnostics.push(
        @diagrams.Diagnostic::error(
          "railroad/topology-limit", "Railroad topology work limit exceeded",
        ),
      )
    }
    return false
  }
  self.work += units
  true
}

///|
fn Builder::connect(
  self : Builder,
  owner : String,
  role : ConnectorRole,
  from : String,
  to : String,
  rule : String,
  constraint : Bool,
) -> Unit {
  let id = connector_id(owner, role)
  self.connector_index[id] = self.connectors.length()
  match self.outgoing.get(from) {
    Some(list) => list.push(self.connectors.length())
    None => self.outgoing[from] = [self.connectors.length()]
  }
  self.points[from] = true
  self.points[to] = true
  self.connectors.push({ id, owner, role, from, to, rule, constraint })
}

///|
/// Build the shared topology for one track. `shape` describes each node, and
/// `order` lists the track's nodes in pre-order.
fn Builder::track(
  self : Builder,
  rule : String,
  body : String?,
  start : String,
  end : String,
  order : ArrayView[String],
  shape : (String) -> Shape,
  label : (String) -> String,
) -> Bool {
  self.points[start] = true
  self.points[end] = true
  guard body is Some(body) else {
    self.connect(rule, Empty, start, end, rule, false)
    self.walk.push(Traverse(connector_id(rule, Empty), false))
    return true
  }
  let shapes : Map[String, Shape] = Map([])
  let constraint : Map[String, Bool] = Map([(body, false)])
  for id in order {
    if !self.charge(1) {
      return false
    }
    let s = shape(id)
    shapes[id] = s
    let inside = constraint.get(id).unwrap_or(false)
    match s {
      Sequence(items) | Choice(items) =>
        for item in items {
          constraint[item] = inside
        }
      Wrap(child, _, _) => constraint[child] = inside
      Assertion(child) => constraint[child] = true
      Exclude(left, excluded) => {
        constraint[left] = inside
        constraint[excluded] = true
      }
      Leaf(_) => ()
    }
  }
  // Canonical points: a sequence and an exclusion share the points of their
  // first and last route terms, so adjacent connectors meet without a gap.
  for i in 0..<order.length() {
    let id = order[order.length() - 1 - i]
    let (entry, exit) = match shapes[id] {
      Sequence(items) =>
        (self.entries[items[0]], self.exits[items[items.length() - 1]])
      Exclude(left, _) => (self.entries[left], self.exits[left])
      _ => (point_id(id, "in"), point_id(id, "out"))
    }
    self.entries[id] = entry
    self.exits[id] = exit
  }
  self.connect(rule, Start, start, self.entries[body], rule, false)
  for id in order {
    if !self.charge(2) {
      return false
    }
    let inside = constraint[id]
    match shapes[id] {
      Leaf(kind) => {
        self.term_index[id] = self.terms.length()
        self.points[self.entries[id]] = true
        self.points[self.exits[id]] = true
        self.terms.push({
          id,
          kind,
          label: label(id),
          rule,
          constraint: inside,
          entry: self.entries[id],
          exit: self.exits[id],
        })
      }
      Assertion(_) => {
        self.term_index[id] = self.terms.length()
        self.points[self.entries[id]] = true
        self.points[self.exits[id]] = true
        self.terms.push({
          id,
          kind: Assertion,
          label: label(id),
          rule,
          constraint: inside,
          entry: self.entries[id],
          exit: self.exits[id],
        })
      }
      Sequence(items) =>
        for k in 1..<items.length() {
          self.connect(
            items[k],
            Gap,
            self.exits[items[k - 1]],
            self.entries[items[k]],
            rule,
            inside,
          )
        }
      Choice(items) =>
        for k, item in items {
          self.connect(id, Split(k), self.entries[id], self.entries[item], rule, inside)
          self.connect(id, Join(k), self.exits[item], self.exits[id], rule, inside)
        }
      Wrap(child, bypass, back) => {
        self.connect(id, Enter, self.entries[id], self.entries[child], rule, inside)
        self.connect(id, Leave, self.exits[child], self.exits[id], rule, inside)
        if bypass {
          self.connect(id, Bypass, self.entries[id], self.exits[id], rule, inside)
        }
        if back {
          self.connect(id, Return, self.exits[child], self.entries[child], rule, inside)
        }
      }
      Exclude(_, _) => ()
    }
  }
  // Constraint regions are drawn inside their owner, without a route link.
  for id in order {
    match shapes[id] {
      Assertion(child) => {
        let a = point_id(id, "inner-in")
        let b = point_id(id, "inner-out")
        self.connect(id, Enter, a, self.entries[child], rule, true)
        self.connect(id, Leave, self.exits[child], b, rule, true)
      }
      Exclude(_, excluded) => {
        let a = point_id(id, "except-in")
        let b = point_id(id, "except-out")
        self.connect(id, Enter, a, self.entries[excluded], rule, true)
        self.connect(id, Leave, self.exits[excluded], b, rule, true)
      }
      _ => ()
    }
  }
  self.connect(rule, End, self.exits[body], end, rule, false)
  let tasks : Array[Task] = [
    Item(Traverse(connector_id(rule, End), false)),
    Emit(body),
    Item(Traverse(connector_id(rule, Start), false)),
  ]
  fn go(owner : String, role : ConnectorRole) -> Task {
    Item(Traverse(connector_id(owner, role), false))
  }
  while tasks.pop() is Some(task) {
    if !self.charge(1) {
      return false
    }
    match task {
      Item(step) => self.walk.push(step)
      Emit(id) => {
        let next : Array[Task] = match shapes[id] {
          Leaf(_) => [Item(Visit(id, None))]
          Assertion(child) =>
            [Item(Visit(id, None)), go(id, Enter), Emit(child), go(id, Leave)]
          Sequence(items) => {
            let list = [Emit(items[0])]
            for k in 1..<items.length() {
              list.push(go(items[k], Gap))
              list.push(Emit(items[k]))
            }
            list
          }
          Choice(items) => {
            let list = []
            for k, item in items {
              list.push(go(id, Split(k)))
              list.push(Emit(item))
              list.push(go(id, Join(k)))
            }
            list
          }
          Wrap(child, bypass, back) => {
            let list = [go(id, Enter), Emit(child), go(id, Leave)]
            if bypass {
              list.push(go(id, Bypass))
            }
            if back {
              list.push(go(id, Return))
            }
            list
          }
          Exclude(left, excluded) =>
            [Emit(left), go(id, Enter), Emit(excluded), go(id, Leave)]
        }
        for i in 0..<next.length() {
          tasks.push(next[next.length() - 1 - i])
        }
      }
    }
  }
  true
}

///|
fn regex_shape(index : @regex.Index, id : String) -> Shape {
  let node = index.node(id).unwrap()
  match node.kind {
    Literal(_) | Class(_) | Set(_, _) => Leaf(Consumed)
    Anchor(_) => Leaf(Anchor)
    Sequence(items) => Sequence(items)
    Choice(items) => Choice(items)
    Group(_, child) => Wrap(child, false, false)
    Repeat(bounds, child) =>
      Wrap(
        child,
        bounds.min == 0,
        match bounds.max {
          None => true
          Some(max) => max > 1
        },
      )
    Assertion(_, _, child) => Assertion(child)
  }
}

///|
fn ebnf_shape(index : @ebnf.Index, id : String) -> Shape {
  let node = index.node(id).unwrap()
  match node.kind {
    Terminal(_, _) | Special(_) => Leaf(Consumed)
    Reference(_, _) => Leaf(Reference(index.resolution(id).unwrap_or(Unresolved)))
    Empty => Leaf(Empty)
    Sequence(items) => Sequence(items)
    Choice(items) => Choice(items)
    Optional(child) => Wrap(child, true, false)
    ZeroOrMore(child) => Wrap(child, true, true)
    OneOrMore(child) => Wrap(child, false, true)
    Count(count, child) => Wrap(child, count == "0", count != "1" && count != "0")
    Exclusion(left, excluded) => Exclude(left, excluded)
  }
}

///|
fn new_builder(limit : Int) -> Builder {
  {
    walk: [],
    terms: [],
    connectors: [],
    term_index: Map([]),
    connector_index: Map([]),
    entries: Map([]),
    exits: Map([]),
    outgoing: Map([]),
    points: Map([]),
    diagnostics: [],
    limit,
    work: 0,
  }
}

///|
fn Builder::finish(
  self : Builder,
  kind : SubjectKind,
  model_id : String,
  fingerprint : String,
  tracks : Array[Track],
) -> TopologyResult {
  if !self.diagnostics.is_empty() {
    return {
      topology: None,
      diagnostics: ReadOnlyArray::from_array(self.diagnostics),
    }
  }
  {
    topology: Some({
      kind,
      model_id,
      fingerprint,
      tracks: ReadOnlyArray::from_array(tracks),
      terms: ReadOnlyArray::from_array(self.terms),
      connectors: ReadOnlyArray::from_array(self.connectors),
      walk: ReadOnlyArray::from_array(self.walk),
      term_index: self.term_index,
      connector_index: self.connector_index,
      entries: self.entries,
      exits: self.exits,
      outgoing: self.outgoing,
      points: self.points,
    }),
    diagnostics: [],
  }
}

///|
/// Build the topology of a regex model. The pattern is one track whose
/// identity is the model identity.
pub fn Topology::regex(
  model : @regex.Regex,
  limits? : @regex.Limits = @regex.Limits::new(),
) -> TopologyResult {
  let indexed = @regex.Index::build(model, limits~)
  guard indexed.index is Some(index) else {
    return { topology: None, diagnostics: indexed.diagnostics }
  }
  let b = new_builder(limits.work)
  let start = point_id(model.id, "start")
  let end = point_id(model.id, "end")
  b.entries[model.id] = start
  b.exits[model.id] = end
  ignore(
    b.track(
      model.id,
      Some(model.root),
      start,
      end,
      index.order[:],
      id => regex_shape(index, id),
      id => index.node(id).unwrap().label(),
    ),
  )
  b.finish(Regex, model.id, regex_fingerprint(model), [
    { id: model.id, name: model.title.unwrap_or(model.id), start, end },
  ])
}

///|
/// Build the topology of a grammar. Each rule is one track. References are
/// terms; no connector joins two rules.
pub fn Topology::ebnf(
  grammar : @ebnf.Grammar,
  limits? : @ebnf.Limits = @ebnf.Limits::new(),
) -> TopologyResult {
  let indexed = @ebnf.Index::build(grammar, limits~)
  guard indexed.index is Some(index) else {
    return { topology: None, diagnostics: indexed.diagnostics }
  }
  let b = new_builder(limits.work)
  let tracks = []
  let mut cursor = 0
  for rule in grammar.rules() {
    let start = point_id(rule.id, "start")
    let end = point_id(rule.id, "end")
    b.entries[rule.id] = start
    b.exits[rule.id] = end
    tracks.push({ id: rule.id, name: rule.name, start, end })
    let order = []
    // The index lists rule bodies in rule order.
    if rule.body is Some(_) {
      while cursor < index.order.length() &&
        index.owner(index.order[cursor]) == Some(rule.id) {
        order.push(index.order[cursor])
        cursor += 1
      }
    }
    if !b.track(
        rule.id,
        rule.body,
        start,
        end,
        order,
        id => ebnf_shape(index, id),
        id => index.node(id).unwrap().label(),
      ) {
      break
    }
  }
  b.finish(Ebnf, grammar.id, ebnf_fingerprint(grammar), tracks)
}
