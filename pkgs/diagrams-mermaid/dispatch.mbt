///|
/// Multi-kind entry points preserve the sequence-only API.
pub(all) enum ParsedDiagram {
  State(@state_ast.Diagram)
  Flowchart(@flowchart_ast.Diagram)
  Sequence(@ast.Diagram)
  Swimlane(@swimlane_ast.Diagram)
  Zenuml(@zenuml_ast.Diagram)
  Architecture(@architecture_ast.Diagram)
} derive(Eq, Debug)

///|
pub(all) enum DiagramTree {
  State(@state_cst.Node)
  Flowchart(@swimlane_cst.Node)
  Sequence(@cst.Node)
  Swimlane(@swimlane_cst.Node)
  Zenuml(@zenuml_cst.Node)
  Architecture(@architecture_cst.Node)
  Unsupported(String)
} derive(Eq, Debug)

///|
pub fn DiagramTree::text(self : DiagramTree) -> String {
  match self {
    State(tree) => tree.text()
    Flowchart(tree) => tree.text()
    Sequence(tree) => tree.text()
    Swimlane(tree) => tree.text()
    Zenuml(tree) => tree.text()
    Architecture(tree) => tree.text()
    Unsupported(source) => source
  }
}

///|
pub struct DiagramReadResult {
  tree : DiagramTree
  ast : ParsedDiagram?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub struct DiagramPrintResult {
  output : String?
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub fn read_diagram(
  source : String,
  limits~ : @swimlane_syntax.Limits = @swimlane_syntax.Limits::new(),
  zenuml_limits~ : @zenuml_syntax.Limits = @zenuml_syntax.Limits::new(),
  architecture_limits~ : @architecture_syntax.Limits = @architecture_syntax.Limits::new(),
  state_limits~ : @state_syntax.Limits = @state_syntax.Limits::new(),
) -> DiagramReadResult {
  if source.length() >
    limits.source
    .max(zenuml_limits.source)
    .max(architecture_limits.source)
    .max(state_limits.source) {
    return {
      tree: Unsupported(source),
      ast: None,
      diagnostics: [
        @diagrams.Diagnostic::error(
          "swimlane/source-limit", "Source limit exceeded",
        ),
      ],
    }
  }
  let mut front = false
  let mut directive = false
  for line in source.split("\n") {
    let mut text = @swimlane_syntax.trim_space(line.to_owned())
    if !directive {
      if text == "---" {
        front = !front
        continue
      }
      if front || text.is_empty() {
        continue
      }
    }
    // A directive consumes only through its closing delimiter. Keep scanning
    // the suffix, which may contain another directive or the diagram header.
    let mut remainder = text[:]
    while directive || remainder.has_prefix("%%{") {
      directive = true
      guard remainder.find("}%%") is Some(close) else { break }
      directive = false
      remainder = remainder[close + 3:]
      let mut whitespace = 0
      while whitespace < remainder.length() &&
            @swimlane_syntax.is_space(remainder.at(whitespace).to_int()) {
        whitespace += 1
      }
      remainder = remainder[whitespace:]
    }
    if directive {
      continue
    }
    text = remainder.to_owned()
    if text.is_empty() {
      continue
    }
    if text.has_prefix("%%") {
      continue
    }
    if ["stateDiagram-v2", "stateDiagram"]
      .iter()
      .any(header => {
        text == header ||
        text.has_prefix(header + " ") ||
        text.has_prefix(header + "\t")
      }) {
      let result = @state_syntax.read(source, limits=state_limits)
      return {
        tree: State(result.tree),
        ast: result.ast.map(ast => State(ast)),
        diagnostics: result.diagnostics,
      }
    }
    if text.has_prefix("zenuml") &&
      (
        text.length() == 6 ||
        @swimlane_syntax.is_space(text.at(6).to_int()) ||
        text.at(6).to_int() == 59
      ) {
      let result = @zenuml_syntax.read(source, limits=zenuml_limits)
      return {
        tree: Zenuml(result.tree),
        ast: result.ast.map(ast => Zenuml(ast)),
        diagnostics: result.diagnostics,
      }
    }
    if text.has_prefix("architecture-beta") &&
      (
        text.length() == 17 ||
        @swimlane_syntax.is_space(text.at(17).to_int()) ||
        text.at(17).to_int() == 59
      ) {
      let result = @architecture_syntax.read(source, limits=architecture_limits)
      return {
        tree: Architecture(result.tree),
        ast: result.ast.map(ast => Architecture(ast)),
        diagnostics: result.diagnostics,
      }
    }
    for header in ["flowchart-elk", "flowchart", "graph"] {
      if text.has_prefix(header) &&
        (
          text.length() == header.length() ||
          @swimlane_syntax.is_space(text.at(header.length()).to_int()) ||
          text.at(header.length()).to_int() == 59
        ) {
        let result = @flowchart_syntax.read(source, header~, limits~)
        return {
          tree: Flowchart(result.tree),
          ast: result.ast.map(value => Flowchart(value)),
          diagnostics: result.diagnostics,
        }
      }
    }
    if text.has_prefix("swimlane-beta") &&
      (
        text.length() == 13 ||
        @swimlane_syntax.is_space(text.at(13).to_int()) ||
        text.at(13).to_int() == 59
      ) {
      if source.length() > limits.source {
        return {
          tree: Unsupported(source),
          ast: None,
          diagnostics: [
            @diagrams.Diagnostic::error(
              "swimlane/source-limit", "Source limit exceeded",
            ),
          ],
        }
      }
      let result = @swimlane_syntax.read(source, limits~)
      return {
        tree: Swimlane(result.tree),
        ast: result.ast.map(ast => Swimlane(ast)),
        diagnostics: result.diagnostics,
      }
    }
    if text.has_prefix("sequenceDiagram") {
      if source.length() > limits.source {
        return {
          tree: Unsupported(source),
          ast: None,
          diagnostics: [
            @diagrams.Diagnostic::error(
              "swimlane/source-limit", "Source limit exceeded",
            ),
          ],
        }
      }
      let result = read(source)
      return {
        tree: Sequence(result.tree),
        ast: result.ast.map(ast => Sequence(ast)),
        diagnostics: result.diagnostics,
      }
    }
    break
  }
  {
    tree: Unsupported(source),
    ast: None,
    diagnostics: [
      @diagrams.Diagnostic::error(
        "mermaid/unsupported-diagram", "Expected sequenceDiagram, swimlane-beta, flowchart, graph, zenuml, architecture-beta, stateDiagram or stateDiagram-v2",
      ),
    ],
  }
}

///|
pub fn print_diagram(
  diagram : ParsedDiagram,
  limits~ : @swimlane_syntax.Limits = @swimlane_syntax.Limits::new(),
  zenuml_limits~ : @zenuml_syntax.Limits = @zenuml_syntax.Limits::new(),
  architecture_limits~ : @architecture_syntax.Limits = @architecture_syntax.Limits::new(),
  state_limits~ : @state_syntax.Limits = @state_syntax.Limits::new(),
) -> DiagramPrintResult {
  match diagram {
    State(ast) => {
      let result = @state_printer.print(ast, limits=state_limits)
      { output: result.output, diagnostics: result.diagnostics, }
    }
    Flowchart(ast) => {
      let result = @flowchart_printer.print(ast, limits~)
      { output: result.output, diagnostics: result.diagnostics, }
    }
    Zenuml(ast) => {
      let result = @zenuml_printer.print(ast, limits=zenuml_limits)
      { output: result.output, diagnostics: result.diagnostics, }
    }
    Architecture(ast) => {
      let result = @architecture_printer.print(ast, limits=architecture_limits)
      { output: result.output, diagnostics: result.diagnostics, }
    }
    Sequence(ast) => {
      let output = print(ast)
      if output.length() > limits.output {
        {
          output: None,
          diagnostics: [
            @diagrams.Diagnostic::error(
              "mermaid/print-limit", "Output limit exceeded",
            ),
          ],
        }
      } else {
        { output: Some(output), diagnostics: [], }
      }
    }
    Swimlane(ast) => {
      let result = @swimlane_printer.print(ast, limits~)
      { output: result.output, diagnostics: result.diagnostics, }
    }
  }
}

///|
pub fn to_swimlane(
  diagram : @swimlane_ast.Diagram,
  limits~ : @swimlane_syntax.Limits = @swimlane_syntax.Limits::new(),
  id~ : String = "swimlane",
) -> @swimlane_conversion.Conversion {
  @swimlane_conversion.to_swimlane(diagram, limits~, id~)
}

///|
pub extend ParsedDiagram with Eq::{equal, not_equal}

///|
pub extend ParsedDiagram with @debug.Debug::{to_repr}

///|
pub extend DiagramTree with Eq::{equal, not_equal}

///|
pub extend DiagramTree with @debug.Debug::{to_repr}

///|
pub extend DiagramReadResult with Eq::{equal, not_equal}

///|
pub extend DiagramReadResult with @debug.Debug::{to_repr}

///|
pub extend DiagramPrintResult with Eq::{equal, not_equal}

///|
pub extend DiagramPrintResult with @debug.Debug::{to_repr}

///|
/// Existing sequence-only inventories retain their original meaning.
pub let swimlane_diagnostic_codes : ReadOnlyArray[String] = @swimlane_syntax.diagnostic_codes

///|
pub let swimlane_conversion_diagnostic_codes : ReadOnlyArray[String] = @swimlane_conversion.diagnostic_codes

///|
pub fn to_zenuml_sequence(
  diagram : @zenuml_ast.Diagram,
  limits~ : @zenuml_syntax.Limits = @zenuml_syntax.Limits::new(),
) -> @zenuml_conversion.Conversion {
  @zenuml_conversion.convert(diagram, limits~)
}

///|
pub fn to_architecture(
  diagram : @architecture_ast.Diagram,
  limits~ : @architecture_syntax.Limits = @architecture_syntax.Limits::new(),
  id~ : String = "architecture",
) -> @architecture_conversion.Conversion {
  @architecture_conversion.to_architecture(diagram, limits~, id~)
}

///|
pub let zenuml_diagnostic_codes : ReadOnlyArray[String] = @zenuml_syntax.diagnostic_codes

///|
pub let zenuml_conversion_diagnostic_codes : ReadOnlyArray[String] = @zenuml_conversion.diagnostic_codes

///|
pub let architecture_diagnostic_codes : ReadOnlyArray[String] = @architecture_syntax.diagnostic_codes

///|
pub let architecture_conversion_diagnostic_codes : ReadOnlyArray[String] = @architecture_conversion.diagnostic_codes

///|
pub fn to_flowchart(
  diagram : @flowchart_ast.Diagram,
  limits~ : @swimlane_syntax.Limits = @swimlane_syntax.Limits::new(),
  id~ : String = "flowchart",
) -> @flowchart_conversion.Conversion {
  @flowchart_conversion.to_flowchart(diagram, limits~, id~)
}

///|
pub let flowchart_diagnostic_codes : ReadOnlyArray[String] = @flowchart_syntax.diagnostic_codes

///|
pub let flowchart_conversion_diagnostic_codes : ReadOnlyArray[String] = @flowchart_conversion.diagnostic_codes

///|
pub fn to_state(
  diagram : @state_ast.Diagram,
  limits~ : @state_syntax.Limits = @state_syntax.Limits::new(),
  id~ : String = "state",
) -> @state_conversion.Conversion {
  @state_conversion.to_state(diagram, limits~, id~)
}

///|
pub let state_diagnostic_codes : ReadOnlyArray[String] = @state_syntax.diagnostic_codes

///|
pub let state_conversion_diagnostic_codes : ReadOnlyArray[String] = @state_conversion.diagnostic_codes
