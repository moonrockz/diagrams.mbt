# Native PlantUML states

This dedicated reader preserves typed state statements and lossless source
nodes. It has no renderer, host or UI dependency. Behavior text and history
remain descriptive data.

}
```mbt check
///|
test {
  let scan = @envelope.scan(
    "@startuml\nstate Ready\nReady --> Done : finish\n@enduml\n",
  )
  let read = @state.read(scan)
  let document = read.document.unwrap()
  let model = @state.to_state(document).state.unwrap()
  assert_eq(model.transitions[0].source, "Ready")
  assert_eq(model.transitions[0].target, "Done")
}
```
