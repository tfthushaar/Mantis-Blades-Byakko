// Byakko - Applying a profile to a cyberarm
//
// Holds two modifier sets for one arm: the profile's base stats, which stay on while the arm is
// out, and its conditional stats, which come and go with Optical Camo or a Sandevistan.
//
// One of these exists per cyberarm, so the player's Mantis choice and Gorilla choice do not
// interfere. Each owns its own sets and never touches the other's.
//
// ---------------------------------------------------------------------------
// Attack speed and combo stats
//
// Profiles DO carry these, because several iconics are defined by exactly those: the Byakko's
// rapid combo on a kill, Sihil's combo after a dash, Black Unicorn's stamina exemption. An
// earlier version excluded them, which left profiles feeling gutted and the global windows
// incoherent, since picking Scalpel still handed you the Byakko's combo.
//
// What they may not do is bypass the animation ceiling. Every speed modifier goes through
// BYKModSet.AddClamped, which applies the same clamp the burst uses, so the light-attack chain
// cannot be pushed into the regime where it stops alternating arms.

public class BYKProfileSlot {
  private let m_armKind: Int32;
  private let m_profileId: Int32;           // what is currently applied, 0 for none
  private let m_base: ref<BYKModSet>;
  private let m_cond: ref<BYKModSet>;
  private let m_condOn: Bool;               // are the conditional mods currently applied
  private let m_profile: ref<BYKProfile>;
  private let m_pkgs: ref<BYKPackageSet>;   // real ability packages, when the profile has any
  private let m_statsFromGame: Bool;        // were the applied stats read from TweakDB

  public func Init(armKind: Int32) -> Void {
    this.m_armKind = armKind;
    this.m_base = new BYKModSet();
    this.m_cond = new BYKModSet();
    this.m_pkgs = new BYKPackageSet();
  }

  public func ArmKind() -> Int32 {
    return this.m_armKind;
  }

  public func ProfileId() -> Int32 {
    return this.m_profileId;
  }

  public func Profile() -> ref<BYKProfile> {
    return this.m_profile;
  }

  public func ConditionApplied() -> Bool {
    return this.m_condOn;
  }

  public func PackageCount() -> Int32 {
    return IsDefined(this.m_pkgs) ? this.m_pkgs.Count() : 0;
  }

  // Were the stats currently applied read out of the game, or taken from the built-in table?
  // The diagnostic prints this, because it is the difference between a number that is the
  // weapon's own and one that was written by hand from a documentation table.
  public func StatsFromGame() -> Bool {
    return this.m_statsFromGame;
  }

  public func IsApplied() -> Bool {
    return IsDefined(this.m_profile) && !this.m_base.IsEmpty();
  }

  // Does this slot need a tick? Only when a conditional profile is actually on an arm.
  public func WantsTick() -> Bool {
    return IsDefined(this.m_profile)
        && this.m_profile.condition != BYKCondNone()
        && this.IsApplied();
  }

  // Put the chosen profile on this weapon, or take it off if the choice is None.
  //
  // Safe to call repeatedly: it does nothing when the profile and the weapon are both already
  // what they should be, which is what makes it safe to drive from a tick.
  public func Sync(game: GameInstance, weapon: wref<WeaponObject>, wantedId: Int32) -> Void {
    if !IsDefined(weapon) {
      // The arm is not out.
      //
      // Stat modifiers can simply be forgotten: they went with the weapon entity, and a stale
      // handle to a dead entity costs nothing.
      //
      // A package cannot. Putting a cyberarm away does not reliably destroy the weapon object,
      // and if it survives with a package still on it, forgetting the handle means the next draw
      // applies a second copy. So packages get a real removal, which is safe here because this
      // only runs behind the caller's world-stability gate and because Clear checks the target is
      // still alive before touching the package system. If the entity really did go, Clear
      // degrades to exactly the Forget that used to happen.
      if IsDefined(this.m_pkgs) {
        this.m_pkgs.Clear(game);
      }
      this.Forget();
      return;
    }
    let entity = weapon.GetEntityID();

    // Already correct: right profile, right weapon, nothing to do.
    if this.m_profileId == wantedId && this.m_base.IsOn(entity) {
      return;
    }

    // Anything else means a change of profile or of weapon. Clear before applying, never layer.
    this.Clear(game);

    if wantedId == EnumInt(EBYKProfile.None) {
      return;
    }
    let profile = BYKMakeProfile(wantedId);
    if !IsDefined(profile) {
      // An id from a settings file this build does not know. Treat as None rather than
      // indexing anything.
      BYKLog.Warn(n"Profile", s"Unknown profile id \(wantedId); treating as none.");
      return;
    }

    let allowNerf = false;
    let settings = BYKSettings();
    if IsDefined(settings) {
      allowNerf = settings.allowDamageReduction;
    }

    // ---- The stats -------------------------------------------------------
    //
    // Preferred from the game itself. BYKResolveIconicStats walks this iconic's hidden mod record
    // and reads its real modifiers, which is where the per-weapon difference actually lives. The
    // authored table in Profile.reds is the fallback for a weapon the walk finds nothing on, and
    // for a player who switches the setting off.
    //
    // Both paths go through AddClamped, so neither can push attack speed past the animation
    // ceiling, and both are filtered by BYKProfileModAllowed.
    let resolved = BYKResolveIconicStats(profile.source);
    let fromGame = ArraySize(resolved) > 0 && BYKUseGameStats();
    let chosen = fromGame ? resolved : profile.mods;
    this.m_statsFromGame = fromGame;

    let applied = 0;
    for m in chosen {
      if IsDefined(m) && BYKProfileModAllowed(m, allowNerf) {
        if this.m_base.AddClamped(game, entity, m.stat, m.kind, m.value) {
          applied += 1;
        }
      }
    }
    this.m_profile = profile;
    this.m_profileId = wantedId;

    // ---- The ability -----------------------------------------------------
    //
    // Two sources, and both are the game's own data rather than a reimplementation:
    //
    //   - the iconic mod fitted to the weapon, which is where almost every iconic keeps its
    //     effect, found by walking the record chain
    //   - the weapon record's own OnAttach, which only three melee weapons in the game use
    //
    // Applied to the WEAPON, not to V. That is where the package sits in the real case, since it
    // belongs to a mod fitted to the weapon, so it is the faithful target. It is also the safer
    // one: a package on the weapon entity cannot outlive the weapon, so the worst case if removal
    // ever failed is bounded by putting the arm away, rather than lasting the whole session. V is
    // passed as the instigator, because the effect is V's.
    if BYKPackagesEnabled() {
      let player = GetPlayer(game);
      let ids = BYKResolveIconicPackages(profile.source);
      for name in profile.packages {
        let pid = TDBID.Create(name);
        if TDBID.IsValid(pid) {
          if !ArrayContains(ids, pid) {
            ArrayPush(ids, pid);
          }
        } else {
          BYKLog.Warn(n"Pkg", s"Profile named a package that does not resolve: \(name)");
        }
      }
      for pid in ids {
        this.m_pkgs.Add(game, weapon, player, pid);
      }
    }

    let src = fromGame ? "from the game" : "from the built-in table";
    BYKLog.Info(n"Profile", s"\(BYKArmKindName(this.m_armKind)): \(profile.name), \(applied) stat(s) \(src), \(this.PackageCount()) ability package(s).");
  }

  // Apply or remove the conditional half as the condition flips. Called from the tick, and only
  // when WantsTick is true.
  public func SyncCondition(game: GameInstance, weapon: wref<WeaponObject>) -> Void {
    if !IsDefined(this.m_profile) || this.m_profile.condition == BYKCondNone() {
      return;
    }
    if !IsDefined(weapon) {
      return;
    }
    let holds = BYKConditionHolds(game, this.m_profile.condition);
    // Equals rather than ==: redscript defines no OperatorEqual for Bool.
    if Equals(holds, this.m_condOn) {
      return;   // no change
    }
    if holds {
      let entity = weapon.GetEntityID();
      let allowNerf = false;
      let settings = BYKSettings();
      if IsDefined(settings) {
        allowNerf = settings.allowDamageReduction;
      }
      for m in this.m_profile.condMods {
        if IsDefined(m) && BYKProfileModAllowed(m, allowNerf) {
          this.m_cond.AddClamped(game, entity, m.stat, m.kind, m.value);
        }
      }
      this.m_condOn = true;
      BYKLog.Verbose(n"Profile", s"\(this.m_profile.name): \(BYKProfileConditionName(this.m_profile.condition)) on.");
    } else {
      this.m_cond.Clear(game);
      this.m_condOn = false;
      BYKLog.Verbose(n"Profile", s"\(this.m_profile.name): condition off.");
    }
  }

  // Only safe while the world is stable.
  public func Clear(game: GameInstance) -> Void {
    if IsDefined(this.m_pkgs) {
      this.m_pkgs.Clear(game);
    }
    this.m_cond.Clear(game);
    this.m_base.Clear(game);
    this.m_condOn = false;
    this.m_profileId = EnumInt(EBYKProfile.None);
    this.m_profile = null;
    this.m_statsFromGame = false;
  }

  // Drop handles with no native calls, for loads, respawns and teardown.
  public func Forget() -> Void {
    if IsDefined(this.m_pkgs) {
      this.m_pkgs.Forget();
    }
    if IsDefined(this.m_cond) {
      this.m_cond.Forget();
    }
    if IsDefined(this.m_base) {
      this.m_base.Forget();
    }
    this.m_condOn = false;
    this.m_profileId = EnumInt(EBYKProfile.None);
    this.m_profile = null;
    this.m_statsFromGame = false;
  }
}

// Should this modifier be applied?
//
// The only thing filtered is a damage multiplier below 1.0. Several iconics genuinely carry
// one: Satori, Errata and Cocktail Stick are all x0.9. On the original weapon that is balance,
// paired with the rest of its kit. Transplanted onto a cyberarm by a player who picked the
// profile for its bleed, it is a straight nerf they did not ask for. So it is opt-in.
public func BYKProfileModAllowed(m: ref<BYKStatMod>, allowDamageReduction: Bool) -> Bool {
  if !IsDefined(m) {
    return false;
  }
  if allowDamageReduction {
    return true;
  }
  if Equals(m.stat, gamedataStatType.DamagePerHit)
     && Equals(m.kind, gameStatModifierType.Multiplier)
     && m.value < 1.0 {
    return false;
  }
  return true;
}

// Which profile the player chose for this arm, validated.
//
// The value comes out of a Mod Settings ini that survives mod updates, so it can be anything.
// Anything unrecognised reads as None.
public func BYKWantedProfileId(armKind: Int32) -> Int32 {
  let settings = BYKSettings();
  if !IsDefined(settings) {
    // Without Mod Settings the mod keeps its original behaviour: the Byakko on Mantis Blades,
    // nothing on Gorilla Arms.
    return armKind == BYKArmMantis() ? EnumInt(EBYKProfile.Byakko) : EnumInt(EBYKProfile.None);
  }
  if !settings.profilesEnabled {
    return EnumInt(EBYKProfile.None);
  }
  let chosen = armKind == BYKArmMantis() ? settings.mantisProfile : settings.gorillaProfile;
  let id = EnumInt(chosen);
  // Validate against the registry rather than trusting the enum: an out-of-range value read
  // from the ini casts to an enum without complaint.
  if id != EnumInt(EBYKProfile.None) && !IsDefined(BYKMakeProfile(id)) {
    return EnumInt(EBYKProfile.None);
  }
  return id;
}
