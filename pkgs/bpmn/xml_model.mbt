///|
pub(all) enum Severity { Error; Warning } derive(Eq, Debug)

///|
pub extend Severity with Eq::{equal, not_equal}

///|
pub extend Severity with @debug.Debug::{to_repr}

///|
/// Half-open UTF-16 offsets into the owned source.
pub struct Span { start : Int; end : Int } derive(Eq, Debug)

///|
pub extend Span with Eq::{equal, not_equal}

///|
pub extend Span with @debug.Debug::{to_repr}

///|
pub struct Position { offset : Int; line : Int; column : Int } derive(Eq, Debug)

///|
pub extend Position with Eq::{equal, not_equal}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
pub struct Location { source_id : String?; start : Position; end : Position } derive(Eq, Debug)

///|
pub extend Location with Eq::{equal, not_equal}

///|
pub extend Location with @debug.Debug::{to_repr}

///|
pub struct SourceMap { source_id : String?; length : Int; line_starts : ReadOnlyArray[Int] } derive(Eq, Debug)

///|
pub extend SourceMap with Eq::{equal, not_equal}

///|
pub extend SourceMap with @debug.Debug::{to_repr}

///|
fn source_map(source : String, source_id : String?) -> SourceMap {
  let starts = [0]
  let mut i = 0
  while i < source.length() {
    let c = unit(source, i)
    i += 1
    if c == 13 { if unit(source, i) == 10 { i += 1 }; starts.push(i) }
    else if c == 10 { starts.push(i) }
  }
  { source_id, length: source.length(), line_starts: ReadOnlyArray::from_array(starts) }
}

///|
/// Offsets outside the source are rejected, not clamped into invented locations.
pub fn SourceMap::position(self : SourceMap, offset : Int) -> Position? {
  if offset < 0 || offset > self.length { return None }
  let mut lo = 0
  let mut hi = self.line_starts.length()
  while lo + 1 < hi {
    let mid = lo + (hi - lo) / 2
    if self.line_starts[mid] <= offset { lo = mid } else { hi = mid }
  }
  Some({ offset, line: lo + 1, column: offset - self.line_starts[lo] + 1 })
}

///|
pub fn SourceMap::location(self : SourceMap, span : Span) -> Location? {
  guard span.start <= span.end && self.position(span.start) is Some(start) && self.position(span.end) is Some(end) else { return None }
  Some({ source_id: self.source_id, start, end })
}

///|
pub struct Diagnostic { code : String; severity : Severity; message : String; span : Span?; location : Location? } derive(Eq, Debug)

///|
pub extend Diagnostic with Eq::{equal, not_equal}

///|
pub extend Diagnostic with @debug.Debug::{to_repr}

///|
fn finding(code : String, message : String, span? : Span, map? : SourceMap) -> Diagnostic {
  let location = match (map, span) { (Some(m), Some(s)) => m.location(s); _ => None }
  { code, severity: Error, message, span, location }
}

///|
/// Lexical source records. Raw text is never normalized or entity-expanded.
pub(all) enum TokenKind {
  Open; EndOpen; Close; EmptyClose; Name; Whitespace; Equals; Quote
  AttributeValue; Text; CharacterReference; Comment; ProcessingInstruction
  CData; Declaration; Error
} derive(Eq, Debug)

///|
pub extend TokenKind with Eq::{equal, not_equal}

///|
pub extend TokenKind with @debug.Debug::{to_repr}

///|
pub struct Token { kind : TokenKind; text : String; span : Span } derive(Eq, Debug)

///|
pub extend Token with Eq::{equal, not_equal}

///|
pub extend Token with @debug.Debug::{to_repr}

///|
pub struct ExpandedName { namespace_uri : String; local_name : String } derive(Eq, Debug)

///|
pub extend ExpandedName with Eq::{equal, not_equal}

///|
pub extend ExpandedName with @debug.Debug::{to_repr}

///|
pub struct XmlAttribute {
  raw_name : String
  name : ExpandedName
  value : String
  span : Span
  value_span : Span
  namespace_declaration : Bool
} derive(Eq, Debug)

///|
pub extend XmlAttribute with Eq::{equal, not_equal}

///|
pub extend XmlAttribute with @debug.Debug::{to_repr}

///|
pub(all) enum XmlNodeKind { Document; Element; Text; Comment; ProcessingInstruction; CData; Declaration; Error } derive(Eq, Debug)

///|
pub extend XmlNodeKind with Eq::{equal, not_equal}

///|
pub extend XmlNodeKind with @debug.Debug::{to_repr}

///|
/// Nodes use local arena indexes, so deeply nested XML does not require recursive
/// values or recursive CST operations. Bindings are declarations on this node.
pub struct XmlNode {
  kind : XmlNodeKind
  raw_name : String
  name : ExpandedName?
  attributes : ReadOnlyArray[XmlAttribute]
  bindings : ReadOnlyArray[(String, String)]
  children : ReadOnlyArray[Int]
  parent : Int?
  span : Span
  value : String
  complete : Bool
} derive(Eq, Debug)

///|
pub extend XmlNode with Eq::{equal, not_equal}

///|
pub extend XmlNode with @debug.Debug::{to_repr}

///|
pub struct Cst { tokens : ReadOnlyArray[Token]; nodes : ReadOnlyArray[XmlNode]; complete : Bool } derive(Eq, Debug)

///|
pub extend Cst with Eq::{equal, not_equal}

///|
pub extend Cst with @debug.Debug::{to_repr}

///|
pub fn Cst::text(self : Cst) -> String {
  if self.tokens.length() == 1 { return self.tokens[0].text }
  let b = StringBuilder()
  for token in self.tokens { b.write_string(token.text) }
  b.to_string()
}

///|
/// A processing bound is inclusive. All fields must be positive. Node count
/// includes the document node, elements, content nodes and attributes.
pub struct Limits {
  source_units : Int
  output_units : Int
  nodes : Int
  depth : Int
  token_units : Int
  diagnostics : Int
} derive(Eq, Debug)

///|
pub extend Limits with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub fn Limits::new(source_units? : Int = 16777216, output_units? : Int = 16777216, nodes? : Int = 1000000, depth? : Int = 4096, token_units? : Int = 1048576, diagnostics? : Int = 256) -> Limits {
  { source_units, output_units, nodes, depth, token_units, diagnostics }
}

///|
pub struct ReadResult { tree : Cst; document : Document?; source_map : SourceMap?; diagnostics : ReadOnlyArray[Diagnostic] } derive(Eq, Debug)

///|
pub extend ReadResult with Eq::{equal, not_equal}

///|
pub extend ReadResult with @debug.Debug::{to_repr}

///|
/// Stable XML syntax/namespace/limit diagnostic inventory. BPMN lowering codes
/// are separate; later structural/reference stages do not use this inventory.
pub let xml_diagnostic_codes : ReadOnlyArray[String] = [
  "xml/invalid-limits", "xml/source-limit", "xml/node-limit", "xml/depth-limit",
  "xml/token-limit", "xml/diagnostic-limit", "xml/invalid-character",
  "xml/invalid-name", "xml/invalid-tag", "xml/unclosed-tag", "xml/mismatched-tag",
  "xml/duplicate-attribute", "xml/undeclared-prefix", "xml/invalid-namespace",
  "xml/character-reference", "xml/outside-root", "xml/root-required",
  "xml/invalid-comment", "xml/unclosed-comment", "xml/unclosed-cdata",
  "xml/invalid-pi", "xml/unclosed-pi", "xml/invalid-declaration", "xml/encoding",
  "xml/prohibited-declaration", "xml/cdata-close",
]
