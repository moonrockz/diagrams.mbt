///|
// Two-axis constraints are used only when a flowchart authors local edge hints.
fn directional_offsets(
  members : ArrayView[Int],
  links : ArrayView[(Int,Int,Int,@model.Direction)],
  sizes : ArrayView[(Double,Double)],
  direction : @model.Direction,
  gap : Double,
  budget : Budget,
) -> (Map[Int,Point],Double,Double) {
  let xs=[];let ys=[]
  for (a,b,length,dir) in links {
    if !budget.charge(1) { return (Map([]),0.0,0.0) }
    match dir { LR => xs.push((a,b,length)); RL => xs.push((b,a,length)); TB => ys.push((a,b,length)); BT => ys.push((b,a,length)) }
  }
  let xr=weighted_ranks(members,xs,budget,break_cycles=true)
  let yr=weighted_ranks(members,ys,budget,break_cycles=true)
  let buckets : Map[(Int,Int),Int]=Map([])
  let mut largest=1;let mut w=0.0;let mut h=0.0
  for id in members {
    if !budget.charge(1) { return (Map([]),0.0,0.0) }
    let key=(xr.get(id).unwrap_or(0),yr.get(id).unwrap_or(0))
    let count=buckets.get(key).unwrap_or(0)+1;buckets[key]=count;largest=Int::max(largest,count)
    w=Double::max(w,sizes[id].0);h=Double::max(h,sizes[id].1)
  }
  let horizontal=horizontal(direction)
  let stride_x=(w+gap)*(if horizontal { 1.0 } else { largest.to_double() })
  let stride_y=(h+gap)*(if horizontal { largest.to_double() } else { 1.0 })
  let taken : Map[(Int,Int),Int]=Map([])
  let positions=Map([]);let mut width=0.0;let mut height=0.0
  for id in members {
    if !budget.charge(1) { return (Map([]),0.0,0.0) }
    let key=(xr.get(id).unwrap_or(0),yr.get(id).unwrap_or(0))
    let ordinal=taken.get(key).unwrap_or(0);taken[key]=ordinal+1
    let point : Point={x:key.0.to_double()*stride_x+(if horizontal { 0.0 } else { ordinal.to_double()*(w+gap) }),y:key.1.to_double()*stride_y+(if horizontal { ordinal.to_double()*(h+gap) } else { 0.0 })}
    positions[id]=point;width=Double::max(width,point.x+sizes[id].0);height=Double::max(height,point.y+sizes[id].1)
  }
  (positions,width,height)
}
