///|
/// A colour family of the archify classic preset.
pub(all) enum Family {
  Frontend
  Backend
  Database
  Cloud
  Security
  MessageBus
  External
} derive(Eq, Debug)

///|
pub extend Family with Eq::{not_equal, equal}

///|
pub extend Family with @debug.Debug::{to_repr}

///|
/// The name of the family, as used in CSS class and variable names.
pub fn Family::name(self : Family) -> String {
  match self {
    Frontend => "frontend"
    Backend => "backend"
    Database => "database"
    Cloud => "cloud"
    Security => "security"
    MessageBus => "messagebus"
    External => "external"
  }
}

///|
/// The families, in the order of the CSS that the renderer writes.
pub let all_families : ReadOnlyArray[Family] = [
  Frontend, Backend, Database, Cloud, Security, MessageBus, External,
]

///|
/// The colours of one family. `fill` and `stroke` are archify's values. `ink`
/// is the colour of text in this family, with at least 4.5:1 contrast.
pub(all) struct FamilyColors {
  fill : Color
  stroke : Color
  ink : Color
} derive(Eq, Debug)

///|
pub extend FamilyColors with Eq::{not_equal, equal}

///|
pub extend FamilyColors with @debug.Debug::{to_repr}

///|
/// The colours of one theme variant, dark or light.
pub(all) struct Palette {
  bg : Color
  text : Color
  muted : Color
  mask : Color
  arrow : Color
  frontend : FamilyColors
  backend : FamilyColors
  database : FamilyColors
  cloud : FamilyColors
  security : FamilyColors
  messagebus : FamilyColors
  external : FamilyColors
} derive(Eq, Debug)

///|
pub extend Palette with Eq::{not_equal, equal}

///|
pub extend Palette with @debug.Debug::{to_repr}

///|
/// The colours of the family `f`.
pub fn Palette::family(self : Palette, f : Family) -> FamilyColors {
  match f {
    Frontend => self.frontend
    Backend => self.backend
    Database => self.database
    Cloud => self.cloud
    Security => self.security
    MessageBus => self.messagebus
    External => self.external
  }
}

///|
/// A theme with a dark and a light variant.
pub(all) struct Theme {
  dark : Palette
  light : Palette
} derive(Eq, Debug)

///|
pub extend Theme with Eq::{not_equal, equal}

///|
pub extend Theme with @debug.Debug::{to_repr}

///|
fn fam(fill : Color, stroke : Int, ink : Int) -> FamilyColors {
  { fill, stroke: Color::hex(stroke), ink: Color::hex(ink) }
}

///|
/// The classic preset of archify (MIT), in dark and light. In the light
/// variant, the ink of six families is a darker shade of the same hue, because
/// archify's colour has less than 4.5:1 contrast as text.
pub fn Theme::classic() -> Theme {
  let rgba = Color::rgba
  {
    dark: {
      bg: Color::hex(0x020617),
      text: Color::hex(0xffffff),
      muted: Color::hex(0x94a3b8),
      mask: Color::hex(0x0f172a),
      arrow: Color::hex(0x94a3b8),
      frontend: fam(rgba(8, 51, 68, 40), 0x22d3ee, 0x22d3ee),
      backend: fam(rgba(6, 78, 59, 40), 0x34d399, 0x34d399),
      database: fam(rgba(76, 29, 149, 40), 0xa78bfa, 0xa78bfa),
      cloud: fam(rgba(120, 53, 15, 30), 0xfbbf24, 0xfbbf24),
      security: fam(rgba(136, 19, 55, 40), 0xfb7185, 0xfb7185),
      messagebus: fam(rgba(251, 146, 60, 30), 0xfb923c, 0xfb923c),
      external: fam(rgba(30, 41, 59, 50), 0x94a3b8, 0x94a3b8),
    },
    light: {
      bg: Color::hex(0xf4f5f7),
      text: Color::hex(0x111827),
      muted: Color::hex(0x5b6474),
      mask: Color::hex(0xffffff),
      arrow: Color::hex(0x64748b),
      frontend: fam(rgba(34, 211, 238, 15), 0x0891b2, 0x077995),
      backend: fam(rgba(52, 211, 153, 18), 0x059669, 0x047d58),
      database: fam(rgba(167, 139, 250, 20), 0x7c3aed, 0x7c3aed),
      cloud: fam(rgba(251, 191, 36, 18), 0xd97706, 0xa75c05),
      security: fam(rgba(251, 113, 133, 15), 0xe11d48, 0xd81c45),
      messagebus: fam(rgba(251, 146, 60, 15), 0xea580c, 0xc3490a),
      external: fam(rgba(148, 163, 184, 18), 0x64748b, 0x606f85),
    },
  }
}

///|
/// The families that participants with no specific kind get, in order.
let cycle : Array[Family] = [Frontend, Backend, Database, Cloud, MessageBus]

///|
/// The colour family of a participant kind. A participant with no specific
/// kind gets the family at `cycle_index` of a fixed cycle.
pub fn family_of(kind : @sequence.ParticipantKind, cycle_index : Int) -> Family {
  match kind {
    Actor | Client => Frontend
    Service | Control => Backend
    Database | Collections | Entity => Database
    Queue => MessageBus
    Boundary => Security
    Resource => Cloud
    Participant => cycle[cycle_index % cycle.length()]
  }
}
