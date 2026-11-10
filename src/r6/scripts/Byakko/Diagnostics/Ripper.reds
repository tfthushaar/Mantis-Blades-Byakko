// Byakko - Writing what the game actually holds to the log (default F9)
//
// The mod reads each iconic's real stats and real ability at equip time, so this is no longer the
// route by which those reach a player. What it is for now is showing the working: it prints, per
// weapon, the shared weapon-class block, the iconic's own hidden mod, that mod's real stat
// modifiers with their modifier types, and the ability package with its stats and effectors.
//
// That matters for three reasons. It answers "where did this number come from" for anyone who
// wants to check a profile rather than trust it. It is how the hand-written fallback table in
// Profile.reds gets corrected. And it is the only way to see what the resolver decided to skip,
// since curve and combined modifiers are reported here but deliberately never transplanted.
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
// Shared by every place an iconic's stats can live.
//
// The modifier type IS reported, which an earlier version of this said was impossible. It reads
// back as a CName, not an enum: n"Additive", n"Multiplier" or n"AdditiveMultiplier". Comparing it
// against a gameStatModifierType compiles and matches nothing, which is how 456 modifiers once
// all came back labelled "other" and why the type was written off as unreachable. It was readable
// the whole time, just not as an enum. Printing it matters because a stat and a value alone do
// not say whether +10 or x10 is meant.
//
// Curve and combined modifiers are flagged rather than printed as values, because neither has
// one: both compute from a reference stat read off a reference object, so the number depends on
// the weapon it is read from.
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
        BYKLog.Info(n"Rip", s"\(indent)\(statName) \(NameToString(c.ModifierType())) \(c.Value())");
      } else {
        let cb = m as CombinedStatModifier_Record;
        if IsDefined(cb) {
          // Printed in the shape the documentation gives for the formula, so it can be read
          // against the wiki without having to decode the field order.
          let refObj = NameToString(cb.RefObject());
          let op = NameToString(cb.OpSymbol());
          let refStat = "?";
          let rs = cb.RefStat();
          if IsDefined(rs) {
            refStat = EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(rs.StatType())));
          }
          BYKLog.Info(n"Rip", s"\(indent)\(statName) \(NameToString(cb.ModifierType())) = (\(refObj).\(refStat)) \(op) \(cb.Value())   [combined, not transplantable]");
        } else {
          BYKLog.Info(n"Rip", s"\(indent)\(statName) \(NameToString(m.ModifierType()))  [curve, value depends on the weapon, not transplantable]");
        }
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

  // The iconic's own stats and its ability, both of which live on a hidden mod fitted to the
  // weapon rather than on the weapon record.
  //
  // The statModifierGroups above are the WEAPON CLASS's stats, which is why all eight katana
  // iconics came back byte-identical there: Byakko, Satori, Scalpel and the rest share one
  // katana stat block. What separates them is one hop further out. See Profiles/IconicResolver.reds.
  BYKLogIconicChain(name);

  // The weapon record's own packages. Three melee weapons in the game carry one here.
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
  // ---- What the mod would actually apply ------------------------------
  //
  // The decisive section, and the reason one keypress is enough.
  //
  // Everything above is raw record content. This is the resolver's own verdict: for each profile,
  // exactly which stats it would put on an arm and which abilities it would transplant. It calls
  // the same two functions the live path calls, so what it prints is what you would get rather
  // than a description of what should happen.
  //
  // It also answers the one question compile probes cannot. A probe proves an accessor resolves;
  // it says nothing about whether the record on the other end holds anything. A profile printing
  // zero stats and zero abilities here means that weapon keeps its data somewhere this walk does
  // not reach, and a profile printing a large stat block means the numbers need a second look
  // before they go on a cyberarm.
  BYKLog.Info(n"Rip", "");
  BYKLog.Info(n"Rip", "---- RESOLVER VERDICT: what each profile would apply ----");
  let id2 = 1;
  while id2 <= BYKLastProfileId() {
    let p2 = BYKMakeProfile(id2);
    if IsDefined(p2) {
      let rs = BYKResolveIconicStats(p2.source);
      let rp = BYKResolveIconicPackages(p2.source);
      BYKLog.Info(n"Rip", s"\(p2.name)  [\(p2.source)]");
      if ArraySize(rs) == 0 {
        BYKLog.Info(n"Rip", s"    stats:     none found, falling back to \(ArraySize(p2.mods)) hand-written");
      } else {
        BYKLog.Info(n"Rip", s"    stats:     \(ArraySize(rs)) from the game");
        for m in rs {
          if IsDefined(m) {
            let sn = EnumValueToString("gamedataStatType", Cast<Int64>(EnumInt(m.stat)));
            let kn = EnumValueToString("gameStatModifierType", Cast<Int64>(EnumInt(m.kind)));
            BYKLog.Info(n"Rip", s"                 \(sn) \(kn) \(m.value)");
          }
        }
      }
      if ArraySize(rp) == 0 {
        BYKLog.Info(n"Rip", "    abilities: none found by the walk");
      } else {
        for pid in rp {
          BYKLog.Info(n"Rip", s"    ability:   \(TDBID.ToStringDEBUG(pid))");
        }
      }
      // The weapon-level packages, which the resolver merges in on top of the walk.
      for extra in p2.packages {
        BYKLog.Info(n"Rip", s"    ability:   \(extra)   (named on the weapon record)");
      }
    }
    id2 += 1;
  }

  BYKLog.Info(n"Rip", "---- end ----");

  BYKShowMessage(game, "Byakko: wrote the full iconic dump and the resolver verdict to the log.", 6.0);
}
