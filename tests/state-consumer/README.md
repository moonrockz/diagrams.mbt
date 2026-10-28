# Fresh state consumers

Run `mise run test:state-consumer` from the repository root. Each temporary
workspace imports only the modules its case needs and runs on wasm, wasm-gc, js
and native with compiler warnings denied. Temporary workspaces are removed after
each case.

The model case constructs hierarchy and descriptions using only
`moonrockz/diagrams`. The Mermaid and PlantUML cases import their dedicated state
reader packages, print canonical source and convert to state values without
importing a rendering package. The player case constructs state values directly,
inspects themed curved SVG geometry and emits a supplied repeated/concurrent
scenario with an isolated node visit through the shared offline renderer.

By default the script points dependencies at this checkout for implementation
qualification. Run `mise run test:state-consumer -- --published` after publication
to resolve the root manifest version from the registry. This mode supplies no
local workspace overrides. All cases still use fresh temporary workspaces and
run on every target.
