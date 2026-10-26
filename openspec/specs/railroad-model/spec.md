# railroad-model Specification

## Purpose
Represent patterns and grammars as immutable values whose meaning survives
format conversion, drawing and structural exploration.

## Requirements

### Requirement: Separate pattern and grammar values

The library SHALL expose format-independent regex and EBNF models and accept
both through the shared renderer contract. It SHALL preserve expression order,
rule order, titles, notes and typed semantic distinctions. Public collections
SHALL be immutable and independent of mutable constructor inputs.

#### Scenario: Construct a grammar without PlantUML

- **WHEN** a caller constructs a grammar and later changes the arrays passed to its constructor
- **THEN** the grammar retains its original rules and can render without a PlantUML reader

### Requirement: Pattern operators retain their roles

Pattern values SHALL distinguish consumed atoms, choices, grouping, repetition
and zero-width constraints. They SHALL retain bounds, names, modifiers and
assertion descriptions without evaluating a regex or expanding repetitions.

#### Scenario: A large finite repeat

- **WHEN** a constructed expression repeats an atom one million times
- **THEN** the model stores the bound without creating one million atom occurrences

#### Scenario: Negative lookahead

- **WHEN** a pattern includes a negative lookahead
- **THEN** the model marks it as a constraint rather than an alternative consuming branch

### Requirement: Grammar references and restrictions

Grammar values SHALL retain named definitions, references, empty expressions,
special sequences and exclusions. Reference lookup SHALL report missing or
ambiguous definitions while keeping named nonterminals renderable without a
fabricated target. Recursive references SHALL be permitted without automatic
expansion. Exclusions SHALL remain constraints on their left term.

#### Scenario: Undefined rule

- **WHEN** a grammar refers to a rule that has no definition
- **THEN** validation identifies the reference and missing name
- **AND** rendering keeps the unresolved nonterminal visible

#### Scenario: A recursive exclusion

- **WHEN** a grammar contains recursion and a term excluded from another term
- **THEN** validation terminates and retains the exclusion without turning the excluded term into an accepted branch

### Requirement: Stable occurrence identity and validation

Each rule, expression occurrence and constraint SHALL have stable identity
within its view. Equal text in different positions SHALL not merge identities.
Constructed-model validation SHALL check ownership, references, repetition
bounds and explicit resource limits and report errors without partial output.

#### Scenario: Equal terminals in different branches

- **WHEN** two branches contain the same terminal text
- **THEN** selection and diagnostics distinguish the two occurrences

#### Scenario: A malformed constructed expression

- **WHEN** a caller supplies invalid bounds or a cycle in expression containment
- **THEN** validation reports the invalid model without recursing indefinitely

### Requirement: Immutable external trace evidence

The library SHALL expose immutable regex/EBNF trace values separate from the
diagram. They SHALL retain attempt identity, ordered path/visit occurrences,
orientation, supplied outcomes, optional input spans and failure points.
Repeated or backtracked occurrences SHALL not be merged. Unvisited alternatives
SHALL not be classified as failed without supplied evidence.

#### Scenario: Failure after a matched prefix

- **WHEN** a supplied attempt traverses two terminals and rejects the next terminal
- **THEN** its traversed prefix and failure terminal remain independently addressable

#### Scenario: One occurrence belongs to different attempts

- **WHEN** a connector appears in a failed attempt and a later successful attempt
- **THEN** both attempt memberships and their order are retained

### Requirement: External matching and parsing provider trait

The library SHALL expose a publicly implementable trait that accepts a typed
regex or EBNF subject, input, view identity and explicit limits and returns
trace evidence. EBNF requests SHALL identify a start rule. Results SHALL
distinguish matched, non-matched, unsupported, exhausted and error outcomes.
No production matching/parsing engine SHALL be bundled.

#### Scenario: Consumer implements a regex-only provider

- **WHEN** a separate consumer implements the trait for regex requests
- **THEN** it can supply trace data for rendering and return unsupported for EBNF requests without implementing a dummy EBNF matcher

#### Scenario: Provider exhausts its budget

- **WHEN** a provider cannot finish within the requested budget
- **THEN** it returns exhaustion rather than a non-match

### Requirement: Source-bound trace validation

Trace validation SHALL check subject kind, model/view identity, occurrence and
connector targets, declared step continuity, input-span bounds and explicit
trace budgets. It SHALL reject stale or invalid evidence without label-based
target guessing. It SHALL validate structure without computing or verifying a
regex match or grammar parse.

#### Scenario: Same labels in another grammar

- **WHEN** a trace for one grammar is supplied with another grammar that has equal terminal labels
- **THEN** validation reports the source mismatch rather than highlighting equal text in the other grammar

#### Scenario: Invalid failure position

- **WHEN** a supplied failure span exceeds the input's UTF-16 bounds
- **THEN** validation reports the invalid span without producing highlighted output
