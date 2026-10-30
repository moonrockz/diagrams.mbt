# bpmn-traversal Specification

## Purpose
Inspect BPMN documents through consistent read-only tree traversal and explicit,
bounded queries over their flow and reference graphs.

## Requirements

### Requirement: Read-only document node view

Traversal SHALL expose node identity, kind, named fields, children, containment
path and an optional source location without copying or changing the document.
It SHALL include choreography, conversation, diagram interchange and preserved
extension content. Node handles SHALL belong to one immutable document revision.

#### Scenario: Locate a nested task

- **WHEN** a caller visits a task inside a subprocess
- **THEN** its view identifies the task kind, ID, parent, containment path and source span when available

#### Scenario: Visit foreign content

- **WHEN** a vendor extension contains two nested elements
- **THEN** the traversal exposes those elements with expanded names and their original child order

#### Scenario: A handle from another revision

- **WHEN** a lookup uses a node handle owned by a different document revision
- **THEN** it reports a document-mismatch error without returning an unrelated node

### Requirement: Consistent traversal styles

The module SHALL provide callback walking, folding, bottom-up reduction, a typed
visitor, pull and push enter/leave events, and a navigable tree cursor. Complete
traversals SHALL agree on containment order and node identity. Default traversal
SHALL visit children in source/model order and SHALL NOT follow reference edges.

#### Scenario: All styles see the same nodes

- **WHEN** each traversal style visits a corpus document without pruning
- **THEN** their normalized enter/leave event sequences and identities are equal

#### Scenario: A reference cycle is not containment

- **WHEN** sequence flows connect tasks `A` to `B` and `B` to `A`
- **THEN** a complete tree walk visits each contained element once and terminates

### Requirement: Traversal control

Traversals SHALL support continue, skip-children and stop decisions. Skipping a
node's children SHALL still leave that node. Stopping SHALL emit no subsequent
enter or leave events. A typed visitor SHALL allow callers to implement only
the node categories they need.

#### Scenario: Skip a subprocess body

- **WHEN** the enter callback skips the children of a subprocess
- **THEN** the traversal emits its leave event, omits its descendants and continues with its next sibling

#### Scenario: Stop on the first user task

- **WHEN** a visitor returns stop at the first user task
- **THEN** no later node or ancestor leave callback runs

### Requirement: Cursor and traversal independence

Each traversal and cursor SHALL keep its own state. A cursor SHALL navigate to
parent, first child and adjacent siblings, and expose the current containment
path. Traversal of a valid document within configured limits SHALL not depend
on the host call-stack depth.

#### Scenario: Two walks over one document

- **WHEN** a callback starts another traversal over the same immutable document
- **THEN** both traversals keep their own order and control state

#### Scenario: Deep containment

- **WHEN** a constructed document has 10,000 nested elements and its configured limit permits them
- **THEN** walking, event reading and reduction complete on all four targets without a call-stack overflow

### Requirement: Explicit graph edge kinds

Graph queries SHALL distinguish containment, sequence flow, message flow,
association and general references. Callers SHALL select the edge kinds and
direction. Queries SHALL return source element identities and SHALL NOT infer
edges from diagram coordinates, labels or XML document order.

#### Scenario: An annotation is not a control-flow step

- **WHEN** a task has an association to an annotation and a sequence flow to another task
- **THEN** a sequence-flow reachability query includes the next task and excludes the annotation

### Requirement: Bounded deterministic graph queries

Reachability and route queries SHALL terminate on cycles and obey explicit node,
edge and result limits. Reachability SHALL return each identity once. A route
query SHALL return one shortest directed route, with document order as its tie
break, or a distinct unreachable, invalid-reference, ambiguous or limit result.

#### Scenario: A reachable cycle

- **WHEN** a graph has `A -> B`, `B -> A` and `B -> C`
- **THEN** reachability from `A` includes `A`, `B` and `C` once and a route to `C` is `A -> B -> C`

#### Scenario: Equal-length routes

- **WHEN** two shortest routes exist and their first edges have different document positions
- **THEN** repeated queries choose the route whose first differing edge appears earlier in the document

#### Scenario: A bound prevents a complete search

- **WHEN** the search exhausts its node limit before it can decide reachability
- **THEN** it reports a limit result and does not report the target as unreachable

### Requirement: Public BPMN query adapter

A public opt-in MoonBit adapter SHALL expose the existing immutable document tree to the shared query core. It SHALL preserve concrete kinds, categories, namespace-aware attributes and containment fields, document order, handle identity and optional locations. The independent BPMN document module SHALL remain usable with only core dependencies.

#### Scenario: Inspect complete document content

- **WHEN** a query searches a document containing processes, choreography, conversations, diagram interchange, comments, processing instructions and vendor extensions
- **THEN** the adapter exposes each retained node in its existing containment position
- **AND** a known kind and an extension with the same local name in a different namespace remain distinct

#### Scenario: A reader-only consumer remains independent

- **WHEN** a fresh consumer imports only the BPMN document module
- **THEN** it retains reading and all existing traversal functions on all four targets without query, diagram, Python or host I/O dependencies

### Requirement: Query and traversal identity agreement

Query captures and projected node views SHALL identify the same immutable document revision and ordinal as the existing traversal. They SHALL not add nodes for absent fields or resolve references as containment. Model-backed values without source text SHALL not acquire invented locations. Handles from another revision SHALL remain distinct failures.

#### Scenario: Match and walk identify the same task

- **WHEN** a walk and a query select the same task in one document tree
- **THEN** their handles, path, attributes and optional location agree
- **AND** rebuilding after a source revision change does not silently reuse the old handle

#### Scenario: Constructed documents remain queryable

- **WHEN** a MoonBit consumer constructs a valid document without source text and queries its tree
- **THEN** the same matching rules apply and source locations remain absent

### Requirement: Published traversal compatibility map

The public consumer documentation SHALL map MoonBit and Python operations for node inspection, handles and paths, walk, fold, reduce, pruned reduce, typed visitors, push/pull events, cursors, and graph lookup, reachability and routes. The map SHALL state defaults, control values, ordering, failures, limits and source units. Missing mapped operations SHALL block a parity claim.

#### Scenario: Compare complete traversal surfaces

- **WHEN** a shared corpus executes each mapped operation in MoonBit and Python
- **THEN** normalized identities, enter/leave order, control effects, fields and outcomes agree
- **AND** Python has no extra domain rule or different default edge selection

#### Scenario: Default visitor methods are free of user callbacks

- **WHEN** a Python visitor implements only the activity method
- **THEN** its event order equals a MoonBit visitor with the same override
- **AND** no Python enter, leave or other family method is invoked as a default

### Requirement: Query selection composes with explicit graph operations

Consumers SHALL be able to use captured BPMN handles as graph endpoints without converting them to ambiguous string IDs. Graph operations SHALL retain their existing edge kinds, direction, deterministic tie breaks, explicit resources and distinct invalid-reference, ambiguous, unreachable and limit outcomes.

#### Scenario: Selected task has a duplicate ID

- **WHEN** a query captures one of two nodes with the same ID and uses its handle as a graph endpoint
- **THEN** the endpoint identifies that node rather than selecting an arbitrary ID match
- **AND** an ID-only lookup still reports ambiguity

#### Scenario: External resources are explicit

- **WHEN** a graph query needs a referenced external document
- **THEN** both consumers use only resources explicitly supplied by the caller
- **AND** an absent resource produces the same failure without filesystem or network access
