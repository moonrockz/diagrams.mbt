///|
/// A captured node with its projected values. `node` is the adapter node of
/// the cursor's tree, so a capture is always qualified by that tree.
pub struct CapturedNode {
  name : String
  node : Int
  values : ReadOnlyArray[Projected]
} derive(Eq, Debug)

///|
pub extend CapturedNode with Eq::{equal, not_equal}

///|
pub extend CapturedNode with @debug.Debug::{to_repr}

///|
/// One successful match: the source pattern index and the bound captures in
/// source order of their capture sites.
pub struct QueryMatch {
  pattern : Int
  captures : ReadOnlyArray[CapturedNode]
} derive(Eq, Debug)

///|
pub extend QueryMatch with Eq::{equal, not_equal}

///|
pub extend QueryMatch with @debug.Debug::{to_repr}

///|
/// The result of one batch request. `Rows` is data and never claims
/// completion; the next request gives the terminal state.
pub(all) enum QueryBatch {
  Rows(ReadOnlyArray[QueryMatch])
  Complete
  Stopped
  Failed(QueryFailure)
} derive(Eq, Debug)

///|
pub extend QueryBatch with Eq::{equal, not_equal}

///|
pub extend QueryBatch with @debug.Debug::{to_repr}

///|
pub(all) enum CursorState {
  Running
  Complete
  Stopped
  Failed(QueryFailure)
} derive(Eq, Debug)

///|
pub extend CursorState with Eq::{equal, not_equal}

///|
pub extend CursorState with @debug.Debug::{to_repr}

///|
priv enum Goal {
  GMatch(Int, Int)
  GParts(Int, Int, Int, Int)
}

///|
priv enum Goals {
  Done
  Cons(Goal, Goals)
}

///|
priv enum Binds {
  BNil
  BCons(Int, Int, Binds)
}

///|
priv struct Choice {
  alt : Bool
  pnode : Int
  node : Int
  part : Int
  mut next : Int
  cont : Goals
  binds : Binds
}

///|
priv enum Step {
  Emit
  Exhausted
  Fail(QueryFailure)
}

///|
/// An execution of a plan over one tree. Cursors are independent: each has
/// its own position and cumulative budgets. Matching uses explicit heap
/// stacks, so deep trees do not use the host stack.
pub struct QueryCursor[T] {
  priv plan : QueryPlan
  priv tree : T
  priv projection : Projection
  priv limits : ExecutionLimits
  priv mut state : CursorState
  priv roots : Array[Int]
  priv mut candidate : Int
  priv mut pattern : Int
  priv mut goals : Goals?
  priv mut binds : Binds
  priv choices : Array[Choice]
  priv mut work : Int
  priv mut results : Int
  priv mut output : Int
}

///|
pub impl[T] @debug.Debug for QueryCursor[T] with to_repr(self) {
  @debug.Repr::Repr(("QueryCursor", self.state, self.results))
}

///|
pub extend QueryCursor with @debug.Debug::{to_repr}

///|
/// Starts an execution of the plan below `root` (the tree root by default),
/// including `root` itself. An incompatible schema, an invalid root or invalid
/// limits give a cursor that is already failed; the tree is not searched.
pub fn[T : QueryTree] QueryPlan::execute(
  self : QueryPlan,
  tree : T,
  root? : Int,
  projection? : Projection,
  limits? : ExecutionLimits = ExecutionLimits::new(),
) -> QueryCursor[T] {
  let schema = tree.schema()
  let projection = projection.unwrap_or(Projection::identity(schema))
  let root = root.unwrap_or(tree.root())
  let state = if self.schema_id != schema.id ||
    self.schema_version != schema.version {
    CursorState::Failed(
      IncompatibleSchema(
        expected="\{self.schema_id}@\{self.schema_version}",
        actual="\{schema.id}@\{schema.version}",
      ),
    )
  } else if projection.schema_id != schema.id ||
    projection.schema_version != schema.version {
    CursorState::Failed(
      IncompatibleSchema(
        expected="\{projection.schema_id}@\{projection.schema_version}",
        actual="\{schema.id}@\{schema.version}",
      ),
    )
  } else if !limits.valid() {
    Failed(InvalidLimits)
  } else if root < 0 || root >= tree.node_count() {
    Failed(InvalidRoot)
  } else {
    Running
  }
  {
    plan: self,
    tree,
    projection,
    limits,
    state,
    roots: if state is Running { [root] } else { [] },
    candidate: -1,
    pattern: 0,
    goals: None,
    binds: BNil,
    choices: [],
    work: 0,
    results: 0,
    output: 0,
  }
}

///|
pub fn[T] QueryCursor::state(self : QueryCursor[T]) -> CursorState {
  self.state
}

///|
/// The work units used so far.
pub fn[T] QueryCursor::work(self : QueryCursor[T]) -> Int {
  self.work
}

///|
/// The matches delivered so far.
pub fn[T] QueryCursor::delivered(self : QueryCursor[T]) -> Int {
  self.results
}

///|
/// Stops a running cursor. A stopped cursor does not claim completion.
pub fn[T] QueryCursor::stop(self : QueryCursor[T]) -> Unit {
  if self.state is Running {
    self.state = Stopped
  }
  self.release()
}

///|
/// Releases the cursor's search state. Closing is idempotent; a running
/// cursor becomes stopped.
pub fn[T] QueryCursor::close(self : QueryCursor[T]) -> Unit {
  self.stop()
}

///|
fn[T] QueryCursor::release(self : QueryCursor[T]) -> Unit {
  self.roots.clear()
  self.choices.clear()
  self.goals = None
  self.binds = BNil
}

///|
fn[T] QueryCursor::spend(self : QueryCursor[T]) -> Bool {
  if self.work >= self.limits.work {
    return false
  }
  self.work += 1
  true
}

///|
fn bind(sites : Array[Int], node : Int, binds : Binds) -> Binds {
  let mut result = binds
  for site in sites {
    result = BCons(site, node, result)
  }
  result
}

///|
fn[T : QueryTree] select(tree : T, sel : CSel, node : Int) -> Bool {
  match sel {
    CAny => true
    CKind(name) => tree.kind(node) == Some(name)
    CCategory(category) => tree.category(node) == category
  }
}

///|
/// Takes the next alternative of the newest choice point. Returns `Exhausted`
/// when no choice point is left.
fn[T : QueryTree] QueryCursor::backtrack(self : QueryCursor[T]) -> Step? {
  while self.choices.last() is Some(top) {
    let node = self.plan.nodes[top.pnode]
    if top.alt {
      if top.next < node.branches.length() {
        let branch = node.branches[top.next]
        top.next += 1
        self.goals = Some(Cons(GMatch(branch, top.node), top.cont))
        self.binds = top.binds
        return None
      }
    } else {
      let children = self.tree.children(top.node)
      let (field, pattern) = match node.parts[top.part] {
        CChild(pattern) => (None, pattern)
        CField(field, pattern) => (Some(field), pattern)
        CAbsent(_) => abort("absent parts are not choice points")
      }
      while top.next < children.length() {
        if !self.spend() {
          return Some(Fail(Limit(Work)))
        }
        let position = top.next
        top.next += 1
        let child = children[position]
        if field is Some(name) && self.tree.field(child) != Some(name) {
          continue
        }
        self.goals = Some(
          Cons(
            GMatch(pattern, child),
            Cons(GParts(top.pnode, top.node, top.part + 1, position + 1), top.cont),
          ),
        )
        self.binds = top.binds
        return None
      }
    }
    self.choices.pop() |> ignore
  }
  Some(Exhausted)
}

///|
fn[T] QueryCursor::push_choice(
  self : QueryCursor[T],
  choice : Choice,
) -> Step? {
  if self.choices.length() >= self.limits.pending {
    return Some(Fail(Limit(Pending)))
  }
  self.choices.push(choice)
  self.goals = None
  None
}

///|
/// Runs the matcher of the current candidate and pattern until it finds a
/// match or exhausts its choices.
fn[T : QueryTree] QueryCursor::advance(self : QueryCursor[T]) -> Step {
  while true {
    guard self.goals is Some(goals) else {
      match self.backtrack() {
        Some(step) => return step
        None => continue
      }
    }
    match goals {
      Done => {
        self.goals = None
        return Emit
      }
      Cons(goal, rest) => {
        if !self.spend() {
          return Fail(Limit(Work))
        }
        match goal {
          GMatch(p, n) => {
            let node = self.plan.nodes[p]
            if node.alternation {
              let choice = Choice::{
                alt: true,
                pnode: p,
                node: n,
                part: 0,
                next: 0,
                cont: rest,
                binds: bind(node.sites, n, self.binds),
              }
              if self.push_choice(choice) is Some(step) {
                return step
              }
            } else if !select(self.tree, node.sel, n) {
              self.goals = None
              if self.backtrack() is Some(step) {
                return step
              }
            } else {
              self.binds = bind(node.sites, n, self.binds)
              self.goals = Some(Cons(GParts(p, n, 0, 0), rest))
            }
          }
          GParts(p, n, k, min) => {
            let node = self.plan.nodes[p]
            if k == node.parts.length() {
              self.goals = Some(rest)
              continue
            }
            match node.parts[k] {
              CAbsent(field) => {
                let mut present = false
                for child in self.tree.children(n) {
                  if !self.spend() {
                    return Fail(Limit(Work))
                  }
                  if self.tree.field(child) == Some(field) {
                    present = true
                    break
                  }
                }
                if present {
                  self.goals = None
                  if self.backtrack() is Some(step) {
                    return step
                  }
                } else {
                  self.goals = Some(Cons(GParts(p, n, k + 1, min), rest))
                }
              }
              _ => {
                let choice = Choice::{
                  alt: false,
                  pnode: p,
                  node: n,
                  part: k,
                  next: min,
                  cont: rest,
                  binds: self.binds,
                }
                if self.push_choice(choice) is Some(step) {
                  return step
                }
              }
            }
          }
        }
      }
    }
  }
  Exhausted
}

///|
fn binding(binds : Binds, names : ReadOnlyArray[String], name : String) -> Int? {
  let mut at = binds
  while at is BCons(site, node, rest) {
    if names[site] == name {
      return Some(node)
    }
    at = rest
  }
  None
}

///|
fn[T : QueryTree] QueryCursor::accepts(
  self : QueryCursor[T],
  rule : CRule,
) -> Bool? {
  for predicate in rule.predicates {
    if !self.spend() {
      return None
    }
    guard binding(self.binds, self.plan.capture_names, predicate.capture)
      is Some(node) else {
      return Some(false)
    }
    let ok = match predicate.kind {
      HasAttr => self.tree.attribute(node, predicate.attribute) is Some(_)
      MissingAttr => self.tree.attribute(node, predicate.attribute) is None
      AttrEq =>
        self.tree.attribute(node, predicate.attribute) is Some(value) &&
        value.text == predicate.values[0]
      AttrNotEq =>
        self.tree.attribute(node, predicate.attribute) is Some(value) &&
        value.text != predicate.values[0]
      AttrIn =>
        self.tree.attribute(node, predicate.attribute) is Some(value) &&
        predicate.values.contains(value.text)
      TextEq => self.tree.text(node) == Some(predicate.values[0])
    }
    if !ok {
      return Some(false)
    }
  }
  Some(true)
}

///|
fn[T : QueryTree] QueryCursor::row(
  self : QueryCursor[T],
) -> Result[QueryMatch, QueryFailure] {
  let bound : Array[(Int, Int)] = []
  let mut at = self.binds
  while at is BCons(site, node, rest) {
    bound.push((site, node))
    at = rest
  }
  bound.sort_by_key(b => b.0)
  let captures = []
  for b in bound {
    let values = []
    for field in self.projection.resolved {
      let value = project(self.tree, b.1, field)
      let units = value.units()
      if units > self.limits.output_units - self.output {
        return Err(Limit(Output))
      }
      self.output += units
      values.push(value)
    }
    captures.push(CapturedNode::{
      name: self.plan.capture_names[b.0],
      node: b.1,
      values: ReadOnlyArray::from_array(values),
    })
  }
  Ok({ pattern: self.pattern, captures: ReadOnlyArray::from_array(captures) })
}

///|
/// Finds the next match, or sets a terminal state and returns `None`.
fn[T : QueryTree] QueryCursor::next_match(self : QueryCursor[T]) -> QueryMatch? {
  while self.state is Running {
    if self.candidate < 0 {
      guard self.roots.pop() is Some(node) else {
        self.state = Complete
        self.release()
        return None
      }
      if !self.spend() {
        self.fail(Limit(Work))
        return None
      }
      let children = self.tree.children(node)
      for i = children.length() - 1; i >= 0; i = i - 1 {
        self.roots.push(children[i])
      }
      self.candidate = node
      self.pattern = 0
      self.start_pattern()
    }
    match self.advance() {
      Emit => {
        let rule = self.plan.rules[self.pattern]
        match self.accepts(rule) {
          None => {
            self.fail(Limit(Work))
            return None
          }
          Some(false) => continue
          Some(true) => ()
        }
        if self.results >= self.limits.results {
          self.fail(Limit(Results))
          return None
        }
        match self.row() {
          Ok(row) => {
            self.results += 1
            return Some(row)
          }
          Err(failure) => {
            self.fail(failure)
            return None
          }
        }
      }
      Exhausted => {
        self.pattern += 1
        if self.pattern < self.plan.rules.length() {
          self.start_pattern()
        } else {
          self.candidate = -1
        }
      }
      Fail(failure) => {
        self.fail(failure)
        return None
      }
    }
  }
  None
}

///|
fn[T] QueryCursor::start_pattern(self : QueryCursor[T]) -> Unit {
  self.choices.clear()
  self.binds = BNil
  self.goals = Some(
    Cons(GMatch(self.plan.rules[self.pattern].root, self.candidate), Done),
  )
}

///|
fn[T] QueryCursor::fail(self : QueryCursor[T], failure : QueryFailure) -> Unit {
  self.state = Failed(failure)
  self.release()
}

///|
/// Returns up to `max` matches (at least one is requested when `max` is
/// smaller). When no match is left it returns the terminal state instead:
/// `Complete`, `Stopped` or `Failed`. A terminal state found after some rows
/// is returned by the next request, so `Rows` never implies completion.
pub fn[T : QueryTree] QueryCursor::next_batch(
  self : QueryCursor[T],
  max : Int,
) -> QueryBatch {
  let rows = []
  let limit = if max < 1 { 1 } else { max }
  while rows.length() < limit {
    match self.next_match() {
      Some(row) => rows.push(row)
      None => break
    }
  }
  if !rows.is_empty() {
    return Rows(ReadOnlyArray::from_array(rows))
  }
  match self.state {
    Running | Complete => Complete
    Stopped => Stopped
    Failed(failure) => Failed(failure)
  }
}

///|
/// All matches of an execution and its terminal state.
pub struct QueryResult {
  matches : ReadOnlyArray[QueryMatch]
  outcome : CursorState
} derive(Eq, Debug)

///|
pub extend QueryResult with Eq::{equal, not_equal}

///|
pub extend QueryResult with @debug.Debug::{to_repr}

///|
/// Runs an execution to its terminal state. On failure, `matches` holds the
/// matches found before the failure.
pub fn[T : QueryTree] QueryPlan::collect(
  self : QueryPlan,
  tree : T,
  root? : Int,
  projection? : Projection,
  limits? : ExecutionLimits = ExecutionLimits::new(),
) -> QueryResult {
  let cursor = self.execute(tree, root?, projection?, limits~)
  let matches = []
  while cursor.next_match() is Some(row) {
    matches.push(row)
  }
  { matches: ReadOnlyArray::from_array(matches), outcome: cursor.state }
}
