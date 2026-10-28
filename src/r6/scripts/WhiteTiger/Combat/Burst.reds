// White Tiger - The Byakko loop
//
// Kill someone with the blades and you get a short window where they move like Byakko does:
// faster, and with the pause between light combo attacks gone. Kill again inside the window
// and it starts over. That loop is the whole point of the mod - the baseline stats are just
// what makes the loop worth chasing.
//
// All of the state here is session-only. Nothing in this file is persistent, nothing is
// written into the save, and every modifier it creates is tracked by the handle used to
// remove it again. Uninstalling the mod leaves a save exactly as it was.
//
// ---------------------------------------------------------------------------
// Why a status effect will not do the job
//
// A timed status effect would handle its own expiry and would be less code. It cannot be
// used here. A status effect applies to the player, and the melee hit executor reads attack
// speed off the weapon entity, so the modifier has to go on the blades. That leaves the
// window to be timed by hand, which is what the rest of this file does.
//
// ---------------------------------------------------------------------------
// The rules that keep it from leaking
//
// A stat modifier that is added and never removed is permanent, invisible, and stacks once
// per kill. A player who hits that ends up pinned at the engine's speed ceiling with no idea
// why, and no way back short of a new save. Four rules prevent it:
//
//   1. One modifier at a time, per stat, tracked by handle. Refreshing a live window pushes
//      its deadline out; it never adds a second modifier.
//   2. Arming always clears first. If anything is already applied - to this weapon or to one
//      that has since gone away - it is removed before anything new is added.
//   3. Expiry is driven by a tick that only exists while a window is live, and that tick
//      carries a generation token so a chain left over from a previous session dies instead
//      of ticking against the new one.
//   4. Nothing is written to, or removed from, an entity that is not currently attached. The
//      modifiers on a weapon entity die with that entity, so a weapon that has gone away
//      needs its handles dropped, not removed.

public class WTBurstState {
  private let m_active: Bool;
  private let m_deadline: Float;          // sim-time seconds
  private let m_targetEntity: EntityID;   // the weapon the modifiers are on
  private let m_speedMod: ref<gameStatModifierData>;
  private let m_comboMod: ref<gameStatModifierData>;
  private let m_playerMod: ref<gameStatModifierData>;
  private let m_playerEntity: EntityID;
  private let m_kills: Int32;             // kills chained inside the current window

  public func IsActive() -> Bool {
    return this.m_active;
  }

  public func GetKills() -> Int32 {
    return this.m_kills;
  }

  public func GetRemaining(game: GameInstance) -> Float {
    if !this.m_active {
      return 0.0;
    }
    return MaxF(0.0, this.m_deadline - WTNow(game));
  }

  // Start a window, or push a live one's deadline out.
  //
  // Called once per Mantis Blade kill. The weapon has already been checked as attached and
  // as actually being Mantis Blades by the caller.
  public func Arm(game: GameInstance, weapon: wref<WeaponObject>) -> Void {
    let settings = WTSettings();
    let seconds = WTConfig.BurstSecondsDefault();
    let mult = WTConfig.BurstMultDefault();
    let killCombo = true;
    let buffPlayer = true;
    if IsDefined(settings) {
      // Both clamped rather than trusted. The sliders are bounded, but the values come back
      // through a settings file on disk that can be hand-edited, and a negative duration
      // would arm a window whose deadline is already in the past.
      seconds = ClampF(settings.burstSeconds, 0.5, WTConfig.MaxBurstSeconds());
      mult = ClampF(settings.burstMult, 1.0, WTConfig.MaxBurstMult());
      killCombo = settings.burstRemovesComboPause;
      buffPlayer = settings.burstAlsoBuffsPlayer;
    }

    let entity = weapon.GetEntityID();

    // Rule 1: a live window on this same weapon is refreshed, never re-applied. Adding a
    // second modifier here is exactly how this kind of mod ends up permanently stacked.
    if this.m_active && EntityID.IsDefined(entity) && Equals(this.m_targetEntity, entity) {
      this.m_deadline = WTNow(game) + seconds;
      this.m_kills += 1;
      WTLog.Verbose(n"Burst", s"Refreshed: \(seconds)s, chain \(this.m_kills).");
      return;
    }

    // Rule 2: anything already applied goes first - including to a weapon that has since
    // been unequipped, which is the case this branch exists for.
    this.Clear(game);

    let stats = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return;
    }
    let sid = WTWeaponStatsId(weapon);

    // The speed itself. Multiplier, so it scales whatever the blades are already at rather
    // than overwriting the player's own build.
    let speed = RPGManager.CreateStatModifier(gamedataStatType.AttackSpeed, gameStatModifierType.Multiplier, mult);
    if IsDefined(speed) {
      stats.AddModifier(sid, speed);
      this.m_speedMod = speed;
    }

    // The part that is actually felt. Byakko's iconic removes the pause between light combo
    // attacks, and the game has a flag for precisely that. This matters more than the raw
    // multiplier: arm cyberware has a long-standing vanilla bug where it does not scale with
    // attack speed at all, and if that bug is live on this patch then the flag is the only
    // half of the burst a player will notice. It is deliberately not folded into the data
    // layer, because Byakko only removes the pause while the window is open.
    if killCombo {
      let combo = RPGManager.CreateStatModifier(gamedataStatType.CanWeaponInfinitlyCombo, gameStatModifierType.Additive, 1.0);
      if IsDefined(combo) {
        stats.AddModifier(sid, combo);
        this.m_comboMod = combo;
      }
    }

    // Mirror the speed onto V as well. Which stats object the melee state machine reads for
    // arm cyberware is uncertain and varies by patch, and covering both costs one extra
    // modifier that comes off on the same tick as the other two. This only ever runs while V
    // is holding the blades.
    if buffPlayer {
      let player = GetPlayer(game);
      if IsDefined(player) {
        let pMod = RPGManager.CreateStatModifier(gamedataStatType.AttackSpeed, gameStatModifierType.Multiplier, mult);
        if IsDefined(pMod) {
          let pid = Cast<StatsObjectID>(player.GetEntityID());
          stats.AddModifier(pid, pMod);
          this.m_playerMod = pMod;
          this.m_playerEntity = player.GetEntityID();
        }
      }
    }

    this.m_active = true;
    this.m_targetEntity = entity;
    this.m_deadline = WTNow(game) + seconds;
    this.m_kills = 1;
    WTLog.Info(n"Burst", s"Armed: x\(mult) for \(seconds)s.");
  }

  // Take everything back off. Safe to call at any time, including when nothing is applied,
  // and including when the weapon it was applied to no longer exists.
  public func Clear(game: GameInstance) -> Void {
    let stats = GameInstance.GetStatsSystem(game);
    if IsDefined(stats) {
      // Rule 4: only remove from an entity that is still there. A weapon entity takes its
      // stat modifiers with it when it goes, so for a weapon that has gone the right move is
      // to drop the handle - calling into the stats system for a freed entity is the write
      // this whole design is built to avoid.
      if this.TargetAlive(game) {
        let sid = Cast<StatsObjectID>(this.m_targetEntity);
        if IsDefined(this.m_speedMod) {
          stats.RemoveModifier(sid, this.m_speedMod);
        }
        if IsDefined(this.m_comboMod) {
          stats.RemoveModifier(sid, this.m_comboMod);
        }
      }
      if IsDefined(this.m_playerMod) && EntityID.IsDefined(this.m_playerEntity) {
        let player = GetPlayer(game);
        // Only if it is still the same player entity. After a load it is not, and that
        // modifier died with the old one.
        if IsDefined(player) && Equals(player.GetEntityID(), this.m_playerEntity) {
          stats.RemoveModifier(Cast<StatsObjectID>(this.m_playerEntity), this.m_playerMod);
        }
      }
    }
    // Drop every handle whether or not the removals above could run, so a stale handle can
    // never be removed twice or outlive the state it belongs to.
    this.m_speedMod = null;
    this.m_comboMod = null;
    this.m_playerMod = null;
    this.m_playerEntity = WTNoEntity();
    this.m_targetEntity = WTNoEntity();
    this.m_active = false;
    this.m_kills = 0;
  }

  // Is the weapon the modifiers were applied to still a live, attached entity?
  private func TargetAlive(game: GameInstance) -> Bool {
    if !EntityID.IsDefined(this.m_targetEntity) {
      return false;
    }
    let ent = GameInstance.FindEntityByID(game, this.m_targetEntity);
    if !IsDefined(ent) {
      return false;
    }
    let obj = ent as GameObject;
    if !IsDefined(obj) {
      return false;
    }
    return obj.IsAttached();
  }

  // One step of the expiry clock. Returns whether the window is still live, which is what
  // the caller uses to decide whether to schedule another tick.
  public func Tick(game: GameInstance) -> Bool {
    if !this.m_active {
      return false;
    }
    // Mid-transition: hold the window open and try again next tick rather than reach into a
    // streaming world to take the modifier off. The window does not tick down either, since
    // sim time does not advance while the game is not running.
    if !WTWorldStable(game) {
      return true;
    }
    // The blades are gone - holstered, swapped, or the save was reloaded. End the window.
    if !this.TargetAlive(game) {
      WTLog.Verbose(n"Burst", "Target weapon gone; clearing.");
      this.Clear(game);
      return false;
    }
    if WTNow(game) >= this.m_deadline {
      WTLog.Info(n"Burst", s"Expired after \(this.m_kills) kill(s).");
      this.Clear(game);
      return false;
    }
    return true;
  }
}

// Sim time in seconds. Sim time does not advance while the game is paused or in a menu, so
// a window does not quietly drain away while the player is in their inventory.
public func WTNow(game: GameInstance) -> Float {
  return EngineTime.ToFloat(GameInstance.GetSimTime(game));
}
