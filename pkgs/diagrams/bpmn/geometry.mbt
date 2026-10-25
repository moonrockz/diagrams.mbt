///|
/// Exact finite XML numeric spelling. Renderers may approximate for measurements
/// but must retain these tokens when drawing supplied geometry.
pub struct Number { token : String } derive(Eq, Debug)

///|
fn digit_end(s : String, start : Int) -> Int {
  let mut i=start
  while i < s.length() && s.code_unit_at(i).to_int() >= 48 && s.code_unit_at(i).to_int() <= 57 { i+=1 }
  i
}

///|
pub fn Number::parse(token : String) -> Number? {
  let mut i=if token.has_prefix("+") || token.has_prefix("-") { 1 } else { 0 }
  let start=i; i=digit_end(token,i); let whole=i-start
  let mut fraction=0
  if i < token.length() && token.code_unit_at(i).to_int() == 46 { i+=1; let start=i; i=digit_end(token,i); fraction=i-start }
  if whole+fraction == 0 { return None }
  if i < token.length() && (token.code_unit_at(i).to_int() == 101 || token.code_unit_at(i).to_int() == 69) {
    i+=1
    if i < token.length() && (token.code_unit_at(i).to_int() == 43 || token.code_unit_at(i).to_int() == 45) { i+=1 }
    let start=i; i=digit_end(token,i); if start == i { return None }
  }
  if i == token.length() { Some({token,}) } else { None }
}

///|
pub struct ExactPoint { x : Number; y : Number } derive(Eq, Debug)

///|
pub fn ExactPoint::new(x : Number, y : Number) -> ExactPoint { {x,y} }

///|
pub struct ExactBounds { x : Number; y : Number; width : Number; height : Number } derive(Eq, Debug)

///|
pub fn ExactBounds::new(x : Number, y : Number, width : Number, height : Number) -> ExactBounds { {x,y,width,height} }

///|
pub struct Font { name : String?; size : Number?; bold : Bool?; italic : Bool?; underline : Bool?; strike_through : Bool? } derive(Eq, Debug)

///|
pub fn Font::new(name? : String, size? : Number, bold? : Bool, italic? : Bool, underline? : Bool, strike_through? : Bool) -> Font { {name,size,bold,italic,underline,strike_through} }

///|
pub extend Font with Eq::{equal,not_equal}

///|
pub extend Font with @debug.Debug::{to_repr}

///|
pub(all) enum MessageVisibility { Initiating; NonInitiating } derive(Eq, Debug)

///|
pub extend MessageVisibility with Eq::{equal,not_equal}

///|
pub extend MessageVisibility with @debug.Debug::{to_repr}

///|
pub struct LabelGeometry { bounds : ExactBounds?; style : SourceIdentity?; font : Font? } derive(Eq, Debug)

///|
pub fn LabelGeometry::new(bounds? : ExactBounds, style? : SourceIdentity, font? : Font) -> LabelGeometry { {bounds,style,font} }

///|
pub struct ShapeGeometry {
  identity : SourceIdentity; bounds : ExactBounds?; label : LabelGeometry?
  horizontal : Bool?; expanded : Bool?; marker_visible : Bool?; message_visible : Bool?
} derive(Eq, Debug)

///|
pub fn ShapeGeometry::new(identity : SourceIdentity, bounds? : ExactBounds, label? : LabelGeometry, horizontal? : Bool, expanded? : Bool, marker_visible? : Bool, message_visible? : Bool) -> ShapeGeometry { {identity,bounds,label,horizontal,expanded,marker_visible,message_visible} }

///|
pub struct EdgeGeometry {
  identity : SourceIdentity; points : ReadOnlyArray[ExactPoint]; label : LabelGeometry?
  source_shape : SourceIdentity?; target_shape : SourceIdentity?; message_visible : MessageVisibility?
} derive(Eq, Debug)

///|
pub fn EdgeGeometry::new(identity : SourceIdentity, points : ArrayView[ExactPoint], label? : LabelGeometry, source_shape? : SourceIdentity, target_shape? : SourceIdentity, message_visible? : MessageVisibility) -> EdgeGeometry { {identity,points:ReadOnlyArray::from_array(points),label,source_shape,target_shape,message_visible} }

///|
pub extend Number with Eq::{equal, not_equal}

///|
pub extend Number with @debug.Debug::{to_repr}

///|
pub extend ExactPoint with Eq::{equal, not_equal}

///|
pub extend ExactPoint with @debug.Debug::{to_repr}

///|
pub extend ExactBounds with Eq::{equal, not_equal}

///|
pub extend ExactBounds with @debug.Debug::{to_repr}

///|
pub extend LabelGeometry with Eq::{equal, not_equal}

///|
pub extend LabelGeometry with @debug.Debug::{to_repr}

///|
pub extend ShapeGeometry with Eq::{equal, not_equal}

///|
pub extend ShapeGeometry with @debug.Debug::{to_repr}

///|
pub extend EdgeGeometry with Eq::{equal, not_equal}

///|
pub extend EdgeGeometry with @debug.Debug::{to_repr}
