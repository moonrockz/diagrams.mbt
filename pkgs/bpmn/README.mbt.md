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
and processing instructions do not expand references. Outside the root, only
literal XML whitespace is allowed; references to whitespace are errors. Malformed comments,
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
| `output_units` | 16,777,216 | Complete generated XML in UTF-16 units |
| `nodes` | 1,000,000 | Document, element/content nodes, attributes and namespace declarations |
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

The five frozen BPMN 2.0.2 schemas drive the standard `Kind` alternatives,
`TypeId`, type derivation, substitution groups, fields, occurrence bounds,
choices and named enumeration types. `schema_types`, `schema_elements`,
`schema_fields` and `schema_groups` expose this read-only inventory. Run
`mise run bpmn-schema:generate` to regenerate it. `validate:bpmn-schema` checks
input digests and byte-identical regeneration, including the declaration
coverage manifest under `tests/corpus/bpmn-2.0.2/coverage.json`.

`Element` holds a standard kind, schema type identity, typed `Scalar` attributes,
optional scalar text, and ordered `Content`. Content distinguishes text,
elements, comments and inert processing instructions. Constructors copy input
collections into read-only arrays. Updating an element returns a new value. Parsed elements retain their effective
namespace context in a shared immutable core map, so content updates keep
inherited QName bindings and prefix shadowing without copying every ancestor
binding into every descendant.
`Document` holds its root plus ordered prolog and epilog comments/instructions.
Outside-root whitespace is source trivia and is omitted from document values.

`Definitions`, `Import`, `BaseElement`, `RootElement` and `Documentation` give
typed foundation construction or inspection. Abstract base/root views require
a concrete element whose schema type derives from that base. Family-specific
process/collaboration APIs follow in group 4; complete choreography,
conversation, DI and opaque vendor data qualification follow in group 5.
Unknown elements or foreign attributes still give an unsupported finding and
prevent typed projection in this slice. Their XML CST remains available.
Structure validation, reference-resource resolution and full traversal follow
in later groups. Reading or writing does not validate all BPMN constraints.

```mbt check
///|
test "construct immutable foundations without inserting defaults" {
  let documentation = @bpmn.Documentation::new([Text("Review & approve")])
  let process = @bpmn.Element::new(Process, attributes=[("id", "P")], children=[documentation.element])
  let definitions = @bpmn.Definitions::new("urn:example", children=[process])
  let document = definitions.document()
  assert_eq(definitions.roots()[0].base().id(), Present("P"))
  assert_eq(process.boolean("isExecutable"), Absent)
  assert_eq(documentation.text_format(), Absent)
  let compact = @bpmn.write(document)
  let pretty = @bpmn.write(document, format=Pretty)
  assert_false(compact.contains("textFormat"))
  assert_eq(@bpmn.read(compact).document, Some(document))
  assert_eq(@bpmn.read(pretty).document, Some(document))
}
```

`Field[T]` distinguishes `Absent`, `Present(value)` and `InvalidValue(scalar)`.
Absent schema defaults stay absent. Booleans, identifiers, URIs, exact integers,
exact numeric tokens, references and generated enumeration alternatives have
separate `Scalar` cases. `ExactNumber` retains the DI token without passing
through a host float. Decimal fractions and exponent tokens therefore keep all
digits. XML Schema double also admits `INF`, `-INF` and `NaN`;
`is_finite()` distinguishes them. `ExactInteger` has no host integer-size limit;
fields declared as XML Schema `int` enforce its signed 32-bit range. String
whitespace is retained; token, URI, numeric and reference types apply their
schema whitespace policy. Invalid scalar spellings remain inspectable in a
typed document with findings, and cannot be written as valid values.

References retain original spelling plus expanded namespace identity.
`ReferenceKind::Id` uses a local NCName; `QName` resolves prefixes against explicit
bindings. No external document is opened. Construct references from an
`ExpandedName` to avoid inventing a source prefix. `Element::new` accepts string
attributes with explicit local `bindings`; `Element::from_values` accepts typed
attributes, optional typed scalar text and ordered content. A local child name
whose schema type depends on its parent needs an explicit `value_type` when
constructed outside that context. The writer rejects a missing or conflicting
type identity instead of producing a document that reads back differently. An explicit type override adds the corresponding
`xsi:type` reference so it survives serialization. No IDs or DI are generated.

```mbt check
///|
test "constructed references carry expanded identity" {
  let source = @bpmn.Reference::new(@bpmn.ExpandedName::new("urn:other", "Task"))
  let flow = @bpmn.Element::from_values(MessageFlow, values=[
    @bpmn.Attribute::new(@bpmn.ExpandedName::new("", "sourceRef"), Reference(source)),
  ])
  let document = @bpmn.Definitions::new("urn:example", children=[flow]).document()
  let xml = @bpmn.write(document)
  assert_true(xml.contains("xmlns:ns1=\"urn:other\""))
  assert_true(xml.contains("sourceRef=\"ns1:Task\""))
  assert_eq(@bpmn.read(xml).document, Some(document))
}
```

## Equality, source reproduction and canonical output

Document equality compares standard kind/type, expanded attribute names, typed
scalar values and ordered semantic content. It ignores source spans, raw prefix
aliases, attribute ordering and element-only formatting whitespace. Adjacent
text/CDATA normalize to text values. Mixed content, comments, processing
instructions and inherited `xml:space` are retained. Exact number tokens compare
exactly. Namespace aliases on known QName values compare by expanded identity.

`tree.text()` reproduces the source bytes represented by the decoded string,
including quote style, CDATA, declarations and invalid regions. `write` produces
this library's deterministic XML format, not XML C14N. The default is compact;
`format=Pretty` uses two spaces for element-only content. Both keep mixed text
and containment order. Pretty output adds no whitespace inside mixed content,
scalar elements or an inherited `xml:space='preserve'` scope.

Canonical namespaces use `bpmn`, `bpmndi`, `dc`, `di`, `xml` and `xsi` for known
URIs, and `ns1`, `ns2`, ... for other used QName identities in sorted URI order.
Used bindings are declared at the root. Unused aliases disappear. Attributes
sort by namespace URI, then local name. Namespace names are literal strings;
they do not trigger I/O. Known QName tokens are rewritten with matching
bindings. Opaque vendor subtree namespace preservation is completed in group 5.

```mbt check
///|
test "source reproduction and canonical writing serve different purposes" {
  let source = "<d:definitions xmlns:d='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:example'><d:process id='P'/></d:definitions>"
  let result = @bpmn.read(source)
  assert_eq(result.tree.text(), source)
  let document = result.document.unwrap()
  let canonical = @bpmn.write(document)
  assert_false(canonical == source)
  assert_eq(@bpmn.read(canonical).document, Some(document))
  assert_eq(@bpmn.write(@bpmn.read(canonical).document.unwrap()), canonical)
}
```

## Writer failures and limits

`try_write(document, format?, limits?)` returns `WriteResult` with either complete
output or diagnostics. It never exposes a partial buffer. `write` is a convenience
API that returns the string or raises `WriteError::Failed(diagnostics)`.
This adds a checked error to the earlier provisional convenience API.

The writer checks XML names/characters, namespace bindings, duplicate expanded
attributes, typed scalar consistency, comments and processing instructions.
It rejects unbound QName references, invalid scalars and incompatible `xsi:type`
values. Namespace bindings must obey XML reserved-prefix rules. Comments cannot
contain `--` or end with `-`. Comment/PI CR and leading PI data whitespace are
rejected because XML normalization would change their value. Construct text CR
is preserved through a character reference instead.

```mbt check
///|
test "invalid QName binding returns an explicit failure" {
  let flow = @bpmn.Element::new(MessageFlow, attributes=[("sourceRef", "missing:T")])
  let document = @bpmn.Definitions::new("urn:example", children=[flow]).document()
  let result = @bpmn.try_write(document)
  assert_eq(result.output, None)
  assert_eq(result.diagnostics[0].code, "bpmn/unbound-qname")
  let reserved = @bpmn.Element::new(Definitions, bindings=[("xml", "urn:wrong")])
  assert_eq(@bpmn.try_write(@bpmn.Document::new(reserved)).diagnostics[0].code, "bpmn/namespace-conflict")
}
```

The writer uses explicit stacks for preflight and emission, including very deep
constructed documents. It checks depth and node/attribute/binding counts before
descending. It bounds complete output and individual escaped tokens before
appending. Canonical namespace declarations count toward output records. Input
and output record counts each obey `nodes`; neither is the sum of both passes.
Pretty indentation also obeys the token/output bounds. Limits must be positive;
`source_units` applies to reading, while `output_units` applies to writing.
Writer failure produces one error with an optional original span. Constructed
values have no invented source location.

Writer codes are `bpmn/output-limit`, `bpmn/write-node-limit`,
`bpmn/write-depth-limit`, `bpmn/write-token-limit`, `bpmn/write-invalid-limits`,
`bpmn/forbidden-text`, `bpmn/invalid-name`, `bpmn/namespace-conflict`,
`bpmn/invalid-scalar`, `bpmn/scalar-type-mismatch`, `bpmn/unbound-qname`,
`bpmn/type-conflict`, `bpmn/duplicate-attribute`, `bpmn/invalid-content`,
`bpmn/invalid-comment`, `bpmn/invalid-pi`, `bpmn/outside-root`,
`bpmn/definitions-required`, `bpmn/unsupported-element`, `bpmn/unsupported-type`
and `bpmn/unsupported-attribute`. Lowering also uses `bpmn/invalid-scalar`,
`bpmn/unbound-qname`, the unsupported codes and `bpmn/definitions-required`.
These findings do not change the XML CST's completeness. A simple `walk` visits
containment in preorder and never follows reference attributes.
