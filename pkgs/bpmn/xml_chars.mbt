///|
fn unit(s : String, i : Int) -> Int { if i < 0 || i >= s.length() { -1 } else { s.code_unit_at(i).to_int() } }

///|
fn space(c : Int) -> Bool { c == 32 || c == 9 || c == 10 || c == 13 }

///|
fn xml_char(c : Int) -> Bool {
  c == 9 || c == 10 || c == 13 || (c >= 32 && c <= 0xd7ff) || (c >= 0xe000 && c <= 0xfffd) || (c >= 0x10000 && c <= 0x10ffff)
}

///|
fn codepoint(s : String, i : Int) -> (Int, Int) {
  let c = unit(s, i)
  if c >= 0xd800 && c <= 0xdbff {
    let next = unit(s, i+1)
    if next >= 0xdc00 && next <= 0xdfff { return (0x10000 + (c-0xd800)*1024 + next-0xdc00, 2) }
  }
  (c, 1)
}

///|
fn name_start(c : Int) -> Bool {
  c == 95 || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) ||
  (c >= 0xc0 && c <= 0xd6) || (c >= 0xd8 && c <= 0xf6) || (c >= 0xf8 && c <= 0x2ff) ||
  (c >= 0x370 && c <= 0x37d) || (c >= 0x37f && c <= 0x1fff) ||
  (c >= 0x200c && c <= 0x200d) || (c >= 0x2070 && c <= 0x218f) ||
  (c >= 0x2c00 && c <= 0x2fef) || (c >= 0x3001 && c <= 0xd7ff) ||
  (c >= 0xf900 && c <= 0xfdcf) || (c >= 0xfdf0 && c <= 0xfffd) ||
  (c >= 0x10000 && c <= 0xeffff)
}

///|
fn name_char(c : Int) -> Bool {
  name_start(c) || c == 45 || c == 46 || (c >= 48 && c <= 57) || c == 0xb7 ||
  (c >= 0x300 && c <= 0x36f) || (c >= 0x203f && c <= 0x2040)
}

///|
fn ncname(s : String) -> Bool {
  if s.is_empty() { return false }
  let mut i = 0
  while i < s.length() {
    let (c, width) = codepoint(s, i)
    if !(if i == 0 { name_start(c) } else { name_char(c) }) { return false }
    i += width
  }
  true
}

///|
fn qname(s : String) -> (String, String)? {
  if s.find(":") is Some(at) {
    let prefix = s[:at].to_owned()
    let suffix = s[at+1:].to_owned()
    if ncname(prefix) && ncname(suffix) { Some((prefix, suffix)) } else { None }
  } else if ncname(s) { Some(("", s)) } else { None }
}

///|
fn reference(s : String) -> Int? {
  match s {
    "amp" => return Some(38); "lt" => return Some(60); "gt" => return Some(62)
    "quot" => return Some(34); "apos" => return Some(39)
    _ => ()
  }
  guard s.has_prefix("#") else { return None }
  let hex = s.has_prefix("#x")
  let begin = if hex { 2 } else { 1 }
  if s.length() == begin { return None }
  let radix = if hex { 16 } else { 10 }
  let mut n = 0
  for i in begin..<s.length() {
    let c = unit(s, i)
    let digit = if c >= 48 && c <= 57 { c - 48 }
      else if hex && c >= 65 && c <= 70 { c - 55 }
      else if hex && c >= 97 && c <= 102 { c - 87 } else { return None }
    if digit >= radix || n > (0x10ffff - digit) / radix { return None }
    n = n * radix + digit
  }
  if xml_char(n) { Some(n) } else { None }
}
