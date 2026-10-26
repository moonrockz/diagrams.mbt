# diagram-icons Specification

## Purpose
Identify and render participant and architecture symbols consistently in
portable standalone diagram artifacts without resource lookup at runtime.

## Requirements

### Requirement: Immutable namespaced icon references

Icon references SHALL be immutable values with namespace and key, independent
of participant semantic kind and source grammar. Known aliases SHALL resolve
according to the frozen catalog while the source AST retains declared spelling.
References SHALL not contain executable markup or require I/O to resolve.

#### Scenario: An icon and a semantic kind coexist

- **WHEN** a participant has a database kind and a PostgreSQL icon reference
- **THEN** both values remain available and changing render kind does not erase the icon

### Requirement: Complete frozen annotator catalog

The library SHALL render every icon key and alias in the frozen ZenUML core
3.47.9 participant registry, including UML, cloud, application and technology
symbols. Catalog records SHALL identify source, asset digest, licence and
required attribution. Coverage SHALL use the participant registry, not the
smaller upstream static SVG icon map.

#### Scenario: Every registered annotator

- **WHEN** each key in the frozen registry is rendered as a participant annotator
- **THEN** it resolves to its registered symbol without an unknown-icon warning or generic fallback

#### Scenario: Representative symbol families

- **WHEN** a diagram uses Actor, Boundary, Control, Entity, Database, EC2, Lambda, AzureFunction, BigQuery, PostgreSQL and Kubernetes annotators
- **THEN** each renders its matching symbol and retains its participant label

### Requirement: Built-in architecture symbols

Architecture icons `cloud`, `database`, `disk`, `internet` and `server` SHALL
render without caller registration. Group and service labels SHALL remain
readable when a symbol is present or absent. Quoted service icon text SHALL
render as escaped text and SHALL not be treated as an external asset address.

#### Scenario: Architecture defaults

- **WHEN** groups and services use each of the five built-in icons
- **THEN** each shows its corresponding inline symbol in fixed dark, fixed light and adaptive output

### Requirement: Unknown symbols remain visible

An unresolved annotator or architecture icon SHALL produce a stable warning
that names its key and affected element. Output SHALL keep the label and use a
visible generic symbol that identifies the unresolved name. It SHALL not fetch
an asset, execute markup or silently substitute another registered icon.

#### Scenario: An unregistered icon pack

- **WHEN** an architecture service uses `custom:missing` with no bundled definition
- **THEN** output shows its label and unresolved icon name with a warning and performs no network request

### Requirement: Standalone vector output and isolation

Symbols SHALL use inline vector geometry with no scripts, external references
or icon fonts. Only used symbols SHALL appear in output definitions. Local
definitions SHALL respect the output ID prefix. The same inputs SHALL give
identical symbol bytes on all four targets.

#### Scenario: Repeated and separate inline diagrams

- **WHEN** one symbol repeats in a diagram and a second diagram uses a different ID prefix
- **THEN** the first diagram shares its local definition and the second has isolated definitions without ID collisions

### Requirement: Symbol legibility and accessible identity

Symbol bounds SHALL take part in layout measurement and overlap checks. Labels
SHALL not overlap symbols. Symbol identity SHALL be available as accessible text
without replacing the participant/service name. Symbols SHALL remain visible
in both themes, with provider colours retained where required by their assets.

#### Scenario: Long alias and sublabel

- **WHEN** an annotated participant has a long alias and a render sublabel
- **THEN** its icon, alias and sublabel fit the measured header and remain readable without overlap in dark and light output

### Requirement: Symbols survive playback and export

Animated display and downloaded static SVG SHALL retain all symbols from the
canonical static diagram. Playback, selection and theme changes SHALL not
replace an annotated participant with a plain box or fetch a resource.

#### Scenario: Export an annotated sequence during playback

- **WHEN** a reader downloads SVG while an annotated ZenUML sequence is playing
- **THEN** the SVG equals a direct static render with the same symbols, model, theme and options
