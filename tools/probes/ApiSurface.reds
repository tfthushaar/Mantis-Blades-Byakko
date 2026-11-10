// Byakko - API surface probe
//
// Not shipped. This compiles but is never loaded by the game; it exists so the native calls
// the mod depends on can be re-checked against a new game patch in seconds:
//
//   ./tools/validate.ps1 -GameDir "..." -ExtraDir ./tools/probes -OnlyExtra
//
// A patch that removes or renames any of these would otherwise fail the whole redscript
// compile on a player's machine and take every script mod down with it, so this is the cheap
// early warning. Every call below is confirmed present on 2.5.
//
// Keep one concern per function. scc reports unresolved symbols per site, so a single compile
// says exactly which calls died rather than just that something did.

module BYKP

// 1. Camo active, as a stat on the player
public func F01(game: GameInstance, player: ref<GameObject>) -> Bool {
  let sid = Cast<StatsObjectID>(player.GetEntityID());
  return GameInstance.GetStatsSystem(game).GetStatValue(sid, gamedataStatType.OpticalCamoIsActive) > 0.0;
}

// 2. Sandevistan active
public func F02(player: ref<GameObject>) -> Bool {
  return StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.SandevistanBuff");
}

// 3. Dodge / dash locomotion state, polled
public func F03(game: GameInstance) -> Bool {
  let bbs = GameInstance.GetBlackboardSystem(game);
  if !IsDefined(bbs) { return false; }
  let psm = bbs.Get(GetAllBlackboardDefs().PlayerStateMachine);
  if !IsDefined(psm) { return false; }
  let loco = psm.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion);
  return loco == EnumInt(gamePSMLocomotionStates.Dodge)
      || loco == EnumInt(gamePSMLocomotionStates.DodgeAir);
}

// 4. Event-driven: a blackboard listener on the locomotion int, so a short dodge is never missed
public class F04Listener extends ScriptableSystem {
  private let m_id: ref<CallbackHandle>;
  public func Hook(game: GameInstance) -> Void {
    let psm = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().PlayerStateMachine);
    if IsDefined(psm) {
      this.m_id = psm.RegisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion, this, n"OnLoco");
    }
  }
  public func Unhook(game: GameInstance) -> Void {
    let psm = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().PlayerStateMachine);
    if IsDefined(psm) && IsDefined(this.m_id) {
      psm.UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion, this.m_id);
    }
  }
  protected cb func OnLoco(value: Int32) -> Bool {
    return false;
  }
}

// 5. Gorilla Arms identification, same route as the blades
public func F05(player: ref<GameObject>) -> Bool {
  let w = GameObject.GetActiveWeapon(player);
  if !IsDefined(w) { return false; }
  return Equals(RPGManager.GetItemType(w.GetItemID()), gamedataItemType.Cyb_StrongArms);
}

// 6. The combo flag the dash window applies, and the gorilla knobs
public func F06(game: GameInstance, sid: StatsObjectID) -> Float {
  let s = GameInstance.GetStatsSystem(game);
  return s.GetStatValue(sid, gamedataStatType.CanWeaponInfinitlyCombo)
       + s.GetStatValue(sid, gamedataStatType.StrongArmsStaminaCostReduction)
       + s.GetStatValue(sid, gamedataStatType.EffectiveChargeTime);
}

// ---------------------------------------------------------------------------
// Condition surface, added for the iconic transplant work.
//
// Confirmed present. The three routes to Optical Camo are kept separate so a patch that breaks
// one is reported as breaking that one, not as "camo detection is gone".
// ---------------------------------------------------------------------------

public func G01(game: GameInstance, sid: StatsObjectID) -> Float {
  return GameInstance.GetStatsSystem(game).GetStatValue(sid, gamedataStatType.OpticalCamoIsActive);
}

public func G02(player: ref<PlayerPuppet>) -> Bool {
  return player.IsInvisible();
}

public func G03(player: ref<GameObject>) -> Bool {
  return StatusEffectSystem.ObjectHasStatusEffect(player, t"BaseStatusEffect.Cloaked");
}

public func G04(game: GameInstance, sid: StatsObjectID) -> Float {
  return GameInstance.GetStatPoolsSystem(game).GetStatPoolValue(sid, gamedataStatPoolType.OpticalCamoCharges, false);
}

public func G05(player: ref<GameObject>) -> Bool {
  return StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"Sandevistan");
}

// Crit stats, which every conditional iconic effect needs.
public func G06(game: GameInstance, sid: StatsObjectID) -> Float {
  let s = GameInstance.GetStatsSystem(game);
  return s.GetStatValue(sid, gamedataStatType.CritChance) + s.GetStatValue(sid, gamedataStatType.CritDamage);
}

// ---------------------------------------------------------------------------
// The iconic ability layer.
//
// This is where an iconic's actual behaviour lives, as opposed to its weapon class's stats.
// An item record's OnAttach carries gameplay logic packages; each package carries stat
// modifiers and effectors, and a whole package can be applied to another object, which is how
// a real iconic ability reaches a cyberarm instead of being reimplemented by hand.
//
// Signatures confirmed by probe, and they are not obvious:
//   ApplyPackage  takes THREE arguments, target and instigator both wref<GameObject>
//   RemovePackage takes TWO, a wref<GameObject> and the id
//
// Probed and absent, so nothing may depend on them: GameplayLogicPackage_Record.Abilities and
// .StatusEffects and .StatGroups; RPGManager.ApplyGameplayLogicPackage;
// GameInstance.GetPlayerDevelopmentSystem; GameObject.AddAbility; StatsSystem.AddAbility;
// WeaponItem_Record.Attachments and .DefaultItems; Item_Record.IsIconic and .Abilities.
// ---------------------------------------------------------------------------

public func H01(r: ref<Item_Record>) -> Int32 {
  let pkgs: array<wref<GameplayLogicPackage_Record>>;
  r.OnAttach(pkgs);
  return ArraySize(pkgs);
}

public func H02(p: ref<GameplayLogicPackage_Record>) -> Int32 {
  let mods: array<wref<StatModifier_Record>>;
  p.Stats(mods);
  return ArraySize(mods);
}

public func H03(p: ref<GameplayLogicPackage_Record>) -> Int32 {
  let effs: array<wref<Effector_Record>>;
  p.Effectors(effs);
  return ArraySize(effs);
}

public func H04(e: ref<Effector_Record>) -> CName {
  return e.EffectorClassName();
}

public func H05(game: GameInstance, target: ref<GameObject>, instigator: ref<GameObject>, pkg: TweakDBID) -> Void {
  GameInstance.GetGameplayLogicPackageSystem(game).ApplyPackage(target, instigator, pkg);
}

public func H06(game: GameInstance, target: ref<GameObject>, pkg: TweakDBID) -> Void {
  GameInstance.GetGameplayLogicPackageSystem(game).RemovePackage(target, pkg);
}
