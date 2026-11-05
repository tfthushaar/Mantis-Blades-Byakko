// Byakko - Identifying the blades
//
// Mantis Blades are cyberware, not an inventory weapon, so they live under their own record
// tree and none of the katana record names reach them. The game does however give them
// their own item type, gamedataItemType.Cyb_MantisBlades, which is a far steadier handle
// than matching record-name strings: it covers all 41 Mantis Blade records (base, Chemical,
// Electric, Thermal, MaxTac, every rarity and ++ tier) without listing any of them, and it
// keeps working if a patch adds more.
//
// gamedataItemType.Cyb_MantisBlades is confirmed to exist on the installed game by compiling
// a probe against the game's own scc.exe.

public func BYKIsMantisItem(id: ItemID) -> Bool {
  if !ItemID.IsValid(id) {
    return false;
  }
  if Equals(RPGManager.GetItemType(id), gamedataItemType.Cyb_MantisBlades) {
    return true;
  }
  // Belt and braces: match the record name too.
  //
  // The item type is the authority and covers all 41 of the game's Mantis Blade records,
  // MaxTac included, since Cyb_MantisBlades is the only mantis type in either the base or the
  // Phantom Liberty database. This second check exists for records this mod has never seen:
  // a future patch, or another mod's custom blades whose item type was set to something else.
  // Missing those would be silent, and a string compare on a weapon swap costs nothing.
  //
  // ToStringDEBUG can return an empty string, in which case this simply never matches and the
  // item type above remains the only test, which is how the check behaved before this existed.
  let name = TDBID.ToStringDEBUG(ItemID.GetTDBID(id));
  if Equals(name, "") {
    return false;
  }
  return StrContains(name, "MantisBlades") || StrContains(name, "mantis_blades");
}

// The Mantis Blades installed in V's arms, drawn or not, or an invalid ItemID.
//
// Separate from the equipped-weapon lookup because the two answer different questions. The
// blades are only the *active weapon* while they are actually deployed, so with a gun in hand
// the equipped-weapon check correctly reports no blades even though they are installed. The
// diagnostic needs to tell those two cases apart, because they look identical to a player who
// just pressed the hotkey and got told they have no Mantis Blades.
public func BYKInstalledMantisItem(game: GameInstance) -> ItemID {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return ItemID.None();
  }
  let data = EquipmentSystem.GetData(player);
  if !IsDefined(data) {
    return ItemID.None();
  }
  let id = data.GetActiveItem(gamedataEquipmentArea.ArmsCW);
  if BYKIsMantisItem(id) {
    return id;
  }
  return ItemID.None();
}

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

public func BYKIsMantisWeapon(weapon: wref<WeaponObject>) -> Bool {
  if !IsDefined(weapon) {
    return false;
  }
  return BYKIsMantisItem(weapon.GetItemID());
}

// The Mantis Blade weapon object the player currently has out, or null.
//
// Returns null rather than guessing in every case where the answer is not certain: no
// player, an unstable world, nothing equipped, something else equipped, or an equipped
// blade whose entity is not attached yet. Every caller treats null as "do nothing", which
// is why this is allowed to be strict.
public func BYKEquippedMantis(game: GameInstance) -> wref<WeaponObject> {
  if !BYKWorldStable(game) {
    return null;
  }
  return BYKEquippedMantisSettled(game);
}

// The same lookup for a caller that has already established the world is stable.
//
// Split out because the stability gate walks the player, the time system, two blackboards
// and the workspot system, and a caller that just ran it has no reason to pay for it twice.
// Anything calling this without having checked is reading equipment mid-stream, which is the
// exact crash this module exists to avoid.
public func BYKEquippedMantisSettled(game: GameInstance) -> wref<WeaponObject> {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return null;
  }
  let weapon = GameObject.GetActiveWeapon(player);
  if !BYKWeaponSafe(weapon) {
    return null;
  }
  if !BYKIsMantisWeapon(weapon) {
    return null;
  }
  return weapon;
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
