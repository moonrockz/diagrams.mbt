# Diagram gallery

The published [gallery](/gallery/) and the local review gallery use checked
renderer output. The original 15 cards keep their IDs and detail routes. The
expanded inventory adds three distinct source examples to each of ten families,
plus six connector comparisons. This gives 51 cards. The comparisons share one
source and do not count toward the 30 additional source examples.

The additional examples cover these structures:

| Family | Additional sources |
| --- | --- |
| Sequence | Authentication retries, worker lifetime, parallel checkout |
| ZenUML | Nested calls and returns, exception cleanup, queue fan-out |
| Architecture | Storage group, group-boundary ports, nested network junction |
| BPMN | Approval loop, cross-pool messages, subprocess boundary timeout |
| Swimlane | Three-team escalation, reverse handoff, nested ownership |
| Flowchart | Mermaid decisions, modern PlantUML fork/repeat, legacy retry |
| Regex | Identifier, alternatives and repetition, assertions and capture |
| EBNF | Commands, recursive lists, protocol fields |
| JSON | API response, nested inventory, exact and repeated values |
| YAML | Deployment map, services list, mixed collections |

Each additional source has fixed light and dark SVG previews, an adaptive SVG
artifact and standalone light and dark players. Source downloads preserve the
reader input. Theme and player variants do not count as distinct sources.

## Compare connector options

The six connector comparison cards use the same Mermaid flowchart. Their titles
and descriptions state the render settings: `ConnectorStyle::Elbow`, `Rounded`
or `Curved`, combined with `CrossingMode::Bridge` or `Plain`. They use
`minimum_approach=24.0`, `corner_radius=8.0` and `bridge_radius=5.0`.

Pass those settings through `SvgRenderer::new`:

```text
SvgRenderer::new(
  connectors=ConnectorOptions::new(
    style=Curved,
    crossing=Bridge,
    minimum_approach=24.0,
    corner_radius=8.0,
    bridge_radius=5.0,
  ),
)
```
Omitting the style retains the diagram family's natural path style. Bridge mode
is the default for unrelated crossings. A crossing never adds graph connectivity.
The offline player follows the resolved display path and downloads its canonical
static SVG.

The fixed dark players and adaptive SVGs are published companion artifacts as
well as local gallery downloads:

| Style and crossing | Comparison card | Dark player | Adaptive SVG |
| --- | --- | --- | --- |
| Elbow, bridge | [Compare](/gallery/connector-elbow-bridge/) | [Play](/assets/examples/connector-elbow-bridge-dark.html) | [SVG](/assets/examples/connector-elbow-bridge-adaptive.svg) |
| Elbow, plain | [Compare](/gallery/connector-elbow-plain/) | [Play](/assets/examples/connector-elbow-plain-dark.html) | [SVG](/assets/examples/connector-elbow-plain-adaptive.svg) |
| Rounded, bridge | [Compare](/gallery/connector-rounded-bridge/) | [Play](/assets/examples/connector-rounded-bridge-dark.html) | [SVG](/assets/examples/connector-rounded-bridge-adaptive.svg) |
| Rounded, plain | [Compare](/gallery/connector-rounded-plain/) | [Play](/assets/examples/connector-rounded-plain-dark.html) | [SVG](/assets/examples/connector-rounded-plain-adaptive.svg) |
| Curved, bridge | [Compare](/gallery/connector-curved-bridge/) | [Play](/assets/examples/connector-curved-bridge-dark.html) | [SVG](/assets/examples/connector-curved-bridge-adaptive.svg) |
| Curved, plain | [Compare](/gallery/connector-curved-plain/) | [Play](/assets/examples/connector-curved-plain-dark.html) | [SVG](/assets/examples/connector-curved-plain-adaptive.svg) |

## Build and verify

Run `mise run gallery -- --site-assets --qualify` to verify the renderer snapshots,
write local and published artifacts, and check local links and players in the
browser. After qualification, `mise run gallery -- --existing-output --check
--site-assets` checks stored artifacts without compiling the renderers again.
Run the site build, link checks and browser suite to qualify root and next routes.

The site supports family navigation without scripting. With scripting, family
and text filters combine and report the resulting count. Each detail page keeps
its preview, exact source and downloads available without scripting, including
at narrow viewport widths.

Players illustrate structure or caller-supplied scenarios. They do not evaluate
conditions, execute workflows or simulate BPMN tokens. Regex matching and EBNF
parsing require an external engine; structural examples do not claim execution
evidence.

## State sources

The state family adds six distinct checked sources, three Mermaid 12.2.0 and
three PlantUML 1.2026.9. The set covers lifecycles, self-loops, composite states,
choice, fork/join, concurrent regions, descriptions, notes, boundary endpoints
and shallow/deep history. Each source has adaptive, light and dark SVG and
standalone finite-scenario players. Source, SVG and player variants do not
count as additional sources.

Run `mise run test:state` to qualify stored source-to-player artifacts offline.
`mise run gallery -- --existing-output --site-assets --qualify` checks their
source bindings, all existing artifacts and browser controls. Root, next and
release-version detail pages offer preview/source controls, source downloads,
SVG variants and offline players, including at 360 pixels without scripting.
See [state geometry and playback](states-and-animation.md) for exact limits and
[Mermaid](mermaid-states.md) and [PlantUML](plantuml-states.md) for source profiles.
State playback does not evaluate guards, execute actions or restore history.
