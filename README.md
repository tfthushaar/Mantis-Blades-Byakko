# Byakko - Mantis Blades Overhaul

**Mantis Blades that feel like the Byakko.**

The Byakko (白虎, "white tiger") is Wakako Okada's katana, and it is the best-feeling melee
weapon in Cyberpunk 2077. What makes it feel that way is its loop. You kill someone and the
weapon pays you back straight away: a burst of speed, and the stutter between light attacks
disappears. You chain into the next target and keep it going.

Mantis Blades are the most cyberpunk weapon in the game and they feel heavy and slow. Killing
someone with them gives you nothing.

This mod gives them that loop.

Throughout this page, "the Byakko" means Wakako's katana and "this mod" means the thing you
are installing.

---

## What it does

**Always, while the blades are equipped**

| | |
|---|---|
| Reach | +1 metre |
| Leap | Leap at enemies, including in mid-air |
| Bleed | The Byakko's bleed application rate |
| Armour penetration | +25% |
| Stamina | Attack speed no longer sags as stamina drains |
| Resting attack speed | Brought up to 2.1, the Byakko's number |

**On a kill with the blades**

* A burst of attack speed, +17.5% by default, for 10 seconds.
* The pause between light attack combos is removed for that window.
* Killing again inside the window starts it over, so a good fight never drops out of it.

All of it is adjustable in the settings menu, and the burst is the part worth tuning. See
[Settings](#settings).

---

## Installing

**Requirements**

* [RED4ext](https://www.nexusmods.com/cyberpunk2077/mods/2380)
* [redscript](https://www.nexusmods.com/cyberpunk2077/mods/1511)
* [TweakXL](https://www.nexusmods.com/cyberpunk2077/mods/4197)
* [Codeware](https://www.nexusmods.com/cyberpunk2077/mods/7780)

**Optional**

* [Mod Settings](https://www.nexusmods.com/cyberpunk2077/mods/4885). Without it the mod runs
  on its defaults, which are the Byakko's own numbers, and there is simply no menu to change
  them. Nothing breaks. If you want to tune the burst, install it.

* [Melee Attack Speed Cap Fix](https://www.nexusmods.com/cyberpunk2077/mods/34588), or the
  one-line tweak in [The 200% cap](#the-200-cap) below. Vanilla clamps melee attack speed at
  200% and a built character can already be at that ceiling, in which case the speed half of
  the burst has nowhere to go. Press F8 and the mod will tell you whether that is you.

**Install**

With Vortex, install the archive as normal. By hand, extract it into your Cyberpunk 2077
folder, the one containing `bin`, `r6` and `engine`. You should end up with:

```
Cyberpunk 2077/
  r6/
    scripts/Byakko/...
    tweaks/Byakko/...
```

**Uninstall**

Delete those two `Byakko` folders. Nothing is written into your save, so there is nothing to
clean up and no safe-uninstall procedure to follow. Your character is exactly as it was.

---

## The 200% cap

Vanilla Cyberpunk clamps melee attack speed at 200%. Bonuses past that ceiling still show up
on your perks, your cyberware and your weapon stats, and they do nothing at all. A built
Reflexes character can be sitting at or near it before installing anything.

The good news is that it is one number in the game's data, not something baked into the engine.
`BaseStats.AttackSpeed.max` is 2.0 in vanilla. Raising it is a single line of TweakXL, which is
all that [Melee Attack Speed Cap Fix](https://www.nexusmods.com/cyberpunk2077/mods/34588) does.
If you would rather not add another mod, drop this into any `.yaml` under `r6/tweaks/`:

```yaml
BaseStats.AttackSpeed.max: 99.0
```

This mod does not change that number itself, because it is a global clamp on every melee weapon
in the game rather than something that can be raised for Mantis Blades alone, and quietly
altering a game-wide value is how mods start fighting each other.

**How much this affects you depends on your build.** Only the speed half of the burst is
clamped. The combo-pause removal, which is the half most people notice, works through the
animation state machine and never touches the attack speed stat, so no ceiling applies to it.
The reach, leap, bleed, armour penetration and stamina flag are all unaffected too.

**Press F8 with the blades equipped and the mod will tell you whether you are over the cap**,
rather than leaving you to guess. See [Diagnostics](#diagnostics).

---

## Diagnostics

Equip the Mantis Blades and press **F8** (rebindable). The mod prints what the game actually
reports, on screen and into `red4ext/logs/`:

* Both attack speed stats, the one the swing animation reads and the one the inventory screen
  shows. They are separate fields, and a mod can move one while you read the other.
* Whether the data layer applied. A line reading `0` means the TweakXL half did not land,
  which usually means another Mantis Blade mod replaced the same data.
* Whether you are over the vanilla melee cap and therefore wasting the bonus.
* Whether a burst is live, how long it has left, and how many kills you have chained into it.

If you are reporting a problem, press F8 and include that readout. It answers most questions
before they need asking.

---

## Settings

Under **Byakko - Mantis Blades Overhaul** in the Mod Settings menu. The defaults are the
katana's own numbers, so you do not have to configure anything to get the intended feel.

**On-kill burst**

| Setting | Default | |
|---|---|---|
| Burst on kill | on | The loop itself. |
| Burst attack speed | 1.175 | The Byakko's reported +17.5%. Mind the cap. |
| Burst duration | 10s | The Byakko's reported duration. Pauses in menus. |
| Remove light combo pause | on | The other half of the Byakko's iconic, and the part you feel most. |
| Also buff V, not just the blades | on | See the note below. |
| Show a message on burst | off | Handy while tuning, noisy in a fight. |

**Resting attack speed**

| Setting | Default | |
|---|---|---|
| Lift resting attack speed | on | So the burst starts from a katana-like baseline. |
| Resting target | 2.1 | The Byakko's. Only ever speeds the blades up. If your build is already faster, nothing is applied. |

About "Also buff V": the blades are cyberware, and which stats object the melee animation
reads for arm cyberware is uncertain and has changed between patches. The burst is applied to
both the blades and V so it works either way. Turn it off if it fights with another melee mod.

---

## Known issues and honest limits

**Arm cyberware has a history of ignoring attack speed.** There is a long-standing vanilla bug
where arm cyberware and base fists do not scale with attack speed, and it is the reason
[Fenix Mantis Blades Overhaul](https://www.nexusmods.com/cyberpunk2077/mods/28451) and
[Base Fists and Arm Cyberware Attack Speed Fix](https://www.nexusmods.com/cyberpunk2077/mods/14130)
exist. How much of it is still live varies by patch.

This mod is built so that does not matter. The combo-pause removal changes the feel through the
animation state machine rather than the attack speed stat, so it works regardless, and it is
the half you notice most. The speed multiplier is applied to both the blades and V, because
which of the two the melee animation reads for cyberware has changed between patches. If the
mod feels good but the speed numbers never seem to move much, that is what is going on, and
nothing is broken.

**Base damage is left alone.** The Byakko's sheet lists 148, but Mantis Blades scale their
damage with your level and tier. Pinning them to the katana's number would be a straight
downgrade on a Tier 5++ character, so damage is not touched.

**Stamina cost per swing is not forced to the Byakko's 6.4.** The stamina penalty flag is what
actually changes how the blades feel under pressure, and that is applied. The raw cost per
swing is left to the game.

---

## Compatibility

This mod adds to the Mantis Blade records instead of overwriting them, so another mantis mod's
changes survive alongside it. Where you both change the same stat, both apply.

Mods that occupy the same ground, worth a look before deciding you need this one:

* [Fenix Mantis Blades Overhaul](https://www.nexusmods.com/cyberpunk2077/mods/28451)
* [Iconic MaxTac Mantis Blades](https://www.nexusmods.com/cyberpunk2077/mods/34907)
* [Iconic Mantis Blade](https://www.nexusmods.com/cyberpunk2077/mods/32588)
* [Melee Attack Speed Cap Fix](https://www.nexusmods.com/cyberpunk2077/mods/34588), which is
  complementary and effectively a soft requirement.

If two mods set the same Mantis Blade stat to different absolute values, whichever loads last
wins. If this mod's data layer is being overridden, F8 shows it as a `0`.

---

## Safety

Built so it cannot corrupt a save or leave anything behind.

* **It persists nothing.** No save data, no schema, no migration. Everything it does is a stat
  modifier on a weapon that only exists while the blades are drawn.
* **It cannot stack.** The burst keeps one modifier per stat at a time, tracked by handle.
  Killing again pushes the window's deadline out instead of adding a second buff.
* **It stands down during loads, fast travel, time skips, the ripperdoc chair, menus and
  cutscenes.** That is when the game is rebuilding the world, and reading equipment mid-rebuild
  is how a mod crashes the game.
* **It does not hook V's damage path.** Kill detection runs on the enemy that died rather than
  on every hit V deals.
* **Removing the mod reverts everything**, data layer included.
* **A missing optional dependency will not break your other mods.** This matters more than it
  sounds. When a redscript mod references something that is not there, the whole redscript
  compile fails and *every* script mod in your game stops working, with a message naming the
  mod that caused it. Every call this mod makes into Mod Settings is isolated so that cannot
  happen. Codeware is a genuine hard requirement and is checked the same way, so the four
  combinations are verified at build time rather than hoped for.

---

## Building from source

```powershell
# compile-check against your install without launching the game
./tools/validate.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077"

# check the mod still compiles with and without each optional dependency
./tools/validate.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077" -DependencyMatrix

# build a release archive (validates first)
./tools/build.ps1 -Version 0.2.0 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077"
```

`validate.ps1` compiles the mod with the game's own `scc.exe` against a private copy of the
script cache inside a temp sandbox. It never touches your game folder, and it catches an
unresolved method in seconds instead of a launch cycle.

---

## Licence

MIT. See [LICENSE](LICENSE).
