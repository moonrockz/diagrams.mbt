# plantuml-syntax Specification

## Purpose
Read and write PlantUML pattern, grammar and data diagrams without a renderer
runtime, while preserving source text and making compatibility limits explicit.

## Requirements

### Requirement: Native diagram dispatch

The library SHALL read one native regex, EBNF, JSON, YAML or activity block and
return its typed kind. Activity blocks SHALL use `@startuml` and `@enduml`.
Raw body reading SHALL require an explicit kind and, for activities, dialect.
Wrong closing markers, other diagram kinds, extra blocks and trailing
non-trivia SHALL produce diagnostics rather than partial success.

#### Scenario: Dispatch each supported block

- **WHEN** a complete `@startregex`, `@startebnf`, `@startjson` or `@startyaml` block is read
- **THEN** the result identifies its kind and retains its matching closing marker

#### Scenario: Two diagrams in one source

- **WHEN** a source contains two complete blocks
- **THEN** reading diagnoses unsupported multiple blocks instead of rendering only the first

#### Scenario: Dispatch both activity dialects

- **WHEN** modern and legacy activity blocks are read separately
- **THEN** each result identifies an activity document and its dialect and supports printing and flowchart conversion

#### Scenario: Another UML family

- **WHEN** a complete `@startuml` block contains a class or sequence diagram
- **THEN** reading reports an unsupported diagram and returns no activity model or SVG

#### Scenario: Existing body-only callers

- **WHEN** an existing caller supplies a regex, EBNF, JSON or YAML body with its explicit kind
- **THEN** its reading, canonical writing and conversion results retain their existing contracts

### Requirement: Lossless source and locations

Reading SHALL return a CST that reproduces every input code unit within the
source limit, including invalid input, comments and presentation commands.
Diagnostics SHALL use stable codes and half-open UTF-16 spans. Recovery SHALL
respect the body language's quoting and nesting rules.

#### Scenario: Unicode and a malformed statement

- **WHEN** a source with an emoji, CRLF and malformed syntax is read
- **THEN** reproduction equals the source and the finding locates the original code units

### Requirement: Typed regex expressions

The regex AST SHALL cover the pinned profile's literals, escapes, classes,
concatenation, choices, groups, anchors, lookarounds and quantifiers. It SHALL
retain group names, assertion polarity and repetition bounds or modifiers.
Unsupported syntax SHALL remain in the CST and produce an explicit finding.

#### Scenario: An assertion and a repeated group

- **WHEN** a supported pattern contains a named group, a negative lookahead and a bounded repetition
- **THEN** the AST retains the three distinct constructs without treating the assertion as consumed text

### Requirement: Typed EBNF grammars

The EBNF AST SHALL preserve ordered rules, Unicode rule names, terminals,
references, choices, concatenation, grouping, optional terms, repetition,
counts, special sequences, exclusions, empty expressions and notes supported
by the pinned profile. A recursive reference SHALL remain a reference.

#### Scenario: A recursive rule

- **WHEN** a supported grammar refers to its own rule
- **THEN** reading terminates and retains the reference without expanding its definition

### Requirement: Ordered JSON values

JSON reading SHALL retain objects, arrays, strings, booleans, null and exact
number lexemes. It SHALL preserve source member order and duplicate members in
the AST. It SHALL diagnose invalid escapes and numbers without coercing them
through a floating-point value.

#### Scenario: Precision and repeated member names

- **WHEN** an object has a large integer and two members with the same name
- **THEN** its AST retains the integer spelling and both member occurrences in order

### Requirement: Native PlantUML YAML semantics

YAML diagram reading SHALL follow the published PlantUML profile for indentation,
collections, quotes, comments and scalar text. It SHALL retain the pinned
diagram semantics rather than apply an unrelated YAML schema. Unsupported
features and upstream refusals SHALL be documented and diagnosed explicitly.

#### Scenario: A scalar resembles a boolean

- **WHEN** the supported YAML body contains `enabled: true`
- **THEN** conversion retains the native diagram's string value rather than creating a JSON boolean

#### Scenario: YAML-looking reference syntax

- **WHEN** a scalar contains anchor, alias or tag spelling
- **THEN** it stays literal if the pinned profile treats it as text, or gives the documented refusal
- **AND** reading does not expand aliases, load resources or construct objects

### Requirement: Presentation metadata is separate

The AST SHALL retain supported titles, notes, highlight selectors and style
metadata. Highlight paths SHALL preserve quoted segments and array indices.
Conversion SHALL apply documented semantic highlights and diagnose unresolved
selectors or unapplied presentation settings without executing author content.

#### Scenario: A key contains a slash

- **WHEN** a highlight selects a quoted member name that contains `/`
- **THEN** the slash stays within that segment and does not select another member path

### Requirement: Canonical writing reflects typed values

Canonical writing SHALL derive output from the typed AST, with deterministic
formatting and escaping. Reading that output SHALL preserve the logical AST
apart from source locations and trivia placement. Repeated writing SHALL be
stable. Output-limit failure SHALL return a diagnostic without partial output.
An unrepresentable typed value SHALL give a diagnostic rather than stale source.

#### Scenario: Edit a parsed value

- **WHEN** a caller changes a typed terminal or scalar and writes the AST
- **THEN** the output contains that change and reads back to the changed logical value

### Requirement: Pure bounded processing

Reading, writing and conversion SHALL use explicit positive source, depth,
node, work, diagnostic and output bounds. They SHALL terminate without implicit
I/O. Preprocessor directives that request execution or external input SHALL
produce errors. Failed conversion or rendering SHALL not return successful
empty output.

#### Scenario: An include directive

- **WHEN** source contains an include or macro-execution request
- **THEN** the CST retains it, conversion reports an unsupported directive, and no file or network access occurs

#### Scenario: Excessive nesting

- **WHEN** nesting exceeds the supplied limit
- **THEN** processing reports limit exhaustion before a stack overflow or partial render

### Requirement: Published compatibility profile

The library SHALL publish a versioned feature and refusal inventory for regex,
EBNF, JSON, YAML and both activity dialects. The baseline SHALL remain PlantUML
`1.2026.9`. The inventory SHALL separate native acceptance, literal-data
handling, library safety refusals and unsupported presentation features.
Portable results SHALL agree on all four targets.

#### Scenario: A documented example is refused upstream

- **WHEN** a frozen documentation example fails in the pinned reference
- **THEN** its fixture records that refusal and reason instead of claiming supported syntax or omitting the example

#### Scenario: Activity coverage is separate

- **WHEN** a reader inspects the compatibility inventory
- **THEN** modern activity, legacy activity and the four existing native block kinds have separately checkable coverage and refusal records
