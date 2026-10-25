---
title: BPMN and flow animation
summary: Read portable BPMN documents, select views and generate static SVG or offline playback.
order: 2
---
# BPMN and flow animation

Use `moonrockz/bpmn` independently to read, write, validate and traverse BPMN XML.
It depends on MoonBit core only. It retains processes, collaborations,
choreography, conversations, diagram interchange and vendor extensions. Reference
resolution accepts explicit resources; namespace URIs and import locations never
cause network or filesystem access.

The [BPMN document guide](../../pkgs/bpmn/README.mbt.md) has compiled examples for
reading, typed construction, writing, validation, reference indexes and bounded
graph traversal. Syntax, structural and reference diagnostics remain distinct.
Source reproduction keeps the original spelling; canonical writing is deterministic.

## Select and render a view

Use [diagrams-bpmn](../../pkgs/diagrams-bpmn/README.mbt.md) to select a process,
collaboration or diagram plane. Automatic selection requires one view at its
selected tier. Select explicitly when a document has multiple candidate views.
Choreography and conversation documents remain typed, but their rendering is
deferred and produces an explicit diagnostic.

The [SVG guide](../../pkgs/diagrams-svg/README.mbt.md) documents supplied-DI,
preferred-DI and automatic geometry policies. Supplied views preserve exact
coordinates, label bounds and waypoints. Automatic layout deliberately ignores
DI. Limits fail with diagnostics; legibility findings describe supplied geometry
without silently moving it.

![A BPMN process with two lanes, task markers, a timer boundary event, a gateway and data artifacts.](/assets/examples/bpmn-process-di-supplied-light.svg)

Compare the process in [dark](/assets/examples/bpmn-process-di-supplied-dark.svg)
and [light](/assets/examples/bpmn-process-di-supplied-light.svg), or its automatic
[dark](/assets/examples/bpmn-process-di-automatic-dark.svg) and
[light](/assets/examples/bpmn-process-di-automatic-light.svg) layout.
Read the [process XML](/assets/examples/process-di.bpmn).

The collaboration has an expanded subprocess and a black-box participant. Compare
its supplied [dark](/assets/examples/bpmn-collaboration-di-supplied-dark.svg) and
[light](/assets/examples/bpmn-collaboration-di-supplied-light.svg) views, or the
[collaboration XML](/assets/examples/collaboration-di.bpmn).

## Follow connections offline

[diagrams-animated](../../pkgs/diagrams-animated/README.mbt.md) generates one HTML
artifact with inline SVG, data, styles and runtime. It starts still and needs no
network, external font or UI framework. Its controls support keyboard operation,
reduced motion, hidden-page suspension and static printing. Download SVG returns
the exact canonical static bytes and preserves viewer state.

Open the collaboration player in [dark](/assets/examples/bpmn-collaboration-dark.html)
or [light](/assets/examples/bpmn-collaboration-light.html), the
[automatic process player](/assets/examples/bpmn-automatic.html), or the
[finite concurrent BPMN scenario](/assets/examples/bpmn-concurrent.html).

The finite sequence scenario selects one alternative, repeats a loop twice, and
runs parallel branches. Open it in [dark](/assets/examples/sequence-scenario-dark.html)
or [light](/assets/examples/sequence-scenario-light.html). Unselected messages
remain visible. Repeated participants do not create invented interaction cycles.

The [pure motion guide](../../pkgs/diagrams/animation/README.mbt.md) documents
occurrences, finite serial/parallel plans, explicit branch choices, deterministic
sampling and bounded structural queries. Illustrative flow repeats authored
connections. A structural route is a path over drawn connections. Conditions,
events and gateway synchronization are not evaluated. Neither mode executes a
business process or simulates tokens.

## Review and verify

Run `mise run gallery` and open `_gallery/index.html` for the complete review
set, including XML for choreography and conversation documents. After snapshot
qualification, `mise run gallery -- --existing-output --check --qualify` checks
all stored files, links and browser output without a workspace/site rebuild.
Run `mise run test:animation` for the full offline player qualification.

`mise run gallery -- --site-assets` refreshes the selected site examples from
verified snapshots. Versions and publication remain separate owner decisions.
