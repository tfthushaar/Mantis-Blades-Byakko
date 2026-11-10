# Changelog

## 1.6.0

**Every iconic's real ability, and every iconic's real stats, both read out of the game.** On by
default.

1.5.0 claimed this was impossible for all but three weapons. That was wrong, and wrong for a
boring reason: it looked in one place and concluded the thing was not anywhere. An iconic does not
keep its effect on its weapon record. The game fits each iconic a hidden mod, and that mod carries
both the ability and the stats that make the weapon what it is. The weapon record holds only the
weapon class's shared block, which is why all eight katana iconics read back identical and why
Byakko looked indistinguishable from Satori.

The mod now walks that chain at runtime, per weapon, with no hardcoded list:

    weapon -> fitted parts -> the iconic's hidden mod -> its stats and its ability

So picking **Byakko** gives you Byakko's own ability, not a reimplementation of it, and the same
holds for every profile the walk finds something on. The three weapon-level packages found earlier
are still applied; they turned out to be the exception, not the whole picture.

**Stats now come from the game too.** The table built into the mod was transcribed by hand from a
documentation file dated April 2024 for blades, and estimated for blunt weapons, which is why
profiles carried a "values" field admitting which. The real modifiers are read instead, and the
hand-written table is the fallback for a weapon that has nothing to read. F8 says which of the two
your arm is using.

**The detail that made this usable rather than merely possible.** A stat modifier's type reads back
as a name, not an enum. Comparing it against the enum compiles cleanly and matches nothing, which
is how an earlier version labelled all 456 modifiers it read "other" and concluded the type was
unreachable. Without it, a transplanted stat is a coin flip between adding ten and multiplying by
ten. It was readable the whole time.

**Fixes**

- The F8 readout was still printing `EffectiveRange` and `ArmorPenetrationBonus`, the two dead
  stats 1.4.0 replaced. It reported 0 for reach and armour penetration while both were working,
  which would have sent anyone checking straight back to the wrong conclusion. It prints `Range`
  and `CanWeaponIgnoreArmor` now.
- An ability is applied to the arm rather than to V. That is where it sits in the real case, and it
  means the effect cannot outlive the weapon it came with: the worst case if removal ever failed is
  bounded by putting the arm away instead of lasting the session.
- Putting an arm away now genuinely removes its ability instead of dropping the handle. Dropping it
  was safe for stat modifiers, which die with the weapon entity, but a weapon object does not
  reliably die when a cyberarm is retracted, and a surviving one would have taken a second copy of
  the ability on the next draw.
- Curve and combined modifiers are read and reported but never transplanted. Both compute their
  value from a reference stat read off a reference object, so a curve keyed to a katana's quality
  means nothing on a pair of Mantis Blades. It would produce a number, just not the right one.

---


## 1.5.0

**Real iconic abilities, transplanted rather than imitated.** New setting, off by default.

The game applies a gameplay logic package to you when you equip an iconic. This hands that same
package to your cyberarm, so you get the weapon's actual ability rather than this mod's
reconstruction of it.

It only works for three melee iconics, and that is a fact about the game rather than a
limitation here. Reading every iconic melee record showed that most carry no weapon-specific
package at all: all eight katana iconics attach only the generic "a melee weapon is in your
hands" package, and their stat modifiers are byte-identical to each other. Whatever separates
Byakko from Satori is not reachable through any accessor the scripting layer exposes. The three
that do carry their own are **Sihil**, **Gwynbleidd** and **Sasquatch's Hammer**.

For every other profile the reimplemented effects are still the only honest option, and F8 now
says which case you are looking at: a real package transplanted, a real package available but
switched off, or no package to transplant.

**Why it is off by default.** Every other effect in this mod is a stat modifier: it has a
handle, it comes off, and the worst case is a wrong number. A package's contents cannot be read
from script, so this is the one feature that applies something it cannot fully inspect. It is
removed when you put the arm away, change profile, or load a save, and it is opt-in so the rest
of the mod can be used without it.

---


## 1.4.0

**The reach and armour penetration bonuses were doing nothing, in every version since the
first. They work now.**

Reading the real item records out of the game settled what no amount of checking stat names
could: melee weapons use `Range` for reach and `CanWeaponIgnoreArmor` for armour penetration.
This mod was setting `EffectiveRange` and `ArmorPenetrationBonus`, which are real stats that no
weapon in the game reads.

The proof is visible in a Mantis Blade's own record, which carries `Range = 2.0` and
`CanWeaponIgnoreArmor = 0.25`, with the mod's old modifiers sitting beside them on stats
nothing looks at. Nothing could have caught this earlier: both names are valid, so every build
passed and the diagnostic read them back correctly. They were simply the wrong stats.

If the +1m reach and +25% armour penetration never felt like they did anything, that is
because they did not.

**Gorilla Arms already combo infinitely.** Their own record carries
`CanWeaponInfinitlyCombo = 1` and `CanWeaponDash = 1`, so the dash window's combo flag was
redundant on them from the day it shipped and only its optional attack speed did anything.
Not harmful, but it meant the same setting felt completely different on the two arms with no
explanation. F8 now says so.

---


## 1.3.0

**Profiles now carry their weapon's speed and combo effects**, which several iconics are
actually defined by. The previous release left those out, which made picking a profile feel
gutted and made the windows incoherent besides: picking Scalpel still handed you the Byakko's
combo, because that combo was a global feature rather than the Byakko's.

* **Byakko** owns its on-kill combo window again, as its own effect.
* **Sihil** owns its dash combo window.
* **Butcher's Cleaver** added. The original speeds up while the target is bleeding, which is
  not state this mod tracks, so the speed is offered on a kill window instead and the readout
  says so rather than passing it off as the real condition.
* If the profile you pick has no window of its own, the global settings still apply, so nothing
  about an existing install changes.

Every speed modifier from any source, profile included, is held under the animation ceiling. A
profile cannot push the light-attack chain into the regime where it stops alternating arms.

**New: read the real iconic stats out of your game.** Press **F9** and every iconic's actual
stat modifiers are written to the redscript log, read from the game's own TweakDB.

This matters because of where the profile numbers come from. The blade profiles are transcribed
from modding documentation dated April 2024, whose stat names were checked against the current
build but whose values were not. The blunt profiles and Sihil are approximations, because that
documentation has no stat rows for blunt weapons and omits Sihil entirely. F9 is how those get
checked against what the game actually holds, and it only reads.

---


## 1.2.0

**Pick which iconic melee weapon's stats go on your cyberarms.** Sixteen profiles, chosen per
arm in the settings menu.

Blades on Mantis Blades, and blades or blunt on Gorilla Arms. Katanas are deliberately offered
for Gorilla Arms too: there are only a handful of iconic blunt weapons, and the blade stats
transplant perfectly well.

Three profiles bring a conditional effect, applied and removed as the condition flips:

* **Scalpel**, crit chance and bleed while a Sandevistan is running.
* **Jinchu-Maru**, guaranteed crits and the leap while Optical Camo is active.
* **Cocktail Stick**, bleed while Optical Camo is active, which is how the original works.

**The readout tells you where each profile's numbers came from.** The blade profiles are
transcribed from the game's own data. The blunt ones are approximations, because no source
gives their real modifiers, and the displayed percentages on wikis cannot be transplanted: they
are the underlying rate after the weapon's tier scaling, so Byakko and Satori show +30% and +17%
bleed from the identical modifier. Press F8 and the profile section says which kind you have,
along with what the profile does not include.

**Damage reductions are off by default.** Satori, Errata and Cocktail Stick genuinely carry a
x0.9 damage multiplier, balanced against the rest of their kit. Transplanted onto a cyberarm by
someone who picked the profile for its bleed, that is a nerf they did not ask for. There is a
setting if you want the full transplant.

Your existing behaviour is unchanged on update: the Mantis profile defaults to Byakko, and
Gorilla Arms default to none.

---


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
