// Byakko - Transplanting an iconic's real gameplay logic package
//
// This is the part of the mod that hands a cyberarm an iconic's actual ability rather than an
// imitation of it. The game applies these packages itself when the weapon is equipped;
// GameplayLogicPackageSystem.ApplyPackage puts the same package on something else.
//
// ---------------------------------------------------------------------------
// Which iconics this can do
//
// All of them that have one. An earlier version of this file said otherwise, and said it in a
// changelog too: that only three melee weapons carried a package, that all eight katana iconics
// attached nothing but the generic GLP.HoldingMelee, and that "whatever makes Byakko different
// from Satori is not reachable through any accessor redscript exposes". That was wrong. It was a
// conclusion drawn from looking in one place, the weapon record, and finding nothing there.
//
// An iconic keeps its effect on a hidden mod fitted to it, not on the weapon record, and that mod
// is reachable. Profiles/IconicResolver.reds has the walk and the reasoning. The three
// weapon-level packages found earlier are real, they are just the exception rather than the whole
// story:
//
//   Sihil                 Items.Preset_Sword_Sihil_inline0
//   Gwynbleidd            Items.Preset_Sword_Witcher_inline0
//   Sasquatch's Hammer    GLP.HoldingSasquatchHammer
//
// ---------------------------------------------------------------------------
// Why the target is the weapon
//
// In the real case the package belongs to a mod fitted to the weapon, so the weapon is the
// faithful target, and the cyberarm IS the weapon here. V is passed as the instigator, because
// the effect is V's.
//
// It is also the safer of the two choices, which is worth saying plainly. A package applied to the
// weapon entity cannot outlive the weapon: if removal ever failed, putting the arm away ends it.
// A package applied to V would last the rest of the session. Given that this is the one feature
// that hands over something the mod did not author, bounding the worst case to the weapon's
// lifetime is worth more than the alternative.
//
// ---------------------------------------------------------------------------
// The rules it still keeps
//
//   - Only ids resolved from TweakDB or named in the profile registry are ever passed. Nothing
//     comes from a settings string or from player input.
//   - Tracked by both the package id and the target's entity id, and removed before anything new
//     is applied. One set never mixes two targets.
//   - Removed on unequip, on profile change, on session start and on detach.
//   - If the package system is unavailable it does nothing rather than retrying.
//   - It has its own setting, so the rest of the mod can be run without it.

public class BYKPackageSet {
  private let m_applied: array<TweakDBID>;
  private let m_target: EntityID;

  public func Count() -> Int32 {
    return ArraySize(this.m_applied);
  }

  public func IsOn(target: EntityID) -> Bool {
    if ArraySize(this.m_applied) == 0 {
      return false;
    }
    return BYKSameEntity(this.m_target, target);
  }

  // Apply one package, remembering it so it can come back off.
  //
  // `target` is what the package lands on, normally the cyberarm. `instigator` is who it belongs
  // to, normally V. Passing the player as instigator is what makes an effector attribute its work
  // to V rather than to a weapon.
  public func Add(game: GameInstance, target: ref<GameObject>, instigator: ref<GameObject>, id: TweakDBID) -> Bool {
    if !IsDefined(target) || !TDBID.IsValid(id) {
      return false;
    }
    let sys = GameInstance.GetGameplayLogicPackageSystem(game);
    if !IsDefined(sys) {
      return false;
    }
    let entity = target.GetEntityID();
    if ArraySize(this.m_applied) > 0 && !BYKSameEntity(this.m_target, entity) {
      // Refuse rather than orphan what is already applied to a different object, for the same
      // reason BYKModSet refuses to mix entities.
      BYKLog.Warn(n"Pkg", "Refused to mix two targets in one package set.");
      return false;
    }
    if ArrayContains(this.m_applied, id) {
      // Already on. Applying twice would stack it and leave one copy behind on removal.
      return false;
    }
    // Fall back to the target as its own instigator rather than passing null, which is what the
    // game does for a package with no obvious source.
    let source = IsDefined(instigator) ? instigator : target;
    sys.ApplyPackage(target, source, id);
    ArrayPush(this.m_applied, id);
    this.m_target = entity;
    BYKLog.Info(n"Pkg", s"Applied \(TDBID.ToStringDEBUG(id)).");
    return true;
  }

  // Take them all back off. Only safe while the world is stable.
  public func Clear(game: GameInstance) -> Void {
    if ArraySize(this.m_applied) > 0 && BYKEntityAlive(game, this.m_target) {
      let sys = GameInstance.GetGameplayLogicPackageSystem(game);
      let ent = GameInstance.FindEntityByID(game, this.m_target);
      let obj = ent as GameObject;
      if IsDefined(sys) && IsDefined(obj) {
        for id in this.m_applied {
          sys.RemovePackage(obj, id);
          BYKLog.Verbose(n"Pkg", s"Removed \(TDBID.ToStringDEBUG(id)).");
        }
      }
    }
    this.Forget();
  }

  // Drop the record of what was applied without calling into the game.
  //
  // Used only where the target really is gone: a load, a respawn, a teardown, or the arm being
  // put away. In those cases the package went with the object it was on, which is the whole
  // reason the weapon is the target rather than the player.
  public func Forget() -> Void {
    ArrayClear(this.m_applied);
    this.m_target = BYKNoEntity();
  }
}

// Is ability transplanting switched on?
//
// Defaults to on. It was off while the only thing it could do was three weapons, and while a
// package's contents were believed to be unreadable. Both of those changed: the resolver reaches
// every iconic that has an ability, and a package's stats and effectors can be listed with
// pkg.Stats() and pkg.Effectors(), which the F9 dump prints. Transplanting the real ability is
// the point of the mod, so it is on unless a player turns it off.
public func BYKPackagesEnabled() -> Bool {
  let settings = BYKSettings();
  if !IsDefined(settings) {
    // Without Mod Settings there is no menu to turn it off in, so the default applies.
    return true;
  }
  return settings.transplantAbilities;
}

// Should stats be read out of the game rather than taken from the built-in table?
//
// Defaults to on, for the same reason. The built-in table is a transcription of a documentation
// file dated April 2024 for blades, and an approximation for blunts; the game is the game.
public func BYKUseGameStats() -> Bool {
  let settings = BYKSettings();
  if !IsDefined(settings) {
    return true;
  }
  return settings.useGameStats;
}
