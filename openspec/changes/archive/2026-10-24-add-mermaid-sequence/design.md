# Design: add-mermaid-sequence

## Context

See `proposal.md` for the motivation. The workspace has one library module,
`moonrockz/diagrams` (`pkgs/diagrams`), which has only a version value. The
unpublished docs tool `apps/site` renders Mermaid with
`bobzhang/beautiful_mermaid`. `docs/design/overview.md` proposes this flow: read
a format, build a diagram model, check it, write a format.

These constraints apply:

- Library code builds and tests on wasm, wasm-gc, js and native. It is pure and
  has no I/O, no clock and no network access.
- Only `apps/site` can import Rabbita. `scripts/validate-packages.mbtx` checks
  this rule.
- Each module uses the root version. `scripts/versions.mbtx` checks this rule.

Research found these facts:

- **Existing Mermaid libraries.** No MoonBit Mermaid parser keeps source spans
  or comments, and none recovers from errors. `beautiful_mermaid` reads lines
  with regular expressions. It skips lines that it does not know, and it ignores
  `activate` and `autonumber`. `moonbit-community/mermaid` 0.2.0 is a complete
  port of Mermaid 12.2.0, with the upstream LALR tables. It stops at the first
  error and it is about 160,000 lines.
- **Archify.** Archify (`~/.claude/skills/archify`, v3.2, MIT) has no sequence
  layout engine. The author gives the y value of each message. It does not
  support self-messages, and its frames are labels only, without loop, alt or
  opt sections. Its look is a set of CSS colour tokens, dash patterns, rounded
  rectangles and arrowhead markers. One embedded `<style>` element can hold all
  of it. Archify's own SVG export has dark and light themes in this form.
- **Rabbita.** `moonbit-community/rabbita` does not build for wasm-gc. It
  renders to a string only through an async server-side app.
- **Text width.** `moonbit-community/metrics` 0.1.1 is pure, has no
  dependencies and builds on all four targets. It has advance-width tables for
  sans, serif and monospace text.

## Goals / non-goals

**Goals:**

- One structure that the later formats and adapters reuse without a change: one
  model for each diagram kind, generic links and render properties.
- A parser that reports every problem with its source position, and a printer
  whose output the parser reads back to the same AST.
- An SVG that looks like archify, and is correct and easy to read on GitHub, on
  a web page and in a slide deck.
- Output that is a pure function of its inputs: the same input gives the same
  bytes on all four targets.

**Non-goals:**

- Pixel identity with Mermaid's own renderer. We use Mermaid's grammar and
  meaning, but our own look.
- A general graph layout. Sequence diagrams use a column-and-row layout.

## Decisions

### D1. One model for each diagram kind

**Owner:** each diagram kind has one format-independent model. All formats of
that kind produce it. This change adds the first one, `Sequence`. Later changes
add other kinds, for example a `Flow` model for flowcharts, DOT and Draw.io. One
generic nodes-and-edges model for all kinds would lose what a sequence diagram
needs: message order, activations, frames and notes.

**Call:** the model lives in the package `moonrockz/diagrams/sequence`. Its
values are immutable. It has:

- participants in declaration order, each with an ID, a label, a kind, an
  optional box group, an optional link and optional render properties;
- an ordered list of events: messages, notes, activation starts and ends,
  participant creation and destruction, and frames;
- frames that nest, each with a kind (loop, alt, opt, par, critical, break or
  rect) and one or more sections with an optional label;
- an optional title, accessibility title and accessibility description;
- autonumber events. As in Mermaid, `autonumber` can occur more than once. Each
  occurrence turns numbering on with an optional start and step, or turns it
  off, from that point on. Each message gets its number, or no number, from
  the autonumber state at its position.

Each message has a sender, a receiver, a line style (solid or dotted), a head at
each end, a label and an optional link. Mermaid 12.2.0 has many arrow forms:
open, filled, cross, async point, half arrows and central connections. The model
stores each end as a head value, so it does not need one value for each
spelling. The Mermaid AST keeps the exact spelling for the printer.

### D2. The format AST stays separate from the model

**Owner:** the Mermaid AST keeps Mermaid's own syntax and spelling, and the
printer writes Mermaid from the AST. The conversion from the AST to the model
goes in one direction only and can lose spelling details.

**Call:** the reading pipeline has these steps:

1. `parse(source)` gives a lossless CST and syntax diagnostics. The text of the
   CST is always equal to the source, also when the source has errors.
2. `lower(cst)` gives a typed AST and more diagnostics. An unknown or bad
   statement becomes an error node in the CST and is not in the AST.
3. `print(ast)` gives canonical Mermaid text. The printer uses a documented
   order and spelling: two-space indentation, one statement on each line and
   the arrow spelling of the AST.
4. `to_sequence(ast)` gives the model and diagnostics, for example a message to
   a participant that was destroyed.

`read(source)` runs the first two steps and returns the CST, an optional AST and
all diagnostics. The root package of `diagrams-mermaid` also has
`render_svg(source, options)` for the common case.

A diagnostic has a stable code (for example `mermaid/unknown-statement`), a
severity, a message and a span. The span has UTF-16 offsets, and lines and
columns that start at 1. These values are the same on all targets.

**Alternative considered:** reuse the parser of `moonbit-community/mermaid`. It
was rejected because it has no CST, no recovery and no spans.

### D3. The parser

**Call:** a hand-written lexer and a recursive-descent parser over lines. A
sequence diagram is a list of statements, separated as the grammar's lexer
separates them. After an error, the parser goes to the next statement boundary
and continues. The authority for the syntax is the Mermaid 12.2.0 sequence
grammar (`sequenceDiagram.jison`), with all of its statements: `participant`,
`actor`, the `@{...}` participant configuration, `create`, `destroy`, `box`,
`activate`, `deactivate`, `note`, `loop`, `alt`/`else`, `opt`, `par`/`and`,
`par_over`, `critical`/`option`, `break`, `rect`, `autonumber`, `link`, `links`,
`properties`, `details`, `title`, `accTitle`, `accDescr` and every message
arrow. `%%` comments and `%%{...}%%` directives are trivia in the CST, and
directives are also in the AST.

Mermaid's parser accepts some text that its documentation does not describe.
When the grammar and the documentation do not agree, the grammar wins, and a
test records the case.

### D4. Links and render properties

**Owner:** a link connects a participant or a message to the item that it
represents. The Mermaid syntax for links is valid Mermaid, so GitHub and
mermaid.js still render the file. In Mermaid, `#` starts a comment, also in a
message text and in a `link` text, so a Smithy shape is written with `/` in
place of `#`:

- A participant gets a link from Mermaid's `link` or `links` statement when the
  URL has a link scheme, for example `link W: shape @ smithy:example.weather/Weather`.
- A message gets a link when its whole label is a Smithy shape in this form,
  for example `C->>W: example.weather/GetForecast`. The renderer then shows the
  short name `GetForecast`.

The owner chose this spelling on 2026-10-23 (bead `diagrams-67z.8`). The first
version of this design used `#`, which Mermaid reads as the start of a comment.

**Call:** the link target is the Smithy shape ID in its normal form, with `#`,
for example `example.weather#GetForecast`. Only the Mermaid spelling uses `/`.
So a resolver and the Smithy transcript adapter use normal shape IDs. The model
label keeps the text as written, for example `example.weather/GetForecast`. The
renderer shows the short name of a label that names its `smithy` link target,
in either spelling. The short name is the text after `/` or `#`, so
`example.weather/City$name` shows as `City$name`.

**Call:** a link is a scheme and a target, for example `smithy` and
`example.weather#Weather`. This change knows the schemes `smithy` and `openrpc`.
A link with any other scheme stays a normal Mermaid link. A shape label must
match this form: a namespace of two or more identifiers joined by `.`, then
`/`, then a shape name, and optionally `$` and a member name. Smithy also
allows a namespace of one identifier, but a label such as `read/write` must not
become a link, so a label needs at least one `.` in its namespace. A label with
any other text stays a plain label. A Mermaid `link` statement attaches to a
participant only. So in this change an `openrpc:` link can be on a participant,
but not on a message. The change `add-openrpc-sequence` defines how a message
names an OpenRPC method.

Render properties are a separate, optional value on each participant and
message:

- for a participant: a kind, a sublabel and a description;
- for a message: a sublabel and a description.

This change only stores the properties and uses them in the renderer. A resolver
is a pure function that takes a `Sequence` and a source, such as a Smithy model,
and returns a `Sequence` with properties filled in from the links, plus
diagnostics. The later changes add the resolvers.

### D5. The renderer trait

**Call:** the package `moonrockz/diagrams/render` has:

```moonbit
pub(open) trait Renderer {
  render(Self, Diagram) -> Rendered
}
```

`Diagram` is an enum with one case for each diagram kind. This change adds only
`Sequence`. `Rendered` holds the output text, its media type and diagnostics. A
renderer that does not support a diagram kind returns an error diagnostic and no
output. This lets the animated renderer of a later change use the same trait.

**Alternative considered:** one trait for each diagram kind. It was rejected
because a caller would then need to know the diagram kind before rendering.

### D6. Layout before painting

**Call:** the SVG renderer has two pure steps. The layout turns a `Sequence` and
a theme into a geometry value: a box for each participant, label and note, and a
path for each message, lifeline, activation and frame. The painter writes SVG
from the geometry. The legibility tests check the geometry, so they can find an
overlap without an SVG parser.

The layout:

- **Columns.** It puts participants in columns in model order. Each column is
  wide enough for its label, and each gap is wide enough for the widest message
  label between its two participants. A message that crosses more than one gap
  needs the width of its label across all of those gaps. When they are too
  narrow, the layout adds the missing width to them in equal parts.
- **Label chips.** Each message label sits on an opaque chip above its line, as
  in archify. A chip can cover lifelines, so a label of a message from `A` to
  `D` can cross the lifelines of `B` and `C`.
- **Rows.** It moves a cursor down the page. Each event takes one or more rows.
  The spacing follows archify's rules: messages are at least 28 px apart, and
  there is space for each line of a note.
- **Self-messages.** A message to the same participant is a loop to the right
  of the lifeline. Archify does not support it, so its look is our call.
- **Frames.** A frame is a rounded band that encloses its events, with a label
  chip and dashed section dividers.
- **Activations.** Nested activations are 10 px bars, and each nested bar moves
  4 px to the right.

### D7. The look

**Owner:** the default theme is archify's "classic" preset, in dark and light.
The minimum text size is 11 px. This is larger than archify's 7 px notes and
9 px labels, because legibility comes first.

**Call:** the colour tokens and class names come from archify's template, for
example `--bg: #020617` and `--backend-stroke: #34d399` in dark. Plain Mermaid
has few participant types, and many grey boxes look bland. So the theme maps
participant kinds to archify's colour families:

- actor and client: frontend (cyan);
- service and control: backend (green);
- database, collections and entity: database (violet);
- queue: message bus (orange);
- boundary: security (rose).

A participant with no kind gets the next colour family in a fixed cycle, in
model order. A request message uses the colour of its sender. A dotted message,
which is usually a reply, is grey and dashed. A message with a cross head is
rose.

**Owner:** lines, boxes and fills use archify's colour values exactly. Coloured
text, such as a label in the colour of its message, uses a text shade of the
same hue. In the dark theme the text shade is the accent itself when it passes
4.5:1. In the light theme, six accents are below 4.5:1 on `#f4f5f7`, for example
`#059669` at 3.45:1. Each of them gets a darker text shade of the same hue that
passes 4.5:1 against the chip or background behind it.

**Call:** the theme computes each text shade once, as a theme value. It lowers
the lightness of the accent in small steps until the contrast is at least 4.5:1.
A test keeps the computed values, so a change to a token shows in review.

**Owner:** colours that the author writes in Mermaid, such as
`rect rgb(191, 223, 255)` or `box Purple`, show as a tint. The renderer paints
the colour with a fixed opacity over the theme background, so text on it still
passes the contrast rule in both themes.

**Call:** the tint opacity is 0.18, which is close to archify's light-theme
fills. The renderer accepts the CSS colour forms that Mermaid accepts: named
colours, hex values, `rgb()` and `rgba()`. A colour that it cannot read gives a
warning diagnostic, and the renderer uses the theme colour.

There are two theme modes:

- **Adaptive** (default): one `<style>` element with CSS variables. Dark is the
  fallback, `@media (prefers-color-scheme: light)` selects light, and a
  `data-theme` attribute on the root overrides both. This mode is for GitHub and
  web pages.
- **Fixed:** literal colour values as presentation attributes. There are no CSS
  variables, no `@media` and no `<style>`. This mode is for slide tools and
  non-browser renderers. The caller selects dark or light.

Translucent fills use an opaque mask rectangle below them, as in archify. Text
uses archify's monospace font stack. The layout measures text with the monospace
profile of `moonbit-community/metrics`. A monospace font makes the measured
width close to the drawn width on most machines. The SVG has no font data and no
external references.

The SVG has a `<title>` and a `<desc>` from the title and the accessibility
fields. Participant and message groups have `data-` attributes for their IDs and
links. The animated renderer will use these attributes later.

**Call:** marker IDs and adaptive selectors use a deterministic namespace from
an FNV-1a hash of the unscoped SVG, including the theme and mode. Both rendering
entry points accept `id_prefix` for repeated inline copies that need separate
root overrides. The renderer encodes caller prefixes as code points. It scopes
only generated IDs, fragment references and CSS, and keeps user text unchanged.
Half-arrow markers reflect their local upper or lower side when the endpoint
points left, including sender heads and self-message return legs.

### D8. Legibility checks

**Owner:** legibility is a tested property, not a review opinion.

**Call:** a pure check runs on the layout geometry and returns findings. The
tests run it on every corpus diagram. It checks:

- no label box overlaps another label box, a participant box, an activation
  bar, a frame border or section divider, or a message line that it does not
  belong to. Lifelines do not count, because chips are opaque and can cover
  them;
- each label fits inside its box or chip;
- no text is smaller than 11 px;
- each text colour has a contrast ratio of at least 4.5:1 against the colour
  behind it, in both themes, after the alpha composition of the fills.

The check is also public, so a caller can check its own theme.

### D9. Module layout and dependencies

**Call:**

| Module | Path | Packages | Depends on |
| --- | --- | --- | --- |
| `moonrockz/diagrams` | `pkgs/diagrams` | root, `sequence`, `render` | core only |
| `moonrockz/diagrams-svg` | `pkgs/diagrams-svg` | root, `layout`, `theme`, `writer` | `diagrams`, `moonbit-community/metrics` |
| `moonrockz/diagrams-mermaid` | `pkgs/diagrams-mermaid` | root, `cst`, `syntax`, `ast`, `printer`, `sequence` | `diagrams`, `diagrams-svg` |
| `tests` (unpublished) | `tests` | acceptance suites, corpus, gallery | all of the above |

The SVG writer is our own small XML writer, with attribute and text escaping.
`marianoguerra/xml` is the model for it. We do not depend on an SVG library,
because none of the libraries we found writes SVG with the control that we need,
and the writer is small.

### D10. Corpus and qualification

**Call:** the `tests` module has a frozen corpus:

- every sequence example from the Mermaid 12.2.0 documentation (MIT), with its
  source, licence and SHA-256 digest;
- our own cases for each statement, each arrow form, each error code, links and
  layout edge cases.

A MoonBit task script runs `moonbit-community/mermaid` once on the corpus. The
script writes the expected participants, messages and frames as fixture files.
The tests compare our model with these files. CI does not build
`moonbit-community/mermaid`. The script runs only when someone refreshes the
fixtures.

Snapshot tests keep the SVG of each corpus diagram in both theme modes. So a
pull request that changes the look shows the change in its diff.
`mise run gallery` writes `_gallery/index.html` with every corpus diagram in
dark and light, for visual review. `_gallery/` is in `.gitignore`.

## Risks / trade-offs

- [Text on other machines is wider or narrower than measured] → We use a
  monospace stack and a small safety margin in each box. The fixed mode gives a
  predictable result in slide tools.
- [Mermaid adds syntax after 12.2.0] → The version is part of the requirements.
  An unknown statement gives a diagnostic, not wrong output. A later change can
  add the new syntax.
- [The full grammar is a large first change] → The first task group is a thin
  path from parse to SVG for one message. Each later group adds a complete part
  with its own tests.
- [Bland or wrong colours in some viewers] → The adaptive mode depends on CSS
  support. GitHub `<img>` views follow the operating system theme, not the
  GitHub setting. The fixed mode is the fallback, and the gallery shows both.
- [The archify licence] → Archify is MIT. We copy colour values and spacing
  rules, not code. The `NOTICE` section of the `diagrams-svg` README credits it.

## Migration plan

There is no migration. All modules and packages are new. Rollback is a revert of
the change.
