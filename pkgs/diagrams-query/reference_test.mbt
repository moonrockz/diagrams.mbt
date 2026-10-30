///|
/// A deterministic generator for the randomized comparison.
struct Rng {
  mut state : UInt64
  names : Array[String]
}

///|
fn Rng::below(self : Rng, n : Int) -> Int {
  self.state = self.state * 6364136223846793005UL + 1442695040888963407UL
  ((self.state >> 33).to_int() & 0x7FFFFFFF) % n
}

///|
fn random_tree(rng : Rng) -> FsTree {
  let t = FsTree::new()
  t.add("dir") |> ignore
  let n = 2 + rng.below(12)
  for _ in 1..<n {
    let dirs = []
    for i, node in t.nodes {
      if node.kind == "dir" {
        dirs.push(i)
      }
    }
    let parent = dirs[rng.below(dirs.length())]
    let kind = ["dir", "file", "link"][rng.below(3)]
    let field = ["entry", "meta"][rng.below(2)]
    let attrs = match rng.below(3) {
      0 => []
      1 => [("name", "")]
      _ => [("name", "v\{rng.below(2)}")]
    }
    let text = if rng.below(2) == 0 { None } else { Some("t\{rng.below(2)}") }
    t.add(kind, parent~, field~, attrs~, text?) |> ignore
  }
  t
}

///|
fn random_pattern(rng : Rng, depth : Int) -> @query.Pattern {
  let captures = []
  for _ in 0..<rng.below(3) {
    let name = "c\{rng.names.length()}"
    rng.names.push(name)
    captures.push(name)
  }
  if depth < 2 && rng.below(5) == 0 {
    let branches = []
    for _ in 0..<(1 + rng.below(2)) {
      branches.push(random_pattern(rng, depth + 1))
    }
    return @query.Pattern::alternation(branches, captures~)
  }
  let selector : @query.Selector = match rng.below(5) {
    0 => Wildcard
    1 => Category(["container", "leaf"][rng.below(2)])
    _ => Kind(@query.QName::new(["dir", "file", "link"][rng.below(3)]))
  }
  let parts = []
  if depth < 3 {
    for _ in 0..<rng.below(3) {
      let part : @query.Part = match rng.below(4) {
        0 => Absent(@query.QName::new(["entry", "meta"][rng.below(2)]))
        1 =>
          Field(
            @query.QName::new(["entry", "meta"][rng.below(2)]),
            random_pattern(rng, depth + 1),
          )
        _ => Child(random_pattern(rng, depth + 1))
      }
      parts.push(part)
    }
  }
  @query.Pattern::node(selector, parts~, captures~)
}

///|
fn random_predicates(rng : Rng) -> Array[@query.Predicate] {
  let predicates = []
  if rng.names.is_empty() {
    return predicates
  }
  for _ in 0..<rng.below(3) {
    let capture = rng.names[rng.below(rng.names.length())]
    let predicate = match rng.below(6) {
      0 => @query.Predicate::has_attr(capture, "name")
      1 => @query.Predicate::missing_attr(capture, "name")
      2 => @query.Predicate::attr_eq(capture, "name", ["", "v0"][rng.below(2)])
      3 => @query.Predicate::attr_not_eq(capture, "name", "v1")
      4 => @query.Predicate::attr_in(capture, "name", ["v0", "v1"])
      _ => @query.Predicate::text_eq(capture, ["t0", "t1"][rng.below(2)])
    }
    predicates.push(predicate)
  }
  predicates
}

///|
/// The reference evaluator: a direct recursive enumeration, written without
/// the plan, choice points or budgets. Bindings are (site, node) pairs.
struct Reference {
  tree : FsTree
  mut site : Int
}

///|
/// Assigns capture sites in source order (parts before own captures) and
/// returns the matches of `pattern` at `node`, in enumeration order.
fn Reference::sites(self : Reference, pattern : @query.Pattern) -> SiteTree {
  match pattern {
    Node(_, parts, captures) => {
      let children = parts.map(part => match part {
        Child(p) => Some(self.sites(p))
        Field(_, p) => Some(self.sites(p))
        Absent(_) => None
      })
      let own = captures.map(_ => {
        self.site += 1
        self.site - 1
      })
      { pattern, children: children.iter().to_array(), own: own.iter().to_array() }
    }
    Alternation(branches, captures) => {
      let children = branches.map(p => Some(self.sites(p)))
      let own = captures.map(_ => {
        self.site += 1
        self.site - 1
      })
      { pattern, children: children.iter().to_array(), own: own.iter().to_array() }
    }
  }
}

///|
struct SiteTree {
  pattern : @query.Pattern
  children : Array[SiteTree?]
  own : Array[Int]
}

///|
fn Reference::matches(
  self : Reference,
  s : SiteTree,
  node : Int,
) -> Array[Array[(Int, Int)]] {
  let n = self.tree.nodes[node]
  match s.pattern {
    Alternation(_, _) => {
      let out = []
      for branch in s.children {
        for r in self.matches(branch.unwrap(), node) {
          let copy = r.copy()
          for site in s.own {
            copy.push((site, node))
          }
          out.push(copy)
        }
      }
      out
    }
    Node(selector, parts, _) => {
      let ok = match selector {
        Wildcard => true
        Category(c) => n.category == c
        Kind(q) => n.kind == q.local_name && n.ns == ""
      }
      if !ok {
        return []
      }
      let own = s.own.map(site => (site, node))
      self
      .assign(s, parts, node, 0, 0)
      .map(r => {
        let copy = own.copy()
        copy.append(r)
        copy
      })
    }
  }
}

///|
fn Reference::assign(
  self : Reference,
  s : SiteTree,
  parts : ReadOnlyArray[@query.Part],
  node : Int,
  k : Int,
  min : Int,
) -> Array[Array[(Int, Int)]] {
  if k == parts.length() {
    return [[]]
  }
  let children = self.tree.nodes[node].children
  match parts[k] {
    Absent(f) =>
      if children.iter().any(c => self.tree.nodes[c].field == f.local_name) {
        []
      } else {
        self.assign(s, parts, node, k + 1, min)
      }
    Child(_) | Field(_, _) => {
      let out = []
      for j in min..<children.length() {
        let child = children[j]
        if parts[k] is Field(f, _) && self.tree.nodes[child].field != f.local_name {
          continue
        }
        for first in self.matches(s.children[k].unwrap(), child) {
          for rest in self.assign(s, parts, node, k + 1, j + 1) {
            let copy = first.copy()
            copy.append(rest)
            out.push(copy)
          }
        }
      }
      out
    }
  }
}

///|
fn reference_rows(form : @query.QueryForm, tree : FsTree) -> Array[String] {
  let reference = Reference::{ tree, site: 0 }
  let rules = form.rules.map(rule => (reference.sites(rule.pattern), rule.predicates))
  let names = []
  for rule in form.rules {
    collect_names(rule.pattern, names)
  }
  let out = []
  let stack = [0]
  while stack.pop() is Some(node) {
    for i = tree.nodes[node].children.length() - 1; i >= 0; i = i - 1 {
      stack.push(tree.nodes[node].children[i])
    }
    for index, rule in rules {
      for binding in reference.matches(rule.0, node) {
        let accepted = rule.1.iter().all(p => {
          guard binding.iter().find_first(b => names[b.0] == p.capture) is Some((_, n)) else {
            return false
          }
          let attr = tree.nodes[n].attrs.iter().find_first(a => a.0 == "name").map(a => a.1)
          match p.name {
            "has-attr?" => attr is Some(_)
            "missing-attr?" => attr is None
            "attr-eq?" => attr == Some(p.operands[1])
            "attr-not-eq?" => attr is Some(v) && v != p.operands[1]
            "attr-in?" => attr is Some(v) && p.operands.iter().drop(1).any(x => x == v)
            _ => tree.nodes[n].text == Some(p.operands[0])
          }
        })
        if accepted {
          let sorted = binding.copy()
          sorted.sort_by_key(b => b.0)
          out.push("\{index}: " + sorted.map(b => "\{names[b.0]}=\{b.1}").iter().join(" "))
        }
      }
    }
  }
  out
}

///|
fn collect_names(pattern : @query.Pattern, names : Array[String]) -> Unit {
  match pattern {
    Node(_, parts, captures) => {
      for part in parts {
        match part {
          Child(p) | Field(_, p) => collect_names(p, names)
          Absent(_) => ()
        }
      }
      names.append(captures.iter().to_array())
    }
    Alternation(branches, captures) => {
      for b in branches {
        collect_names(b, names)
      }
      names.append(captures.iter().to_array())
    }
  }
}

///|
test "the evaluator agrees with an independent reference evaluator" {
  let rng = Rng::{ state: 20261030UL, names: [] }
  let mut compared = 0
  let mut nonempty = 0
  for _ in 0..<1500 {
    let tree = random_tree(rng)
    let rules = []
    for _ in 0..<(1 + rng.below(2)) {
      rng.names.clear()
      rules.push(@query.Rule::new(random_pattern(rng, 0), predicates=random_predicates(rng)))
    }
    let form = @query.QueryForm::new(rules)
    guard @query.compile_form(form, fs_schema) is Ok(plan) else { continue }
    compared += 1
    let expected = reference_rows(form, tree)
    let result = plan.collect(tree)
    let actual = result.matches.map(m => "\{m.pattern}: " +
      m.captures.map(c => "\{c.name}=\{c.node}").iter().join(" "))
    assert_eq(actual.iter().to_array(), expected)
    assert_true(result.outcome is Complete)
    if !expected.is_empty() {
      nonempty += 1
    }
    // Batches of any size concatenate to the same rows.
    let cursor = plan.execute(tree)
    let batched = []
    while cursor.next_batch(1 + rng.below(3)) is Rows(rows) {
      batched.append(rows.iter().to_array())
    }
    assert_eq(batched, result.matches.iter().to_array())
  }
  assert_true(compared > 1000)
  assert_true(nonempty > 400)
}
