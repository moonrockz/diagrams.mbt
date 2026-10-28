///|
// Iterative Kosaraju condensation keeps deep and cyclic scopes off the call stack.
fn ranks(
  members : ArrayView[Int32],
  links : ArrayView[(Int32, Int32)],
  budget : Budget,
) -> Map[Int32, Int32] {
  let outgoing : Map[Int32, Array[Int32]] = Map([])
  let incoming : Map[Int32, Array[Int32]] = Map([])
  for (a, b) in links {
    if !budget.charge(1) {
      return Map([])
    }
    match outgoing.get(a) {
      Some(values) => values.push(b)
      None => outgoing[a] = [b]
    }
    match incoming.get(b) {
      Some(values) => values.push(a)
      None => incoming[b] = [a]
    }
  }
  let seen = Map([])
  let order = []
  for start in members {
    let stack = [(start, false)]
    while stack.pop() is Some((node, leave)) {
      if !budget.charge(1) {
        return Map([])
      }
      if leave {
        order.push(node)
        continue
      }
      if seen.contains(node) {
        continue
      }
      seen[node] = true
      stack.push((node, true))
      let neighbors = outgoing.get(node).unwrap_or([])
      for i in 0..<neighbors.length() {
        stack.push((neighbors[neighbors.length() - 1 - i], false))
      }
    }
  }
  let components : Map[Int32, Int32] = Map([])
  let count : Array[Int32] = []
  for i in 0..<order.length() {
    let start = order[order.length() - 1 - i]
    if components.contains(start) {
      continue
    }
    let component = count.length()
    count.push(0)
    let stack = [start]
    while stack.pop() is Some(node) {
      if !budget.charge(1) {
        return Map([])
      }
      if components.contains(node) {
        continue
      }
      components[node] = component
      count[component] += 1
      stack.append(incoming.get(node).unwrap_or([]))
    }
  }
  let edges : Map[(Int32, Int32), Bool] = Map([])
  let next : Array[Array[Int32]] = Array::makei(count.length(), _ => [])
  let indegree = Array::make(count.length(), 0)
  let rank = Array::make(count.length(), 0)
  for (a, b) in links {
    if !budget.charge(1) {
      return Map([])
    }
    let a = components[a]
    let b = components[b]
    if a != b && !edges.contains((a, b)) {
      edges[(a, b)] = true
      next[a].push(b)
      indegree[b] += 1
    }
  }
  let queue = []
  for i in 0..<count.length() {
    if indegree[i] == 0 {
      queue.push(i)
    }
  }
  let mut cursor = 0
  while cursor < queue.length() {
    if !budget.charge(1) {
      return Map([])
    }
    let a = queue[cursor]
    cursor += 1
    for b in next[a] {
      rank[b] = Int32::max(rank[b], rank[a] + 1)
      indegree[b] -= 1
      if indegree[b] == 0 {
        queue.push(b)
      }
    }
  }
  let result = Map([])
  for node in members {
    result[node] = rank[components[node]]
  }
  result
}

///|
fn weighted_ranks(
  members : ArrayView[Int32],
  links : ArrayView[(Int32, Int32, Int32)],
  budget : Budget,
  break_cycles~ : Bool = false,
) -> Map[Int32, Int32] {
  let links=if break_cycles { cycle_free_links(links,budget) } else { links.to_owned() }
  let pairs = []
  let outgoing : Map[Int32, Array[(Int32, Int32)]] = Map([])
  for (a, b, length) in links {
    if !budget.charge(1) {
      return Map([])
    }
    if length < 1 || length > 1000000 {
      budget.error(
        "swimlane/layout-limit", "Connection rank length exceeds its safe bound",
      )
      return Map([])
    }
    pairs.push((a, b))
    match outgoing.get(a) {
      Some(items) => items.push((b, length))
      None => outgoing[a] = [(b, length)]
    }
  }
  let base = ranks(members, pairs, budget)
  let result = Map([])
  for (id, rank) in base {
    result[id] = rank
  }
  let order = members.to_owned()
  order.sort_by((a, b) => {
    let c = base.get(a).unwrap_or(0).compare(base.get(b).unwrap_or(0))
    if c == 0 {
      a.compare(b)
    } else {
      c
    }
  })
  for a in order {
    for (b, length) in outgoing.get(a).unwrap_or([]) {
      if !budget.charge(1) {
        return Map([])
      }
      // Edges inside a condensed cycle have the same base rank. They use return
      // channels, rather than growing ranks forever.
      if base.get(b).unwrap_or(0) > base.get(a).unwrap_or(0) {
        if result[a] > 1000000 - length {
          budget.error(
            "swimlane/layout-limit", "Rank extent exceeds its safe bound",
          )
          return Map([])
        }
        result[b] = Int32::max(result[b], result[a] + length)
      }
    }
  }
  result
}

///|
// Keep authored forward constraints and route later cycle-closing connections
// as feedback. This is opt-in so existing swimlane geometry remains unchanged.
fn cycle_free_links(links : ArrayView[(Int,Int,Int)], budget : Budget) -> Array[(Int,Int,Int)] {
  let accepted=[]
  let outgoing : Map[Int,Array[Int]]=Map([])
  for (a,b,length) in links {
    if !budget.charge(1) { return [] }
    if a == b { continue }
    let stack=[b]; let seen : Map[Int,Bool]=Map([]); let mut cycle=false
    while stack.pop() is Some(current) {
      if !budget.charge(1) { return [] }
      if current == a { cycle=true;break }
      if seen.contains(current) { continue }; seen[current]=true
      for next in outgoing.get(current).unwrap_or([]) {
        if !budget.charge(1) { return [] };stack.push(next)
      }
    }
    if !cycle {
      accepted.push((a,b,length))
      match outgoing.get(a) { Some(values) => values.push(b); None => outgoing[a]=[b] }
    }
  }
  accepted
}
