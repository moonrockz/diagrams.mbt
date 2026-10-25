///|
/// Revision equality is stricter than document meaning. It includes the source,
/// resource key, lexical metadata and every constructed value. No allocation
/// counter, clock, hash-only identity or mutable token pointer is involved.
priv struct DocumentRevision { document : Document; resource_id : String? }

///|
fn same_origin(a : SourceOrigin?, b : SourceOrigin?, cache : Array[(SourceOrigin,SourceOrigin)]) -> Bool {
  match (a,b) {
    (None,None) => true
    (Some(a),Some(b)) => {
      if physical_equal(a,b) || cache.iter().any(p => physical_equal(a,p.0) && physical_equal(b,p.1)) { return true }
      if a != b { return false }
      if cache.length() < 8 { cache.push((a,b)) }; true
    }
    _ => false
  }
}

///|
fn same_revision(a : DocumentRevision, b : DocumentRevision) -> Bool {
  if physical_equal(a,b) { return true }
  if a.resource_id != b.resource_id { return false }
  let a=a.document; let b=b.document
  let origins : Array[(SourceOrigin,SourceOrigin)] = []
  if !same_origin(a.origin,b.origin,origins) || a.prolog_spans != b.prolog_spans || a.epilog_spans != b.epilog_spans { return false }
  let stack : Array[(Content,Content)] = [(Element(a.root),Element(b.root))]
  for (ac,bc) in [(a.prolog,b.prolog),(a.epilog,b.epilog)] {
    if ac.length() != bc.length() { return false }
    for i in 0..<ac.length() { stack.push((ac[i],bc[i])) }
  }
  while stack.pop() is Some((a,b)) {
    match (a,b) {
      (Element(a),Element(b)) => {
        if physical_equal(a,b) { continue }
        if !same_origin(a.origin,b.origin,origins) { return false }
        // An unmodified source element's closed scope is determined by its
        // complete source identity and span. Edited/constructed values still
        // compare their complete captured context.
        let source_context=a.captured_context && b.captured_context && a.origin != None && a.span != None && a.span == b.span
        if a.kind != b.kind || a.value_type != b.value_type || a.text_value != b.text_value || a.span != b.span || a.content_spans != b.content_spans || a.raw_name != b.raw_name || a.bindings != b.bindings || a.captured_context != b.captured_context || (!source_context && a.context != b.context) || a.values.length() != b.values.length() || a.contents.length() != b.contents.length() { return false }
        for i in 0..<a.values.length() {
          let aa=a.values[i]; let bb=b.values[i]
          if aa.name != bb.name || aa.raw_name != bb.raw_name || aa.value != bb.value || aa.span != bb.span || !same_origin(aa.origin,bb.origin,origins) { return false }
          // Scalar Reference equality excludes spelling; revision identity does not.
          if aa.value.token() != bb.value.token() { return false }
        }
        if a.text_value.map(v => v.token()) != b.text_value.map(v => v.token()) { return false }
        for i in 0..<a.contents.length() { stack.push((a.contents[i],b.contents[i])) }
      }
      (Text(a),Text(b)) | (Comment(a),Comment(b)) => if a != b { return false }
      (ProcessingInstruction(target=a,data=ad),ProcessingInstruction(target=b,data=bd)) => if a != b || ad != bd { return false }
      _ => return false
    }
  }
  true
}
