# Architecture values

Architecture values retain authored identities and explicit connections.
Constructors copy collections. Parent ownership, ports, independent arrowheads,
parallel connection identities and ordered alignments remain separate values.

```mbt check
///|
test "architecture constructors" {
  let services = [
    @architecture.Service::new("api"),
    @architecture.Service::new("db"),
  ]
  let edge = @architecture.Connection::new(
    "request",
    @architecture.Endpoint::new("api", Right),
    @architecture.Endpoint::new("db", Left),
    target_head=true,
  )
  let architecture = @architecture.Architecture::new("example", services[:], [
    edge,
  ])
  assert_eq(@architecture.validate(architecture).length(), 0)
}
```

`validate` has explicit node, connection, depth and work limits. It reports
missing/duplicate identities, invalid parents, ownership cycles, invalid
endpoints, unowned group attachments and invalid alignment members. Validation
does not invent nodes or repair ownership. No syntax, renderer or host API is
required to construct or validate a model.
