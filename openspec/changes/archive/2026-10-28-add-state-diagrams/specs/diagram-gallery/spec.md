## ADDED Requirements

### Requirement: Qualified state diagram examples

The checked local and published galleries SHALL add a state family with at
least three distinct Mermaid sources and three distinct PlantUML sources.
Across the set, examples SHALL cover simple lifecycles, labelled transitions,
self-loops, composite states, concurrency, choice/fork/join and PlantUML history.
Theme, connector and playback variants SHALL NOT count as distinct sources.

#### Scenario: Browse state coverage

- **WHEN** a reader opens the state gallery family
- **THEN** at least six distinct sources are available, each labelled with its format and scope and linked to a stable detail page

### Requirement: State source previews and players

Each state example SHALL provide exact source, adaptive/light/dark script-free
SVG and a qualified offline player through the checked artifact pipeline.
Details SHALL offer existing preview/source controls, source copy/download and
SVG downloads. Labels SHALL describe structural playback and supplied scenarios
without claiming event processing, guard evaluation or history restoration.

#### Scenario: Inspect a history example

- **WHEN** a reader opens the PlantUML history example
- **THEN** source, themed SVG downloads and the offline player are available and the page states that history is descriptive rather than restored by execution

### Requirement: State guides and gallery compatibility

Guides SHALL describe pinned syntax profiles, refusals, model construction,
geometry, connector options, playback/query limits and exhaustive enum migration.
State pages SHALL obey versioned base paths, no-script/narrow browsing and both
themes. Existing IDs, family anchors, routes, source and static SVG bytes SHALL
remain unchanged. Shared player updates SHALL be qualified separately.

#### Scenario: Versioned no-script browsing

- **WHEN** root and next state pages open without JavaScript at 360 CSS pixels in either theme
- **THEN** preview, source, scope and downloads remain readable and all detail/asset/player links resolve in the selected version tree

#### Scenario: Existing gallery regression

- **WHEN** the checked gallery inventory and prior artifact digests are compared after state support
- **THEN** all existing examples retain their URLs, source and SVG bytes and any shared-player HTML changes match reviewed runtime snapshots
