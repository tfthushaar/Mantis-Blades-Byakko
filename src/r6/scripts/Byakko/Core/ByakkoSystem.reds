// Byakko - The system
//
// Owns the burst window, the resting baseline and the two ticks that drive them. A
// ScriptableSystem, so it is created with the session and torn down with it.
//
// There are no persistent fields in this class. Byakko has nothing worth saving:
// everything it does is a stat modifier on a weapon entity that only exists while the blades
// are out. Nothing it writes survives a reload, so deleting the mod cannot leave a save in a
// state the base game does not understand, and there is no schema to migrate on update.

public class ByakkoSystem extends ScriptableSystem {
  private let m_burst: ref<BYKBurstState>;
  private let m_baseline: ref<BYKBaselineState>;

  private let m_playerAttachCbId: Uint32;
  private let m_sessionStarted: Bool;
  private let m_callbacksRegistered: Bool;

  // Two independent tick chains, each with its own generation token.
  //
  // The token is what stops a chain left over from a previous session ticking against the
  // new one. On a load the old callbacks are still queued in the delay system and will fire;
  // bumping the generation at session start means they see a number that is no longer
  // current and return without doing anything, instead of stacking a second live chain on
  // top of the new one.
  private let m_generation: Int32;
  private let m_burstTickLive: Bool;    // a burst-expiry chain is already running
  private let m_slowTickLive: Bool;     // the baseline chain is already running
  private let m_settleTicks: Int32;     // stand-down counter after the world goes unstable
  private let m_diagKeyDown: Bool;     // diagnostic key debounce: some setups deliver only one of press/release

  public static func Get(game: GameInstance) -> ref<ByakkoSystem> {
    // The systems container is null during world transitions; never dereference it then.
    let container = GameInstance.GetScriptableSystemsContainer(game);
    if !IsDefined(container) {
      return null;
    }
    return container.Get(n"ByakkoSystem") as ByakkoSystem;
  }

  // ---- Lifecycle --------------------------------------------------------

  private func OnAttach() -> Void {
    BYKLog.Info(n"Core", s"Byakko \(ByakkoVersion()) attaching.");
    this.EnsureSettings();
    this.m_burst = new BYKBurstState();
    this.m_baseline = new BYKBaselineState();
    this.RegisterPlayerAttach();
    // Register the diagnostic key and start a tick here as well as at session start. If the
    // player-attached callback is ever missed, this chain is the one that keeps retrying the
    // registration, so the key cannot end up silently unregistered. Session start bumps the
    // generation, which retires this chain in favour of its own.
    this.EnsureCallbacks();
    this.ScheduleSlowTick();
  }

  // The player-puppet-attached callback is the reliable "session is ready" signal. It fires
  // on new game, on load and on respawn, which is exactly when the old state has to go.
  private func RegisterPlayerAttach() -> Void {
    let ps = GameInstance.GetPlayerSystem(this.GetGameInstance());
    if IsDefined(ps) {
      this.m_playerAttachCbId = ps.RegisterPlayerPuppetAttachedCallback(this, n"OnWTPlayerAttached");
    }
  }

  private func OnWTPlayerAttached(player: ref<GameObject>) -> Void {
    this.StartSession();
  }

  private func StartSession() -> Void {
    // Retire every tick chain from before this point, then start one fresh.
    this.m_generation += 1;
    this.m_burstTickLive = false;
    this.m_slowTickLive = false;
    this.m_settleTicks = BYKConfig.SettleTicks();

    // Drop any window that was open before the load. The weapon it was applied to no longer
    // exists, so there is nothing to remove - but the handles have to go, or the next Clear
    // would try to remove a modifier from an entity that has been freed.
    if IsDefined(this.m_burst) {
      this.m_burst.Clear(this.GetGameInstance());
    }
    if IsDefined(this.m_baseline) {
      this.m_baseline.Clear(this.GetGameInstance());
    }

    this.EnsureSettings();
    this.EnsureCallbacks();
    this.m_sessionStarted = true;
    this.ScheduleSlowTick();
    BYKLog.Info(n"Core", "Session started.");
  }

  private func EnsureSettings() -> Void {
    let rt = ByakkoRuntime.Get();
    if IsDefined(rt) && !rt.HasSettings() {
      let settings = new ByakkoSettings();
      settings.Register();
      rt.SetSettings(settings);
      BYKLog.Verbose(n"Core", "Settings registered with Mod Settings.");
    }
  }

  // The diagnostic hotkey. Guarded and idempotent, and retried from the slow tick, so a
  // callback system that was not up yet at session start cannot leave the key silently
  // unregistered - which looks exactly like the key doing nothing.
  private func EnsureCallbacks() -> Void {
    if this.m_callbacksRegistered {
      return;
    }
    let cbs = GameInstance.GetCallbackSystem();
    if !IsDefined(cbs) {
      return;
    }
    cbs.RegisterCallback(n"Input/Key", this, n"OnWTKeyInput");
    this.m_callbacksRegistered = true;
  }

  private func OnDetach() -> Void {
    // Retire the tick chains so nothing fires against a system that is going away.
    this.m_generation += 1;
    this.m_burstTickLive = false;
    this.m_slowTickLive = false;
    BYKLog.Verbose(n"Core", "Detaching.");
  }

  // ---- Kills ------------------------------------------------------------

  // A Mantis Blade kill landed. Called from the victim's death hook.
  public func OnMantisKill() -> Void {
    if !IsDefined(this.m_burst) {
      return;
    }
    let game = this.GetGameInstance();

    // The death hook fires from inside the engine tearing the victim down. Reading the
    // player's equipment is safe there, but only once the world itself is settled - during a
    // load or a scene it is not, and a kill can land on the frame a scene starts.
    if !BYKWorldStable(game) {
      return;
    }
    let weapon = BYKEquippedMantis(game);
    if !IsDefined(weapon) {
      // The blades went away between the killing blow and the death. Nothing to buff.
      return;
    }
    let settings = BYKSettings();
    if IsDefined(settings) && !settings.burstEnabled {
      return;
    }
    this.m_burst.Arm(game, weapon);
    this.ScheduleBurstTick();

    if IsDefined(settings) && settings.showBurstToast {
      BYKShowMessage(game, s"Byakko: blades hot (\(this.m_burst.GetKills()))", 1.5);
    }
  }

  // ---- Burst expiry tick ------------------------------------------------
  //
  // Only runs while a window is live. Between fights nothing here is scheduled at all, so
  // the mod costs nothing when it is not doing anything.

  private func ScheduleBurstTick() -> Void {
    if this.m_burstTickLive {
      return;   // a chain is already running; do not start a second one
    }
    let ds = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      return;
    }
    let cb = new BYKBurstTickCallback();
    cb.game = this.GetGameInstance();
    cb.generation = this.m_generation;
    this.m_burstTickLive = true;
    ds.DelayCallback(cb, BYKConfig.BurstTickSeconds(), false);
  }

  public func OnBurstTick(generation: Int32) -> Void {
    if generation != this.m_generation {
      return;   // a chain from a previous session; let it die here
    }
    this.m_burstTickLive = false;
    if !IsDefined(this.m_burst) {
      return;
    }
    if this.m_burst.Tick(this.GetGameInstance()) {
      this.ScheduleBurstTick();
    }
  }

  // ---- Slow tick --------------------------------------------------------
  //
  // Keeps the resting baseline current and nothing else. Runs on a lazy cadence because the
  // things that move the underlying number - a perk, a level, new cyberware, a settings
  // change - do not happen mid-swing.

  private func ScheduleSlowTick() -> Void {
    if this.m_slowTickLive {
      return;
    }
    let ds = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      return;
    }
    let cb = new BYKSlowTickCallback();
    cb.game = this.GetGameInstance();
    cb.generation = this.m_generation;
    this.m_slowTickLive = true;
    ds.DelayCallback(cb, 2.0, false);
  }

  public func OnSlowTick(generation: Int32) -> Void {
    if generation != this.m_generation {
      return;
    }
    this.m_slowTickLive = false;
    let game = this.GetGameInstance();

    this.EnsureCallbacks();   // last-resort retry for the diagnostic key

    // Stand down while the world is streaming, and keep standing down for a few ticks after
    // it reports itself stable again. The streaming system is still busy for a moment after
    // the loading screen clears, and the equipment lookup this tick performs is exactly the
    // kind of read that finds a half-built entity in that window.
    if !BYKWorldStable(game) {
      this.m_settleTicks = BYKConfig.SettleTicks();
      this.ScheduleSlowTick();
      return;
    }
    if this.m_settleTicks > 0 {
      this.m_settleTicks -= 1;
      this.ScheduleSlowTick();
      return;
    }

    BYKBaselineEvaluate(game, this.m_baseline, this.m_burst);
    this.ScheduleSlowTick();
  }

  // ---- Diagnostics ------------------------------------------------------

  private cb func OnWTKeyInput(event: ref<KeyInputEvent>) -> Void {
    let settings = BYKSettings();
    if !IsDefined(settings) || !settings.diagnosticsEnabled {
      return;
    }
    if !Equals(event.GetKey(), settings.diagnosticKey) {
      return;
    }
    // Act on the press, and fall back to the release for setups that never deliver a press
    // for this key, which is one reported way a mod hotkey appears to do nothing at all. The
    // down-flag keeps a normal press-and-release pair from printing the readout twice, and
    // stops a held key from repeating it.
    let action = event.GetAction();
    if Equals(action, EInputAction.IACT_Press) {
      if this.m_diagKeyDown {
        return;
      }
      this.m_diagKeyDown = true;
    } else {
      if !Equals(action, EInputAction.IACT_Release) {
        return;   // repeats and anything else
      }
      let pressWasSeen = this.m_diagKeyDown;
      this.m_diagKeyDown = false;
      if pressWasSeen {
        return;   // already handled on the press
      }
    }
    BYKShowDiagnostics(this.GetGameInstance(), this);
  }

  public func GetBurst() -> ref<BYKBurstState> {
    return this.m_burst;
  }
}

// Burst-expiry driver. Carries a generation token so a stale chain stops instead of stacking.
public class BYKBurstTickCallback extends DelayCallback {
  public let game: GameInstance;
  public let generation: Int32;

  public func Call() -> Void {
    let sys = ByakkoSystem.Get(this.game);
    if IsDefined(sys) {
      sys.OnBurstTick(this.generation);
    }
  }
}

// Baseline driver, same generation rule.
public class BYKSlowTickCallback extends DelayCallback {
  public let game: GameInstance;
  public let generation: Int32;

  public func Call() -> Void {
    let sys = ByakkoSystem.Get(this.game);
    if IsDefined(sys) {
      sys.OnSlowTick(this.generation);
    }
  }
}
