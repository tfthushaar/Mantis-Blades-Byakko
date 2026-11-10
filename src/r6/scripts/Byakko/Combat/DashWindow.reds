// Byakko - Sihil's dash window
//
// Sihil gives unlimited combo attacks for a short time after dashing. Mechanically that is what
// the Byakko already does on a kill: a timed window carrying `CanWeaponInfinitlyCombo`. Only the
// trigger differs, so this is the same machinery with a different way in.
//
// Applies to both cyberarms, but it is worth knowing what it does on each.
//
// Mantis Blades do not have an infinite combo, so the window is a real change there. Gorilla
// Arms already ship with CanWeaponInfinitlyCombo = 1 and CanWeaponDash = 1 in their own record,
// read straight out of the game, so the combo flag is redundant on them and only the optional
// attack speed does anything. That is not a bug, and the readout says which case applies rather
// than leaving a player to wonder why the same setting feels different on the two arms.
//
// ---------------------------------------------------------------------------
// Catching the dash
//
// There is no "just dashed" flag reachable from script, and no `Dash` locomotion state either.
// Since 2.0 the Dash perk turns V's dodge into a dash, so a dash *is* a dodge to the state
// machine, and `PlayerStateMachine.Locomotion` reading `Dodge` or `DodgeAir` is the trigger.
//
// It is read through a blackboard listener rather than polled. A dodge is shorter than any tick
// interval worth running, so polling would miss dashes at random, which is worse than not
// having the feature. The listener also costs nothing between dashes. Registration lives on the
// system; this file only reacts.
//
// ---------------------------------------------------------------------------
// Composing with the kill burst
//
// Both windows can be live at once and both want the same stats. For the combo flag that is
// harmless, since two Additive 1.0 modifiers still read as a set flag. For attack speed it is
// not: two multipliers compose, and that is exactly how the arm-alternation animation bug
// happened. So the speed part is clamped against the *current* value, which already includes
// whatever the burst is contributing, and it defaults to applying no speed at all. The combo
// flag is the effect; speed is an opt-in extra.

public class BYKDashWindow {
  private let m_active: Bool;
  private let m_deadline: Float;      // sim-time seconds
  private let m_dashes: Int32;        // dashes chained inside the current window
  private let m_mods: ref<BYKModSet>;

  public func IsActive() -> Bool {
    return this.m_active;
  }

  public func GetDashes() -> Int32 {
    return this.m_dashes;
  }

  public func GetRemaining(game: GameInstance) -> Float {
    if !this.m_active {
      return 0.0;
    }
    return MaxF(0.0, this.m_deadline - BYKNow(game));
  }

  private func Mods() -> ref<BYKModSet> {
    if !IsDefined(this.m_mods) {
      this.m_mods = new BYKModSet();
    }
    return this.m_mods;
  }

  // Open the window, or push a live one's deadline out.
  //
  // The caller has already established that the world is stable and that this weapon is an
  // attached cyberarm.
  // The profile argument is the active arm's profile, or null.
  //
  // When that profile declares a dash window, its numbers win: Sihil's combo belongs to Sihil,
  // not to every profile. When it does not, the global settings apply, which is what every
  // install had before profiles existed and keeps those installs unchanged.
  public func Arm(game: GameInstance, weapon: wref<WeaponObject>, profile: ref<BYKProfile>) -> Void {
    let settings = BYKSettings();
    let seconds = BYKConfig.DashWindowSecondsDefault();
    let speedMult = BYKConfig.DashWindowSpeedDefault();
    if IsDefined(settings) {
      seconds = ClampF(settings.dashWindowSeconds, 0.5, BYKConfig.MaxBurstSeconds());
      speedMult = ClampF(settings.dashWindowSpeed, 1.0, BYKConfig.MaxBurstMult());
    }
    let useProfile = BYKProfileHasDashWindow(profile);
    if useProfile {
      seconds = ClampF(profile.dashWindowSeconds, 0.5, BYKConfig.MaxBurstSeconds());
    }

    let entity = weapon.GetEntityID();

    // A live window on this same weapon is refreshed, never re-applied. Adding a second set of
    // modifiers here is how this kind of feature ends up permanently stacked.
    if this.m_active && this.Mods().IsOn(entity) {
      this.m_deadline = BYKNow(game) + seconds;
      this.m_dashes += 1;
      BYKLog.Verbose(n"Dash", s"Refreshed: \(seconds)s, chain \(this.m_dashes).");
      return;
    }

    // Anything already applied goes first, including to a weapon that has since been put away.
    this.Clear(game);

    let stats = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return;
    }
    let sid = Cast<StatsObjectID>(entity);

    // The effect itself. A profile's own window replaces this rather than adding to it.
    if useProfile {
      for m in profile.dashWindowMods {
        if IsDefined(m) {
          this.Mods().AddClamped(game, entity, m.stat, m.kind, m.value);
        }
      }
    } else {
      this.Mods().Add(game, entity, gamedataStatType.CanWeaponInfinitlyCombo,
                      gameStatModifierType.Additive, 1.0);
    }

    // Opt-in speed on top, held under the animation ceiling against the current value so it
    // composes safely with a kill burst that may already be running. Skipped when a profile
    // supplied its own modifiers, which already carry whatever speed that iconic has.
    if !useProfile && speedMult > 1.001 {
      let current = stats.GetStatValue(sid, gamedataStatType.AttackSpeed);
      let applied = BYKClampMultToCeiling(current, speedMult);
      if applied > 1.001 {
        this.Mods().Add(game, entity, gamedataStatType.AttackSpeed,
                        gameStatModifierType.Multiplier, applied);
      } else {
        BYKLog.Verbose(n"Dash", s"No speed headroom at \(current); combo flag only.");
      }
    }

    if this.Mods().IsEmpty() {
      BYKLog.Warn(n"Dash", "Nothing applied; not arming.");
      return;
    }

    this.m_active = true;
    this.m_deadline = BYKNow(game) + seconds;
    this.m_dashes = 1;
    BYKLog.Info(n"Dash", s"Armed for \(seconds)s (\(this.Mods().Count()) modifier(s)).");
  }

  // Only safe while the world is stable. Across a session boundary use Forget.
  public func Clear(game: GameInstance) -> Void {
    if IsDefined(this.m_mods) {
      this.m_mods.Clear(game);
    }
    this.m_active = false;
    this.m_dashes = 0;
    this.m_deadline = 0.0;
  }

  // Drop handles with no native calls, for loads, respawns and teardown.
  public func Forget() -> Void {
    if IsDefined(this.m_mods) {
      this.m_mods.Forget();
    }
    this.m_active = false;
    this.m_dashes = 0;
    this.m_deadline = 0.0;
  }

  // One step of the expiry clock. Returns whether the window is still live.
  public func Tick(game: GameInstance) -> Bool {
    if !this.m_active {
      return false;
    }
    // Mid-transition: hold the window open and try again rather than reach into a streaming
    // world to take modifiers off. Sim time does not advance then either, so nothing drains.
    if !BYKWorldStable(game) {
      return true;
    }
    if !BYKEntityAlive(game, this.Mods().Entity()) {
      BYKLog.Verbose(n"Dash", "Target weapon gone; clearing.");
      this.Clear(game);
      return false;
    }
    if BYKNow(game) >= this.m_deadline {
      BYKLog.Info(n"Dash", s"Expired after \(this.m_dashes) dash(es).");
      this.Clear(game);
      return false;
    }
    return true;
  }
}

// Is this locomotion state a dash?
//
// Dodge and DodgeAir, because there is no Dash state: the Dash perk turns the dodge into a
// dash. A player without that perk gets the window on a plain dodge, which is a reasonable
// reading of the same effect and avoids gating the feature behind a perk the mod cannot see.
public func BYKLocomotionIsDash(state: Int32) -> Bool {
  return state == EnumInt(gamePSMLocomotionStates.Dodge)
      || state == EnumInt(gamePSMLocomotionStates.DodgeAir);
}
