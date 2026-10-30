# Shared BPMN traversal corpus

This unpublished package is the normalized oracle of the BPMN traversal
compatibility map. MoonBit and Python run the same operations over the same
fixtures. They must write the same text.

- `fixtures/*.bpmn` are the documents. `fixtures/<stem>.graph` is the graph
  script of `<stem>.bpmn`.
- `expected/<stem>.txt` is the normalized text of one fixture.
  `expected/deep.txt` summarizes a generated 10,000-depth tree.
- `normalize.mbt` and `graph.mbt` write the text with the public
  `moonrockz/bpmn` API. `corpus_test.mbt` compares it with `expected/` on
  wasm, wasm-gc, js and native.
- `apps/python-native/python/tests/test_bpmn_corpus.py` writes the same text
  through `diagrams_mbt.bpmn` and compares it with the same files.

Commands:

- `mise run traversal-corpus:expected` writes `expected/` from the MoonBit
  oracle (`dump/`, native) and embeds the files. Review the diff before you
  commit it.
- `mise run traversal-corpus:generate` embeds `fixtures/` and `expected/` in
  `corpus.generated.mbt`.
- `mise run validate:traversal-corpus` fails when the embedding is stale. The
  `validate` task runs it.

`.gitattributes` keeps the exact fixture bytes, including CRLF line ends.

## Reading and source units

Each fixture is read with source identifier `corpus:<file name>` and the
default limits. Trees are built with the default limits and no resource
identifier. Offsets and columns count UTF-16 code units; lines and columns
start at 1. A failed read writes only its diagnostics.

## Text format

Free text is in double quotes, with `\`, `"`, LF, CR and TAB escaped. An
expanded name is `{namespace}local`. An absent value is `-`. A position is
`line:column:offset`; a location is `source@start-end`; a span is
`start-end`.

Per node, in preorder: one `#<ordinal>` line with depth, category, kind and its
class (`standard`, `foreign` or `unknown`), ID, parent, path step, span,
location, resource identifier, child count and value. Then, as applicable, the
element projection, each attribute (expanded name, raw name, scalar tag, token
and detail, span, location), the `id` and `name` scalars, each field, the
`field(first field)` lookup, the children, the path, and the handle lookups:
`same` (the tree itself), `rebuilt` (a second tree of the same document),
`other` (a tree with resource identifier `corpus:other`), and `path.resolve`
in the rebuilt and other trees.

Traversal sections write tokens, 16 per line: `+n` enter, `-n` leave, `n:k`
a reduction combine of node `n` with `k` child results. Control rules:

- skip rule: `SkipChildren` at each ordinal `n` with `n % 5 == 2`.
- stop ordinal: `length * 2 / 3`.

| Section | Operation |
| --- | --- |
| `walk` | `walk` with enter and leave, always `Continue` |
| `walk-skip` | `walk` with the skip rule |
| `walk-stop` | `walk`, `Stop` at the stop ordinal |
| `walk-subtree` | `walk` from the node with ordinal `length / 2` |
| `fold` | `fold` that appends tokens, with the skip rule |
| `reduce` | `reduce`; result is the node count |
| `reduce-pruned-skip` | `reduce_pruned` with the skip rule |
| `reduce-pruned-stop` | `reduce_pruned`, `Stop` at the stop ordinal; result `none` |
| `visitor-activity` | `accept` with only `visit_activity`: `n:<kind>`, `SkipChildren` at even ordinals |
| `visitor-full` | `accept` with `enter` (skip rule), `leave` and every family method (`Stop` at the stop ordinal) |
| `events` | pull `EventReader` |
| `events-controls` | pull reader with `skip_children` (skip rule) and `stop` (stop ordinal); `end` when `next` is then absent |
| `push` | `push_events` with the skip rule and the stop ordinal |
| `cursor` | preorder with `TreeCursor`: `fc` first child, `ns` next sibling, `p` parent; `>n:d` moved to node `n` at relative depth `d`, `!` failed |
| `cursor-subtree` | a fixed move list from the first node with depth 2 or more and two or more children: `lc` last child, `ps` previous sibling |

## Graph scripts

A `.graph` line is a command and its words. `#` starts a comment line.

- `graph <label> [resource_id=<id>] [document=<location>:<file>]...
  [external=<location>|<namespace>|<import type>|<symbol>,...]...
  [limits=<graph limits>]` builds `DocumentGraph::new` for the fixture.
- `lookup <endpoint> [limits=...]`
- `reachable <endpoint> [kinds=<kind>,...] [direction=<direction>] [limits=...]`
- `route <endpoint> <endpoint> [kinds=...] [direction=...] [limits=...]`

An absent option keeps the MoonBit default. Graph limits are
`nodes:<n>,edges:<n>,results:<n>,work:<n>` in any subset. Endpoints are
`id:<id>`, `qname:<namespace>|<local>`, `symbol:<resource>|<namespace>|<local>`,
`node:<ordinal>` (a handle in a tree of the fixture with the graph's resource
identifier) and `foreign:<ordinal>` (a handle in a tree with resource identifier
`corpus:foreign`). A graph node is `<resource>#<ordinal>(<id>)` or
`ext:<resource>|<name>#<occurrence>`.
