// White Tiger - Identifying the blades
//
// Mantis Blades are cyberware, not an inventory weapon, so they live under their own record
// tree and none of the katana record names reach them. The game does however give them
// their own item type - gamedataItemType.Cyb_MantisBlades - which is a far steadier handle
// than matching record-name strings: it covers all 41 Mantis Blade records (base, Chemical,
// Electric, Thermal, MaxTac, every rarity and ++ tier) without listing any of them, and it
// keeps working if a patch adds more.
//
// gamedataItemType.Cyb_MantisBlades is confirmed to exist on the installed game by compiling
// a probe against the game's own scc.exe.

public func WTIsMantisItem(id: ItemID) -> Bool {
  if !ItemID.IsValid(id) {
    return false;
  }
  return Equals(RPGManager.GetItemType(id), gamedataItemType.Cyb_MantisBlades);
}

public func WTIsMantisWeapon(weapon: wref<WeaponObject>) -> Bool {
  if !IsDefined(weapon) {
    return false;
  }
  return WTIsMantisItem(weapon.GetItemID());
}

// The Mantis Blade weapon object the player currently has out, or null.
//
// Returns null rather than guessing in every case where the answer is not certain: no
// player, an unstable world, nothing equipped, something else equipped, or an equipped
// blade whose entity is not attached yet. Every caller treats null as "do nothing", which
// is why this is allowed to be strict.
public func WTEquippedMantis(game: GameInstance) -> wref<WeaponObject> {
  if !WTWorldStable(game) {
    return null;
  }
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return null;
  }
  let weapon = GameObject.GetActiveWeapon(player);
  if !WTWeaponSafe(weapon) {
    return null;
  }
  if !WTIsMantisWeapon(weapon) {
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
public func WTWeaponStatsId(weapon: wref<WeaponObject>) -> StatsObjectID {
  return Cast<StatsObjectID>(weapon.GetEntityID());
}

// An empty EntityID, for clearing a stored one.
//
// There is no EntityID.None() on this game version, and a struct field cannot simply be
// assigned null, so a default-constructed local is the way to express "nothing here".
// Pairs with EntityID.IsDefined, which is what every read of a cleared field checks.
public func WTNoEntity() -> EntityID {
  let none: EntityID;
  return none;
}
