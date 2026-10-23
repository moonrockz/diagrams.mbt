///|
/// An sRGB colour. `alpha` is the opacity in percent, from 0 to 100.
pub struct Color {
  r : Int
  g : Int
  b : Int
  alpha : Int
} derive(Eq, Debug)

///|
pub extend Color with Eq::{not_equal, equal}

///|
pub extend Color with @debug.Debug::{to_repr}

///|
/// An opaque colour from a hex value, for example `0x020617`.
pub fn Color::hex(value : Int) -> Color {
  { r: (value >> 16) & 0xff, g: (value >> 8) & 0xff, b: value & 0xff, alpha: 100 }
}

///|
/// A colour with the opacity `alpha` in percent.
pub fn Color::rgba(r : Int, g : Int, b : Int, alpha : Int) -> Color {
  { r, g, b, alpha }
}

///|
fn hex2(n : Int) -> String {
  let digits = "0123456789abcdef"
  let hi = digits.view(start_offset=n >> 4, end_offset=(n >> 4) + 1)
  let lo = digits.view(start_offset=n & 0xf, end_offset=(n & 0xf) + 1)
  "\{hi}\{lo}"
}

///|
/// The opacity as a decimal number, for example `0.4` for 40 percent.
fn opacity_text(percent : Int) -> String {
  if percent >= 100 {
    "1"
  } else if percent % 10 == 0 {
    "0.\{percent / 10}"
  } else if percent < 10 {
    "0.0\{percent}"
  } else {
    "0.\{percent}"
  }
}

///|
/// CSS text for the colour: `#rrggbb` when it is opaque, else `rgba(...)`.
pub fn Color::to_css(self : Color) -> String {
  if self.alpha >= 100 {
    "#\{hex2(self.r)}\{hex2(self.g)}\{hex2(self.b)}"
  } else {
    "rgba(\{self.r}, \{self.g}, \{self.b}, \{opacity_text(self.alpha)})"
  }
}

///|
/// The opaque colour of `top` painted over the opaque colour `bottom`.
pub fn over(top : Color, bottom : Color) -> Color {
  let a = top.alpha.to_double() / 100.0
  let mix = (t : Int, u : Int) => (t.to_double() * a + u.to_double() * (1.0 - a))
    .round()
    .to_int()
  { r: mix(top.r, bottom.r), g: mix(top.g, bottom.g), b: mix(top.b, bottom.b), alpha: 100 }
}

///|
fn channel(c : Int) -> Double {
  let v = c.to_double() / 255.0
  if v <= 0.03928 {
    v / 12.92
  } else {
    @math.pow((v + 0.055) / 1.055, 2.4)
  }
}

///|
/// The relative luminance of an opaque colour, as WCAG 2 defines it.
pub fn luminance(c : Color) -> Double {
  0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
}

///|
/// The WCAG 2 contrast ratio of two opaque colours, from 1 to 21.
pub fn contrast(a : Color, b : Color) -> Double {
  let la = luminance(a)
  let lb = luminance(b)
  let (hi, lo) = if la > lb { (la, lb) } else { (lb, la) }
  (hi + 0.05) / (lo + 0.05)
}
