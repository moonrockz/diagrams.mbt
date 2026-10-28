# Spec Delta

## ADDED Requirements

### Requirement: Moonrockz project branding

The current site SHALL use the selected Lunar drafter badge on its landing page
and the matching bunny-and-pencil icon in its header and favicon assets.
Branding alternative B and C originals and generation prompts SHALL remain
available in the repository. Site asset URLs SHALL follow the active base path
and version tree.

#### Scenario: Open the branded site

- **WHEN** a reader opens the current root or next landing page
- **THEN** the selected A badge, header icon and favicon load without broken links
- **AND** the original B and C images remain in the brand asset directory

### Requirement: Landing page presentation

The landing page SHALL provide a prominent branded introduction, clear links to
getting started, docs, API and gallery, and visual examples of supported diagram
families. Content SHALL distinguish implemented capabilities from planned work
and retain existing semantic limits and heading anchors.

#### Scenario: Browse from the landing page

- **WHEN** a reader opens the page at 360, 768 or 1440 CSS pixels in either theme
- **THEN** the introduction, primary links and examples remain readable without clipped content
- **AND** every primary link resolves within the active version tree unless it explicitly leaves the site

