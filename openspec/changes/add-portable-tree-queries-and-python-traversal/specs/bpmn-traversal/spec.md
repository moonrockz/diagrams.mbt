# Spec Delta

## ADDED Requirements

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
