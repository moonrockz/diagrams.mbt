# bpmn-documents Specification

## Purpose
Read, inspect and write BPMN documents independently of diagram rendering,
while preserving source text, document meaning and extension content.

## Requirements

### Requirement: Independent portable BPMN module

The `moonrockz/bpmn` module SHALL read, construct, validate and write BPMN 2.0.2
documents without importing a diagram, renderer, browser or host I/O module.
Its public document values SHALL be immutable. Its operations SHALL give equal
results on wasm, wasm-gc, js and native for equal inputs.

#### Scenario: A consumer needs only BPMN

- **WHEN** a fresh consumer imports only `moonrockz/bpmn` and core libraries
- **THEN** it can read a process, inspect a task, construct a changed document and write that document on all four targets
- **AND** the original document remains equal to its value before the change

### Requirement: Lossless source reproduction

Reading SHALL retain an owned CST whose reproduction equals the input text,
including malformed text. CST spans SHALL partition the source without loss.
Source reproduction SHALL be separate from writing a typed document.

#### Scenario: Source spelling is retained

- **WHEN** a document contains CRLF, comments, processing instructions, CDATA, entity references, namespace aliases and mixed attribute quotes
- **THEN** CST reproduction returns exactly the original text

#### Scenario: Invalid XML is retained

- **WHEN** the source has a mismatched closing tag followed by another invalid element
- **THEN** reproduction returns the complete source and reading reports both recoverable errors
- **AND** the result does not expose an apparently valid complete document

### Requirement: Namespace-aware XML reading

Reading SHALL identify XML elements and attributes by namespace URI and local
name. It SHALL distinguish unqualified attributes from namespaced attributes,
resolve namespace scopes and decode XML character references. It SHALL report
undeclared prefixes, duplicate expanded attribute names and invalid XML text.

#### Scenario: Equivalent BPMN namespace prefixes

- **WHEN** two valid sources differ only in the prefix bound to the BPMN model namespace
- **THEN** reading gives equivalent typed BPMN values
- **AND** each CST reproduces its own source spelling

#### Scenario: Two prefixes give a duplicate attribute

- **WHEN** two attributes have different prefixes bound to the same namespace and the same local name
- **THEN** reading reports a duplicate-attribute error at the second attribute

### Requirement: Typed BPMN document coverage

The document model SHALL represent BPMN 2.0.2 semantic elements, attributes,
containment and references, including processes, collaborations, choreography
and conversations. It SHALL keep present values, absent values, child order,
documentation, expressions and identifiers. It SHALL NOT insert absent defaults
or evaluate expressions while reading or writing.

#### Scenario: A process and its flow elements

- **WHEN** a process contains a user task, a boundary timer event, an exclusive gateway, sequence flows and a nested subprocess
- **THEN** the typed document exposes their kinds, attributes, containment and references in source order

#### Scenario: Choreography and conversation are document values

- **WHEN** a document contains a choreography task with participant references and a collaboration with a conversation node and links
- **THEN** callers can inspect, construct, write and traverse those typed elements without a renderer

#### Scenario: An absent default stays absent

- **WHEN** a document omits an optional Boolean attribute that has a schema default
- **THEN** the model records its absence and writing does not add the attribute

### Requirement: Diagram interchange data

The model SHALL keep BPMN diagram interchange planes, shape bounds, edge
waypoints, label bounds and display flags, with their element references. It
SHALL keep decimal values without loss of precision during document reading and
writing. A document SHALL be valid input without diagram interchange data.

#### Scenario: Geometry survives a document round trip

- **WHEN** a document has two planes and a waypoint coordinate `123.4567890123456789`
- **THEN** writing and reading keep both planes and that exact decimal value

#### Scenario: A semantic-only document

- **WHEN** a valid process has no diagram interchange elements
- **THEN** the reader returns its typed document without a missing-diagram error

### Requirement: Extension preservation

The document model SHALL retain foreign namespace attributes, extension
elements, mixed content and their namespace bindings. Reading and writing SHALL
preserve their meaning and order without requiring a vendor plugin. Unsupported
elements in a BPMN namespace SHALL be retained and reported with a diagnostic.

#### Scenario: A vendor expression retains its prefix binding

- **WHEN** an extension contains mixed text and an attribute whose value uses a vendor namespace prefix
- **THEN** writing retains that content and a binding that gives the prefix the same namespace URI

#### Scenario: An unknown BPMN element

- **WHEN** an element in the BPMN model namespace has an unknown local name
- **THEN** reading reports that element as unsupported and retains it for reproduction and document writing

### Requirement: Deterministic document writing

The writer SHALL provide documented canonical and pretty formats. Both SHALL
preserve child order, identifiers, references, extensions and present values.
Reading either output SHALL give an equivalent typed document. Writing a read
canonical output again SHALL give identical bytes on all four targets.

#### Scenario: Canonical output is stable

- **WHEN** each valid corpus document is written, read and written again in canonical format
- **THEN** the two canonical outputs have identical bytes and their typed documents are equivalent

#### Scenario: Escaping keeps the value

- **WHEN** a task label contains `<`, `&`, a quote and non-BMP Unicode text
- **THEN** writing produces well-formed escaped XML and reading gives the original label

#### Scenario: Invalid constructed text

- **WHEN** a caller constructs a document with a forbidden XML control character
- **THEN** the writer returns an error and no XML output

### Requirement: Structured diagnostics and source locations

Diagnostics SHALL have stable codes, severity, a message and a source location
when one exists. Locations SHALL use half-open UTF-16 offsets and one-based
lines and columns, with CRLF counted as one line break. Generated values SHALL
be diagnosable without a source location. Reading SHALL retain multiple findings
up to an explicit diagnostic limit.

#### Scenario: A diagnostic follows non-BMP text

- **WHEN** an undeclared prefix follows a non-BMP character on a CRLF-delimited line
- **THEN** its diagnostic points to the correct UTF-16 source slice on all four targets

#### Scenario: A constructed value has no source text

- **WHEN** validation finds a required field missing in a constructed element
- **THEN** the finding identifies the element and field without inventing a source span

### Requirement: Document validation and reference identity

Validation SHALL distinguish XML syntax, BPMN structure and reference findings.
It SHALL detect duplicate IDs, missing required fields, wrong local reference
targets and invalid containment. QName references SHALL use namespace-aware
identity. An unresolved reference SHALL retain its original value and a finding;
it SHALL NOT become a reference to an arbitrary element with the same local name.

#### Scenario: Duplicate task IDs

- **WHEN** two tasks in one document have the same ID
- **THEN** validation reports the duplicate and lookup reports ambiguity

#### Scenario: A flow points to a missing element

- **WHEN** a sequence flow names a missing target
- **THEN** validation reports the flow ID and target value without dropping the flow

#### Scenario: Two imported namespaces share a local name

- **WHEN** two supplied documents define the same local name in different target namespaces
- **THEN** resolving a qualified reference selects only the document with the matching namespace

### Requirement: Explicit external resources

References to imported documents SHALL resolve only against resources that the
caller supplies. Reading, validation and writing SHALL perform no filesystem,
network, clock or environment access. Missing resources SHALL produce a distinct
unresolved-import finding.

#### Scenario: An import was not supplied

- **WHEN** a document imports an HTTP location and the resource set is empty
- **THEN** resolution reports the missing import and makes no network request

### Requirement: Bounded document processing

Reading and writing SHALL accept explicit limits for source/output size, open
element depth, node count, attribute size and diagnostic count. Exceeding a limit
SHALL give a stable limit diagnostic and no successful complete result. DTD and
external entity declarations SHALL be rejected without expansion or resolution.

#### Scenario: A depth limit is reached

- **WHEN** input requires one more open element than the supplied depth limit
- **THEN** reading reports the depth-limit code without a stack overflow

#### Scenario: An external entity is declared

- **WHEN** a source declares an external entity whose URI is a local file
- **THEN** reading reports a prohibited-declaration error, preserves the CST and does not access that file

#### Scenario: Output exceeds its bound

- **WHEN** writing the document would exceed the supplied output limit
- **THEN** the result has a limit finding and no partial XML presented as successful output
