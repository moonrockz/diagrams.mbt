# Frozen BPMN 2.0.2 inputs

The five XSD files are the normative machine-readable inputs linked by the
[OMG BPMN 2.0.2 specification](https://www.omg.org/spec/BPMN/2.0.2/).
They were fetched on 2026-10-24 without changing their bytes, including CRLF.

| File | Source URL |
| --- | --- |
| BPMN20.xsd | https://www.omg.org/spec/BPMN/20100501/BPMN20.xsd |
| Semantic.xsd | https://www.omg.org/spec/BPMN/20100501/Semantic.xsd |
| BPMNDI.xsd | https://www.omg.org/spec/BPMN/20100501/BPMNDI.xsd |
| DC.xsd | https://www.omg.org/spec/BPMN/20100501/DC.xsd |
| DI.xsd | https://www.omg.org/spec/BPMN/20100501/DI.xsd |
| minimal.bpmn | https://github.com/moonrockz/diagrams.mbt/blob/DamianReeves/bpmn-diagrams-animation/tests/corpus/bpmn-2.0.2/minimal.bpmn |

`minimal.bpmn` is a project-authored start–task–end fixture with complete DI,
licensed under the repository's Apache-2.0 license. It is not an OMG example.
The OMG files remain OMG specification materials; see `NOTICE.md`. They are
unpublished test inputs, not part of the portable module.

`SHA256SUMS` records SHA-256 over the exact UTF-8 file bytes. Run
`mise run validate:bpmn-corpus` to check the files and their embedded test data;
`mise run bpmn-corpus:generate` updates the embedding. Unpublished acceptance
tests compute all six digests again on each of the four targets.

`mise run bpmn-schema:generate` derives the standard kind/type inventory, typed
enumeration alternatives and schema field/group metadata from these five fixed
inputs. It also writes `coverage.json`, with one file/path entry per element or
attribute declaration and the input digests. `mise run validate:bpmn-schema`
checks byte-identical regeneration. The manifest includes 313 element and 195
attribute declarations; the portable acceptance suite independently counts them
through the XML CST and checks generated metadata. Rendering and family-specific
API qualification are separate tasks in the active OpenSpec change.
