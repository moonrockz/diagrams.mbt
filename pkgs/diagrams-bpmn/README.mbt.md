# moonrockz/diagrams-bpmn

This pure adapter converts `moonrockz/bpmn` documents into the independent
`moonrockz/diagrams/bpmn` visual model. `to_diagram` returns an optional
`Diagram::Bpmn` and ordered diagnostics. `render_svg` reads, converts and calls
the SVG renderer. Neither operation reads files, fetches imports or changes XML.

The converter covers process and collaboration graphical kinds, including typed
tasks, events and their definitions, gateways, subprocesses, expanded process
calls, pools, nested lanes, data, groups, annotations and connections. It dispatches
on the effective schema type, including `xsi:type`. BPMN-looking elements inside
opaque vendor payloads remain inert. Choreography and conversation documents
retain their typed reader/writer/traversal support; selecting them returns
`bpmn/unsupported-view`. They never become generic tasks.

## Select a view

Use `ViewSelector::Process(id)`, `Collaboration(id)` or `Plane(id)`. A plane
selector accepts its plane ID or its parent diagram ID. `View(id)` selects an
identity first and diagnoses a deferred or invalid kind explicitly.

Automatic selection examines planes first, then collaborations, then processes.
The first nonempty tier must contain exactly one candidate. One plane and its
referenced process count as one view. A collaboration includes its participant
processes, rather than competing with them. Multiple matching planes need an
explicit plane selector, even when they refer to the same process.

```mbt check
///|
test "select a semantic process without requiring DI during conversion" {
  let source = "<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:example'><b:process id='P'><b:userTask id='T' name='Review'/></b:process><b:process id='Other'/></b:definitions>"
  let document = @bpmn.read(source).document.unwrap()
  let ambiguous = @adapter.to_diagram(document)
  assert_eq(ambiguous.diagnostics[0].code, "bpmn/ambiguous-view")
  let selected = @adapter.to_diagram(document, selector=Process("P"))
  guard selected.diagram is Some(Bpmn(view)) else { fail("missing process") }
  assert_eq(view.source.source_id, Some("P"))
  assert_eq(view.nodes[0].kind, UserTask)
  assert_eq(view.nodes[0].geometry, None)
}
```

## Render supplied geometry

`render_svg(source, geometry_policy=RequireDi)` paints complete process and
collaboration DI, including the standard graphical kinds and their markers.
The default `PreferDi` uses all supplied geometry when complete; missing or
partial DI gives `bpmn/incomplete-di` and computes the whole view. `RequireDi`
returns no output when required bounds or waypoints are missing. Invalid supplied
geometry is an error under either policy. Legibility warnings preserve authored
positions rather than moving individual elements.

`Automatic` explicitly ignores DI during conversion and geometry generation,
including DI endpoint overrides. It can render semantic input with broken DI.
With an explicit process selector, it does not require choosing between that
process's planes. Automatic layout measures labels, ranks each scope after cycle condensation,
packs lane/group bands and routes orthogonal connections around shapes and labels.
Bounded search failure returns a layout-limit diagnostic without partial output.

Static SVG stays script-free. Labels are escaped text; source IDs, resource keys,
containment paths, visual endpoints and render properties are inert metadata.
See `moonrockz/diagrams-svg/bpmn-layout` for the pure geometry and legibility APIs.

```mbt check
///|
test "render semantic input or require supplied DI explicitly" {
  let source="<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:example'><b:process id='P'><b:userTask id='T' name='Review'/></b:process></b:definitions>"
  let automatic=@adapter.render_svg(source,geometry_policy=Automatic)
  assert_true(automatic.output != None)
  assert_eq(automatic.diagnostics,[])
  let required=@adapter.render_svg(source,geometry_policy=RequireDi)
  assert_eq(required.output,None)
  assert_eq(required.diagnostics[0].code,"bpmn/incomplete-di")
}
```

## Source identities and geometry

`SourceIdentity` keeps the caller's resource key, optional original XML ID and
source-order containment path. Node `id` and flow `id` are unique render IDs.
An uninstanced root element with an XML ID keeps that spelling. Imported elements,
participant instances and anonymous elements use length-prefixed generated IDs.
The original ID stays in `source.source_id` or `identity.source_id`. These IDs are
never written into the document. Multiple input documents may reuse local IDs.

Nodes keep pool/lane/subprocess ownership and boundary attachment. Markers keep
loop mode, compensation, event-subprocess/interrupting flags, collection status,
called activity kind/identity and event definitions. Expressions and timer text
remain descriptions. Group labels resolve category values; category membership is retained in
`Ownership.groups` for automatic group bounds. Data references keep
their referenced name and collection marker. Connections distinguish sequence,
message, association and data-input/output kinds. A many-source data association
has one visual connection per source with a shared original identity. A valid
source-less association has `has_source=false` and no semantic source identity.
No transition or execution outcome is invented.

Flow `semantic_source` and `semantic_target` retain actual document endpoints.
Visual `source`/`target` may identify an owning activity, or a selected DI
`sourceElement`/`targetElement`, for example the boundary of a black-box pool.
A shared process can have distinct participant instances. A reference with several
possible visual instances needs an unambiguous selected DI endpoint; the adapter
returns an ambiguity diagnostic instead of choosing an arbitrary instance.

Selected DI retains exact finite decimal/exponent tokens in `Number`, shape and
label bounds, waypoints, fonts, display flags and endpoint-shape identities.
`bounds`/`points` remain the original integer convenience inputs. Fractional DI
is retained in `geometry`, without rounding it into those convenience fields.
Absence or partial geometry remains explicit for the renderer's whole-view policy.
Multiple DI occurrences for an otherwise identical projected identity return
`bpmn/ambiguous-di`, rather than assigning coordinates by source order.

The core model also accepts caller-supplied `RenderProperties` and `Link` values
through immutable constructors and `with_properties`. Vendor extensions never
supply active styles, markup or links. The model has no dependency on `bpmn`.

```mbt check
///|
test "conversion retains an anonymous node without editing the source" {
  let document = @bpmn.read("<b:definitions xmlns:b='http://www.omg.org/spec/BPMN/20100524/MODEL' targetNamespace='urn:example'><b:process id='P'><b:task/></b:process></b:definitions>").document.unwrap()
  let before = @bpmn.write(document)
  guard @adapter.to_diagram(document).diagram is Some(Bpmn(view)) else { fail("missing process") }
  assert_eq(view.nodes[0].source.source_id, None)
  assert_eq(view.nodes[0].source.path, [0, 0, 0])
  assert_eq(@bpmn.write(document), before)
}
```

## References, findings and limits

Supply `ResourceSet` and optional root `resource_id` explicitly. Import location
keys and target namespaces follow the standalone module's strict QName rules.
Each imported process resolves references using its own import closure. Reused
immutable indexes avoid reparsing XML. No local-ID fallback crosses namespaces.

Malformed or ambiguous selected references prevent a diagram. Findings outside
the selected view remain warnings; an unrelated unresolved import does not block
a self-contained process. `map_diagnostic` preserves diagnostic code/severity
and the source's half-open UTF-16 offsets with one-based lines/columns. CRLF and
non-BMP characters use the same positions as the source reader. Constructed
values have no invented spans. Conversion-specific findings use the affected
element's source location when available.

`Limits` bounds validation, source tokens, depth, diagnostics and conversion
work. Conversion charges index construction, identity paths and indexed field lookups
against `nodes`. Reference fields are indexed once instead of rescanning every
reference for every node. Imported re-resolution charges the existing resource closure's record
count before rebuilding its resolver. Exhaustion returns no partial diagram.
`bpmn/conversion-limit` differs from unresolved or unsupported input.

Conversion adds these codes to the standalone module's validation codes:

- `bpmn/view-not-found`, `bpmn/missing-plane`, `bpmn/ambiguous-view`,
  `bpmn/ambiguous-plane`, `bpmn/unsupported-view` and `bpmn/unsupported-element`.
- `bpmn/invalid-reference`, `bpmn/ambiguous-endpoint`, `bpmn/ambiguous-di`,
  `bpmn/duplicate-id`, `bpmn/invalid-geometry` and `bpmn/conversion-limit`.

The checked graphical coverage manifest is
`tests/corpus/bpmn-model/graphical-coverage.json`. Its embedded copy is checked
against the converter inventory and a concrete assertion for each of the 38
standard graphical kinds. Additional assertions cover all ten event-definition
symbols, ownership, markers, imports, exact DI and deferred views. Non-graphical
implicit throw events remain in multi-instance descriptions, without invented
visible event shapes. Base
`tDataAssociation` has no standalone global element; an invalid `xsi:type`
downcast is diagnosed, while its two concrete association declarations convert.

## Match and constructor migration

Adding `Bpmn` to the public `moonrockz/diagrams/render.Diagram` enum changes source
compatibility for exhaustive matches. Add a `Bpmn(view)` case or return an
unsupported-kind renderer result. Existing sequence constructors and SVG bytes
remain unchanged. In the provisional BPMN constructors, pass integer convenience
geometry as `bounds=` or `points=`; use `geometry=` for exact selected DI.
No version change, release or module publication is part of this change.
