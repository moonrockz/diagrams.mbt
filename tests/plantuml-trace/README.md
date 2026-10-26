# External trace provider consumers

These tests are a consumer outside the library. They implement the public
`RailroadTraceProvider` trait with small scripted stubs. The stubs return fixed
evidence for known inputs; they are not regex matchers or grammar parsers.
