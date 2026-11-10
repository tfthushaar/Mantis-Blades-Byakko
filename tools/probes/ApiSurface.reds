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
