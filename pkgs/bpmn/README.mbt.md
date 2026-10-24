# moonrockz/bpmn

Portable BPMN document values, a lossless namespace-aware XML CST, source maps,
writing and containment walking. The module imports only MoonBit core. It reads
decoded strings without filesystem, network, clock or environment access.

## Reading stages

`read(source, source_id?, limits?)` scans XML, constructs the owned CST, resolves
namespace scopes and lowers supported BPMN values. An XML error prevents typed
lowering. XML recovery keeps malformed regions and resumes at tag boundaries.
`tree.complete` describes the XML stage; typed lowering can still report an
unsupported BPMN element/field or exhaust the diagnostic budget.

The XML stage supports XML 1.0 names, namespaces, quoted attributes, comments,
processing instructions, CDATA, mixed text, the five predefined entities and
numeric character references. Its rules follow
[XML 1.0, fifth edition](https://www.w3.org/TR/xml/) and
[Namespaces in XML 1.0, third edition](https://www.w3.org/TR/xml-names/).
Namespace names compare as literal strings. Declarations apply to the whole
start tag, and a default namespace applies to elements. Ordinary unprefixed
attributes have an empty namespace. Duplicate expanded attribute names fail.
The reserved `xml` binding is present without a declaration.

```mbt check
///|
test "inspect XML namespaces and mixed content without a renderer" {
  let source = "<r xmlns='urn:r' xmlns:p='urn:p' p:a='&#x1F600;'>left<![CDATA[<raw>&]]><p:c/>right</r>"
  let result = @bpmn.read(source)
  assert_eq(result.tree.text(), source)
  assert_true(result.tree.complete)
  let root = result.tree.nodes[1]
  assert_eq(root.name.unwrap().namespace_uri, "urn:r")
  assert_eq(root.attributes[2].value, "😀")
  assert_eq(root.children.map(i => result.tree.nodes[i].kind).iter().to_array(), [Text, CData, Element, Text])
  // This XML vocabulary has no typed BPMN projection yet.
  assert_eq(result.document, None)
}
```

The CST has flat, immutable `nodes` and lexical `tokens`. Node zero is the
document; child and parent indexes refer to that CST. Element nodes expose raw
and expanded names, ordered attributes, local namespace declarations, child
indexes and source spans. Text/CDATA values are decoded and normalized;
processing-instruction values contain data after the target. Each token retains
its original text and half-open UTF-16 span. Tokens partition the source. Use
`tree.text()` to reproduce the original spelling, including invalid XML.

Literal CRLF and CR become LF in decoded values. Literal attribute whitespace
becomes spaces; referenced whitespace retains its referenced character. CDATA
and processing instructions do not expand references. Malformed comments,
forbidden characters, invalid scalars and undeclared entities give findings.
DTD, entity and other markup declarations are prohibited, with no expansion or
resource resolution. Neither schema locations nor namespace URIs cause I/O.

Input is already decoded. The optional XML declaration must name version 1.0;
accepted encoding labels are case-insensitive `UTF-8` and `US-ASCII`. An ASCII
declaration fails if the input has non-ASCII characters. File decoding belongs
to a host adapter. An initial Unicode BOM is retained in source reproduction.

## Source locations

Offsets and columns count UTF-16 code units; lines and columns start at one.
CRLF is one line break. `source_map.position(offset)` and `location(span)` reject
out-of-range offsets. Diagnostics have a stable code, severity, message and
optional span/location. A supplied source ID is data, not a path to open.

```mbt check
///|
test "a diagnostic after an emoji uses source coordinates" {
  let result = @bpmn.read("<r>\r\n😀<p:x/></r>", source_id="memory:example")
  let location = result.diagnostics[0].location.unwrap()
  assert_eq(location.source_id, Some("memory:example"))
  assert_eq(location.start.line, 2)
  assert_eq(location.start.column, 4)
  assert_eq(result.document, None)
}
```

## Processing limits

All `Limits::new` fields are inclusive and must be positive.

| Field | Default | What it bounds |
| --- | --- | --- |
| `source_units` | 16,777,216 | Decoded source in UTF-16 units |
| `output_units` | 16,777,216 | Reserved for the bounded writer in group 3 |
| `nodes` | 1,000,000 | Document, element/content nodes and attributes |
| `depth` | 4,096 | Element depth, including empty elements |
| `token_units` | 1,048,576 | One lexical token or complete attribute/text value |
| `diagnostics` | 256 | Findings shared by XML reading and typed lowering |

A limit finding prevents a successful typed document. The diagnostic that
exceeds the finding budget replaces its last slot with `xml/diagnostic-limit`.
Reading stops at a parser limit. The remaining raw source is retained as one
error preservation token, exempt from token size; it is not decoded or expanded.
Oversized source is rejected before constructing a source map or node arena.
Its finding identifies offset zero and the source ID. Invalid limits produce
one configuration finding without an invented source location, even when the
configured diagnostic limit is zero. Source reproduction remains available.

```mbt check
///|
test "limit exhaustion preserves the complete source" {
  let source = "<r><s/></r>"
  let result = @bpmn.read(source, limits=@bpmn.Limits::new(depth=1))
  assert_eq(result.tree.text(), source)
  assert_eq(result.document, None)
  assert_eq(result.diagnostics[0].code, "xml/depth-limit")
}
```

## XML diagnostic inventory

All codes below have error severity. BPMN lowering codes are separate.

| Code | Meaning |
| --- | --- |
| `xml/invalid-limits` | At least one configured bound is not positive |
| `xml/source-limit` | Source exceeds its UTF-16 bound |
| `xml/node-limit` | Node/attribute records exceed their bound |
| `xml/depth-limit` | Element depth exceeds its bound |
| `xml/token-limit` | A lexical token or attribute/text value is too large |
| `xml/diagnostic-limit` | The next finding exceeds the shared budget |
| `xml/invalid-character` | A literal character is forbidden in XML 1.0 |
| `xml/invalid-name` | An element/attribute name is not a qualified XML name |
| `xml/invalid-tag` | Attribute quoting, spacing or tag punctuation is malformed |
| `xml/unclosed-tag` | An open element remains at end of input |
| `xml/mismatched-tag` | A closing tag does not match the current open element |
| `xml/duplicate-attribute` | Attribute expanded names or namespace declarations repeat |
| `xml/undeclared-prefix` | A qualified element/attribute uses an unbound prefix |
| `xml/invalid-namespace` | A reserved binding or prefix undeclaration is invalid |
| `xml/character-reference` | A reference is malformed, undeclared or not an XML scalar |
| `xml/outside-root` | Non-whitespace text or CDATA occurs outside the document element |
| `xml/root-required` | The source does not contain exactly one document element |
| `xml/invalid-comment` | A comment contains `--` or ends with `-` |
| `xml/unclosed-comment` | A comment has no closing delimiter |
| `xml/unclosed-cdata` | A CDATA section has no closing delimiter |
| `xml/invalid-pi` | A processing instruction has an invalid or reserved target |
| `xml/unclosed-pi` | A processing instruction has no closing delimiter |
| `xml/invalid-declaration` | The declaration has invalid position, version or pseudo-attributes |
| `xml/encoding` | The declared encoding is unsupported or conflicts with the decoded input |
| `xml/prohibited-declaration` | DTD/entity/other markup declarations are prohibited |
| `xml/cdata-close` | `]]>` occurs in ordinary character data |

```mbt check
///|
test "the documented inventory agrees with the exported codes" {
  assert_eq(@bpmn.xml_diagnostic_codes.iter().to_array(), [
    "xml/invalid-limits", "xml/source-limit", "xml/node-limit", "xml/depth-limit",
    "xml/token-limit", "xml/diagnostic-limit", "xml/invalid-character",
    "xml/invalid-name", "xml/invalid-tag", "xml/unclosed-tag", "xml/mismatched-tag",
    "xml/duplicate-attribute", "xml/undeclared-prefix", "xml/invalid-namespace",
    "xml/character-reference", "xml/outside-root", "xml/root-required",
    "xml/invalid-comment", "xml/unclosed-comment", "xml/unclosed-cdata",
    "xml/invalid-pi", "xml/unclosed-pi", "xml/invalid-declaration", "xml/encoding",
    "xml/prohibited-declaration", "xml/cdata-close",
  ])
}
```

## Typed BPMN values and writing

The typed projection currently supports definitions, processes, generic tasks,
start/end events, sequence flows, incoming/outgoing text and DI
plane/shape/bounds/edge/waypoint values. Unknown families and namespaced typed
fields remain inspectable in the complete CST and give lowering findings.
Schema-derived foundations, complete BPMN families, extension values,
validation, explicit references and the full traversal contract follow in
later groups of `add-bpmn-diagrams-and-animation`.

```mbt check
///|
test "read, inspect, write and keep the original source" {
  let source = "<definitions xmlns=\"http://www.omg.org/spec/BPMN/20100524/MODEL\" targetNamespace=\"urn:example\"><process id=\"P\"><task id=\"T\" name=\"Review &amp; approve\"/></process></definitions>"
  let result = @bpmn.read(source)
  assert_eq(result.tree.text(), source)
  assert_eq(result.diagnostics.length(), 0)
  let document = result.document.unwrap()
  let tasks : Array[String] = []
  document.walk(e => { if e.kind == Task { tasks.push(e.attribute("name").unwrap()) } })
  assert_eq(tasks, ["Review & approve"])
  assert_eq(@bpmn.read(@bpmn.write(document)).document, Some(document))
}
```

`write` emits compact XML with fixed standard prefixes and ordered attributes
and children. It is for valid minimal values; group 3 adds the validating,
bounded canonical/pretty writer. `tree.text()` is the source reproduction API.
Coordinate attribute strings keep exact values. Constructors copy their input
collections into read-only arrays; a walk visits containment in preorder and
does not follow reference attributes.

Current lowering codes are `bpmn/unsupported-content`,
`bpmn/unsupported-attribute`, `bpmn/unsupported-element` and
`bpmn/definitions-required`. They do not change the XML CST's completeness.
