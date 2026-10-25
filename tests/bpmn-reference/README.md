# Test-only BPMN reference

This private package pins `bpmn-moddle@10.3.1` and its dependency lockfile.
`mise run bpmn-corpus:reference` invokes it through the MoonBit task in
`scripts/bpmn-reference.mbtx`. The package is not a workspace module, is not
published, and is not a dependency of `moonrockz/bpmn` or any renderer.
The comparison rules live in `../corpus/bpmn-model/README.md`.
