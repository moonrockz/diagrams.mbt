///|
pub struct Limits { nodes : Int; edges : Int; work : Int; output_units : Int } derive(Eq, Debug)

///|
pub fn Limits::new(nodes? : Int = 10000, edges? : Int = 50000, work? : Int = 1000000, output_units? : Int = 16777216) -> Limits { {nodes,edges,work,output_units} }

///|
pub(all) struct Point { x : Double; y : Double } derive(Eq, Debug)

///|
pub(all) struct Rect { x : Double; y : Double; width : Double; height : Double } derive(Eq, Debug)

///|
pub fn Rect::contains(self : Rect, other : Rect, tolerance? : Double = 0.0) -> Bool { other.x >= self.x-tolerance && other.y >= self.y-tolerance && other.x+other.width <= self.x+self.width+tolerance && other.y+other.height <= self.y+self.height+tolerance }

///|
pub fn Rect::overlaps(self : Rect, other : Rect) -> Bool { self.x < other.x+other.width && other.x < self.x+self.width && self.y < other.y+other.height && other.y < self.y+self.height }

///|
pub struct Label {
  text : String; font : @model.Font; bounds : @model.ExactBounds?; box : Rect
  size : Double; weight : Int; rotation : Int; mask : Bool; owner : String; family : @theme.Family?
} derive(Eq, Debug)

///|
pub struct Shape { node : @model.Node; index : Int; bounds : @model.ExactBounds; box : Rect; label : Label? } derive(Eq, Debug)

///|
pub struct Connection { flow : @model.Flow; index : Int; source : String; target : String; points : ReadOnlyArray[@model.ExactPoint]; line : ReadOnlyArray[Point]; label : Label? } derive(Eq, Debug)

///|
pub(all) enum Source { Supplied; Automatic } derive(Eq, Debug)

///|
pub struct Geometry {
  view : @model.Bpmn; shapes : ReadOnlyArray[Shape]; connections : ReadOnlyArray[Connection]
  source : Source; translate_x : Int64; translate_y : Int64; width : Int64; height : Int64
} derive(Eq, Debug)

///|
pub struct Result { geometry : Geometry?; diagnostics : ReadOnlyArray[@diagrams.Diagnostic] } derive(Eq, Debug)

///|
priv struct Budget { limits : Limits; diagnostics : Array[@diagrams.Diagnostic]; mut work : Int; mut failed : Bool }

///|
fn Budget::error(self : Budget, code : String, message : String) -> Unit {
  if !self.failed { self.diagnostics.push(@diagrams.Diagnostic::error(code,message)) }
  self.failed=true
}

///|
fn Budget::charge(self : Budget, amount : Int) -> Bool {
  if amount < 0 || amount > self.limits.work-self.work { self.error("bpmn/layout-limit","BPMN geometry work limit exceeded"); return false }
  self.work+=amount; true
}

///|
/// Canonical derived SVG numbers have at most three fractional digits. Authored
/// supplied coordinates bypass this formatter and keep their exact tokens.
pub fn svg_number(value : Double) -> String? {
  if value != value || value.abs() > 1000000000000.0 { return None }
  let magnitude=(value.abs()*1000.0+0.5).floor().to_int64()
  let scaled=if value < 0.0 { -magnitude } else { magnitude }
  if scaled == 0L { return Some("0") }
  let negative=scaled < 0L; let magnitude=if negative { -scaled } else { scaled }
  let whole=magnitude/1000L; let fraction=(magnitude%1000L).to_int()
  let prefix=if negative { "-" } else { "" }
  if fraction == 0 { return Some("\{prefix}\{whole}") }
  let digits="\{if fraction < 100 { "0" } else { "" }}\{if fraction < 10 { "0" } else { "" }}\{fraction}"
  Some("\{prefix}\{whole}."+digits.trim_end(chars="0").to_owned())
}

///|
fn number(value : Double) -> @model.Number { @model.Number::parse(svg_number(value).unwrap()).unwrap() }

///|
fn exact_bounds(r : Rect) -> @model.ExactBounds { @model.ExactBounds::new(number(r.x),number(r.y),number(r.width),number(r.height)) }

///|
fn exact_point(p : Point) -> @model.ExactPoint { @model.ExactPoint::new(number(p.x),number(p.y)) }

///|
fn coordinate(n : @model.Number) -> Double? {
  let value=try @string.parse_double(n.token) catch { _ => return None }
  if value == value && value.abs() <= 1000000000.0 { Some(value) } else { None }
}

///|
fn rectangle(r : @model.ExactBounds) -> Rect? {
  guard coordinate(r.x) is Some(x) && coordinate(r.y) is Some(y) && coordinate(r.width) is Some(width) && coordinate(r.height) is Some(height) && width > 0.0 && height > 0.0 else { return None }
  Some({x,y,width,height})
}

///|
fn point(p : @model.ExactPoint) -> Point? { match (coordinate(p.x),coordinate(p.y)) { (Some(x),Some(y)) => Some({x,y}); _ => None } }

///|
pub fn family(kind : @model.NodeKind) -> @theme.Family {
  match kind {
    UserTask | ManualTask => Frontend
    DataObject | DataObjectReference | DataInput | DataOutput | DataStore | DataStoreReference => Database
    ExclusiveGateway | InclusiveGateway | ParallelGateway | ComplexGateway | EventBasedGateway => Cloud
    StartEvent | EndEvent | IntermediateCatchEvent | IntermediateThrowEvent | BoundaryEvent => MessageBus
    SendTask | ReceiveTask | Message => MessageBus
    Participant | Lane | Group | TextAnnotation => External
    _ => Backend
  }
}

///|
pub extend Limits with Eq::{equal,not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal,not_equal}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub extend Rect with Eq::{equal,not_equal}

///|
pub extend Rect with @debug.Debug::{to_repr}

///|
pub extend Label with Eq::{equal,not_equal}

///|
pub extend Label with @debug.Debug::{to_repr}

///|
pub extend Shape with Eq::{equal,not_equal}

///|
pub extend Shape with @debug.Debug::{to_repr}

///|
pub extend Connection with Eq::{equal,not_equal}

///|
pub extend Connection with @debug.Debug::{to_repr}

///|
pub extend Source with Eq::{equal,not_equal}

///|
pub extend Source with @debug.Debug::{to_repr}

///|
pub extend Geometry with Eq::{equal,not_equal}

///|
pub extend Geometry with @debug.Debug::{to_repr}

///|
pub extend Result with Eq::{equal,not_equal}

///|
pub extend Result with @debug.Debug::{to_repr}

///|
/// Preserve family hues while checking text against opaque canvas and the
/// actual coloured body. Sequence palette values are unchanged.
pub fn bpmn_palette(p : @theme.Palette) -> @theme.Palette {
  fn shaded(colors : @theme.FamilyColors) -> @theme.FamilyColors { {..colors,ink:@theme.text_shade(colors.ink,[p.bg,@theme.over(colors.fill,p.bg)])} }
  {..p,frontend:shaded(p.frontend),backend:shaded(p.backend),database:shaded(p.database),cloud:shaded(p.cloud),security:shaded(p.security),messagebus:shaded(p.messagebus),external:shaded(p.external)}
}

///|
/// Half the polyline's measured length, rather than its middle vertex.
pub fn midpoint(line : ArrayView[Point]) -> Point? {
  if line.is_empty() { return None }
  fn distance(a : Point, b : Point) -> Double {
    let dx=(b.x-a.x).abs(); let dy=(b.y-a.y).abs(); let hi=Double::max(dx,dy); let lo=Double::min(dx,dy)
    if hi == 0.0 { 0.0 } else { hi*(1.0+(lo/hi)*(lo/hi)).sqrt() }
  }
  let mut total=0.0
  for i in 1..<line.length() { total+=distance(line[i-1],line[i]) }
  let mut remaining=total/2.0
  for i in 1..<line.length() {
    let length=distance(line[i-1],line[i])
    if length > 0.0 && remaining <= length { let t=remaining/length; return Some({x:line[i-1].x+(line[i].x-line[i-1].x)*t,y:line[i-1].y+(line[i].y-line[i-1].y)*t}) }
    remaining-=length
  }
  line.get(0)
}
