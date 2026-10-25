///|
/// A definitions root. Children retain the caller's containment order; schema
/// validation is separate from construction and serialization.
pub struct Definitions { element : Element } derive(Eq, Debug)

///|
pub extend Definitions with Eq::{equal, not_equal}

///|
pub extend Definitions with @debug.Debug::{to_repr}

///|
pub fn Definitions::new(target_namespace_uri : String, id? : String, name? : String, expression_language? : String, type_language? : String, exporter? : String, exporter_version? : String, children? : ArrayView[Element] = []) -> Definitions {
  let values = [Attribute::new(ExpandedName::new("","targetNamespace"),Uri(target_namespace_uri))]
  for (key,value) in [("id",id),("name",name),("expressionLanguage",expression_language),("typeLanguage",type_language),("exporter",exporter),("exporterVersion",exporter_version)] {
    if value is Some(value) {
      let scalar = if key == "id" { Scalar::Identifier(value) } else if key == "expressionLanguage" || key == "typeLanguage" { Scalar::Uri(value) } else { Scalar::Text(value) }
      values.push(Attribute::new(ExpandedName::new("",key),scalar))
    }
  }
  { element: Element::from_values(Kind::Definitions, values~, contents=children.map(e => Content::Element(e))) }
}

///|
pub fn Definitions::from_element(element : Element) -> Definitions? { if element.kind == Kind::Definitions { Some({ element, }) } else { None } }

///|
pub fn Definitions::document(self : Definitions) -> Document { Document::new(self.element) }

///|
pub fn Definitions::target_namespace(self : Definitions) -> Field[String] { self.element.string("targetNamespace") }

///|
pub fn Definitions::imports(self : Definitions) -> ReadOnlyArray[Import] { ReadOnlyArray::from_array(self.element.children.iter().filter_map(Import::from_element).to_array()) }

///|
pub fn Definitions::roots(self : Definitions) -> ReadOnlyArray[RootElement] { ReadOnlyArray::from_array(self.element.children.iter().filter_map(RootElement::from_element).to_array()) }

///|
pub struct Import { element : Element } derive(Eq, Debug)

///|
pub extend Import with Eq::{equal, not_equal}

///|
pub extend Import with @debug.Debug::{to_repr}

///|
pub fn Import::new(namespace_uri : String, location : String, import_type : String) -> Import {
  { element: Element::from_values(Kind::Import, values=[Attribute::new(ExpandedName::new("","namespace"),Uri(namespace_uri)),Attribute::new(ExpandedName::new("","location"),Text(location)),Attribute::new(ExpandedName::new("","importType"),Uri(import_type))]) }
}

///|
pub fn Import::from_element(element : Element) -> Import? { if element.kind == Kind::Import { Some({ element, }) } else { None } }

///|
pub fn Import::namespace_uri(self : Import) -> Field[String] { self.element.string("namespace") }

///|
pub fn Import::location(self : Import) -> Field[String] { self.element.string("location") }

///|
pub fn Import::import_type(self : Import) -> Field[String] { self.element.string("importType") }

///|
/// A typed view over a concrete element derived from the abstract base type.
pub struct BaseElement { element : Element } derive(Eq, Debug)

///|
pub extend BaseElement with Eq::{equal, not_equal}

///|
pub extend BaseElement with @debug.Debug::{to_repr}

///|
fn derived_from(element : Element, local_name : String) -> Bool {
  match element.value_type { Some(name) => schema_type(name).map(t => t.is_subtype_of(ExpandedName::new("http://www.omg.org/spec/BPMN/20100524/MODEL",local_name))).unwrap_or(false); None => false }
}

///|
pub fn BaseElement::from_element(element : Element) -> BaseElement? { if derived_from(element,"tBaseElement") { Some({ element, }) } else { None } }

///|
pub fn BaseElement::id(self : BaseElement) -> Field[String] { self.element.string("id") }

///|
pub fn BaseElement::documentation(self : BaseElement) -> ReadOnlyArray[Documentation] { ReadOnlyArray::from_array(self.element.children.iter().filter_map(Documentation::from_element).to_array()) }

///|
pub fn BaseElement::extension_elements(self : BaseElement) -> Element? { self.element.children.iter().find_first(e => e.kind == ExtensionElements) }

///|
pub struct RootElement { element : Element } derive(Eq, Debug)

///|
pub extend RootElement with Eq::{equal, not_equal}

///|
pub extend RootElement with @debug.Debug::{to_repr}

///|
pub fn RootElement::from_element(element : Element) -> RootElement? { if derived_from(element,"tRootElement") { Some({ element, }) } else { None } }

///|
pub fn RootElement::base(self : RootElement) -> BaseElement { { element: self.element } }

///|
pub struct Documentation { element : Element } derive(Eq, Debug)

///|
pub extend Documentation with Eq::{equal, not_equal}

///|
pub extend Documentation with @debug.Debug::{to_repr}

///|
pub fn Documentation::new(contents : ArrayView[Content], id? : String, text_format? : String) -> Documentation {
  let values : Array[Attribute] = []
  if id is Some(id) { values.push(Attribute::new(ExpandedName::new("","id"),Identifier(id))) }
  if text_format is Some(value) { values.push(Attribute::new(ExpandedName::new("","textFormat"),Text(value))) }
  { element: Element::from_values(Kind::Documentation, values~, contents~) }
}

///|
pub fn Documentation::from_element(element : Element) -> Documentation? { if element.kind == Kind::Documentation { Some({ element, }) } else { None } }

///|
pub fn Documentation::text_format(self : Documentation) -> Field[String] { self.element.string("textFormat") }

///|
pub fn Element::string(self : Element, name : String) -> Field[String] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Text(s)) | Some(Identifier(s)) | Some(Uri(s)) => Present(s); Some(other) => InvalidValue(other) }
}

///|
pub fn Element::integer(self : Element, name : String) -> Field[ExactInteger] {
  match self.scalar(ExpandedName::new("",name)) { None => Absent; Some(Integer(n)) => Present(n); Some(other) => InvalidValue(other) }
}

///|
pub fn Document::definitions(self : Document) -> Definitions? { Definitions::from_element(self.root) }

///|
pub fn Definitions::id(self : Definitions) -> Field[String] { self.element.string("id") }

///|
pub fn Definitions::name(self : Definitions) -> Field[String] { self.element.string("name") }

///|
pub fn Definitions::expression_language(self : Definitions) -> Field[String] { self.element.string("expressionLanguage") }

///|
pub fn Definitions::type_language(self : Definitions) -> Field[String] { self.element.string("typeLanguage") }

///|
pub fn Definitions::exporter(self : Definitions) -> Field[String] { self.element.string("exporter") }

///|
pub fn Definitions::exporter_version(self : Definitions) -> Field[String] { self.element.string("exporterVersion") }

///|
pub fn Documentation::id(self : Documentation) -> Field[String] { self.element.string("id") }
