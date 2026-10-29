///|
/// The outline dependency assumes trusted table offsets. Validate the static
/// glyf profile and rebuild only the tables this renderer consumes before
/// calling it, so malformed optional tables cannot trigger unchecked reads.
fn font_u16(data : Bytes, index : Int32) -> Int32 raise RasterFailure {
  guard index >= 0 && index <= data.length() - 2 else {
    raise raster_fail("raster/font-data", "Truncated TrueType table")
  }
  data[index].to_int() * 256 + data[index + 1].to_int()
}

///|
fn font_u32(data : Bytes, index : Int32) -> Int64 raise RasterFailure {
  font_u16(data, index).to_int64() * 65536L +
  font_u16(data, index + 2).to_int64()
}

///|
fn font_slice(
  data : Bytes,
  offset : Int64,
  length : Int64,
) -> Bytes raise RasterFailure {
  guard offset >= 0L &&
    length >= 0L &&
    offset <= data.length().to_int64() &&
    length <= data.length().to_int64() - offset else {
    raise raster_fail(
      "raster/font-data", "TrueType table range is outside the supplied bytes",
    )
  }
  data[offset.to_int():(offset + length).to_int()].to_owned()
}

///|
fn validate_cmap(data : Bytes, num_glyphs : Int32) -> Bool raise RasterFailure {
  let count = font_u16(data, 2)
  guard count <= 4096 && 4 + count * 8 <= data.length() else {
    raise raster_fail("raster/font-data", "Invalid cmap directory")
  }
  let mut wrapped = false
  let mut mapped = 0L
  let mut copied = 0L
  let visited : Map[Int64, Bool] = Map([])
  for i in 0..<count {
    let offset = font_u32(data, 4 + i * 8 + 4)
    guard offset <= data.length().to_int64() - 2L else {
      raise raster_fail("raster/font-data", "Invalid cmap subtable offset")
    }
    if visited.contains(offset) {
      continue
    }
    visited[offset] = true
    let start = offset.to_int()
    let format = font_u16(data, start)
    if format == 12 {
      let length = font_u32(data, start + 4)
      copied = charge_cmap_bytes(copied, length, data.length())
      let table = font_slice(data, offset, length)
      let groups = font_u32(table, 12)
      guard groups <= 100000L && 16L + groups * 12L <= table.length().to_int64() else {
        raise raster_fail("raster/font-data", "Invalid cmap group count")
      }
      for n in 0..<groups.to_int() {
        let at = 16 + n * 12
        let first = font_u32(table, at)
        let last = font_u32(table, at + 4)
        let gid = font_u32(table, at + 8)
        guard first <= last &&
          last <= 1114111L &&
          gid + (last - first) < num_glyphs.to_int64() else {
          raise raster_fail("raster/font-data", "Invalid cmap glyph range")
        }
        mapped = charge_cmap_mappings(mapped, last - first + 1L)
      }
    } else if format == 4 {
      let length = font_u16(data, start + 2).to_int64()
      copied = charge_cmap_bytes(copied, length, data.length())
      let table = font_slice(data, offset, length)
      let count2 = font_u16(table, 6)
      let segments = count2 / 2
      guard count2 % 2 == 0 &&
        segments > 0 &&
        16 + segments * 8 <= table.length() else {
        raise raster_fail("raster/font-data", "Invalid cmap segment count")
      }
      for seg in 0..<segments {
        let last = font_u16(table, 14 + seg * 2)
        let first = font_u16(table, 16 + segments * 2 + seg * 2)
        let range_at = 16 + segments * 6 + seg * 2
        let range = font_u16(table, range_at)
        guard first <= last else {
          raise raster_fail("raster/font-data", "Reversed cmap range")
        }
        if range != 0 {
          guard range_at + range + (last - first) * 2 <= table.length() - 2 else {
            raise raster_fail(
              "raster/font-data", "cmap glyph array is truncated",
            )
          }
        }
        let raw_delta = font_u16(table, 16 + segments * 4 + seg * 2)
        let delta = if raw_delta >= 32768 {
          raw_delta - 65536
        } else {
          raw_delta
        }
        mapped = charge_cmap_mappings(mapped, (last - first + 1).to_int64())
        if first != 65535 {
          for cp in first..<=last {
            let raw = if range == 0 {
              cp
            } else {
              font_u16(table, range_at + range + (cp - first) * 2)
            }
            if raw + delta < 0 && !(range != 0 && raw == 0) {
              wrapped = true
            }
            let gid = if range != 0 && raw == 0 {
              0
            } else {
              (raw + delta) & 65535
            }
            guard gid < num_glyphs else {
              raise raster_fail(
                "raster/font-data", "cmap references a glyph outside maxp",
              )
            }
          }
        }
      }
    } else if format == 0 {
      copied = charge_cmap_bytes(copied, 262L, data.length())
      let table = font_slice(data, offset, 262L)
      mapped = charge_cmap_mappings(mapped, 256L)
      for n in 0..<256 {
        guard table[6 + n].to_int() < num_glyphs else {
          raise raster_fail(
            "raster/font-data", "cmap references a glyph outside maxp",
          )
        }
      }
    } else if format == 6 {
      let length = font_u16(data, start + 2).to_int64()
      copied = charge_cmap_bytes(copied, length, data.length())
      let table = font_slice(data, offset, length)
      let entries = font_u16(table, 8)
      guard 10 + entries * 2 <= table.length() else {
        raise raster_fail("raster/font-data", "cmap format 6 is truncated")
      }
      mapped = charge_cmap_mappings(mapped, entries.to_int64())
      for n in 0..<entries {
        guard font_u16(table, 10 + n * 2) < num_glyphs else {
          raise raster_fail(
            "raster/font-data", "cmap references a glyph outside maxp",
          )
        }
      }
    }
  }
  wrapped
}

///|
fn validate_glyph(
  data : Bytes,
  edges : Array[Int32],
  num_glyphs : Int32,
) -> Int32 raise RasterFailure {
  if data.length() == 0 {
    return 0
  }
  let contours = font_u16(data, 0)
  ignore(font_u16(data, 8))
  let mut cursor = 10
  if contours < 32768 {
    guard contours <= 4096 else {
      raise raster_fail("raster/font-limit", "Glyph contour budget exceeded")
    }
    let mut points = 0
    for i in 0..<contours {
      let endpoint = font_u16(data, cursor)
      cursor += 2
      guard i == 0 || endpoint >= points else {
        raise raster_fail(
          "raster/font-data", "Glyph contour endpoints are not ordered",
        )
      }
      points = endpoint + 1
    }
    cursor += 2 + font_u16(data, cursor)
    guard cursor <= data.length() else {
      raise raster_fail("raster/font-data", "Glyph instructions are truncated")
    }
    let mut seen = 0
    let mut coordinates = 0
    while seen < points {
      guard cursor < data.length() else {
        raise raster_fail("raster/font-data", "Glyph flags are truncated")
      }
      let flag = data[cursor].to_int()
      cursor += 1
      let repeat = if (flag & 8) != 0 {
        guard cursor < data.length() else {
          raise raster_fail(
            "raster/font-data", "Glyph repeat flag is truncated",
          )
        }
        let n = data[cursor].to_int() + 1
        cursor += 1
        n
      } else {
        1
      }
      guard repeat <= points - seen else {
        raise raster_fail(
          "raster/font-data", "Glyph flag repetition exceeds its point count",
        )
      }
      let x = if (flag & 2) != 0 { 1 } else if (flag & 16) != 0 { 0 } else { 2 }
      let y = if (flag & 4) != 0 { 1 } else if (flag & 32) != 0 { 0 } else { 2 }
      coordinates += (x + y) * repeat
      seen += repeat
    }
    guard coordinates <= data.length() - cursor else {
      raise raster_fail("raster/font-data", "Glyph coordinates are truncated")
    }
    points
  } else {
    let mut components = 0
    while true {
      let flags = font_u16(data, cursor)
      let gid = font_u16(data, cursor + 2)
      guard gid < num_glyphs && (flags & 2) != 0 else {
        raise raster_fail(
          "raster/font-data", "Compound glyph reference or point attachment is unsupported",
        )
      }
      edges.push(gid)
      cursor += 4 + (if (flags & 1) != 0 { 4 } else { 2 })
      if (flags & 128) != 0 {
        guard font_u16(data, cursor + 2) == 0 && font_u16(data, cursor + 4) == 0 else {
          raise raster_fail(
            "raster/font-profile", "Compound glyph shear/rotation is outside the static outline profile",
          )
        }
      }
      cursor += if (flags & 8) != 0 {
        2
      } else if (flags & 64) != 0 {
        4
      } else if (flags & 128) != 0 {
        8
      } else {
        0
      }
      guard cursor <= data.length() else {
        raise raster_fail(
          "raster/font-data", "Compound glyph transform is truncated",
        )
      }
      components += 1
      guard components <= 256 else {
        raise raster_fail(
          "raster/font-limit", "Compound glyph component budget exceeded",
        )
      }
      if (flags & 32) == 0 {
        break
      }
    }
    0
  }
}

///|
fn validated_font_bytes(
  data : Bytes,
  limits : RasterLimits,
) -> Bytes raise RasterFailure {
  guard data.length() <= limits.max_source_units &&
    data.length() >= 12 &&
    font_u32(data, 0) == 65536L else {
    raise raster_fail(
      "raster/font-data", "Supply a bounded static TrueType glyf font",
    )
  }
  let count = font_u16(data, 4)
  guard count <= 4096 && 12 + count * 16 <= data.length() else {
    raise raster_fail("raster/font-data", "Invalid TrueType table count")
  }
  let tables : Map[String, Bytes] = Map([])
  let mut table_units = 0L
  for i in 0..<count {
    let at = 12 + i * 16
    let name = String::from_array([
      data[at].to_int().unsafe_to_char(),
      data[at + 1].to_int().unsafe_to_char(),
      data[at + 2].to_int().unsafe_to_char(),
      data[at + 3].to_int().unsafe_to_char(),
    ])
    guard !tables.contains(name) else {
      raise raster_fail("raster/font-data", "Duplicate TrueType table")
    }
    let length = font_u32(data, at + 12)
    guard length <= limits.max_source_units.to_int64() - table_units else {
      raise raster_fail("raster/font-limit", "TrueType table copies exceed the source budget")
    }
    table_units += length
    tables[name] = font_slice(data, font_u32(data, at + 8), length)
  }
  for name in ["fvar", "gvar", "CFF ", "CFF2", "COLR", "CBDT", "sbix", "SVG "] {
    guard !tables.contains(name) else {
      raise raster_fail(
        "raster/font-profile", "Variable, CFF and color fonts require another explicit font profile",
      )
    }
  }
  fn table(name : String) -> Bytes raise RasterFailure {
    match tables.get(name) {
      Some(bytes) => bytes
      None =>
        raise raster_fail("raster/font-data", "Missing TrueType table " + name)
    }
  }
  let head = table("head")
  let hhea = table("hhea")
  let maxp = table("maxp")
  let hmtx = table("hmtx")
  let loca = table("loca")
  let glyf = table("glyf")
  let cmap = table("cmap")
  guard head.length() >= 54 && hhea.length() >= 36 && maxp.length() >= 6 else {
    raise raster_fail("raster/font-data", "Truncated TrueType metrics")
  }
  let em = font_u16(head, 18)
  let loca_format = font_u16(head, 50)
  let glyphs = font_u16(maxp, 4)
  let metrics = font_u16(hhea, 34)
  guard em >= 16 &&
    em <= 16384 &&
    glyphs > 0 &&
    metrics > 0 &&
    metrics <= glyphs &&
    (loca_format == 0 || loca_format == 1) &&
    hmtx.length() >= metrics * 4 + (glyphs - metrics) * 2 else {
    raise raster_fail("raster/font-data", "Invalid TrueType metrics")
  }
  let unit = if loca_format == 0 { 2 } else { 4 }
  guard loca.length() >= (glyphs + 1) * unit else {
    raise raster_fail("raster/font-data", "Glyph location table is truncated")
  }
  let wrapped_cmap = validate_cmap(cmap, glyphs)
  let edges : Array[Array[Int32]] = []
  let weights : Array[Int32] = []
  let mut previous = 0L
  for gid in 0..<glyphs {
    let start = if unit == 2 {
      font_u16(loca, gid * 2).to_int64() * 2L
    } else {
      font_u32(loca, gid * 4)
    }
    let end = if unit == 2 {
      font_u16(loca, (gid + 1) * 2).to_int64() * 2L
    } else {
      font_u32(loca, (gid + 1) * 4)
    }
    guard start >= previous && end >= start && end <= glyf.length().to_int64() else {
      raise raster_fail("raster/font-data", "Glyph locations are outside glyf")
    }
    previous = end
    let children : Array[Int32] = []
    weights.push(
      validate_glyph(font_slice(glyf, start, end - start), children, glyphs),
    )
    edges.push(children)
  }
  let marks = Array::make(glyphs, 0)
  let totals = Array::make(glyphs, 0)
  fn visit(gid : Int32, depth : Int32) -> Int32 raise RasterFailure {
    guard depth <= 16 && marks[gid] != 1 else {
      raise raster_fail(
        "raster/font-data", "Compound glyph cycle or depth limit",
      )
    }
    if marks[gid] == 2 {
      return totals[gid]
    }
    marks[gid] = 1
    let mut points = weights[gid]
    for child in edges[gid] {
      let more = visit(child, depth + 1)
      guard more <= 100000 - points else {
        raise raster_fail(
          "raster/font-limit", "Expanded glyph point budget exceeded",
        )
      }
      points += more
    }
    marks[gid] = 2
    totals[gid] = points
    points
  }
  for gid in 0..<glyphs {
    ignore(visit(gid, 0))
  }
  let selected = [
    ("head", head),
    ("hhea", hhea),
    ("maxp", maxp),
    ("hmtx", hmtx),
    ("loca", loca),
    ("glyf", glyf),
    ("cmap", cmap),
  ]
  if tables.get("kern") is Some(kern) {
    guard font_u16(kern, 0) == 0 else {
      raise raster_fail(
        "raster/font-profile", "Only static horizontal kern format 0 is supported",
      )
    }
    let count = font_u16(kern, 2)
    let mut cursor = 4
    guard count <= 4096 else {
      raise raster_fail("raster/font-limit", "Too many kerning subtables")
    }
    for _ in 0..<count {
      let length = font_u16(kern, cursor + 2)
      let coverage = font_u16(kern, cursor + 4)
      guard length >= 14 && coverage >> 8 == 0 && (coverage & 1) == 1 else {
        raise raster_fail(
          "raster/font-profile", "Only static horizontal kern format 0 is supported",
        )
      }
      let table = font_slice(kern, cursor.to_int64(), length.to_int64())
      let pairs = font_u16(table, 6)
      guard 14 + pairs * 6 <= length else {
        raise raster_fail("raster/font-data", "Truncated kerning pairs")
      }
      for n in 0..<pairs {
        guard font_u16(table, 14 + n * 6) < glyphs &&
          font_u16(table, 16 + n * 6) < glyphs else {
          raise raster_fail(
            "raster/font-data", "Kerning pair references an absent glyph",
          )
        }
      }
      cursor += length
    }
    selected.push(("kern", kern))
  }
  // Family/style metadata is explicit in FontFace; unrelated optional tables
  // cannot reach the candidate parser's unchecked readers.
  let safe = @font.rebuild_sfnt(65536, selected)
  if !wrapped_cmap {
    return safe
  }
  // The dependency's format-4 signed remainder can produce negative IDs.
  // Rebuild only affected fonts with equivalent positive format-12 mappings,
  // so outlining and the dependency's independent subset parser agree.
  guard @font.parse_font(safe) is Some(parsed) else {
    raise raster_fail("raster/font-data", "Unable to normalize validated cmap")
  }
  selected[6] = ("cmap", positive_font_cmap(parsed, limits))
  let rebuilt = @font.rebuild_sfnt(65536, selected)
  guard rebuilt.length() <= limits.max_source_units else {
    raise raster_fail("raster/font-limit", "Normalized font exceeds the source budget")
  }
  rebuilt
}

///|
fn charge_cmap_mappings(mapped : Int64, count : Int64) -> Int64 raise RasterFailure {
  guard count >= 0L && count <= 1200000L - mapped else {
    raise raster_fail("raster/font-limit", "cmap expansion exceeds the font budget")
  }
  mapped + count
}

///|
fn charge_cmap_bytes(copied : Int64, count : Int64, size : Int32) -> Int64 raise RasterFailure {
  guard count >= 0L && count <= size.to_int64() * 4L - copied else {
    raise raster_fail("raster/font-limit", "Overlapping cmap tables exceed the font byte budget")
  }
  copied + count
}

///|
fn positive_font_cmap(font : @font.TTFont, limits : RasterLimits) -> Bytes raise RasterFailure {
  let cps = font.cmap.keys().to_array()
  cps.sort()
  let groups : Array[(Int32, Int32, Int32)] = []
  for cp in cps {
    let gid = font.cmap[cp] & 65535
    guard gid < font.num_glyphs else {
      raise raster_fail("raster/font-data", "Normalized cmap references an absent glyph")
    }
    if gid == 0 { continue }
    if groups.last() is Some((first, last, start_gid)) && cp == last + 1 && gid == start_gid + cp - first {
      groups[groups.length() - 1] = (first, cp, start_gid)
    } else {
      guard groups.length() < (limits.max_source_units - 28) / 12 else {
        raise raster_fail("raster/font-limit", "Normalized cmap exceeds the source budget")
      }
      groups.push((cp, cp, gid))
    }
  }
  let bytes = Array::make(28 + groups.length() * 12, b'\x00')
  @font.write_be16(bytes, 2, 1)
  @font.write_be16(bytes, 4, 3)
  @font.write_be16(bytes, 6, 10)
  @font.write_be32(bytes, 8, 12)
  @font.write_be16(bytes, 12, 12)
  @font.write_be32(bytes, 16, bytes.length() - 12)
  @font.write_be32(bytes, 24, groups.length())
  for i, (first, last, gid) in groups {
    @font.write_be32(bytes, 28 + i * 12, first)
    @font.write_be32(bytes, 32 + i * 12, last)
    @font.write_be32(bytes, 36 + i * 12, gid)
  }
  Bytes::from_array(bytes)
}
