# PlantUML state reference corpus

The source grammar and semantic files are copied from PlantUML commit
18d0aae311a4f1eb3723bb4b0ad939185e22f166, version 1.2026.9.
See upstream/COPYING and upstream/LICENSES.md for licenses. They are test-only
reference inputs, separate from the published MoonBit implementations.

The state documentation was frozen from https://plantuml.com/state-diagram on
2026-10-28. Documentation examples are PlantUML project documentation under
CC BY-SA 3.0, with attribution to PlantUML and Arnaud Roques. All 45 textarea
examples have source and pinned upstream acceptance records. Library refusals
are explicit in expectations.json. Hand-authored feature cases use Apache-2.0.

Reference.java inspects actual upstream state entities, ownership, leaf roles,
boundary positions and transition links. Arrow direction is normalized from
upstream link inversion. Timestamp-named presentation label nodes are collapsed by
following upstream links, keeping their labels on the logical transition.
No expected topology comes from the MoonBit converter or rendered pixels.
