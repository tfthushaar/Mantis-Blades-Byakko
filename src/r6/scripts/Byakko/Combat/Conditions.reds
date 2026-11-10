// Byakko - Condition evaluators
//
// Several iconic effects are conditional rather than constant: Scalpel's crit and bleed during
// Sandevistan, Jinchu-Maru's crit under Optical Camo, Cocktail Stick's bleed under Camo. Each
// is a window like the on-kill burst, with a condition instead of a timer.
//
// This file holds the "is that condition true right now" reads and nothing else, so the windows
// that use them stay about modifier bookkeeping.
//
// Every call here is confirmed against the installed game by compiling a probe with its own
// scc.exe. See tools/probes/ApiSurface.reds.
//
// ---------------------------------------------------------------------------
// These fail open, deliberately
//
// A condition that wrongly reads false silently disables the effect that depends on it, and
// that is the failure this project has already shipped twice (the world-state gate, and the
// resting target sitting above a clamp). A condition that wrongly reads true hands the player a
// buff they had not quite earned. Those are not equally bad, so where several independent
// signals mean the same thing, any one of them is enough.

// Is Optical Camo active on V?
//
// Three independent signals, OR-ed. Optical Camo turned out to have an unusually rich set of
// readable state, and using more than one costs three cheap reads while removing any single
// point of failure across a patch:
//
//   1. `OpticalCamoIsActive`, the stat named exactly for the question. The primary.
//   2. `PlayerPuppet.IsInvisible()`, the engine's own view of V being unseen.
//   3. `BaseStatusEffect.Cloaked`, the status effect the cyberware applies.
//
// Probed and NOT available, so nothing here may use them: `gamedataStatType.ActiveCamo`,
// `gamedataStatType.CamoActiveOnPlayer` (it exists as a string in the game data but is not a
// stat), and `gamedataStatPoolType.OpticalCamo` (the pool is `OpticalCamoCharges`).
//
// Signal 2 is also true for other kinds of invisibility. For a condition that means "V is
// currently unseen", that is the right answer anyway.
public func BYKCamoActive(game: GameInstance) -> Bool {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return false;
  }
  let stats = GameInstance.GetStatsSystem(game);
  if IsDefined(stats) {
    let sid = Cast<StatsObjectID>(player.GetEntityID());
    if stats.GetStatValue(sid, gamedataStatType.OpticalCamoIsActive) > 0.0 {
      return true;
    }
  }
  if player.IsInvisible() {
    return true;
  }
  return StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.Cloaked");
}

// How much Optical Camo charge is left, as a stat pool percentage, or 0 when unreadable.
//
// Not a condition, but the diagnostic prints it: a player whose camo window never seems to fire
// usually wants to know whether the game thinks they have camo at all.
public func BYKCamoCharge(game: GameInstance) -> Float {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return 0.0;
  }
  let pools = GameInstance.GetStatPoolsSystem(game);
  if !IsDefined(pools) {
    return 0.0;
  }
  return pools.GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()),
                                gamedataStatPoolType.OpticalCamoCharges, false);
}

// Is a Sandevistan running?
//
// One signal, because only one was found: the status effect the cyberware applies. There is no
// `SandevistanIsActive` stat to pair it with the way camo has one.
public func BYKSandevistanActive(game: GameInstance) -> Bool {
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return false;
  }
  if StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.SandevistanBuff") {
    return true;
  }
  // Tag form as a second route, in case a patch renames the record but keeps the tag.
  return StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"Sandevistan");
}

// Is this target bleeding?
//
// Butcher's Cleaver's real condition. The original attacks faster and costs less stamina while
// the enemy is bleeding, and until now this mod substituted a kill window for it and said so in
// the profile note. This is the actual thing.
//
// Tag first, deliberately. Bleeding is applied by a family of records rather than one: the base
// effect, the weapon-applied variant, and whatever a given patch adds. Asking for the tag catches
// all of them and survives a record being renamed, which is the failure mode that has already
// cost this mod two releases. The record id is the second route only, for the case where a patch
// keeps the record and drops the tag.
//
// Takes the target rather than reading a current target off the player. There is no reliable
// "what is V aiming at" for melee, and the call site already has the victim in hand because it
// runs from the hit, which is the only moment the question is actually meaningful.
public func BYKTargetIsBleeding(target: ref<GameObject>) -> Bool {
  if !IsDefined(target) {
    return false;
  }
  if StatusEffectSystem.ObjectHasStatusEffectWithTag(target, n"Bleeding") {
    return true;
  }
  return StatusEffectSystem.ObjectHasStatusEffect(target, t"BaseStatusEffect.Bleeding");
}
