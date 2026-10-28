# Changelog

## 1.0.0

First public release.

Mantis Blades get the Byakko's loop. While the blades are equipped: +1 metre reach, a leap at
enemies including in mid-air, the Byakko's bleed rate, +25% armour penetration, attack speed
that no longer sags as stamina drains, and a resting attack speed brought up to 2.1. On a kill
with the blades: a burst of attack speed and the light combo pause removed for ten seconds,
restarting on every further kill.

Everything is adjustable from the settings menu, and the defaults are the Byakko's own numbers,
so nothing needs configuring.

**On the 200% melee attack speed cap.** Vanilla clamps melee attack speed at 200%, and a built
character can already be at that ceiling, where the speed half of the burst has nowhere to go.
The clamp is one number in the game's data, `BaseStats.AttackSpeed.max`, so either
[Melee Attack Speed Cap Fix](https://www.nexusmods.com/cyberpunk2077/mods/34588) or a one-line
tweak of your own raises it. Only the speed half is affected: the combo-pause removal works
through the animation state machine and never touches that stat, and the reach, leap, bleed,
armour penetration and stamina flag are unaffected. F8 tells you whether you are over the cap.

Press **F8** with the blades equipped for a readout of what the game actually reports: both
attack speed stats, whether each data-layer change landed, whether you are over the cap, and
whether a burst is live.

### Notes for other mod authors

- Mantis Blades are identified by `gamedataItemType.Cyb_MantisBlades`, which covers all 41
  Mantis Blade records without naming any of them.
- The data layer appends to each record's `statModifierGroups` with `!append-once`, so another
  Mantis Blade mod's own group survives alongside this one.
- The burst applies its modifiers to the weapon entity's stats object, not the player's,
  because that is what the melee hit executor reads. It is mirrored onto the player as well,
  since which of the two the animation reads for arm cyberware has varied between patches.
- Nothing is persisted. No save data, no schema, no migration. Uninstalling reverts everything.

---

## 0.2.0

Hardening and optimisation. Not driven by a reported bug; a re-audit of the whole mod for
defects, for the next most likely failure, and for idle cost.

- **A missing optional dependency no longer breaks your other mods.** When a redscript mod
  references something that is not installed, the whole redscript compile fails and every
  script mod stops working. Every call into Mod Settings is now isolated behind `ModuleExists`,
  so the mod still compiles and runs on its defaults without it. The build checks all four
  dependency combinations.
- Session boundaries no longer reach into the stats system or the entity registry. Handles are
  dropped without native calls on a load, a respawn or a teardown, where the world those
  modifiers lived on has already gone.
- `OnRestored` added as a second chance at the session reset, closing the last route by which a
  stale handle could outlive a load.
- Entity identity is compared by hash rather than by struct equality, so the decision to
  refresh a live window rather than rebuild it does not rest on compiler behaviour.
- The burst only reports itself live if a modifier actually landed.
- The baseline tick backs off while the blades are holstered and snaps back on a kill.
- Removed a duplicated world-stability check on the kill path.
- On-screen messages no longer write to the notification blackboard mid-transition.

## 0.1.0

Initial build, never released.
