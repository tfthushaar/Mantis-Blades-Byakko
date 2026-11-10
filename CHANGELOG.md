# Changelog

## 1.1.0

Adds Sihil's dash combo, and it works on Gorilla Arms as well as Mantis Blades.

**Dash, and you get unlimited combo attacks for a few seconds**, with the pause between light
attacks removed, refreshed every time you dash again. This is Sihil's iconic effect. Dodging
counts as dashing, because the Dash perk is what turns one into the other and the game treats a
dash as a dodge.

It is the first effect here that is not Mantis-only. Nothing about an infinite-combo flag is
specific to blades, so Gorilla Arms get it too.

By default the dash window adds no attack speed, only the combo flag. Speed there would stack
with the on-kill burst's multiplier, and two multipliers on the same stat is what broke the
attack animations in 1.0.1. There is a slider if you want it, and it is held under the animation
ceiling either way.

**Renamed to "Iconic Arms - Mantis Blades and Gorilla Arms Overhaul".** The old name stopped
being accurate once a feature covered both cyberarms. Mod Settings will show this as a new
group, so your existing settings are not carried over: worth a look at the menu after updating.
The install folder is still `r6/scripts/Byakko`, so updating over an existing install works
normally.

**F8 now tells you more.** It names which cyberarm is in hand rather than assuming blades,
reports the dash window alongside the kill burst, and names the specific check that refused if
the mod is standing down.

---


## 1.0.2

Fixes the mod doing nothing on some setups, adds a little more speed, and gives a clearer
answer when the hotkey says you have no Mantis Blades.

**The mod could stand down permanently and never recover.** Its world-state gate included a
`UI_System.IsInMenu` check, and on some setups that reads true during ordinary gameplay. The
gate then never opened, every tick stood down, and F8 reported "world is mid-transition" in
the middle of normal play. That check is gone. It was also the wrong signal: an open inventory
is not a hazard to anything this mod does, and the cases that genuinely are (a load, a pause,
photo mode, the ripperdoc chair, a cutscene) are each covered by their own check. Photo mode is
now checked explicitly as well. Thanks to the player who tracked this down and found that
swapping it for a photo mode check fixed it.

The gate is now written to fail open rather than closed. A gate that wrongly says "unstable"
costs the entire mod; one that wrongly says "stable" for a single tick costs a stat read that
the per-weapon checks refuse anyway. Those are not symmetric.

**F8 now names the check that refused**, instead of saying only that the world is
mid-transition. If a gate ever misfires again, the readout says which one.

- **Animation ceiling raised from 2.0 to 2.2**, and the resting target from 1.7 to 1.85, so the
  blades sit and burst faster than in 1.0.1. The ceiling figure is a judgement call: vanilla
  clamps at 2.0 and behaves, about 2.47 is where the same-arm slashing was reported, and where
  between them it actually breaks has not been pinned down. If it turns up for you, bring the
  ceiling down in the settings.
- **MaxTac Mantis Blades were never excluded.** All five MaxTac records are in the data layer,
  and `Cyb_MantisBlades` is the only Mantis Blade item type in either the base game or Phantom
  Liberty, so the effect applies to them exactly as it does to the rest. If F8 told you
  otherwise, the blades were installed but not drawn: the mod only acts while they are actually
  out, and the readout was not saying so clearly.
- **F8 now names what it found.** It prints the record and item type of whatever is in your
  hands, reports what is installed in your arms cyberware slot, and says plainly when Mantis
  Blades are installed but not deployed.
- Detection now also matches on the record name, not just the item type, so custom or
  future Mantis Blade records are covered even if their item type is set to something else.

---


## 1.0.1

Fixes an animation bug: during a long combo at high attack speed, V would slash with the same
arm over and over instead of alternating.

Mantis Blade light attacks are a chain that alternates arms, and the chain lives in the
animation graph rather than anywhere a mod can reach. Past roughly 2.0 attack speed the graph
stops advancing through it and every swing replays the first attack. Vanilla clamps melee
attack speed to 2.0, very likely for this reason, so the problem only appears once a
cap-raising mod removes that clamp. The resting target shipped at 2.1, which is above the
clamp, so with a cap fix installed the blades sat in the broken regime permanently.

- New **Animation ceiling** setting, default 2.0, which is the highest the blades will be
  pushed by the resting lift and the burst together. Set it to 0 to switch the limiting off.
- The resting target default drops from 2.1 to 1.7, so the default burst lands just under the
  ceiling: 1.7 x 1.175 = 1.998.
- The burst multiplier is now reduced rather than applied blindly when it would cross the
  ceiling, and skipped altogether when there is no headroom. This applies to the modifier
  mirrored onto V as well, worked out against V's own value.
- F8 reports the ceiling and says when you are sitting at it.

If you preferred the old behaviour, set the animation ceiling to 0 and the resting target back
to 2.1.

---


## 1.0.0

First public release.

Mantis Blades get the Byakko's loop. While the blades are equipped: +1 metre reach, a leap at
enemies including in mid-air, the Byakko's bleed rate, +25% armour penetration, attack speed
that no longer sags as stamina drains, and a lifted resting attack speed. On a kill
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
