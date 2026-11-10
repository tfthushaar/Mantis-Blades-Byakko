// Byakko - Transplanting an iconic's real gameplay logic package
//
// This is the one part of the mod that hands a cyberarm an iconic's actual ability rather than
// a reimplementation of it. The game applies these packages itself when you equip the weapon;
// GameplayLogicPackageSystem.ApplyPackage lets the same package be put on something else.
//
// ---------------------------------------------------------------------------
// Which iconics this can do, and why not all of them
//
// Reading every iconic melee record out of the game showed that most of them do NOT carry a
// weapon-specific package. All eight katana iconics attach only `GLP.HoldingMelee`, the generic
// "a melee weapon is in your hands" package, and they are byte-identical to each other in their
// stat modifiers too. Whatever makes Byakko different from Satori is not reachable through any
// accessor redscript exposes: GameplayLogicPackage_Record has no Abilities or StatusEffects
// accessor, and the weapon records have no Attachments or DefaultItems.
//
// Three weapons do carry their own package, so for those the real thing can be transplanted:
//
//   Sihil                 Items.Preset_Sword_Sihil_inline0
//   Gwynbleidd            Items.Preset_Sword_Witcher_inline0
//   Sasquatch's Hammer    GLP.HoldingSasquatchHammer
//
// For the rest, a reimplemented window is the only honest option, and the profile says so.
//
// ---------------------------------------------------------------------------
// Why this is the most carefully guarded thing in the mod
//
// Every other effect here is a stat modifier: it has a handle, it comes off, and the worst case
// is a number being wrong. A package is different. Its contents cannot be inspected from
// script, so what it grants is not fully known, and that means it is the one feature that could
// in principle leave something behind.
//
// So it gets stricter rules than anything else:
//
//   - Only ids from the profile registry are ever passed. Nothing comes from a settings string
//     or from player input.
//   - Applied to the player, tracked by both the package id and the player's entity id, and
//     removed before anything else is applied.
//   - Removed on unequip, on profile change, on expiry of nothing (there is no timer: it is
//     tied to having the arm out), at session start and on detach.
//   - It has its own setting, default off, because a player should be able to run the rest of
//     the mod without the one part that touches something it cannot read.
//   - If the package system is unavailable it does nothing rather than retrying.

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

  // Apply one package to the player, remembering it so it can come back off.
  public func Add(game: GameInstance, target: ref<GameObject>, id: TweakDBID) -> Bool {
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
    // The player is both target and instigator here: the arm is V's, and the effect is V's.
    sys.ApplyPackage(target, target, id);
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
  // Unlike a stat modifier, a package applied to a player who then stops existing is not
  // obviously harmless, so this is used only where the player really is gone: a load, a
  // respawn, a teardown. In those cases the package went with the old player object.
  public func Forget() -> Void {
    ArrayClear(this.m_applied);
    this.m_target = BYKNoEntity();
  }
}

// Is package transplanting switched on?
//
// Default off. This is the one feature whose contents the mod cannot inspect, so it is opt-in
// rather than something a player discovers by accident.
public func BYKPackagesEnabled() -> Bool {
  let settings = BYKSettings();
  if !IsDefined(settings) {
    return false;
  }
  return settings.transplantAbilities;
}
