// Byakko - Diagnostic readout (default F8)
//
// This exists because of the specific way mods in this area fail. Attack speed on melee has
// three traps stacked on top of each other, and all three produce the same symptom, the mod
// appears to do nothing, with no error anywhere:
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

public func BYKShowDiagnostics(game: GameInstance, sys: ref<ByakkoSystem>) -> Void {
  let lines = BYKBuildDiagnostics(game, sys);
  BYKShowMessage(game, lines, 12.0);
  // Also to the log, where it can be copied into a bug report and read without a 12-second
  // limit. The log is the useful copy; the on-screen one is for a quick look mid-fight.
  BYKLog.Info(n"Diag", lines);
}

func BYKBuildDiagnostics(game: GameInstance, sys: ref<ByakkoSystem>) -> String {
  let out = s"Byakko \(ByakkoVersion())\n";
  if !BYKModSettingsPresent() {
    out += "Mod Settings not installed: running on defaults, no menu.\n";
  }

  if !BYKEnabled() {
    return out + "Mod is switched off in settings.";
  }
  // Name the gate that refused, rather than just saying the world is mid-transition.
  //
  // The old version printed only the generic line, and when a gate misfired the only way to
  // find out which one was to read the source. Saying which check said no makes that a
  // keypress.
  let reason = BYKWorldStableReason(game);
  if reason != BYKStableOk() {
    out += s"Standing down: \(BYKStableReasonText(reason)).\n";
    out += "If you are in normal gameplay and see this, that check is misfiring.\n";
    out += "Please report it with this line.\n";
    return out;
  }
  let stats = GameInstance.GetStatsSystem(game);
  let player = GetPlayer(game);
  if !IsDefined(stats) || !IsDefined(player) {
    return out + "Stats system or player not available.";
  }

  // ---- The blades -------------------------------------------------------
  let weapon = BYKEquippedMantisSettled(game);
  if !IsDefined(weapon) {
    // Say exactly what the game reports rather than just "not Mantis Blades". The common case
    // is blades that are installed but not drawn, which looks identical to a player and reads
    // as the mod not supporting their cyberware.
    let active = GameObject.GetActiveWeapon(player);
    if IsDefined(active) {
      out += s"In hand: \(BYKDescribeItem(active.GetItemID()))\n";
    } else {
      out += "In hand: nothing\n";
    }
    let installed = BYKInstalledMantisItem(game);
    if ItemID.IsValid(installed) {
      out += s"Arms cyberware: \(BYKDescribeItem(installed))\n";
      out += "\nMantis Blades ARE installed and supported, they are just not drawn.\n";
      out += "Deploy them and press again. The mod only acts while they are out.\n";
    } else {
      let arms = EquipmentSystem.GetData(player).GetActiveItem(gamedataEquipmentArea.ArmsCW);
      out += s"Arms cyberware: \(BYKDescribeItem(arms))\n";
      out += "\nNo Mantis Blades found in the arms slot.\n";
    }
    return out;
  }
  out += s"In hand: \(BYKArmKindName(BYKArmKind(weapon.GetItemID()))) - \(BYKDescribeItem(weapon.GetItemID()))\n";

  let sid = BYKWeaponStatsId(weapon);
  let speed = stats.GetStatValue(sid, gamedataStatType.AttackSpeed);
  let perSec = stats.GetStatValue(sid, gamedataStatType.AttacksPerSecond);
  let pSpeed = stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.AttackSpeed);

  out += s"Blades AttackSpeed:     \(speed)\n";
  out += s"Blades AttacksPerSecond: \(perSec)   (what the inventory shows)\n";
  out += s"Player AttackSpeed:     \(pSpeed)\n";

  // Trap 2. Report it rather than trying to be clever about it: the cap is enforced by the
  // game, not here, so the only useful thing this mod can do is say when it is being hit.
  if speed > BYKConfig.VanillaMeleeSpeedCap() {
    out += s"\nAbove the vanilla \(BYKConfig.VanillaMeleeSpeedCap()) melee clamp.\n";
    out += "Without a cap-raising mod the excess is discarded.\n";
  }

  // The animation ceiling, and whether it is currently holding anything back. Worth printing
  // because its whole job is to stop the blades reaching a speed where the light-attack chain
  // stops alternating arms, and a player who has raised it wants to see that they did.
  let ceiling = BYKSpeedCeiling();
  if ceiling <= 0.0 {
    out += "\nAnimation ceiling: off. Same-arm slashing in long combos is expected.\n";
  } else {
    out += s"\nAnimation ceiling: \(ceiling)\n";
    if speed >= ceiling - 0.01 {
      out += "  At the ceiling. The burst will not push speed any higher.\n";
    }
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

  // ---- The profile on this arm -------------------------------------------
  //
  // Names the weapon, says whether its numbers came from the game or were approximated, and
  // says what is not included. A player comparing against a wiki deserves to know which of
  // those they are looking at before they report a number as wrong.
  if IsDefined(sys) {
    let kind = BYKArmKind(weapon.GetItemID());
    let slot = kind == BYKArmMantis() ? sys.GetMantisSlot() : sys.GetGorillaSlot();
    out += "
Profile: ";
    if IsDefined(slot) && IsDefined(slot.Profile()) {
      let prof = slot.Profile();
      out += s"\(prof.name)
";
      out += s"  source     \(prof.source)
";
      out += s"  values     \(BYKProfileFidelityName(prof.fidelity))
";
      if prof.condition != BYKCondNone() {
        out += s"  condition  \(BYKProfileConditionName(prof.condition)), currently ";
        out += slot.ConditionApplied() ? "APPLIED
" : "not applied
";
      }
      if NotEquals(prof.note, "") {
        out += s"  note       \(prof.note)
";
      }
    } else {
      out += "none
";
    }
  }

  // ---- Conditions the iconic effects key off -----------------------------
  //
  // Printed because a conditional effect that never seems to fire is otherwise impossible to
  // tell apart from a condition that is never read as true.
  out += "
Conditions:
";
  out += "  Optical Camo    ";
  out += BYKCamoActive(game) ? "ACTIVE" : "off";
  out += s"   (charge \(BYKCamoCharge(game)))
";
  out += "  Sandevistan     ";
  out += BYKSandevistanActive(game) ? "ACTIVE
" : "off
";

  // ---- What this mod currently has applied ------------------------------
  //
  // The leak test in the test plan compares the numbers above against a recorded baseline.
  // These two lines say whether anything of ours is attached right now, which turns "the
  // number looks high" into either "yes, a burst is live" or "no, and it should not be".
  if IsDefined(sys) {
    let baseline = sys.GetBaseline();
    if IsDefined(baseline) {
      out += "\nResting lift applied: ";
      out += baseline.IsApplied() ? "yes\n" : "no\n";
    }
    let burst = sys.GetBurst();
    if IsDefined(burst) && burst.IsActive() {
      out += s"Kill burst LIVE: \(burst.GetRemaining(game))s left, \(burst.GetKills()) kill(s) chained";
      out += burst.HasPlayerMod() ? ", mirrored onto V.\n" : ".\n";
    } else {
      out += "Kill burst idle. Kill something with the blades.\n";
    }
    let dash = sys.GetDash();
    if IsDefined(dash) && dash.IsActive() {
      out += s"Dash combo LIVE: \(dash.GetRemaining(game))s left, \(dash.GetDashes()) dash(es) chained.\n";
    } else {
      out += "Dash combo idle. Dash or dodge with a cyberarm out.\n";
    }
    // Gorilla Arms carry CanWeaponInfinitlyCombo and CanWeaponDash in their own record, so the
    // combo flag is redundant on them. Said here rather than leaving a player to wonder why the
    // same setting feels different on the two arms.
    if BYKArmKind(weapon.GetItemID()) == BYKArmGorilla() {
      out += "  Gorilla Arms already combo infinitely, so the window only adds speed there.\n";
    }
  }

  return out;
}
