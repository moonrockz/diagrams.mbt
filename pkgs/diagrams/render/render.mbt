///|
/// A diagram of one kind. Each kind has its own format-independent model.
pub(all) enum Diagram {
  Sequence(@sequence.Sequence)
  Bpmn(@bpmn.Bpmn)
  Swimlane(@swimlane.Swimlane)
  Regex(@regex.Regex)
  Ebnf(@ebnf.Grammar)
  DataTree(@data_tree.DataTree)
} derive(Eq, Debug)

///|
pub extend Diagram with Eq::{not_equal, equal}

///|
pub extend Diagram with @debug.Debug::{to_repr}

///|
/// The name of the kind of `diagram`, for example `sequence`.
pub fn Diagram::kind_name(self : Diagram) -> String {
  match self {
    Sequence(_) => "sequence"
    Bpmn(_) => "bpmn"
    Swimlane(_) => "swimlane"
    Regex(_) => "regex"
    Ebnf(_) => "ebnf"
    DataTree(_) => "data-tree"
  }
}

///|
/// The result of a renderer. `output` is absent when the renderer cannot
/// render the diagram; `diagnostics` then has an error.
pub struct Rendered {
  output : String?
  media_type : String
  diagnostics : ReadOnlyArray[@diagrams.Diagnostic]
} derive(Eq, Debug)

///|
pub extend Rendered with Eq::{not_equal, equal}

///|
pub extend Rendered with @debug.Debug::{to_repr}

///|
/// A result with `output`.
pub fn Rendered::ok(
  output : String,
  media_type : String,
  diagnostics~ : ArrayView[@diagrams.Diagnostic] = [],
) -> Rendered {
  {
    output: Some(output),
    media_type,
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}

///|
/// The result of a renderer that does not support the kind of `diagram`.
pub fn Rendered::unsupported(
  media_type : String,
  diagram : Diagram,
) -> Rendered {
  {
    output: None,
    media_type,
    diagnostics: [
      @diagrams.Diagnostic::error(
        "render/unsupported-diagram",
        "this renderer does not support \{diagram.kind_name()} diagrams",
      ),
    ],
  }
}

///|
/// Turns a diagram into output text, such as SVG.
pub(open) trait Renderer {
  fn render(Self, Diagram) -> Rendered
}

///|
/// A result with no output, for a diagram that could not be rendered.
/// `diagnostics` says why.
pub fn Rendered::failed(
  media_type : String,
  diagnostics : ArrayView[@diagrams.Diagnostic],
) -> Rendered {
  {
    output: None,
    media_type,
    diagnostics: ReadOnlyArray::from_array(diagnostics),
  }
}
