# Supplied BPMN rendering fixtures

These project-authored inputs use the repository's Apache-2.0 license. They are
not copied OMG examples. `SHA256SUMS` freezes their UTF-8 bytes. The corpus task
checks the inventory, digests and portable embedding in `tests/bpmn-corpus/`.

- `process-di.bpmn` has lanes, an exclusive/default branch, a non-interrupting
  timer boundary, a data collection/input association, a category group and an
  annotation. Every required shape bound and connection route is supplied.
- `collaboration-di.bpmn` has a white-box buyer, an expanded subprocess, a
  black-box supplier, a message with a visible envelope and an annotation.

Both pass the frozen BPMN 2.0.2 XSDs with `xmllint --nonet --schema
../bpmn-2.0.2/BPMN20.xsd`. Portable tests check CST reproduction, document round
trips, structural/reference findings, supplied geometry and all three SVG modes.
Their current-renderer snapshots are in
`tests/bpmn-acceptance/__snapshot__/views.json`. Browser qualification reads those
same snapshots and makes no network requests. No condition, timer or script
expression is executed.
