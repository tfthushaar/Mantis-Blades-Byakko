// Byakko - Identifying the cyberarms
//
// Mantis Blades and Gorilla Arms are cyberware, not inventory weapons, so they live under their
// own record trees and none of the katana record names reach them. The game does give each its
// own item type, gamedataItemType.Cyb_MantisBlades and gamedataItemType.Cyb_StrongArms, which is
// a far steadier handle than matching record-name strings: between them they cover all 41 Mantis
// Blade records (base, Chemical, Electric, Thermal, MaxTac, every rarity and ++ tier) and every
// Gorilla Arms record, without listing any of them, and they keep working if a patch adds more.
//
// Both item types are confirmed present on the installed game by compiling a probe against the
// game's own scc.exe.
//
// ---------------------------------------------------------------------------
// Why there are no Mantis-only lookups here any more
//
// There were five: BYKIsMantisItem, BYKIsMantisWeapon, BYKInstalledMantisItem, BYKEquippedMantis
// and BYKEquippedMantisSettled. They were the whole module back when this was a Mantis Blades
// mod, and they were left in place when Gorilla Arms arrived.
//
// Three features kept calling them long after that: the resting speed lift, the kill burst and
// the F8 readout. So Gorilla Arms received profiles, abilities and both timed windows while
// getting no baseline and no kill burst, and the readout denied they were supported at all. None
// of it was deliberate. Every one of those call sites simply reached for the function whose name
// sounded right.
//
// The call sites are fixed, and the five functions are deleted rather than left for the next one
// to reach for. A Mantis-specific question is asked with BYKArmKind(id) == BYKArmMantis(), which
// cannot be written by accident.

// A readable name for whatever item this is, for the diagnostic. Falls back to the item type
// when the record name is unavailable, and to a placeholder when neither can be read.
public func BYKDescribeItem(id: ItemID) -> String {
  if !ItemID.IsValid(id) {
    return "none";
  }
  let name = TDBID.ToStringDEBUG(ItemID.GetTDBID(id));
  let kind = EnumValueToString("gamedataItemType", Cast<Int64>(EnumInt(RPGManager.GetItemType(id))));
  if NotEquals(name, "") {
    return name + "  [" + kind + "]";
  }
  if NotEquals(kind, "") {
    return "[" + kind + "]";
  }
  return "unreadable";
}

// ---------------------------------------------------------------------------
// Cyberarms in general
//
// Mantis Blades were the only target until the iconic transplant work. Gorilla Arms are the
// second, and the two differ in ways that matter: different item type, different animations,
// different stats worth touching. So "which cyberarm is this" is a question the rest of the mod
// now has to be able to ask, rather than a yes or no about Mantis Blades.
//
// Kept as an Int32 rather than an enum so a value read back from a settings file can be
// validated against it without an enum cast that could land out of range.
// ---------------------------------------------------------------------------

public func BYKArmNone() -> Int32 = 0
public func BYKArmMantis() -> Int32 = 1
public func BYKArmGorilla() -> Int32 = 2

// Which cyberarm is this item, if any.
public func BYKArmKind(id: ItemID) -> Int32 {
  if !ItemID.IsValid(id) {
    return BYKArmNone();
  }
  let kind = RPGManager.GetItemType(id);
  if Equals(kind, gamedataItemType.Cyb_MantisBlades) {
    return BYKArmMantis();
  }
  if Equals(kind, gamedataItemType.Cyb_StrongArms) {
    return BYKArmGorilla();
  }
  // Name fallback, for a record this mod has never seen: a future patch, or another mod's custom
  // arms, whose item type was set to something unexpected. Missing those would be silent, and a
  // string compare on a weapon swap costs nothing.
  //
  // ToStringDEBUG can return an empty string, in which case this never matches and the item type
  // above remains the only test.
  let name = TDBID.ToStringDEBUG(ItemID.GetTDBID(id));
  if Equals(name, "") {
    return BYKArmNone();
  }
  if StrContains(name, "MantisBlades") || StrContains(name, "mantis_blades") {
    return BYKArmMantis();
  }
  if StrContains(name, "StrongArms") || StrContains(name, "strong_arms") {
    return BYKArmGorilla();
  }
  return BYKArmNone();
}

public func BYKArmKindName(kind: Int32) -> String {
  if kind == BYKArmMantis() {
    return "Mantis Blades";
  }
  if kind == BYKArmGorilla() {
    return "Gorilla Arms";
  }
  return "none";
}

// The cyberarm V currently has out, or null. Settled variant: the caller has already run the
// world-stability gate.
//
// Split out because the stability gate walks the player, the time system, two blackboards and
// the workspot system, and a caller that just ran it has no reason to pay for it twice. Anything
// calling the unchecked form without having checked is reading equipment mid-stream, which is the
// exact crash this module exists to avoid.
public func BYKEquippedArmSettled(game: GameInstance) -> wref<WeaponObject> {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return null;
  }
  let weapon = GameObject.GetActiveWeapon(player);
  if !BYKWeaponSafe(weapon) {
    return null;
  }
  if BYKArmKind(weapon.GetItemID()) == BYKArmNone() {
    return null;
  }
  return weapon;
}

// Which cyberarm is in hand right now, or BYKArmNone. Does not run the stability gate.
public func BYKEquippedArmKind(game: GameInstance) -> Int32 {
  let weapon = BYKEquippedArmSettled(game);
  if !IsDefined(weapon) {
    return BYKArmNone();
  }
  return BYKArmKind(weapon.GetItemID());
}

// The stats handle for a weapon entity.
//
// This is the detail that decides whether the whole mod does anything. The melee hit
// executor reads attack speed off the *weapon* entity:
//
//   attackSpeed = statsSystem.GetStatValue( instigatorWeapon.GetEntityID(), AttackSpeed )
//
// so a modifier put on the player's stats object is simply not the number being read.
// Putting it on V instead of on the blades is the single most likely reason a first attempt
// at this appears to do nothing at all.
public func BYKWeaponStatsId(weapon: wref<WeaponObject>) -> StatsObjectID {
  return Cast<StatsObjectID>(weapon.GetEntityID());
}

// An empty EntityID, for clearing a stored one.
//
// There is no EntityID.None() on this game version, and a struct field cannot simply be
// assigned null, so a default-constructed local is the way to express "nothing here".
// Pairs with EntityID.IsDefined, which is what every read of a cleared field checks.
public func BYKNoEntity() -> EntityID {
  let none: EntityID;
  return none;
}

// Do these two handles refer to the same entity?
//
// Compared by hash rather than with Equals on the struct. The modifier bookkeeping decides
// between refreshing a live window and tearing it down and rebuilding it on the strength of
// this answer, so it should not rest on how the compiler chooses to compare a struct. The
// hash is a plain Uint64 and there is nothing ambiguous about comparing two of them.
public func BYKSameEntity(a: EntityID, b: EntityID) -> Bool {
  if !EntityID.IsDefined(a) || !EntityID.IsDefined(b) {
    return false;
  }
  return Equals(EntityID.GetHash(a), EntityID.GetHash(b));
}

// The configured animation-safe ceiling, or 0 when the player has switched it off.
//
// Lives here rather than being read at each call site so the burst and the baseline cannot
// end up disagreeing about what the limit is.
public func BYKSpeedCeiling() -> Float {
  let settings = BYKSettings();
  if !IsDefined(settings) {
    return BYKConfig.AnimationSafeCeilingDefault();
  }
  if settings.animationSafeCeiling <= 0.0 {
    return 0.0;   // switched off
  }
  return ClampF(settings.animationSafeCeiling, 1.0, BYKConfig.MaxRestingAttackSpeed());
}

// Reduce a multiplier so that applying it to `current` does not cross the ceiling.
//
// Returns 1.0 when there is no headroom left at all, which callers treat as "do not apply a
// speed modifier", so nothing is added that the engine would only clamp or that would break
// the attack animation.
//
// Why this exists: Mantis Blade light attacks alternate arms through a chain held in the
// animation graph. Past roughly the vanilla clamp the graph stops advancing and every swing
// replays the first attack with the same arm. The speed is not worth the mod looking broken.
public func BYKClampMultToCeiling(current: Float, mult: Float) -> Float {
  let ceiling = BYKSpeedCeiling();
  if ceiling <= 0.0 {
    return mult;      // limiting switched off
  }
  if current <= 0.01 {
    return mult;      // nothing sensible to divide by; leave the caller's value alone
  }
  if current * mult <= ceiling {
    return mult;      // already fits
  }
  return MaxF(1.0, ceiling / current);
}

// Is this entity id still a live, attached game object?
//
// Shared by the burst and the baseline, because both face the same question before taking a
// modifier back off: the weapon may have been holstered, swapped or destroyed since the
// modifier went on, and a stat write against a freed entity is the crash this guards.
public func BYKEntityAlive(game: GameInstance, id: EntityID) -> Bool {
  if !EntityID.IsDefined(id) {
    return false;
  }
  let ent = GameInstance.FindEntityByID(game, id);
  if !IsDefined(ent) {
    return false;
  }
  let obj = ent as GameObject;
  if !IsDefined(obj) {
    return false;
  }
  return obj.IsAttached();
}

// ---------------------------------------------------------------------------
// Either cyberarm, by weapon object and by installed item
//
// Named for what they match, so a call site cannot quietly mean something narrower than it
// reads. See the file header for what happened when they did.

public func BYKIsCyberarmItem(id: ItemID) -> Bool {
  return BYKArmKind(id) != BYKArmNone();
}

public func BYKIsCyberarmWeapon(weapon: wref<WeaponObject>) -> Bool {
  if !IsDefined(weapon) {
    return false;
  }
  return BYKIsCyberarmItem(weapon.GetItemID());
}

// The cyberarm installed in V's arms, drawn or not, or an invalid ItemID.
//
// Separate from the equipped-weapon lookup because the two answer different questions. An arm is
// only the *active weapon* while it is actually deployed, so with a gun in hand the equipped
// lookup correctly reports no arm even though one is installed. The diagnostic has to tell those
// two cases apart, because they look identical to a player who just pressed the hotkey and was
// told they have no cyberarms.
public func BYKInstalledArmItem(game: GameInstance) -> ItemID {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return ItemID.None();
  }
  let data = EquipmentSystem.GetData(player);
  if !IsDefined(data) {
    return ItemID.None();
  }
  let id = data.GetActiveItem(gamedataEquipmentArea.ArmsCW);
  if BYKIsCyberarmItem(id) {
    return id;
  }
  return ItemID.None();
}
