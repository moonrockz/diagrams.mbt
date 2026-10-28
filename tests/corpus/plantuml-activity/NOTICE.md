# PlantUML activity reference

The baseline is PlantUML 1.2026.9, source commit
`18d0aae311a4f1eb3723bb4b0ad939185e22f166`. The JAR, source archive,
digests and JDK are pinned in `manifest.json`.

The test-only Java adapter uses upstream instruction trees for modern activity
syntax and upstream ordered entities/connections for legacy syntax. It never
calls MoonBit conversion or infers topology from the library renderer.
The adapter and project-authored fixtures use this repository's Apache-2.0
license. The documentation examples are by the PlantUML project, as identified
in provenance.json and the captured pages. Frozen upstream Java sources retain
their GPL notices; COPYING and LICENSES.md accompany them. They are used only
for compatibility testing and are not imported by published library modules.
