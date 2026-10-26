# Spec Delta

## Purpose

Represent patterns and grammars as immutable values whose meaning survives
format conversion, drawing and structural exploration.

## ADDED Requirements

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
