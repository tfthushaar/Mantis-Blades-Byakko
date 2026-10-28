// White Tiger - Diagnostic readout (default F8)
//
// This exists because of the specific way mods in this area fail. Attack speed on melee has
// three traps stacked on top of each other, and all three produce the same symptom - the
// mod appears to do nothing - with no error anywhere:
//
//   1. There are two attack-speed stats. gamedataStatType.AttackSpeed is what the melee hit
//      executor reads; AttacksPerSecond is what the inventory screen prints. Editing one and
//      reading the other looks like a working change that does nothing.
//   2. Vanilla caps melee attack speed at 200%. Everything past the cap still displays on
//      perks, cyberware and weapons, and does nothing at all. A built Reflexes character can
//      already be at the cap, so a mod can test perfectly on a fresh save and be completely
//      inert on a real one.
//   3. Arm cyberware has a long-standing vanilla bug where it does not scale with attack
//      speed. If that is live on the installed patch, the number moves and the swing does
//      not, and no amount of raising it will help.
//
// Guessing which of those is in play costs a launch cycle each time. Printing the actual
// numbers off the actual equipped blades costs a keypress. The readout reports what the game
// says right now, including when the honest answer is that the data layer did not land.

public func WTShowDiagnostics(game: GameInstance, sys: ref<WhiteTigerSystem>) -> Void {
  let lines = WTBuildDiagnostics(game, sys);
  WTShowMessage(game, lines, 12.0);
  // Also to the log, where it can be copied into a bug report and read without a 12-second
  // limit. The log is the useful copy; the on-screen one is for a quick look mid-fight.
  WTLog.Info(n"Diag", lines);
}

func WTBuildDiagnostics(game: GameInstance, sys: ref<WhiteTigerSystem>) -> String {
  let out = s"White Tiger \(WhiteTigerVersion())\n";

  if !WTEnabled() {
    return out + "Mod is switched off in settings.";
  }
  if !WTWorldStable(game) {
    return out + "World is mid-transition; try again once gameplay resumes.";
  }
  let stats = GameInstance.GetStatsSystem(game);
  let player = GetPlayer(game);
  if !IsDefined(stats) || !IsDefined(player) {
    return out + "Stats system or player not available.";
  }

  // ---- The blades -------------------------------------------------------
  let weapon = WTEquippedMantis(game);
  if !IsDefined(weapon) {
    let active = GameObject.GetActiveWeapon(player);
    if IsDefined(active) {
      out += "Equipped weapon is not Mantis Blades.\n";
      out += "Equip the blades and press again.\n";
    } else {
      out += "No weapon equipped. Equip Mantis Blades and press again.\n";
    }
    return out;
  }

  let sid = WTWeaponStatsId(weapon);
  let speed = stats.GetStatValue(sid, gamedataStatType.AttackSpeed);
  let perSec = stats.GetStatValue(sid, gamedataStatType.AttacksPerSecond);
  let pSpeed = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.AttackSpeed);

  out += s"Blades AttackSpeed:     \(speed)\n";
  out += s"Blades AttacksPerSecond: \(perSec)   (what the inventory shows)\n";
  out += s"Player AttackSpeed:     \(pSpeed)\n";

  // Trap 2. Report it rather than trying to be clever about it: the cap is enforced by the
  // game, not here, so the only useful thing this mod can do is say when it is being hit.
  if speed > WTConfig.VanillaMeleeSpeedCap() {
    out += s"\nAbove the vanilla \(WTConfig.VanillaMeleeSpeedCap()) melee cap.\n";
    out += "Without Melee Attack Speed Cap Fix the excess is discarded.\n";
  }

  // ---- Did the data layer land? -----------------------------------------
  //
  // Every line below is a stat the YAML is supposed to have moved. If one reads 0 while the
  // blades are equipped, the data layer did not apply - a TweakXL load error, or another mod
  // replacing the same array - and that is worth knowing before blaming the feel.
  out += "\nData layer (byakko-baseline.yaml):\n";
  out += s"  EffectiveRange  \(stats.GetStatValue(sid, gamedataStatType.EffectiveRange))\n";
  out += s"  CanMeleeLeap    \(stats.GetStatValue(sid, gamedataStatType.CanMeleeLeap))\n";
  out += s"  BleedRate       \(stats.GetStatValue(sid, gamedataStatType.BleedingApplicationRate))\n";
  out += s"  ArmorPen        \(stats.GetStatValue(sid, gamedataStatType.ArmorPenetrationBonus))\n";
  out += s"  IgnoreStamPen   \(stats.GetStatValue(sid, gamedataStatType.CanIgnoreWeaponStaminaPenaties))\n";
  out += s"  InfiniteCombo   \(stats.GetStatValue(sid, gamedataStatType.CanWeaponInfinitlyCombo))   (1 only during a burst)\n";

  // ---- The window -------------------------------------------------------
  if IsDefined(sys) {
    let burst = sys.GetBurst();
    if IsDefined(burst) && burst.IsActive() {
      out += s"\nBurst LIVE: \(burst.GetRemaining(game))s left, \(burst.GetKills()) kill(s) chained.\n";
    } else {
      out += "\nBurst idle. Kill something with the blades.\n";
    }
  }

  return out;
}
