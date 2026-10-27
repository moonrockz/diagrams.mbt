## ADDED Requirements

### Requirement: Smithy-aligned shared site colors

The diagrams.mbt site SHALL inherit the Smithy-aligned default palette from an explicitly published Telescope library and matching CLI release. Landing, docs, API and gallery pages SHALL use a consistent palette in light, dark and system modes. The consumer MUST NOT duplicate shared theme rules to obtain this result.

#### Scenario: Shared palette in a fresh checkout

- **WHEN** a fresh checkout builds the next site using its published Telescope pins
- **THEN** light mode uses background `#f9fafb`, surface `#ffffff`, text `#111827` and accent `#4f46e5`
- **AND** dark mode uses background `#0f1014`, surface `#17181f`, text `#e5e7eb` and accent `#a5b4fc`
- **AND** the site needs no sibling checkout, unpublished dependency or duplicated theme stylesheet

#### Scenario: Consistent reading controls

- **WHEN** a reader switches themes while visiting landing, documentation, API and gallery pages
- **THEN** links, selected navigation, search, code controls and gallery panels remain readable with visible keyboard focus
- **AND** system fallback, stored preferences and reading without JavaScript retain their existing behavior

#### Scenario: Preserve versioned release presentation

- **WHEN** the new next site is assembled with historical release site assets
- **THEN** the new shared presentation applies to the new build under `/diagrams.mbt/next/`
- **AND** historical release assets retain their bytes and the root, latest and minor-version trees retain their accepted roles
