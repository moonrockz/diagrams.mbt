# Process and collaboration fixtures

These project-authored BPMN documents and their reference JSON are unpublished
test inputs under the repository's Apache-2.0 license. They are not OMG examples.
The normative inputs remain the five unchanged OMG schemas in `../bpmn-2.0.2`.

- `activities.bpmn` exercises generic and specialized tasks, global tasks,
  subprocesses, ad-hoc and transaction scopes, calls, standard/multi-instance
  loops, expressions and shared definitions.
- `events.bpmn` exercises start/end, intermediate catch/throw, boundary events,
  all concrete event-definition families, gateways and conditional flows.
- `collaboration.bpmn` exercises pools, participants, nested lanes, message/data
  connections, I/O sets, resources/roles, artifacts and an explicit import.
- `choreography-conversation.bpmn` exercises choreography tasks, sub/call/global
  forms, participant associations, conversations, nested/call/global forms and
  links. Their rendering is explicitly deferred.
- `di-views.bpmn` exercises two planes, shape/label bounds, edge waypoints, fonts,
  display flags and choreography bands with exact decimal/exponent tokens.
- `minimal.reference.json` qualifies the original frozen complete-DI fixture.

Run `mise run validate:bpmn-corpus` to verify exact digests and portable test
embeddings. Run `mise run bpmn-corpus:reference` to refresh the independent
references, digests and embeddings. The latter uses `bpmn-moddle@10.3.1`, with
its transitive dependencies frozen by `tests/bpmn-reference/bun.lock`. It reads
only these supplied files. Normal tests do not install the reference package.
No namespace or import location is fetched. Neither the task nor the portable
module executes script, condition, timer or loop descriptions.

## Comparison rules

The reference adapter records its version, source digest and normalizations in
each JSON file. Unexpected reference warnings fail the refresh.

- Compare explicit own properties. Reference schema defaults do not add fields
  to the MoonBit document, and absent source fields remain absent.
- Reference targets compare as local IDs for these self-contained fixtures.
  `CallActivity.calledElement`, `ItemDefinition.structureRef` and implementation
  names are external QName spellings in the reference model and compare as
  strings. Namespace-aware identity is tested separately by the portable suite.
- All contained objects compare by their BPMN/DC/DI type, parent key and sorted
  direct child keys. Named objects use their ID. Anonymous objects use their
  parent, type and ordinal. Sorted keys avoid a claim that the reference's
  schema-property iteration is the original source order. Our source order and
  canonical/pretty round trips are checked separately.
- Attribute, inert body and reference values compare for every normalized
  object. Script/text child wrappers normalize to the reference's string fields.
  DI bounds and waypoints are included. The reference uses JavaScript Number,
  so numeric comparison uses IEEE-754 values; independent exact-token laws keep
  arbitrary integer and DI numeric precision in the portable document.

The normative `tGlobalScriptTask` has a `script` child. Version 10.3.1 of the
reference instead models it as an attribute. For the one frozen fixture, the
adapter explicitly projects that child to the equivalent reference attribute
before parsing and records the projection. The source digest covers the
original normative document. A typed fixture assertion and both-format round
trips verify that our module keeps its child form and exact script text.

Sources: [normative Semantic.xsd](https://www.omg.org/spec/BPMN/20100501/Semantic.xsd),
[reference model](https://github.com/bpmn-io/bpmn-moddle/blob/v10.3.1/resources/bpmn/json/bpmn.json).

Two additional reference-model differences apply to the choreography fixture.
The normative ConversationNode `messageFlowRef` child is named `messageFlowRefs`
in bpmn-moddle. The adapter projects the one fixture tag for reference parsing
and normalizes the reference field name back. Normative ParticipantAssociation
inner/outer references are children; bpmn-moddle models attributes. The adapter
projects those simple fixture references to attributes. Each projection is
recorded in the reference JSON. Portable typed assertions and round trips use
the original normative child forms, so the reference does not narrow coverage.

Opaque vendor XML has separate portable tests for mixed content, inherited and
unused bindings, shadowing, copied scopes, unbound prefixes, unknown standard
elements/types and namespace limits. These tests do not delegate vendor
semantics to the reference library.
