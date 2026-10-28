// White Tiger - Resting attack speed
//
// The on-kill burst is the point of the mod, but a burst off a slow baseline still feels
// slow between kills. Byakko sits at 2.1 attacks per second; stock Mantis Blades do not.
// This file closes that gap while the blades are equipped.
//
// ---------------------------------------------------------------------------
// Why this is script and not a line of YAML
//
// Two reasons. It sets a target value rather than adding a fixed bonus, so the current
// value has to be read before the difference can be applied, and TweakXL cannot read
// anything. It also wants to be tunable from the settings menu without a restart, and a
// data edit is baked in at load time.
//
// ---------------------------------------------------------------------------
// The compounding trap
//
// Reading the stat to work out the gap would read a value that already includes the last
// modifier this file applied. Add the difference again and the stat climbs every time it is
// evaluated, which is the same permanent-stacking failure the burst is built to avoid, just
// slower. So the order is always: remove ours, read, apply the new difference. Never read
// first.

public class WTBaselineState {
  private let m_targetEntity: EntityID;
  private let m_mod: ref<gameStatModifierData>;
  private let m_appliedTarget: Float;   // the target that produced m_mod

  // Bring the equipped blades up to the configured resting attack speed.
  //
  // Safe to call repeatedly - that is how it tracks a perk, a level or a cyberware change
  // that moves the underlying number. Callers must not call it while a burst is live; see
  // the note in Evaluate.
  public func Apply(game: GameInstance, weapon: wref<WeaponObject>) -> Void {
    let settings = WTSettings();
    let enabled = true;
    let target = WTConfig.RestingAttackSpeedDefault();
    if IsDefined(settings) {
      enabled = settings.restingSpeedEnabled;
      target = ClampF(settings.restingAttackSpeed, 0.0, WTConfig.MaxRestingAttackSpeed());
    }
    if !enabled {
      this.Clear(game);
      return;
    }

    let stats = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return;
    }
    let entity = weapon.GetEntityID();
    let sid = WTWeaponStatsId(weapon);

    // Take our own contribution off before reading, so what comes back is the blades
    // without us. This is the line that stops the value compounding.
    if IsDefined(this.m_mod) {
      if EntityID.IsDefined(this.m_targetEntity) && Equals(this.m_targetEntity, entity) {
        stats.RemoveModifier(sid, this.m_mod);
      }
      this.m_mod = null;
    }

    let base = stats.GetStatValue(sid, gamedataStatType.AttackSpeed);
    let delta = target - base;

    // Only ever speed the blades up. If the player has built past the target - or another
    // mod has - leave their number alone rather than dragging it back down to ours.
    if delta <= 0.001 {
      this.m_targetEntity = entity;
      this.m_appliedTarget = target;
      WTLog.Verbose(n"Data", s"Resting speed already \(base) (target \(target)); nothing applied.");
      return;
    }

    let mod = RPGManager.CreateStatModifier(gamedataStatType.AttackSpeed, gameStatModifierType.Additive, delta);
    if IsDefined(mod) {
      stats.AddModifier(sid, mod);
      this.m_mod = mod;
      this.m_targetEntity = entity;
      this.m_appliedTarget = target;
      WTLog.Info(n"Data", s"Resting speed \(base) -> \(target) (+\(delta)).");
    }
  }

  // Remove our contribution. Follows the same rule as the burst: never touch an entity that
  // is not still there, and always drop the handle either way.
  public func Clear(game: GameInstance) -> Void {
    if IsDefined(this.m_mod) && EntityID.IsDefined(this.m_targetEntity) {
      let stats = GameInstance.GetStatsSystem(game);
      let ent = GameInstance.FindEntityByID(game, this.m_targetEntity);
      let obj = ent as GameObject;
      if IsDefined(stats) && IsDefined(obj) && obj.IsAttached() {
        stats.RemoveModifier(Cast<StatsObjectID>(this.m_targetEntity), this.m_mod);
      }
    }
    this.m_mod = null;
    this.m_targetEntity = WTNoEntity();
    this.m_appliedTarget = 0.0;
  }

  // Does this need re-evaluating? True when the blades changed, when the target moved
  // (the player dragged the slider), or when nothing has been applied yet.
  public func NeedsWork(game: GameInstance, weapon: wref<WeaponObject>) -> Bool {
    let settings = WTSettings();
    if IsDefined(settings) && !settings.restingSpeedEnabled {
      return IsDefined(this.m_mod);
    }
    if !EntityID.IsDefined(this.m_targetEntity) {
      return true;
    }
    if !Equals(this.m_targetEntity, weapon.GetEntityID()) {
      return true;
    }
    let target = WTConfig.RestingAttackSpeedDefault();
    if IsDefined(settings) {
      target = ClampF(settings.restingAttackSpeed, 0.0, WTConfig.MaxRestingAttackSpeed());
    }
    return AbsF(target - this.m_appliedTarget) > 0.001;
  }
}

// Keep the resting baseline current. Called from the system's slow tick.
//
// Skipped entirely while a burst is live: the burst puts a multiplier on the same stat, so
// a read taken now would come back inflated and the computed difference would be wrong. The
// window is seconds long and the next tick after it closes puts this right.
public func WTBaselineEvaluate(game: GameInstance, baseline: ref<WTBaselineState>, burst: ref<WTBurstState>) -> Void {
  if !IsDefined(baseline) {
    return;
  }
  if !WTEnabled() {
    baseline.Clear(game);
    return;
  }
  if IsDefined(burst) && burst.IsActive() {
    return;
  }
  let weapon = WTEquippedMantis(game);
  if !IsDefined(weapon) {
    // Blades not out. Nothing to keep current, and the modifier (if any) went with the
    // weapon entity when it was put away.
    baseline.Clear(game);
    return;
  }
  if baseline.NeedsWork(game, weapon) {
    baseline.Apply(game, weapon);
  }
}
