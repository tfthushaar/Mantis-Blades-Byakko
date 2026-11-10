// Byakko - Reading an iconic's real stats and real ability out of the game
//
// This is the piece that makes the mod do what it set out to do. It finds an iconic weapon's
// actual stat modifiers and its actual ability package, so a cyberarm gets the real thing
// instead of a hand-written imitation of it.
//
// ---------------------------------------------------------------------------
// Why an iconic's effect was so hard to find
//
// It is not where it looks like it should be. Three places were checked first and all three are
// dead ends:
//
//   1. `statModifierGroups` on the weapon record. These belong to the weapon CLASS, which is why
//      all eight katana iconics read back byte-identical: Byakko, Satori, Scalpel and the rest
//      share one katana stat block. Nothing here distinguishes them.
//   2. `OnAttach` on the weapon record. Usually just `GLP.HoldingMelee`, the generic "a melee
//      weapon is in your hands" package. Only three melee weapons in the game attach anything of
//      their own there.
//   3. Accessors that simply do not exist: `Attachments`, `DefaultItems`, `Item_Record.Abilities`,
//      `GameplayLogicPackage_Record.Abilities`, `.StatusEffects`, `.Packages`.
//
// The real structure is one hop further out, and the game's own modding documentation for adding
// an iconic weapon is what gives it away. An iconic is an ordinary weapon with a hidden mod
// fitted to an iconic mod slot, and the MOD carries both halves of what makes it special:
//
//   weapon record
//     -> slotPartListPreset        the fitted parts
//        -> itemPartPreset         the hidden iconic mod
//           -> statModifierGroups  the iconic's own stats, the part that differs per weapon
//           -> OnAttach / OnEquip  the iconic's ability package
//
// Every hop there has a working accessor, which is what the first three attempts lacked.
//
// ---------------------------------------------------------------------------
// The modifier type was readable the whole time
//
// `StatModifier_Record.ModifierType()` returns a **CName**, not an enum. Comparing it against a
// `gameStatModifierType` compiles cleanly and matches nothing, which is how a previous version
// labelled all 456 modifiers it read "other" and concluded the type was unreachable. It reads
// back as n"Additive", n"Multiplier" or n"AdditiveMultiplier", and those map straight onto the
// enum the stats system wants. Without it a transplanted stat is a coin flip between adding 10
// and multiplying by 10, so this one detail is what makes reading stats out of the game usable
// at all rather than merely possible.
//
// ---------------------------------------------------------------------------
// Cost
//
// Everything here walks TweakDB records, so it runs when a profile is chosen or an arm is
// swapped, and never on a tick, a hook or a hit. Results are handed to the caller and not cached,
// because the only thing that would save is a record walk that already happens at most once per
// equip.

// How many of each to accept from one weapon.
//
// A record walk that comes back with hundreds of entries means an assumption here is wrong, and
// the right response is to apply a sane prefix and say so rather than to push 400 modifiers into
// the stats system and find out in a crash log.
public func BYKMaxResolvedStats() -> Int32 = 48
public func BYKMaxResolvedPackages() -> Int32 = 8

// Map a modifier type CName onto the enum the stats system takes.
//
// Returns Invalid for anything unrecognised, including the two values the documentation lists as
// not valid, `Count` and `Invalid`. Callers drop those rather than guessing, because guessing
// wrong here is the difference between +10 and x10.
public func BYKModifierKindFromName(t: CName) -> gameStatModifierType {
  if Equals(t, n"Additive") {
    return gameStatModifierType.Additive;
  }
  if Equals(t, n"Multiplier") {
    return gameStatModifierType.Multiplier;
  }
  if Equals(t, n"AdditiveMultiplier") {
    return gameStatModifierType.AdditiveMultiplier;
  }
  return gameStatModifierType.Invalid;
}

// Is this a package the cyberarm already has, or one that is not the iconic's own?
//
// `GLP.HoldingMelee` is on every melee weapon in the game, the arm included. Applying it a second
// time would stack whatever it carries rather than transplanting anything, so it is refused. The
// check is by name because that is what the record gives, and a name comparison cannot
// accidentally match a weapon-specific package.
public func BYKIsGenericPackage(id: TweakDBID) -> Bool {
  let name = TDBID.ToStringDEBUG(id);
  return StrContains(name, "HoldingMelee")
      || StrContains(name, "HoldingWeapon")
      || StrContains(name, "MeleeWeaponBase");
}

// Every iconic mod fitted to this weapon.
//
// Shared by the stat walk and the package walk so the two cannot disagree about which mods count.
// Most weapons have no fitted parts at all, which is a normal answer rather than a failure.
func BYKResolveIconicMods(sourceId: String, out mods: array<wref<Item_Record>>) -> Void {
  let id = TDBID.Create(sourceId);
  if !TDBID.IsValid(id) {
    return;
  }
  let rec = TweakDBInterface.GetItemRecord(id);
  if !IsDefined(rec) {
    return;
  }
  let parts: array<wref<SlotItemPartPreset_Record>>;
  rec.SlotPartListPreset(parts);
  for part in parts {
    if IsDefined(part) {
      let mod = part.ItemPartPreset();
      if IsDefined(mod) {
        ArrayPush(mods, mod);
      }
    }
  }
}

// This iconic's real stat modifiers, ready to apply.
//
// Only constant modifiers come back. Curve and combined modifiers are deliberately dropped: both
// compute their value from a reference stat read off a reference object, so a curve keyed to a
// katana's Quality means nothing once it is sitting on a pair of Mantis Blades. Transplanting one
// would produce a number, just not the right one, and a wrong number that looks plausible is
// worse here than a missing one.
public func BYKResolveIconicStats(sourceId: String) -> array<ref<BYKStatMod>> {
  let out: array<ref<BYKStatMod>>;
  let mods: array<wref<Item_Record>>;
  BYKResolveIconicMods(sourceId, mods);

  let skipped = 0;
  for mod in mods {
    if IsDefined(mod) {
      let groups: array<wref<StatModifierGroup_Record>>;
      mod.StatModifierGroups(groups);
      for g in groups {
        if IsDefined(g) {
          let sm: array<wref<StatModifier_Record>>;
          g.StatModifiers(sm);
          for m in sm {
            if IsDefined(m) && ArraySize(out) < BYKMaxResolvedStats() {
              let c = m as ConstantStatModifier_Record;
              let st = IsDefined(m) ? m.StatType() : null;
              if IsDefined(c) && IsDefined(st) {
                let kind = BYKModifierKindFromName(c.ModifierType());
                if Equals(kind, gameStatModifierType.Invalid) {
                  skipped += 1;
                  BYKLog.Verbose(n"Resolve", s"Dropped a modifier with type \(NameToString(c.ModifierType())).");
                } else {
                  ArrayPush(out, BYKMod(st.StatType(), kind, c.Value()));
                }
              } else {
                skipped += 1;
              }
            }
          }
        }
      }
    }
  }
  if ArraySize(out) > 0 || skipped > 0 {
    BYKLog.Info(n"Resolve", s"\(sourceId): \(ArraySize(out)) stat(s) read from the game, \(skipped) not transplantable.");
  }
  return out;
}

// This iconic's real ability packages.
//
// A package is the game's own unit of "this weapon does something special". It can be handed to
// another object wholesale, which is why finding one is the same as being able to transplant it,
// and why this does not need to understand what is inside.
public func BYKResolveIconicPackages(sourceId: String) -> array<TweakDBID> {
  let out: array<TweakDBID>;
  let mods: array<wref<Item_Record>>;
  BYKResolveIconicMods(sourceId, mods);

  for mod in mods {
    if IsDefined(mod) {
      // Both hooks, because an iconic mod may carry its ability on either. OnAttach is the one
      // the documentation describes; OnEquip exists on the same record and is cheap to include.
      //
      // Read into SEPARATE arrays and merged by hand. These native accessors fill the array they
      // are given, and nothing documents whether they clear it first. Passing one array to both
      // calls would quietly lose the OnAttach results if OnEquip clears, and the symptom would be
      // an ability that resolves on some weapons and not others for no visible reason.
      let onAttach: array<wref<GameplayLogicPackage_Record>>;
      let onEquip: array<wref<GameplayLogicPackage_Record>>;
      mod.OnAttach(onAttach);
      mod.OnEquip(onEquip);
      let pkgs: array<wref<GameplayLogicPackage_Record>>;
      for p in onAttach {
        ArrayPush(pkgs, p);
      }
      for p in onEquip {
        if !ArrayContains(pkgs, p) {
          ArrayPush(pkgs, p);
        }
      }
      for pkg in pkgs {
        if IsDefined(pkg) && ArraySize(out) < BYKMaxResolvedPackages() {
          let pid = pkg.GetID();
          if BYKIsGenericPackage(pid) {
            BYKLog.Verbose(n"Resolve", s"Skipped generic package \(TDBID.ToStringDEBUG(pid)).");
          } else {
            if !ArrayContains(out, pid) {
              ArrayPush(out, pid);
            }
          }
        }
      }
    }
  }
  if ArraySize(out) > 0 {
    BYKLog.Info(n"Resolve", s"\(sourceId): \(ArraySize(out)) ability package(s) found.");
  }
  return out;
}

// The same walk, written to the log, for the F9 diagnostic.
//
// Kept separate from the two functions above so that the path that actually applies things builds
// no strings.
public func BYKLogIconicChain(sourceId: String) -> Void {
  let mods: array<wref<Item_Record>>;
  BYKResolveIconicMods(sourceId, mods);
  if ArraySize(mods) == 0 {
    BYKLog.Info(n"Rip", "  (no fitted parts, so no iconic mod on this record)");
    return;
  }

  for mod in mods {
    BYKLog.Info(n"Rip", s"  ICONIC MOD \(TDBID.ToStringDEBUG(mod.GetID()))");

    // The iconic's own stats. This is the half that differs per weapon, as opposed to the shared
    // weapon-class block on the weapon record itself.
    let groups: array<wref<StatModifierGroup_Record>>;
    mod.StatModifierGroups(groups);
    let any = false;
    for g in groups {
      if IsDefined(g) {
        let sm: array<wref<StatModifier_Record>>;
        g.StatModifiers(sm);
        if ArraySize(sm) > 0 {
          any = true;
          BYKRipMods(sm, "      ");
        }
      }
    }
    if !any {
      BYKLog.Info(n"Rip", "      (no stat modifiers on the mod)");
    }

    // The iconic's ability. Separate arrays per hook, for the reason given above.
    let onAttach: array<wref<GameplayLogicPackage_Record>>;
    let onEquip: array<wref<GameplayLogicPackage_Record>>;
    mod.OnAttach(onAttach);
    mod.OnEquip(onEquip);
    let pkgs: array<wref<GameplayLogicPackage_Record>>;
    for q in onAttach {
      ArrayPush(pkgs, q);
    }
    for q in onEquip {
      if !ArrayContains(pkgs, q) {
        ArrayPush(pkgs, q);
      }
    }
    if ArraySize(pkgs) == 0 {
      BYKLog.Info(n"Rip", "      (no ability package on the mod)");
    } else {
      for pkg in pkgs {
        if IsDefined(pkg) {
          BYKLog.Info(n"Rip", s"      ABILITY PACKAGE \(TDBID.ToStringDEBUG(pkg.GetID()))");
          let pm: array<wref<StatModifier_Record>>;
          pkg.Stats(pm);
          if ArraySize(pm) > 0 {
            BYKRipMods(pm, "          ");
          }
          let effs: array<wref<Effector_Record>>;
          pkg.Effectors(effs);
          for ef in effs {
            if IsDefined(ef) {
              BYKLog.Info(n"Rip", s"          effector \(TDBID.ToStringDEBUG(ef.GetID()))  [\(NameToString(ef.EffectorClassName()))]");
            }
          }
        }
      }
    }
  }
}
