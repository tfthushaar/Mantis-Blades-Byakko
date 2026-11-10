// Byakko - Applying a profile to a cyberarm
//
// Holds two modifier sets for one arm: the profile's base stats, which stay on while the arm is
// out, and its conditional stats, which come and go with Optical Camo or a Sandevistan.
//
// One of these exists per cyberarm, so the player's Mantis choice and Gorilla choice do not
// interfere. Each owns its own sets and never touches the other's.
//
// ---------------------------------------------------------------------------
// What this deliberately does not do
//
// It does not touch attack speed or the combo flag. Those belong to the burst, the dash window
// and the resting lift, which all route through the animation ceiling. A profile that set
// attack speed directly would bypass that and reintroduce the arm-alternation bug, so no
// profile carries those stats and this applier would not honour them if one did.

public class BYKProfileSlot {
  private let m_armKind: Int32;
  private let m_profileId: Int32;           // what is currently applied, 0 for none
  private let m_base: ref<BYKModSet>;
  private let m_cond: ref<BYKModSet>;
  private let m_condOn: Bool;               // are the conditional mods currently applied
  private let m_profile: ref<BYKProfile>;

  public func Init(armKind: Int32) -> Void {
    this.m_armKind = armKind;
    this.m_base = new BYKModSet();
    this.m_cond = new BYKModSet();
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
      // The arm is not out. Its modifiers went with the weapon entity, so drop the handles
      // without touching anything.
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

    let applied = 0;
    for m in profile.mods {
      if IsDefined(m) && BYKProfileModAllowed(m, allowNerf) {
        if this.m_base.Add(game, entity, m.stat, m.kind, m.value) {
          applied += 1;
        }
      }
    }
    this.m_profile = profile;
    this.m_profileId = wantedId;
    BYKLog.Info(n"Profile", s"\(BYKArmKindName(this.m_armKind)): \(profile.name), \(applied) stat(s).");
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
          this.m_cond.Add(game, entity, m.stat, m.kind, m.value);
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
    this.m_cond.Clear(game);
    this.m_base.Clear(game);
    this.m_condOn = false;
    this.m_profileId = EnumInt(EBYKProfile.None);
    this.m_profile = null;
  }

  // Drop handles with no native calls, for loads, respawns and teardown.
  public func Forget() -> Void {
    if IsDefined(this.m_cond) {
      this.m_cond.Forget();
    }
    if IsDefined(this.m_base) {
      this.m_base.Forget();
    }
    this.m_condOn = false;
    this.m_profileId = EnumInt(EBYKProfile.None);
    this.m_profile = null;
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
