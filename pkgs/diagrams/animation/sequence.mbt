///|
priv struct PendingFrame { frame : @sequence.Frame; path : ReadOnlyArray[Int]; sections : Array[Array[Control]] }

///|
priv struct EventJob { event : @sequence.Event; path : Array[Int]; parent : Int; section : Int; depth : Int }

///|
fn frame_label(kind : @sequence.FrameKind) -> String {
  match kind { Loop => "loop"; Alt => "alt"; Opt => "opt"; Par => "par"; ParOver => "par_over"; Critical => "critical"; Break => "break"; Rect => "rect" }
}

///|
/// Message vertices are occurrences, not participants. Frame branches remain
/// explicit; a loop contributes one authored structural iteration, never a
/// participant cycle or an inferred unbounded execution.
pub fn Catalog::sequence(sequence : @sequence.Sequence, view_id? : String = "sequence", limits? : Limits = Limits::new()) -> CatalogResult {
  let build=builder(Sequence(sequence),view_id,limits); let budget=build.budget
  if budget.failed { return build.finish() }
  let participants=Map([])
  for participant in sequence.participants {
    if !budget.charge(participant.id.length()+1) { return build.finish() }
    if participants.contains(participant.id) { budget.error("animation/invalid-identity","Duplicate sequence participant identity"); return build.finish() }
    participants[participant.id]=true
  }
  if !budget.charge(sequence.events.length()) { return build.finish() }
  let pending : Array[PendingFrame]=[]; let jobs : Array[EventJob]=[]
  for reversed in 0..<sequence.events.length() { let i=sequence.events.length()-1-reversed; jobs.push({event:sequence.events[i],path:[i],parent: -1,section:0,depth:0}) }
  fn append(control : Control, parent : Int, section : Int) -> Unit {
    if parent < 0 { build.controls.push(control) } else { pending[parent].sections[section].push(control) }
  }
  let start="control:\{view_id.length()}:\{view_id}:start"; let end="control:\{view_id.length()}:\{view_id}:end"
  build.node({id:start,label:"Start",kind:Start,occurrence:None,source_node:None})
  build.node({id:end,label:"End",kind:End,occurrence:None,source_node:None})
  while jobs.pop() is Some(job) {
    if !budget.charge(1+job.path.length()) { return build.finish() }
    if job.depth > limits.depth { budget.error("animation/plan-limit","Sequence control depth limit exceeded"); return build.finish() }
    match job.event {
      Message(message) => {
        if !budget.charge(message.sender.length()+message.receiver.length()+message.label.length()) { return build.finish() }
        if !participants.contains(message.sender) || !participants.contains(message.receiver) { budget.error("animation/invalid-identity","Message names a missing participant"); return build.finish() }
        let index=build.occurrences.length(); let key=path_key("sequence:\{view_id.length()}:\{view_id}:",job.path)
        build.occurrence({key,index,kind:SequenceMessage,path:ReadOnlyArray::from_array(job.path),source:None,flow:None,message:Some(message)})
        build.node({id:key,label:message.label,kind:Message,occurrence:Some(key),source_node:None})
        append(Message(index),job.parent,job.section)
      }
      Frame(frame) => {
        let index=pending.length(); let key=path_key("frame:\{view_id.length()}:\{view_id}:",job.path)
        if !budget.charge(frame.sections.length()) { return build.finish() }
        pending.push({frame,path:ReadOnlyArray::from_array(job.path),sections:Array::makei(frame.sections.length(),_ => [])})
        append(Frame(index),job.parent,job.section)
        build.node({id:key+":in",label:frame_label(frame.kind),kind:FrameEnter,occurrence:None,source_node:None})
        build.node({id:key+":out",label:frame_label(frame.kind),kind:FrameExit,occurrence:None,source_node:None})
        for reversed in 0..<frame.sections.length() {
          let section=frame.sections.length()-1-reversed
          if !budget.charge(frame.sections[section].label.map(l => l.length()).unwrap_or(0)+1) { return build.finish() }
          for reversed in 0..<frame.sections[section].events.length() {
            let i=frame.sections[section].events.length()-1-reversed
            if !budget.charge(job.path.length()+3) { return build.finish() }
            let path=job.path.copy(); path.push(section); path.push(i)
            jobs.push({event:frame.sections[section].events[i],path,parent:index,section,depth:job.depth+1})
          }
        }
      }
      _ => ()
    }
    if budget.failed { return build.finish() }
  }
  for frame in pending {
    let sections=Array::makei(frame.sections.length(),i => SectionInfo::{label:frame.frame.sections[i].label,controls:ReadOnlyArray::from_array(frame.sections[i])})
    build.frames.push({key:path_key("frame:\{view_id.length()}:\{view_id}:",frame.path),path:frame.path,kind:frame.frame.kind,sections:ReadOnlyArray::from_array(sections)})
  }
  fn ordered(controls : ArrayView[Control], start : String, end : String) -> Unit {
    let mut previous=start
    for control in controls {
      if !budget.charge(1) { return }
      let (enter,exit)=match control {
        Message(i) => (build.occurrences[i].key,build.occurrences[i].key)
        Frame(i) => (build.frames[i].key+":in",build.frames[i].key+":out")
      }
      build.edge({kind:Order,source:previous,target:enter,occurrence:None}); previous=exit
    }
    build.edge({kind:Order,source:previous,target:end,occurrence:None})
  }
  ordered(build.controls,start,end)
  for frame in build.frames {
    let enter=frame.key+":in"; let exit=frame.key+":out"
    if frame.kind == Alt || frame.kind == Opt || frame.kind == Par || frame.kind == ParOver {
      for section in frame.sections { ordered(section.controls,enter,exit) }
      if frame.kind == Opt { build.edge({kind:Order,source:enter,target:exit,occurrence:None}) }
    } else {
      let controls=[]
      for section in frame.sections { controls.append(section.controls) }
      ordered(controls,enter,exit)
    }
  }
  build.finish()
}
