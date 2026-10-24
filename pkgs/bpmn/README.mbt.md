# moonrockz/bpmn

Portable BPMN document values, source reproduction, writing and containment
walking. This module imports only MoonBit core. It performs no host I/O and has
no dependency on diagrams, renderers or UI frameworks.

This first slice supports definitions, one or more process elements, generic
tasks, start/end events, sequence flows, incoming/outgoing text and the DI
plane/shape/bounds/edge/waypoint vocabulary. Reading does not yet validate the
BPMN schema. Unsupported elements, mixed text and namespaced attributes return
findings with no complete document. Full XML recovery, limits, source maps,
schema-derived types, validation, references and traversal styles follow in
later task groups of `add-bpmn-diagrams-and-animation`.

The initial reader handles namespace bindings, quoted attributes and the five
predefined XML references. Comments, CDATA, numeric references and general
processing instructions await group 2. DTD/entity declarations are rejected.
The input is decoded text; namespace URIs cause no resource access.

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

`Cst::text` reproduces source spelling, including invalid input. `write` emits
compact XML with fixed standard prefixes and ordered attributes/children; it is
separate from reproduction. This initial writer is for valid first-slice values;
the validating canonical/pretty writer follows in group 3. Decimal coordinate
attribute strings retain their exact values. Constructed collections are copied
into read-only arrays. A walk visits containment in preorder and never follows
reference attributes.

Current diagnostics are `xml/outside-root`, `xml/character-reference`,
`xml/prohibited-declaration`, `xml/unclosed-tag`, `xml/mismatched-tag`,
`xml/invalid-tag`, `bpmn/unsupported-content`, `bpmn/unsupported-attribute`,
`bpmn/unsupported-element` and `bpmn/definitions-required`. Each is an error;
source spans are half-open UTF-16 offsets.
