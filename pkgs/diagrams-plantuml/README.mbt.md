# moonrockz/diagrams-plantuml

PlantUML for diagrams.mbt. This module reads native PlantUML regex, EBNF, JSON
and YAML blocks into lossless syntax trees and typed ASTs, writes canonical
PlantUML, and converts the blocks to format-independent models in
`moonrockz/diagrams`. `render_svg` composes reading, conversion and the
`moonrockz/diagrams-svg` renderer.

The module follows PlantUML `1.2026.9` (commit
`18d0aae311a4f1eb3723bb4b0ad939185e22f166`). It has no Java, Graphviz, server
or network dependency, and it runs on `wasm`, `wasm-gc`, `js` and `native`. A
pinned JAR is test-only reference tooling; see
[the corpus notice](../../tests/corpus/plantuml-1.2026.9/NOTICE.md).

| Block | Model | Notes |
| --- | --- | --- |
| `@startregex` | `@regex.Regex` | One pattern line. Structure only; no input matching. |
| `@startebnf` | `@ebnf.Grammar` | Ordered rules and notes. References stay symbolic. |
| `@startjson` | `@data_tree.DataTree` | Exact number lexemes, ordered and repeated members. |
| `@startyaml` | `@data_tree.DataTree` | The native PlantUML YAML subset. Every scalar is text. |

## Read, print and convert

`read` accepts exactly one native block. `read_body` accepts a raw body when the
caller gives its kind. The tree text is always equal to the source, also when the
source has errors. A document is present only when there is no error.

```mbt check
///|
test {
  let source = "@startregex\ntitle Year\n(?<year>\\d{4})-\\d{2}\n@endregex\n"
  let read = @plantuml.read(source)
  assert_eq(read.tree.text(), source)
  assert_eq(read.diagnostics.length(), 0)
  let document = read.document.unwrap()
  assert_eq(
    @plantuml.print(document).output,
    Some("@startregex\ntitle Year\n(?<year>\\d{4})-\\d{2}\n@endregex\n"),
  )
  guard @plantuml.to_diagram(document).diagram is Some(Regex(model)) else {
    fail("regex")
  }
  assert_eq(model.title, Some("Year"))
}
```

Canonical writing derives the text from typed values. Reading the output gives an
equal logical AST: source locations, comments and statement position are not
compared. A value that the native syntax cannot express gives a diagnostic and no
text. The writer never copies stale source text.

```mbt check
///|
test {
  let body = @plantuml.read_body(Ebnf, "expr = term, { (\"+\" | \"-\"), term };")
  assert_eq(body.diagnostics.length(), 0)
  let printed = @plantuml.print_body(body.document.unwrap())
  assert_eq(printed.output, Some("expr = term, { (\"+\" | \"-\"), term };\n"))
}
```

## Errors instead of partial results

Each block kind has a stable inventory of diagnostic codes in `diagnostic_codes`.
Diagnostics use half-open UTF-16 spans. These inputs give errors:

| Input | Code |
| --- | --- |
| Two blocks, or text before or after the block | `plantuml/multiple-blocks`, `plantuml/text-outside-block` |
| A wrong end marker, such as `@endyaml` for `@startjson` | `plantuml/wrong-end-marker` |
| `!include`, `!define`, `!theme` and other preprocessor directives | `plantuml/unsupported-directive` |
| A preprocessor call such as `%date()` | `plantuml/unsupported-preprocessing` |
| A regex with more than one pattern line | `regex/multiple-patterns` |
| An EBNF rule that PlantUML draws as "Syntax error!" | `ebnf/syntax` |
| Malformed JSON | `json/...` |
| A YAML form that the pinned parser refuses, such as a folded `>` value | `yaml/...` |

```mbt check
///|
test {
  let read = @plantuml.read("@startregex\n!include other.puml\nabc\n@endregex\n")
  assert_true(read.document is None)
  assert_eq(read.diagnostics[0].code, "plantuml/unsupported-directive")
}
```

`title` is the diagram title. `caption`, `header`, `footer`, `legend`,
`skinparam`, `<style>`, `skin`, `scale`, `hide`, `!pragma` and `!option` stay in
the AST as inert statements, with an `plantuml/unapplied-presentation` warning.
Library themes and render options paint the diagram.

## Regex profile

The reader follows the token order of the pinned PlantUML reader. It reads
literals and escaped characters, `.`, letter escapes such as `\d` and `\s`,
`\p{...}`, `\x{...}`, `\uXXXX`, `\0ooo`, POSIX classes `[[:name:]]`, sets,
anchors `^ $ \A \Z \z \G \b \B`, numbered backreferences, `\Q...\E`, capturing,
non-capturing and named groups, lookahead and lookbehind assertions,
alternatives and the quantifiers `* + ? {n} {n,} {,m} {n,m}`, also reluctant.
Repetition bounds stay symbolic: `a{1000000}` is one model node.

Adjacent characters of a sequence become one literal term, as PlantUML draws
them. Capturing and non-capturing groups stay in the model and the SVG shows them
as frames. Lookaround assertions are constraints, not consuming branches.

The library refuses `\x` without braces, `\k`, `\P{...}`, inline flags such as
`(?i)`, atomic groups, unclosed sets, quantifiers with two commas and bounds
larger than a 32-bit integer. PlantUML 1.2026.9 refuses lazy brace quantifiers
such as `{2,4}?`, empty alternatives and empty groups; so does this library.

## EBNF profile

Statements dispatch in the pinned order: whole-line notes `(* ... *)`,
multi-line notes `(* ... *)` and `(** ... **)`, single-line rules and
multi-line rules that end with `;`. Rules keep their order and Unicode names.
Expressions have terminals in either quote, nonterminal references, special
sequences `? ... ?`, concatenation, alternatives, grouping, `[ ]`, `{ }`,
`{ }-`, decimal counts `n * x` and exclusions `x - y`. A rule without a body is
an empty rule. Notes on terms and the note below a rule name are kept.

An exclusion takes the rest of its group, as in the pinned reader:
`a - b | c` is `a - (b | c)`. The model keeps the exclusion as a constraint on
its left term; it never becomes an alternative. A reference to a missing or
repeated rule name gives a warning and stays a visible nonterminal. A recursive
reference stays one reference and is never expanded.

## JSON and YAML profiles

JSON keeps all member occurrences in order, including repeated names, and the
exact spelling of numbers such as `12345678901234567890` and `-0.0`. A scalar
root stays a scalar model; PlantUML draws it in a one-element array.

YAML follows the pinned PlantUML line parser, not a general YAML library. Every
scalar is text: `enabled: true` gives the string `true`. Indentation, `-` items,
lists of maps, flow lists `[a, "b,c"]`, quotes, `#` comments, `|` block text and
key-only lines with following text are read. Anchors, aliases and tags such as
`&a`, `*a` and `!!str` stay literal text. A repeated key keeps every line in the
AST; the model takes the last value at the first position, with a
`yaml/duplicate-key` warning, as PlantUML does.

`#highlight` selectors resolve to member and value identities. A quoted segment
keeps a `/` inside it. `*` and `**` are wildcards. A name that matches more than
one member highlights all of them with a warning; `"name"#n` selects one
occurrence. An unresolved selector gives a warning and selects nothing. A
`<<stereotype>>` is inert metadata and never becomes CSS.

```mbt check
///|
test {
  let source = "@startjson\n{\"id\": 12345678901234567890, \"id\": -0.0}\n@endjson\n"
  let document = @plantuml.read(source).document.unwrap()
  guard @plantuml.to_diagram(document).diagram is Some(DataTree(tree)) else {
    fail("json")
  }
  let numbers = tree.nodes.iter().filter_map(n => match n.value {
    Number(lexeme) => Some(lexeme)
    _ => None
  }).collect()
  assert_eq(numbers, ["12345678901234567890", "-0.0"])
}
```

## Render

`render_svg` reads, converts and renders one block. Diagnostics from every stage
accumulate, and an error gives no output.

```mbt check
///|
test {
  let rendered = @plantuml.render_svg(
    "@startyaml\nname: test\nlist:\n  - a\n  - b\n@endyaml\n",
    renderer=@svg.SvgRenderer::new(mode=Fixed(Light)),
  )
  assert_true(rendered.output.unwrap().contains("data-diagram=\"data-tree\""))
}
```

## External trace providers

The library bundles no regex matcher, grammar parser or parser generator. An
external engine implements the public `RailroadTraceProvider` trait from
`moonrockz/diagrams/railroad-trace`. A request has a typed regex or EBNF
subject, the input, the view identity, explicit limits and, for EBNF, the start
rule. A result is `Matched`, `NotMatched`, `Unsupported`, `Exhausted` or
`ProviderError`. A provider that supports one subject kind returns `Unsupported`
for the other.

`render_traced_svg` is the only PlantUML entry point that calls a provider. It
validates the result and renders it with independent highlight channels.
Ordinary rendering, scenes, playback and export never call a provider.

```mbt check
///|
/// A scripted stub: it supports regex requests and reports a failure at
/// the first term. It is an example of the contract, not a matcher.
struct FirstTermFails {}

///|
impl @trace.RailroadTraceProvider for FirstTermFails with trace(_, request) {
  guard request.subject is Regex(_) else { return Unsupported("regex only") }
  let topology = request.topology().topology.unwrap()
  let track = topology.tracks[0]
  let first = topology.terms[0]
  NotMatched(
    @trace.Trace::new(request, "first-term-fails", [
      @trace.Attempt::new(
        "a0",
        NotMatched,
        [Traverse(topology.connector_of(track.id, Start).unwrap().id, false)],
        failure=@trace.FailurePoint::new(Terminal(first.id), position=0),
      ),
    ]),
  )
}

///|
test {
  let result = @plantuml.render_traced_svg(
    "@startregex\nab|cd\n@endregex\n",
    FirstTermFails::{  },
    "x",
  )
  assert_true(result.run.result is Some(NotMatched(_)))
  assert_true(result.rendered.output.unwrap().contains("rr-trace-failure"))
  let grammar = @plantuml.render_traced_svg(
    "@startebnf\nr = \"x\";\n@endebnf\n",
    FirstTermFails::{  },
    "x",
    start_rule="r",
  )
  assert_true(grammar.run.result is Some(Unsupported(_)))
  assert_true(grammar.rendered.output is None)
}
```

To draw evidence that a host adapter already has, pass a `TraceHighlight` to
`SvgRenderer::new(trace=...)` and render normally. The
[SVG module guide](../diagrams-svg/README.mbt.md) describes the channels.
