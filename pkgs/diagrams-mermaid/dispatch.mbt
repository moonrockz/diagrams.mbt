///|
/// Multi-kind entry points preserve the sequence-only API.
pub(all) enum ParsedDiagram {
  Sequence(@ast.Diagram)
  Swimlane(@swimlane_ast.Diagram)
} derive(Eq, Debug)

///|
pub(all) enum DiagramTree {
  Sequence(@cst.Node)
  Swimlane(@swimlane_cst.Node)
  Unsupported(String)
} derive(Eq, Debug)

///|
pub fn DiagramTree::text(self : DiagramTree) -> String {
  match self {
    Sequence(tree) => tree.text()
    Swimlane(tree) => tree.text()
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
) -> DiagramReadResult {
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
  let mut front = false
  let mut directive = false
  for line in source.split("\n") {
    let text = @swimlane_syntax.trim_space(line.to_owned())
    if text == "---" {
      front = !front
      continue
    }
    if front || text.is_empty() {
      continue
    }
    if text.has_prefix("%%{") {
      directive = true
    }
    if directive {
      if text.contains("}%%") {
        directive = false
      }
      continue
    }
    if text.has_prefix("%%") {
      continue
    }
    if text.has_prefix("swimlane-beta") &&
      (
        text.length() == 13 ||
        @swimlane_syntax.is_space(text.at(13).to_int()) ||
        text.at(13).to_int() == 59
      ) {
      let result = @swimlane_syntax.read(source, limits~)
      return {
        tree: Swimlane(result.tree),
        ast: result.ast.map(ast => Swimlane(ast)),
        diagnostics: result.diagnostics,
      }
    }
    if text.has_prefix("sequenceDiagram") {
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
        "mermaid/unsupported-diagram", "Expected sequenceDiagram or swimlane-beta",
      ),
    ],
  }
}

///|
pub fn print_diagram(
  diagram : ParsedDiagram,
  limits~ : @swimlane_syntax.Limits = @swimlane_syntax.Limits::new(),
) -> DiagramPrintResult {
  match diagram {
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
