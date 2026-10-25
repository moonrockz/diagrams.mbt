///|
fn Converter::exact_bounds(self : Converter, e : @bpmn.Element) -> @model.ExactBounds? {
  fn value(key : String) -> @model.Number? {
    match e.number(key) { Present(n) => @model.Number::parse(n.token); _ => None }
  }
  guard value("x") is Some(x) && value("y") is Some(y) && value("width") is Some(width) && value("height") is Some(height) else { self.add("bpmn/invalid-geometry","DI bounds require finite numeric coordinates",e~); return None }
  Some(@model.ExactBounds::new(x,y,width,height))
}

///|
fn Converter::label(self : Converter, di : Int) -> @model.LabelGeometry? {
  let index=self.sources[0].index
  let labels=index.nodes[di].children.filter(i => actual(index.nodes[i].element) == Some(BpmnBPMNLabel))
  if labels.is_empty() { return None }
  if labels.length() > 1 { self.add("bpmn/invalid-geometry","Multiple labels on one DI element",e=index.nodes[di].element); return None }
  let ordinal=labels[0]; let e=index.nodes[ordinal].element
  let bounds=e.children.iter().find_first(c => actual(c) == Some(DcBounds)).bind(c => self.exact_bounds(c))
  let styles=self.resolve_field(0,ordinal,"labelStyle")
  let mut font : @model.Font?=None
  let style=styles.get(0).map(key => {
    let element=self.sources[key.0].index.nodes[key.1].element
    font=element.children.iter().find_first(c => actual(c) == Some(DcFont)).map(c => {
      let size=match c.number("size") { Present(n) => @model.Number::parse(n.token); _ => None }
      @model.Font::new(name?=c.attribute("name"),size?,bold?=flag(c,"isBold"),italic?=flag(c,"isItalic"),underline?=flag(c,"isUnderline"),strike_through?=flag(c,"isStrikeThrough"))
    })
    self.identity(key.0,key.1)
  })
  Some(@model.LabelGeometry::new(bounds?,style?,font?))
}

///|
fn Converter::shape(self : Converter, ordinal : Int) -> @model.ShapeGeometry {
  let e=self.sources[0].index.nodes[ordinal].element
  let bounds=e.children.iter().find_first(c => actual(c) == Some(DcBounds)).bind(c => self.exact_bounds(c))
  @model.ShapeGeometry::new(self.identity(0,ordinal),bounds?,label?=self.label(ordinal),horizontal?=flag(e,"isHorizontal"),expanded?=flag(e,"isExpanded"),marker_visible?=flag(e,"isMarkerVisible"),message_visible?=flag(e,"isMessageVisible"))
}

///|
fn Converter::edge(self : Converter, ordinal : Int) -> @model.EdgeGeometry {
  let e=self.sources[0].index.nodes[ordinal].element
  let points=[]
  for p in e.children {
    if actual(p) != Some(DcPoint) { continue }
    match (p.number("x"),p.number("y")) {
      (Present(x),Present(y)) => match (@model.Number::parse(x.token),@model.Number::parse(y.token)) {
        (Some(x),Some(y)) => points.push(@model.ExactPoint::new(x,y))
        _ => self.add("bpmn/invalid-geometry","DI waypoints require finite coordinates",e=p)
      }
      _ => self.add("bpmn/invalid-geometry","DI waypoint is missing a coordinate",e=p)
    }
  }
  let source_shape=self.resolve_field(0,ordinal,"sourceElement").get(0).map(key => self.identity(key.0,key.1))
  let target_shape=self.resolve_field(0,ordinal,"targetElement").get(0).map(key => self.identity(key.0,key.1))
  @model.EdgeGeometry::new(self.identity(0,ordinal),points,label?=self.label(ordinal),source_shape?,target_shape?,message_visible?=match e.attribute("messageVisibleKind") { Some("initiating") => Some(Initiating); Some("non_initiating") => Some(NonInitiating); _ => None })
}

///|
fn integer(token : String) -> Int? { try Some(@string.parse_int(token)) catch { _ => None } }

///|
fn integer_bounds(geometry : @model.ShapeGeometry?) -> @model.Bounds {
  if geometry.bind(g => g.bounds) is Some(b) && integer(b.x.token) is Some(x) && integer(b.y.token) is Some(y) && integer(b.width.token) is Some(width) && integer(b.height.token) is Some(height) { {x,y,width,height} }
  else { {x:0,y:0,width:0,height:0} }
}

///|
fn integer_points(geometry : @model.EdgeGeometry?) -> Array[@model.Point] {
  let out : Array[@model.Point]=[]
  if geometry is Some(g) { for p in g.points {
    guard integer(p.x.token) is Some(x) && integer(p.y.token) is Some(y) else { return [] }
    out.push({x,y})
  } }
  out
}
