///|
// Iterative Kosaraju condensation keeps deep and cyclic scopes off the call stack.
fn ranks(members : ArrayView[Int], links : ArrayView[(Int,Int)], budget : Budget) -> Map[Int,Int] {
  let outgoing : Map[Int,Array[Int]]=Map([]); let incoming : Map[Int,Array[Int]]=Map([])
  for (a,b) in links {
    if !budget.charge(1) { return Map([]) }
    match outgoing.get(a) { Some(values) => values.push(b); None => outgoing[a]=[b] }
    match incoming.get(b) { Some(values) => values.push(a); None => incoming[b]=[a] }
  }
  let seen=Map([]); let order=[]
  for start in members {
    let stack=[(start,false)]
    while stack.pop() is Some((node,leave)) {
      if !budget.charge(1) { return Map([]) }
      if leave { order.push(node); continue }
      if seen.contains(node) { continue }; seen[node]=true; stack.push((node,true))
      let neighbors=outgoing.get(node).unwrap_or([])
      for i in 0..<neighbors.length() { stack.push((neighbors[neighbors.length()-1-i],false)) }
    }
  }
  let components : Map[Int,Int]=Map([]); let count : Array[Int]=[]
  for i in 0..<order.length() {
    let start=order[order.length()-1-i]
    if components.contains(start) { continue }
    let component=count.length(); count.push(0); let stack=[start]
    while stack.pop() is Some(node) {
      if !budget.charge(1) { return Map([]) }
      if components.contains(node) { continue }
      components[node]=component; count[component]+=1
      stack.append(incoming.get(node).unwrap_or([]))
    }
  }
  let edges : Map[(Int,Int),Bool]=Map([]); let next : Array[Array[Int]]=Array::makei(count.length(),_ => [])
  let indegree=Array::make(count.length(),0); let rank=Array::make(count.length(),0)
  for (a,b) in links {
    if !budget.charge(1) { return Map([]) }
    let a=components[a]; let b=components[b]
    if a != b && !edges.contains((a,b)) { edges[(a,b)]=true; next[a].push(b); indegree[b]+=1 }
  }
  let queue=[]
  for i in 0..<count.length() { if indegree[i] == 0 { queue.push(i) } }
  let mut cursor=0
  while cursor < queue.length() {
    if !budget.charge(1) { return Map([]) }
    let a=queue[cursor]; cursor+=1
    for b in next[a] { rank[b]=Int::max(rank[b],rank[a]+1); indegree[b]-=1; if indegree[b] == 0 { queue.push(b) } }
  }
  let result=Map([])
  for node in members { result[node]=rank[components[node]] }
  result
}
