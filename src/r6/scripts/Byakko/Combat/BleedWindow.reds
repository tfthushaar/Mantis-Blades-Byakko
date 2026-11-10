// Byakko - Butcher's Cleaver's bleed window
//
// The Cleaver attacks faster and costs less stamina while the enemy is bleeding. Until now this
// mod substituted a kill window for that and said so in the profile note, on the grounds that
// "is the target bleeding" was not state it tracked. It is now.
//
// ---------------------------------------------------------------------------
// Where the signal comes from
//
// The hit hook, not a poll. `Combat/KillSignal.reds` already wraps the victim's OnHit to notice
// that V hit something with a cyberarm, so the moment a swing lands on a bleeding enemy is
// already in hand, with the victim already resolved. Asking "is this one bleeding" there costs one
// status-effect query on a hit that has already passed three cheaper checks.
//
// The alternative was reading V's current target and polling it, which is worse twice over: there
// is no reliable current target for melee, and a poll would answer a question about a moment that
// has already gone.
//
// So the condition is really "you are hitting something that is bleeding", refreshed on every
// such hit. For a weapon whose own bleed chance is what makes the target bleed in the first place,
// that is the effect as described rather than an approximation of it.
//
// ---------------------------------------------------------------------------
// Composing with the other two windows
//
// Three windows can now be live at once, and all three want attack speed. The same rule applies
// as for the dash window: speed goes on through `BYKModSet.AddClamped`, which clamps against the
// *current* value and therefore against whatever the other two are already contributing. That is
// the guard that stops this re-opening the arm-alternation animation bug, which is exactly what
// stacking two unclamped multipliers caused in 1.0.1.
//
// Profile-driven only. There is no global setting, because this is one weapon's effect rather than
// a feature of the mod, and a profile that declares no bleed window never arms one.

public class BYKBleedWindow {
  private let m_active: Bool;
  private let m_deadline: Float;      // sim-time seconds
  private let m_hits: Int32;          // hits on a bleeding target inside the current window
  private let m_mods: ref<BYKModSet>;

  public func IsActive() -> Bool {
    return this.m_active;
  }

  public func GetHits() -> Int32 {
    return this.m_hits;
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
  // The caller has established that the world is stable, that this weapon is an attached cyberarm,
  // and that the thing just hit is bleeding.
  public func Arm(game: GameInstance, weapon: wref<WeaponObject>, profile: ref<BYKProfile>) -> Void {
    if !IsDefined(weapon) || !BYKProfileHasBleedWindow(profile) {
      return;
    }
    let seconds = ClampF(profile.bleedWindowSeconds, 0.5, BYKConfig.MaxBurstSeconds());
    let entity = weapon.GetEntityID();

    // A live window on this same weapon is refreshed, never re-applied. Adding a second set of
    // modifiers here is how this kind of feature ends up permanently stacked, and this one refires
    // on every landed hit, so it is the window where that would happen fastest.
    if this.m_active && this.Mods().IsOn(entity) {
      this.m_deadline = BYKNow(game) + seconds;
      this.m_hits += 1;
      return;
    }

    // Anything already applied goes first, including to a weapon that has since been put away.
    this.Clear(game);

    for m in profile.bleedWindowMods {
      if IsDefined(m) {
        this.Mods().AddClamped(game, entity, m.stat, m.kind, m.value);
      }
    }

    if this.Mods().IsEmpty() {
      BYKLog.Warn(n"Bleed", "Nothing applied; not arming.");
      return;
    }

    this.m_active = true;
    this.m_deadline = BYKNow(game) + seconds;
    this.m_hits = 1;
    BYKLog.Info(n"Bleed", s"Armed for \(seconds)s (\(this.Mods().Count()) modifier(s)).");
  }

  // Only safe while the world is stable. Across a session boundary use Forget.
  public func Clear(game: GameInstance) -> Void {
    if IsDefined(this.m_mods) {
      this.m_mods.Clear(game);
    }
    this.m_active = false;
    this.m_hits = 0;
    this.m_deadline = 0.0;
  }

  // Drop handles with no native calls, for loads, respawns and teardown.
  public func Forget() -> Void {
    if IsDefined(this.m_mods) {
      this.m_mods.Forget();
    }
    this.m_active = false;
    this.m_hits = 0;
    this.m_deadline = 0.0;
  }

  // One step of the expiry clock. Returns whether the window is still live.
  public func Tick(game: GameInstance) -> Bool {
    if !this.m_active {
      return false;
    }
    // Mid-transition: hold the window open and try again rather than reach into a streaming world
    // to take modifiers off. Sim time does not advance then either, so nothing drains.
    if !BYKWorldStable(game) {
      return true;
    }
    if !BYKEntityAlive(game, this.Mods().Entity()) {
      BYKLog.Verbose(n"Bleed", "Target weapon gone; clearing.");
      this.Clear(game);
      return false;
    }
    if BYKNow(game) >= this.m_deadline {
      BYKLog.Info(n"Bleed", s"Expired after \(this.m_hits) hit(s).");
      this.Clear(game);
      return false;
    }
    return true;
  }
}
