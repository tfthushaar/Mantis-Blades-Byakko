// Byakko - Runtime world-state gate (crash safety)
//
// Byakko reads the player's equipped weapon and writes stat modifiers onto that weapon's
// entity. While the engine is streaming the world in or out, a load, a fast travel, a time
// skip, a ripperdoc install, a scene, those entities are half-built or being torn down, and
// touching them then dereferences a not-ready or freed native object and crashes the game.
//
// ---------------------------------------------------------------------------
// This gate fails open, on purpose
//
// 1.0.1 and earlier included `UI_System.IsInMenu` here. On at least one real setup that
// blackboard field reads true during ordinary gameplay, so the gate never opened, every tick
// stood down, and the mod did nothing at all while reporting "world is mid-transition". The
// field is also not the signal that was actually wanted: an open inventory is not a streaming
// hazard, a loading screen is, and there is a dedicated field for loading screens.
//
// So each check below is as specific as the thing it guards against, every system it queries
// is null-guarded, and a system that cannot be reached is treated as "not a problem" rather
// than "assume the worst". The hazards that matter are each covered by more than one check, so
// one of them failing open cannot leave the mod writing into a world that is being rebuilt:
// a load with no player is caught by the player check whether or not the loading-screen
// blackboard answers, and a scene is caught by both the workspot and the scene tier.
//
// A gate that wrongly says "unstable" costs the entire mod. A gate that wrongly says "stable"
// for one tick costs a stat read that the per-entity IsAttached checks then refuse anyway.
// Those are not symmetric, and this file is now written for the first one.
//
// Every call here is confirmed to resolve against the installed game by compiling a probe
// with the game's own scc.exe.

// Reason codes. 0 means safe to proceed.
public func BYKStableOk() -> Int32 = 0
public func BYKStableNoPlayer() -> Int32 = 1
public func BYKStableNoBlackboards() -> Int32 = 2
// 3 is unused. It was a loading-screen reason, removed along with the check that produced it.
// Left unassigned rather than reused so the codes stay comparable with older logs.
// 4 is unused. It was the paused reason, removed along with the check that produced it, for
// the reasons set out in BYKWorldStableReason. Left unassigned so the codes stay comparable
// with older logs, the same as 3.
public func BYKStablePhotoMode() -> Int32 = 5
public func BYKStableWorkspot() -> Int32 = 6
public func BYKStableScene() -> Int32 = 7

public func BYKWorldStable(game: GameInstance) -> Bool {
  return BYKWorldStableReason(game) == BYKStableOk();
}

// The gate itself. Returns the first reason it refused, or BYKStableOk.
//
// One function rather than a fast boolean plus a parallel explanation, because two copies of
// this logic would drift and the diagnostic would start lying about why it stood down.
public func BYKWorldStableReason(game: GameInstance) -> Int32 {
  // No controllable player means a load, a teleport or a fast travel is in flight. This is the
  // broadest and most reliable signal there is, and it alone covers the worst cases.
  let player = GetPlayer(game);
  if !IsDefined(player) {
    return BYKStableNoPlayer();
  }

  // The blackboard system itself is gone mid-transition, and dereferencing it then is the very
  // thing this gate exists to prevent.
  let bbs = GameInstance.GetBlackboardSystem(game);
  if !IsDefined(bbs) {
    return BYKStableNoBlackboards();
  }

  // There is no loading-screen check here, and that is deliberate.
  //
  // A GameInstance.GetLoadingScreenBlackboard check was written and then removed. It is not
  // needed: a loading screen has no controllable player, so the check above already covers it,
  // and every native call left out of this gate is one fewer thing that can fail to resolve
  // against a future patch and take the whole redscript compile down with it.

  // There is no pause check here, and that is deliberate. It used to be the second thing this
  // function tested, and it was the same mistake as UI_System.IsInMenu one signal over.
  //
  // Two reasons it had to go.
  //
  // First, it guards against nothing. Read the hazard list at the top of this file: a load, a
  // fast travel, a time skip, a ripperdoc install, a scene. A paused game is the opposite of
  // all of those. Nothing is streaming, no entity is half-built, and every pointer is as
  // settled as it will ever be. The check was added by analogy with "the game is busy" and not
  // because any crash was traced to it.
  //
  // Second, it is far broader than it reads. World time pauses for the inventory, the map, the
  // journal, crafting, the character screen, the cyberware screen, the stash, the phone and the
  // radio. Several mods exist purely to stop menus pausing world time, which is how wide that
  // net is. Any one of those, or any other mod leaving a pause reason registered, made this
  // gate refuse during what the player experiences as ordinary gameplay, and a refusing gate
  // costs the entire mod. That is the S1 failure, reproduced exactly.
  //
  // Nothing is lost by dropping it. Timed windows measure in sim time, which does not advance
  // while paused, so they cannot drain behind a menu whether this gate opens or not. Modifier
  // writes are guarded per entity by IsAttached. The ripperdoc chair, the one place where
  // cyberware genuinely changes under the mod's feet, is caught by the workspot check below.

  // Photo mode, explicitly. It is usually also a paused state, but it moves the camera and
  // re-poses the player, so it is worth refusing on its own signal rather than by implication.
  let pms = GameInstance.GetPhotoModeSystem(game);
  if IsDefined(pms) && pms.IsPhotoModeActive() {
    return BYKStablePhotoMode();
  }

  // The player is in a workspot or scripted scene, most importantly the ripperdoc chair, which
  // is where Mantis Blades get installed and swapped in the first place.
  let ws = GameInstance.GetWorkspotSystem(game);
  if IsDefined(ws) && ws.IsActorInWorkspot(player) {
    return BYKStableWorkspot();
  }

  // A staged or cinematic scene: a holocall, a conversation, a cutscene. Only Default and
  // full-gameplay (SceneTier1) count as safe.
  let psm = bbs.Get(GetAllBlackboardDefs().PlayerStateMachine);
  if IsDefined(psm) {
    let tier = psm.GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier);
    if tier != EnumInt(gamePSMHighLevel.Default) && tier != EnumInt(gamePSMHighLevel.SceneTier1) {
      return BYKStableScene();
    }
  }

  return BYKStableOk();
}

// Reason text, for the diagnostic readout only. Never called from a tick.
public func BYKStableReasonText(reason: Int32) -> String {
  if reason == BYKStableOk() {
    return "stable";
  }
  if reason == BYKStableNoPlayer() {
    return "no controllable player (a load or fast travel is in flight)";
  }
  if reason == BYKStableNoBlackboards() {
    return "blackboard system unavailable";
  }
  if reason == BYKStablePhotoMode() {
    return "photo mode is active";
  }
  if reason == BYKStableWorkspot() {
    return "in a workspot or scene (the ripperdoc chair counts)";
  }
  if reason == BYKStableScene() {
    return "in a cinematic or staged scene";
  }
  return "unknown";
}

// Is this weapon object safe to read stats off, or write stat modifiers onto?
//
// A weapon that is not attached is either streaming in (its stat object may not exist yet) or
// being torn down (it is about to be freed). Writing a modifier onto either is how a stat write
// turns into a crash, and it is also pointless, since a detached weapon is not the one being
// swung.
public func BYKWeaponSafe(weapon: wref<WeaponObject>) -> Bool {
  if !IsDefined(weapon) {
    return false;
  }
  return weapon.IsAttached();
}

// Is world time paused right now?
//
// Reporting only. This is deliberately NOT part of the stability gate: see the long note in
// BYKWorldStableReason for why gating on it cost the mod an entire release. It is here so the
// diagnostic can say what the game reports without that answer being allowed to stop anything.
public func BYKTimePaused(game: GameInstance) -> Bool {
  let ts = GameInstance.GetTimeSystem(game);
  if !IsDefined(ts) {
    return false;
  }
  return ts.IsPausedState();
}
