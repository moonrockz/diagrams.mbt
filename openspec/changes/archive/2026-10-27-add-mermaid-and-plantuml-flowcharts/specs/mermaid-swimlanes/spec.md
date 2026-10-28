# Spec Delta

## MODIFIED Requirements

### Requirement: Mermaid kind dispatch and compatibility

The library SHALL provide a read/print interface that dispatches supported
Mermaid diagram kinds by header, including flowcharts. Existing
sequence-specific read, print, conversion and result types SHALL retain their
contracts. The SVG convenience operation SHALL dispatch sequence, swimlane,
ZenUML, architecture and flowchart source and preserve failure diagnostics
without returning empty text as successful output.

#### Scenario: Read both supported Mermaid kinds

- **WHEN** the dispatching API receives a sequence source and a swimlane source
- **THEN** it returns the appropriate typed variant for each and their CSTs reproduce the respective inputs

#### Scenario: Existing sequence consumer

- **WHEN** an existing consumer compiles and runs its sequence-only reading and printing examples unchanged
- **THEN** the examples retain their existing types and results

#### Scenario: Unsupported Mermaid header

- **WHEN** the dispatching API receives an unsupported diagram header such as `classDiagram`
- **THEN** it reports the unsupported kind and returns no model or rendered output

#### Scenario: Flowchart dispatch

- **WHEN** the dispatching API receives ordinary `flowchart` or `graph` source
- **THEN** it returns a typed flowchart variant, reproduces its source, supports canonical printing and renders it through the flowchart model

#### Scenario: Swimlane ownership remains unchanged

- **WHEN** the same subgraph body is read under `swimlane-beta` and `flowchart`
- **THEN** the swimlane conversion retains its existing responsibility lanes while the flowchart conversion retains ordinary groups
