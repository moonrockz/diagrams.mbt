///|
pub struct ValidationResult {
  document : Document?
  index : DocumentIndex?
  references : ReadOnlyArray[ResolvedReference]
  findings : ReadOnlyArray[ValidationFinding]
  complete : Bool
} derive(Debug)

///|
pub extend ValidationResult with @debug.Debug::{to_repr}

///|
fn combined_findings(groups : ArrayView[ReadOnlyArray[ValidationFinding]], maximum : Int) -> (ReadOnlyArray[ValidationFinding],Bool) {
  let out : Array[ValidationFinding] = []
  for group in groups { for item in group {
    if out.length() >= maximum {
      out[maximum-1]={..item,diagnostic:{..item.diagnostic,code:"bpmn/validation-diagnostic-limit",message:"Combined validation diagnostic limit exceeded"}}
      return (ReadOnlyArray::from_array(out),false)
    }
    out.push(item)
  } }
  (ReadOnlyArray::from_array(out),true)
}

///|
/// Complete means all requested processing finished, not that the model is
/// valid. Error findings and the original immutable document coexist.
pub fn validate(document : Document, resources? : ResourceSet = ResourceSet::new(), resource_id? : String, limits? : Limits = Limits::new()) -> ValidationResult {
  let structure=validate_structure(document,resource_id?,limits~)
  if !structure.complete { return {document:Some(document),index:Some(structure.index),references:[],findings:structure.findings,complete:false} }
  let references=resolve_references(structure.index,resources~,resource_id?,limits~)
  let (findings,within_limit)=combined_findings([structure.findings,references.findings],limits.diagnostics)
  {document:Some(document),index:Some(structure.index),references:references.references,findings,complete:references.complete && within_limit}
}

///|
/// Retain XML/lowering findings alongside the explicit structural and reference
/// stages. A syntax failure never invents a typed document or a source span.
pub fn validate_read(result : ReadResult, resources? : ResourceSet = ResourceSet::new(), resource_id? : String, limits? : Limits = Limits::new()) -> ValidationResult {
  if !valid_limits(limits) {
    let log=ValidationLog::{limits:Limits::new(),findings:[],resource_id,stopped:false}
    log.add(Structure,"bpmn/validation-invalid-limits","All validation limits must be positive",None,None)
    return {document:result.document,index:None,references:[],findings:ReadOnlyArray::from_array(log.findings),complete:false}
  }
  let source_findings=ReadOnlyArray::from_array(result.diagnostics.map(diagnostic => ValidationFinding::{stage:if diagnostic.code.has_prefix("xml/") { Syntax } else { Structure },diagnostic,resource_id,node:None,element_id:None,field:None}))
  let maximum=if limits.diagnostics > 0 { limits.diagnostics } else { 1 }
  guard result.document is Some(document) else {
    let (findings,_)=combined_findings([source_findings],maximum)
    return {document:None,index:None,references:[],findings,complete:false}
  }
  let validated=validate(document,resources~,resource_id?,limits~)
  let (findings,within_limit)=combined_findings([source_findings,validated.findings],maximum)
  {..validated,findings,complete:validated.complete && within_limit}
}
