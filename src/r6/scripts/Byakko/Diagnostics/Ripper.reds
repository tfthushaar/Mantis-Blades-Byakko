// Byakko - Reading an iconic's real stat modifiers out of the game
//
// Every profile's numbers currently come from one of two places, and neither is the game:
//
//   - The blade profiles are transcribed from the CDPR modding documentation's iconic-effects
//     table. That is a markdown file dated April 2024. Its stat *names* were checked against
//     this build; its *values* were not.
//   - The blunt profiles and Sihil are approximations, because that table has no stat rows for
//     blunt weapons and omits Sihil entirely.
//
// This reads the actual modifiers out of TweakDB and writes them to the log, so both can be
// replaced with what the game really has.
//
// ---------------------------------------------------------------------------
// Why this runs on a keypress and never on a tick
//
// It walks record arrays, which is work the shipping runtime has no business doing repeatedly.
// Nothing here is called from a tick, from a hook, or from the burst. It runs when the player
// presses the key and not otherwise, and it only reads.
//
// It is also the answer to "where do these numbers come from" for anyone who wants to check the
// profiles rather than trust them.

// Print one list of stat modifiers.
//
// Shared by the two places an iconic's stats can live. The modifier type is deliberately not
// reported: ConstantStatModifier_Record.ModifierType returns something that is neither a record
// (every accessor on it is an invalid member access) nor anything EnumInt will take, and Equals
// against gameStatModifierType compiles while matching nothing, which is how 456 modifiers once
// all came back labelled "other". Printing the stat and the value is what is certain.
func BYKRipMods(mods: array<wref<StatModifier_Record>>, indent: String) -> Int32 {
  let n = 0;
  for m in mods {
    if IsDefined(m) {
      n += 1;
      let statName = "?";
      let st = m.StatType();
      if IsDefined(st) {
        statName = EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(st.StatType())));
      }
      let c = m as ConstantStatModifier_Record;
      if IsDefined(c) {
        BYKLog.Info(n"Rip", s"\(indent)\(statName) = \(c.Value())");
      } else {
        BYKLog.Info(n"Rip", s"\(indent)\(statName)  (not constant, varies with the weapon)");
      }
    }
  }
  return n;
}

// Dump one record's stat modifiers to the log.
public func BYKRipRecord(name: String) -> Void {
  let id = TDBID.Create(name);
  if !TDBID.IsValid(id) {
    BYKLog.Info(n"Rip", s"\(name): not a valid record id");
    return;
  }
  let rec = TweakDBInterface.GetItemRecord(id);
  if !IsDefined(rec) {
    BYKLog.Info(n"Rip", s"\(name): no item record");
    return;
  }

  let groups: array<wref<StatModifierGroup_Record>>;
  rec.StatModifierGroups(groups);
  if ArraySize(groups) == 0 {
    BYKLog.Info(n"Rip", s"\(name): no stat modifier groups");
    return;
  }

  BYKLog.Info(n"Rip", s"\(name):");
  let total = 0;
  // No `continue` in redscript, so the guards are nested rather than early-exited.
  for g in groups {
    if IsDefined(g) {
      let mods: array<wref<StatModifier_Record>>;
      g.StatModifiers(mods);
      for m in mods {
        if IsDefined(m) {
          total += 1;
          let statName = "?";
          let st = m.StatType();
          if IsDefined(st) {
            statName = EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(st.StatType())));
          }
          // Constant modifiers are the ones that transplant. Curve and combined modifiers
          // depend on the weapon they came from, so they are reported but flagged as unusable.
          let c = m as ConstantStatModifier_Record;
          if IsDefined(c) {
            // The modifier type is deliberately not reported.
            //
            // ConstantStatModifier_Record.ModifierType returns something that is neither a
            // record (every accessor on it is an invalid member access) nor anything EnumInt
            // will take, and Equals against gameStatModifierType compiles but matches nothing,
            // which is how 456 modifiers all came back labelled "other". Rather than print a
            // label that has already been wrong once, print what is certain: the stat and the
            // value. The effect of an iconic is recovered by diffing it against its base
            // weapon, and a diff does not need the modifier type to be meaningful.
            BYKLog.Info(n"Rip", s"    \(statName) = \(c.Value())");
          } else {
            BYKLog.Info(n"Rip", s"    \(statName)  (not a constant modifier, cannot transplant)");
          }
        }
      }
    }
  }
  if total == 0 {
    BYKLog.Info(n"Rip", "    (groups present but empty)");
  }

  // The iconic's own effect.
  //
  // The statModifierGroups above are the WEAPON CLASS's stats, which is why all eight katana
  // iconics came back byte-identical there: Byakko, Satori, Scalpel and the rest share one
  // katana stat block. An iconic's own contribution is attached as a gameplay logic package,
  // which is the "statModifiers plus OnAttach" structure the modding documentation describes.
  // This is the half that matters for transplanting.
  let pkgs: array<wref<GameplayLogicPackage_Record>>;
  rec.OnAttach(pkgs);
  if ArraySize(pkgs) > 0 {
    BYKLog.Info(n"Rip", "  ICONIC EFFECT (OnAttach):");
    for pkg in pkgs {
      if IsDefined(pkg) {
        // The package id is the important line. A package can be applied wholesale to another
        // object with GameplayLogicPackageSystem.ApplyPackage, which is how an iconic's real
        // ability gets onto a cyberarm instead of being reimplemented by hand.
        BYKLog.Info(n"Rip", s"    PACKAGE \(TDBID.ToStringDEBUG(pkg.GetID()))");

        let pmods: array<wref<StatModifier_Record>>;
        pkg.Stats(pmods);
        if ArraySize(pmods) > 0 {
          BYKLog.Info(n"Rip", "      stats:");
          BYKRipMods(pmods, "        ");
        }

        // Effectors are the behaviour half: the leap, the on-kill combo, the camo crit. Their
        // class name says what kind of thing each one does.
        let effs: array<wref<Effector_Record>>;
        pkg.Effectors(effs);
        if ArraySize(effs) > 0 {
          BYKLog.Info(n"Rip", "      effectors:");
          for ef in effs {
            if IsDefined(ef) {
              BYKLog.Info(n"Rip", s"        \(TDBID.ToStringDEBUG(ef.GetID()))  [\(ef.EffectorClassName())]");
            }
          }
        }
        if ArraySize(pmods) == 0 && ArraySize(effs) == 0 {
          BYKLog.Info(n"Rip", "      (package carries neither stats nor effectors)");
        }
      }
    }
  } else {
    BYKLog.Info(n"Rip", "  (no OnAttach packages)");
  }
}

// Dump every record the profiles are built from.
//
// Writes to the redscript log. On a setup where FTLog is not being captured, Advanced Crash
// Reporter's log harvesting picks it up instead.
public func BYKRipAllProfiles(game: GameInstance) -> Void {
  BYKLog.Info(n"Rip", "---- iconic stat modifiers, read from this game's TweakDB ----");

  let id = 1;
  while id <= BYKLastProfileId() {
    let p = BYKMakeProfile(id);
    if IsDefined(p) {
      BYKRipRecord(p.source);
    }
    id += 1;
  }

  // The cyberarms themselves. This is the important half: it says which stats Mantis Blades
  // and Gorilla Arms actually carry, and therefore which ones a profile can meaningfully
  // change. A modifier for a stat the arm does not use is a modifier nobody will feel.
  BYKLog.Info(n"Rip", "---- cyberarms ----");
  BYKRipRecord("Items.AdvancedMantisBladesLegendaryPlusPlus");
  BYKRipRecord("Items.AdvancedMaxTacMantisBladesLegendaryPlusPlus");
  BYKRipRecord("Items.AdvancedStrongArmsLegendaryPlusPlus");

  // Base weapons, so an iconic's own contribution can be told apart from its weapon class's
  // ordinary stats. The records above carry the whole stat block, not just the iconic's delta.
  BYKLog.Info(n"Rip", "---- base weapons, for diffing ----");
  BYKRipRecord("Items.Preset_Katana_Default");
  BYKRipRecord("Items.Preset_Baseball_Bat_Default");

  // The two reach stats, settled by looking at what the Byakko actually uses. Both exist as
  // stat types, the string pool cannot distinguish them, and the mod currently assumes
  // EffectiveRange for its +1m without ever having confirmed it.
  BYKLog.Info(n"Rip", "---- end ----");

  BYKShowMessage(game, "Byakko: iconic stats written to the redscript log.", 6.0);
}
