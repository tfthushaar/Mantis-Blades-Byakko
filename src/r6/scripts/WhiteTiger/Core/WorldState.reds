// White Tiger - Runtime world-state gate (crash safety)
//
// White Tiger reads the player's equipped weapon and writes stat modifiers onto that
// weapon's entity. While the engine is streaming the world in or out - a load, a fast
// travel, a time skip, a ripperdoc install, a scene - the player and their equipment are
// half-built or being torn down, and touching them then dereferences a not-ready or freed
// native object and crashes the game (it shows up as a dynamicBuffer assert, or as an
// access violation in DelaySystem/Tick).
//
// Every call here is confirmed to resolve against the installed game by compiling a probe
// with the game's own scc.exe.

public func WTWorldStable(game: GameInstance) -> Bool {
  // No controllable player means a load / teleport / fast travel is in flight.
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return false;
  }
  // Paused - pause menu, photo mode.
  let ts = GameInstance.GetTimeSystem(game);
  if IsDefined(ts) && ts.IsPausedState() {
    return false;
  }
  // The blackboard system itself is gone mid-transition, and dereferencing it then is the
  // very thing this gate exists to prevent. No blackboards means "not stable".
  let bbs = GameInstance.GetBlackboardSystem(game);
  if !IsDefined(bbs) {
    return false;
  }
  // A blocking menu or loading screen is up - the Skip Time menu, the fast-travel load
  // screen, the inventory. Both pause gameplay and overlap the streaming flood.
  let ui = bbs.Get(GetAllBlackboardDefs().UI_System);
  if IsDefined(ui) && ui.GetBool(GetAllBlackboardDefs().UI_System.IsInMenu) {
    return false;
  }
  // The player is in a workspot or scripted scene - most importantly the ripperdoc chair,
  // which is where Mantis Blades get installed and swapped in the first place.
  let ws = GameInstance.GetWorkspotSystem(game);
  if IsDefined(ws) && ws.IsActorInWorkspot(player) {
    return false;
  }
  // A staged / cinematic scene: a holocall, a conversation, a cutscene. Only Default and
  // full-gameplay (SceneTier1) count as safe.
  let psm = bbs.Get(GetAllBlackboardDefs().PlayerStateMachine);
  if IsDefined(psm) {
    let tier = psm.GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier);
    if tier != EnumInt(gamePSMHighLevel.Default) && tier != EnumInt(gamePSMHighLevel.SceneTier1) {
      return false;
    }
  }
  return true;
}

// Is this weapon object safe to read stats off, or write stat modifiers onto?
//
// A weapon that is not attached is either streaming in (its stat object may not exist yet)
// or being torn down (it is about to be freed). Writing a modifier onto either is how a
// stat write turns into a crash, and it is also pointless - a detached weapon is not the
// one being swung.
public func WTWeaponSafe(weapon: wref<WeaponObject>) -> Bool {
  if !IsDefined(weapon) {
    return false;
  }
  return weapon.IsAttached();
}
