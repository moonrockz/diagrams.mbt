# Spec Delta

## ADDED Requirements

### Requirement: Playback follows styled connectors

Playback bindings SHALL use the final path for the selected connector options,
including smooth curves, rounded corners and crossing bridges. Forward and
reverse motion SHALL follow that path in the resolved direction. Progress,
selection and trace overlays SHALL retain crossing separation and underpass
masks. Styling SHALL NOT change occurrences, graph connectivity or query results.

#### Scenario: Play a curved bridge forward and backward

- **WHEN** a reader plays a curved connection with a bridge and then explores it in reverse
- **THEN** the motion follows the visible curve and bridge in the correct direction in both cases
- **AND** the route retains its original semantic endpoints and occurrence identity

#### Scenario: Highlight the underpass

- **WHEN** a selected or playing connection passes beneath another connection's bridge
- **THEN** its overlay preserves the underpass and does not paint over the bridge as a new joined crossing

#### Scenario: A crossing is not a graph vertex

- **WHEN** two disconnected routes cross and the reader requests reachability between them
- **THEN** the crossing adds no reachable endpoint regardless of connector style

### Requirement: Canonical export retains connector options

Static downloads SHALL equal direct SVG rendering for the same diagram,
connector options and configured trace highlights. Export SHALL preserve viewer
position, selection and speed and exclude transient playback overlays. Every
supported diagram kind SHALL retain offline, keyboard, reduced-motion,
hidden-page and print behavior with the new path styles.

#### Scenario: Download while a bridge is playing

- **WHEN** a reader downloads SVG during curved-bridge playback
- **THEN** the bytes equal direct static rendering, including the bridge and local mask definitions
- **AND** the current occurrence, position, selection and speed do not change

#### Scenario: Styled players without a network

- **WHEN** qualified players for every diagram kind open with network requests blocked
- **THEN** style-specific motion and canonical downloads work without requests or console errors
- **AND** reduced motion, keyboard stepping, page hiding and print retain their existing contracts
