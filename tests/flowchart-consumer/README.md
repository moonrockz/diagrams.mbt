# Fresh flowchart consumers

`mise run test:flowchart-consumer` copies these `.mbt.txt` fixtures into separate
temporary workspaces outside the repository. Each consumer builds and runs on
wasm, wasm-gc, js and native. The script reads the version from the root
`moon.mod` and overrides only the needed local library modules.

The model consumer imports only `moonrockz/diagrams/flowchart`. Its workspace
contains only the consumer and core diagram module. The script rejects parser,
renderer, animation, async-host or UI dependencies in the core module manifest.

The reader consumer imports the dedicated Mermaid flowchart syntax, printer and
converter plus PlantUML activity/envelope packages. It checks canonical source
round trips and both PlantUML dialects without root rendering imports. The
reader module manifests retain their existing SVG dependency for their root
convenience APIs; no UI or upstream renderer runtime is needed.

The SVG/player consumer constructs a model directly, checks geometry and themed
SVG, samples a finite concurrent/repeated motion scenario and emits standalone
HTML through the shared public APIs. It imports no Mermaid or PlantUML reader.
No consumer publishes a package or starts a browser service.
