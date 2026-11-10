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
            // Compared rather than converted: ModifierType does not take EnumInt here, and
            // the two values that matter for transplanting are the only two worth naming.
            let kind = "other";
            if Equals(c.ModifierType(), gameStatModifierType.Additive) {
              kind = "Additive";
            }
            if Equals(c.ModifierType(), gameStatModifierType.Multiplier) {
              kind = "Multiplier";
            }
            BYKLog.Info(n"Rip", s"    \(statName)  \(kind)  \(c.Value())");
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

  // The two reach stats, settled by looking at what the Byakko actually uses. Both exist as
  // stat types, the string pool cannot distinguish them, and the mod currently assumes
  // EffectiveRange for its +1m without ever having confirmed it.
  BYKLog.Info(n"Rip", "---- reach check: look for Range or EffectiveRange above ----");
  BYKLog.Info(n"Rip", "---- end ----");

  BYKShowMessage(game, "Byakko: iconic stats written to the redscript log.", 6.0);
}
