///|
/// A table of values that Python refers to by opaque tokens.
///
/// A token holds the registry kind (bits 48-55), the slot generation
/// (bits 24-47) and the slot (bits 0-23). Removing a value increments the
/// generation of its slot, so an old token cannot reach a later value. The
/// adapter serializes all access, so a registry needs no lock of its own.
pub struct Registry[T] {
  kind : Int32
  priv slots : Array[T?]
  priv generations : Array[Int32]
  priv free : Array[Int32]
  priv mut live : Int32
}

///|
let max_slots : Int32 = 0xFFFFFF

///|
let max_generation : Int32 = 0xFFFFFF

///|
/// A registry with `kind` from 1 to 255. Each registry has its own kind.
pub fn[T] Registry::new(kind : Int32) -> Registry[T] {
  guard kind >= 1 && kind <= 255 else { abort("registry kind out of range") }
  { kind, slots: [], generations: [], free: [], live: 0, }
}

///|
/// Adds `value` and returns its new token.
pub fn[T] Registry::add(
  self : Registry[T],
  value : T,
) -> Int64 raise BridgeError {
  let slot = match self.free.pop() {
    Some(slot) => slot
    None => {
      guard self.slots.length() < max_slots else {
        raise BridgeError("resource-limit", "Too many open native objects.")
      }
      self.slots.push(None)
      self.generations.push(1)
      self.slots.length() - 1
    }
  }
  self.slots[slot] = Some(value)
  self.live += 1
  (self.kind.to_int64() << 48) |
  (self.generations[slot].to_int64() << 24) |
  slot.to_int64()
}

///|
fn[T] Registry::slot(
  self : Registry[T],
  token : Int64,
) -> Int32 raise BridgeError {
  guard token >= 0L && token >> 48 == self.kind.to_int64() else {
    raise BridgeError(
      "wrong-token", "The token belongs to another object kind.",
    )
  }
  let slot = (token & 0xFFFFFFL).to_int()
  let generation = ((token >> 24) & 0xFFFFFFL).to_int()
  guard slot < self.slots.length() && generation > 0 else {
    raise BridgeError(
      "invalid-token", "The token does not name a native object.",
    )
  }
  guard self.generations[slot] == generation && self.slots[slot] is Some(_) else {
    raise BridgeError("closed-token", "The native object is closed.")
  }
  slot
}

///|
/// The value of `token`. Tokens of another kind, unknown slots and closed
/// values raise `wrong-token`, `invalid-token` and `closed-token`.
pub fn[T] Registry::get(
  self : Registry[T],
  token : Int64,
) -> T raise BridgeError {
  self.slots[self.slot(token)].unwrap()
}

///|
/// Removes the value of `token`. Returns `false` when it is already closed, so
/// closing is idempotent. Tokens of another kind or unknown slots still raise.
pub fn[T] Registry::remove(
  self : Registry[T],
  token : Int64,
) -> Bool raise BridgeError {
  let slot = self.slot(token) catch {
    BridgeError("closed-token", _) => return false
    error => raise error
  }
  self.slots[slot] = None
  self.live -= 1
  if self.generations[slot] < max_generation {
    self.generations[slot] += 1
    self.free.push(slot)
  }
  // A slot whose generation is exhausted is retired, never reused.
  true
}

///|
/// The number of open values.
pub fn[T] Registry::live(self : Registry[T]) -> Int32 {
  self.live
}
