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
  private let m_dash: ref<BYKDashWindow>;
  private let m_bleed: ref<BYKBleedWindow>;
  private let m_wantsBleed: Bool;      // does either arm's profile declare a bleed window
  private let m_mantisSlot: ref<BYKProfileSlot>;
  private let m_gorillaSlot: ref<BYKProfileSlot>;

  private let m_playerAttachCbId: Uint32;
  private let m_callbacksRegistered: Bool;

  // Blackboard listener for the dash trigger. Held so it can be unregistered, and dropped
  // without unregistering at session start, because the blackboard it was registered on has
  // been replaced by then and reaching for the old one is a native call into a dead object.
  private let m_locoCbId: ref<CallbackHandle>;
  private let m_locoRegistered: Bool;
  // Was the previous locomotion state a dash? A plain Bool rather than a "last state" int with
  // a -1 sentinel, because redscript rejects a negative literal as a field initializer
  // (INVALID_CONSTANT). It also reads better: the only question asked of it is whether this
  // change is the moment of entering a dash.
  private let m_wasDash: Bool;

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
  private let m_idleTicks: Int32;       // consecutive ticks with no blades in hand
  private let m_diagKeyDown: Bool;
  private let m_ripKeyDown: Bool;      // diagnostic key debounce: some setups deliver only one of press/release

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
    this.m_dash = new BYKDashWindow();
    this.m_bleed = new BYKBleedWindow();
    this.m_mantisSlot = new BYKProfileSlot();
    this.m_mantisSlot.Init(BYKArmMantis());
    this.m_gorillaSlot = new BYKProfileSlot();
    this.m_gorillaSlot.Init(BYKArmGorilla());
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
      this.m_playerAttachCbId = ps.RegisterPlayerPuppetAttachedCallback(this, n"OnBYKPlayerAttached");
    }
  }

  private func OnBYKPlayerAttached(player: ref<GameObject>) -> Void {
    this.StartSession();
  }

  // A save was restored. A second chance at the session reset, in case the player-attached
  // callback was missed: a stale handle surviving a load is the one way this mod could end up
  // writing to a stats object that belongs to a world that no longer exists.
  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    BYKLog.Verbose(n"Core", s"Restored (save \(saveVersion), game \(gameVersion)).");
    this.StartSession();
  }

  private func StartSession() -> Void {
    // Retire every tick chain from before this point, then start one fresh.
    this.m_generation += 1;
    this.m_burstTickLive = false;
    this.m_slowTickLive = false;
    this.m_settleTicks = BYKConfig.SettleTicks();
    this.m_idleTicks = 0;

    // Drop anything held from before the load, without touching the stats system.
    //
    // Forget rather than Clear on purpose. The world those modifiers were applied to has
    // already been destroyed, so there is nothing to remove, and Clear would query the
    // entity registry to establish that - a native world query during a load, which is the
    // precise thing the rest of this mod is built to avoid.
    if IsDefined(this.m_burst) {
      this.m_burst.Forget();
    }
    if IsDefined(this.m_baseline) {
      this.m_baseline.Forget();
    }
    if IsDefined(this.m_bleed) {
      this.m_bleed.Forget();
    }
    if IsDefined(this.m_dash) {
      this.m_dash.Forget();
    }
    if IsDefined(this.m_mantisSlot) {
      this.m_mantisSlot.Forget();
    }
    if IsDefined(this.m_gorillaSlot) {
      this.m_gorillaSlot.Forget();
    }
    // The blackboard this was registered on is gone, so the handle is stale. Drop it without
    // unregistering and register again below, rather than calling into a replaced object.
    this.m_locoCbId = null;
    this.m_locoRegistered = false;
    this.m_wasDash = false;

    this.EnsureSettings();
    this.EnsureCallbacks();
    this.EnsureLocomotionListener();
    this.ScheduleSlowTick();
    BYKLog.Info(n"Core", "Session started.");
  }

  private func EnsureSettings() -> Void {
    let rt = ByakkoRuntime.Get();
    if IsDefined(rt) && !rt.HasSettings() {
      let settings = new ByakkoSettings();
      settings.Register();
      rt.SetSettings(settings);
      BYKLog.Verbose(n"Core", "Settings registered.");
    }
  }

  // The diagnostic hotkey. Guarded and idempotent, and retried from the slow tick, so a
  // callback system that was not up yet at session start cannot leave the key silently
  // unregistered, which looks exactly like the key doing nothing.
  private func EnsureCallbacks() -> Void {
    if this.m_callbacksRegistered {
      return;
    }
    let cbs = GameInstance.GetCallbackSystem();
    if !IsDefined(cbs) {
      return;
    }
    cbs.RegisterCallback(n"Input/Key", this, n"OnBYKKeyInput");
    this.m_callbacksRegistered = true;
  }

  // Register the dash trigger. Guarded and idempotent, and retried from the slow tick, so a
  // blackboard that was not up yet at session start cannot leave the feature silently dead.
  private func EnsureLocomotionListener() -> Void {
    if this.m_locoRegistered {
      return;
    }
    let bbs = GameInstance.GetBlackboardSystem(this.GetGameInstance());
    if !IsDefined(bbs) {
      return;
    }
    let psm = bbs.Get(GetAllBlackboardDefs().PlayerStateMachine);
    if !IsDefined(psm) {
      return;
    }
    this.m_locoCbId = psm.RegisterListenerInt(
      GetAllBlackboardDefs().PlayerStateMachine.Locomotion, this, n"OnBYKLocomotion");
    this.m_locoRegistered = true;
    BYKLog.Verbose(n"Core", "Dash trigger registered.");
  }

  private func ReleaseLocomotionListener() -> Void {
    if !this.m_locoRegistered || !IsDefined(this.m_locoCbId) {
      this.m_locoCbId = null;
      this.m_locoRegistered = false;
      return;
    }
    let bbs = GameInstance.GetBlackboardSystem(this.GetGameInstance());
    if IsDefined(bbs) {
      let psm = bbs.Get(GetAllBlackboardDefs().PlayerStateMachine);
      if IsDefined(psm) {
        psm.UnregisterListenerInt(GetAllBlackboardDefs().PlayerStateMachine.Locomotion, this.m_locoCbId);
      }
    }
    this.m_locoCbId = null;
    this.m_locoRegistered = false;
  }

  // V's locomotion state changed. Fires on every transition, so this is a hot-ish path and
  // leaves on the first cheap test that fails.
  protected cb func OnBYKLocomotion(value: Int32) -> Bool {
    let isDash = BYKLocomotionIsDash(value);
    let wasDash = this.m_wasDash;
    this.m_wasDash = isDash;
    // Only the moment of entering a dash counts, not every frame of being in one, and not
    // leaving one.
    if isDash && !wasDash {
      this.OnDash();
    }
    return false;
  }

  // ---- Bleeding target -------------------------------------------------

  // A cyberarm hit landed on something that is bleeding. Open or refresh the Cleaver's window.
  //
  // Called from the victim's hit hook, so it is on a hotter path than the kill and dash entry
  // points and the cheap guards come first. The caller has already established that the hit came
  // from V's cyberarm and that the victim is bleeding.
  public func OnBleedingTargetHit() -> Void {
    if !IsDefined(this.m_bleed) || !this.m_wantsBleed {
      return;
    }
    if !BYKEnabled() {
      return;
    }
    let game = this.GetGameInstance();
    // Same gate as the kill and dash paths: a hit can land on the frame a scene starts.
    if !BYKWorldStable(game) {
      return;
    }
    let weapon = BYKEquippedArmSettled(game);
    if !IsDefined(weapon) {
      return;
    }
    this.m_bleed.Arm(game, weapon, this.ActiveProfile(game, weapon));
    if !this.m_bleed.IsActive() {
      return;
    }
    this.m_idleTicks = 0;
    this.ScheduleBurstTick();
  }

  // ---- Dash ------------------------------------------------------------

  // V dashed. Open or refresh Sihil's window if a cyberarm is in hand.
  public func OnDash() -> Void {
    if !IsDefined(this.m_dash) {
      return;
    }
    let settings = BYKSettings();
    if IsDefined(settings) && !settings.dashWindowEnabled {
      return;
    }
    if !BYKEnabled() {
      return;
    }
    let game = this.GetGameInstance();
    // The listener can fire while the world is being rebuilt, so the same gate applies here as
    // on the kill path.
    if !BYKWorldStable(game) {
      return;
    }
    let weapon = BYKEquippedArmSettled(game);
    if !IsDefined(weapon) {
      return;   // not holding a cyberarm, nothing to buff
    }
    this.m_dash.Arm(game, weapon, this.ActiveProfile(game, weapon));
    if !this.m_dash.IsActive() {
      return;
    }
    this.m_idleTicks = 0;
    this.ScheduleBurstTick();

    if IsDefined(settings) && settings.showBurstToast {
      BYKShowMessage(game, s"Byakko: dash combo (\(this.m_dash.GetDashes()))", 1.2);
    }
  }

  private func OnDetach() -> Void {
    // Retire the tick chains so nothing fires against a system that is going away, and drop
    // the handles without touching a world that is already being torn down.
    this.m_generation += 1;
    this.m_burstTickLive = false;
    this.m_slowTickLive = false;
    if IsDefined(this.m_burst) {
      this.m_burst.Forget();
    }
    if IsDefined(this.m_baseline) {
      this.m_baseline.Forget();
    }
    if IsDefined(this.m_bleed) {
      this.m_bleed.Forget();
    }
    if IsDefined(this.m_dash) {
      this.m_dash.Forget();
    }
    if IsDefined(this.m_mantisSlot) {
      this.m_mantisSlot.Forget();
    }
    if IsDefined(this.m_gorillaSlot) {
      this.m_gorillaSlot.Forget();
    }
    this.ReleaseLocomotionListener();
    BYKLog.Verbose(n"Core", "Detaching.");
  }

  // ---- Kills ------------------------------------------------------------

  // A Mantis Blade kill landed. Called from the victim's death hook.
  public func OnMantisKill() -> Void {
    if !IsDefined(this.m_burst) {
      return;
    }
    let settings = BYKSettings();
    if IsDefined(settings) && !settings.burstEnabled {
      return;
    }
    let game = this.GetGameInstance();

    // The death hook fires from inside the engine tearing the victim down. Reading the
    // player's equipment is safe there, but only once the world itself is settled: during a
    // load or a scene it is not, and a kill can land on the frame a scene starts.
    if !BYKWorldStable(game) {
      return;
    }
    // Settled variant, because the stability gate just ran. The unchecked lookup would walk
    // the player, the time system, two blackboards and the workspot system a second time.
    let weapon = BYKEquippedMantisSettled(game);
    if !IsDefined(weapon) {
      return;   // the blades went away between the killing blow and the death
    }

    this.m_burst.Arm(game, weapon, this.ActiveProfile(game, weapon));
    if !this.m_burst.IsActive() {
      return;   // nothing landed, so there is nothing to expire
    }
    // The blades are demonstrably in hand, so bring the baseline tick back to its responsive
    // cadence even if it had backed off while they were holstered.
    this.m_idleTicks = 0;
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
    let game = this.GetGameInstance();

    // Drive every timed window from this one chain. Both are ticked before deciding whether to
    // schedule again, rather than short-circuiting on the first live one, so a window never
    // goes unticked because another happened to expire first.
    let live = false;
    if IsDefined(this.m_burst) && this.m_burst.Tick(game) {
      live = true;
    }
    if IsDefined(this.m_dash) && this.m_dash.Tick(game) {
      live = true;
    }
    if IsDefined(this.m_bleed) && this.m_bleed.Tick(game) {
      live = true;
    }

    // A conditional profile needs watching at this cadence rather than the slow one: a
    // Sandevistan is over in seconds. Only a profile that actually has a condition, and is
    // actually on an arm, keeps this chain alive.
    if this.TickConditions(game) {
      live = true;
    }

    if live {
      this.ScheduleBurstTick();
    }
  }


  // The profile currently on whichever arm is in hand, or null.
  private func ActiveProfile(game: GameInstance, weapon: wref<WeaponObject>) -> ref<BYKProfile> {
    if !IsDefined(weapon) {
      return null;
    }
    let kind = BYKArmKind(weapon.GetItemID());
    if kind == BYKArmMantis() && IsDefined(this.m_mantisSlot) {
      return this.m_mantisSlot.Profile();
    }
    if kind == BYKArmGorilla() && IsDefined(this.m_gorillaSlot) {
      return this.m_gorillaSlot.Profile();
    }
    return null;
  }

  // ---- Profiles ---------------------------------------------------------

  // Keep each arm's profile matching what the settings say and what is in hand.
  //
  // Idempotent and cheap when nothing has changed, which is what makes it safe to call from
  // the slow tick rather than needing a settings-change hook.
  private func SyncProfiles(game: GameInstance) -> Void {
    if !IsDefined(this.m_mantisSlot) || !IsDefined(this.m_gorillaSlot) {
      return;
    }
    if !BYKEnabled() {
      this.m_mantisSlot.Clear(game);
      this.m_gorillaSlot.Clear(game);
      this.m_wantsBleed = false;
      return;
    }
    let weapon = BYKEquippedArmSettled(game);
    let kind = BYKArmNone();
    if IsDefined(weapon) {
      kind = BYKArmKind(weapon.GetItemID());
    }
    // Each slot only ever sees the weapon when that weapon is its own kind of arm. The other
    // slot is told there is nothing in hand, so it drops its handles rather than trying to
    // apply Gorilla stats to Mantis Blades.
    let mantisWeapon = kind == BYKArmMantis() ? weapon : null;
    let gorillaWeapon = kind == BYKArmGorilla() ? weapon : null;
    this.m_mantisSlot.Sync(game, mantisWeapon, BYKWantedProfileId(BYKArmMantis()));
    this.m_gorillaSlot.Sync(game, gorillaWeapon, BYKWantedProfileId(BYKArmGorilla()));

    // Cache whether a bleed window is wanted at all, so the victim's hit hook can rule itself out
    // with one field read instead of reaching two profiles on every landed swing.
    this.m_wantsBleed = BYKProfileHasBleedWindow(this.m_mantisSlot.Profile())
                     || BYKProfileHasBleedWindow(this.m_gorillaSlot.Profile());

    // A conditional profile that has just been applied needs the fast chain running.
    if this.m_mantisSlot.WantsTick() || this.m_gorillaSlot.WantsTick() {
      this.ScheduleBurstTick();
    }
  }

  // Apply or remove the conditional half of whichever profile is in hand. Returns whether
  // anything still wants this chain to keep running.
  private func TickConditions(game: GameInstance) -> Bool {
    if !IsDefined(this.m_mantisSlot) || !IsDefined(this.m_gorillaSlot) {
      return false;
    }
    if !this.m_mantisSlot.WantsTick() && !this.m_gorillaSlot.WantsTick() {
      return false;
    }
    // Reading equipment and stats, so the same gate as everywhere else. Returning true keeps
    // the chain alive across a transition instead of dropping it.
    if !BYKWorldStable(game) {
      return true;
    }
    let weapon = BYKEquippedArmSettled(game);
    if !IsDefined(weapon) {
      return false;
    }
    let kind = BYKArmKind(weapon.GetItemID());
    if kind == BYKArmMantis() {
      this.m_mantisSlot.SyncCondition(game, weapon);
    } else {
      if kind == BYKArmGorilla() {
        this.m_gorillaSlot.SyncCondition(game, weapon);
      }
    }
    return true;
  }

  public func GetMantisSlot() -> ref<BYKProfileSlot> {
    return this.m_mantisSlot;
  }

  public func GetGorillaSlot() -> ref<BYKProfileSlot> {
    return this.m_gorillaSlot;
  }

  // ---- Baseline tick ----------------------------------------------------
  //
  // Keeps the resting baseline current and nothing else. Runs on a lazy cadence because the
  // things that move the underlying number - a perk, a level, new cyberware, a settings
  // change - do not happen mid-swing. Backs off further once the blades have been away for a
  // few ticks, since then it is only watching for them to come back.

  private func ScheduleSlowTick() -> Void {
    if this.m_slowTickLive {
      return;
    }
    let ds = GameInstance.GetDelaySystem(this.GetGameInstance());
    if !IsDefined(ds) {
      return;
    }
    let delay = BYKConfig.SlowTickSeconds();
    if this.m_idleTicks >= BYKConfig.IdleTicksBeforeBackoff() {
      delay = BYKConfig.IdleTickSeconds();
    }
    let cb = new BYKSlowTickCallback();
    cb.game = this.GetGameInstance();
    cb.generation = this.m_generation;
    this.m_slowTickLive = true;
    ds.DelayCallback(cb, delay, false);
  }

  public func OnSlowTick(generation: Int32) -> Void {
    if generation != this.m_generation {
      return;
    }
    this.m_slowTickLive = false;
    let game = this.GetGameInstance();

    this.EnsureCallbacks();            // last-resort retry for the diagnostic key
    this.EnsureLocomotionListener();   // and for the dash trigger

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

    this.SyncProfiles(game);

    if BYKBaselineEvaluate(game, this.m_baseline, this.m_burst) {
      this.m_idleTicks = 0;
    } else {
      // Saturate rather than counting up forever, so this cannot overflow in a long session.
      if this.m_idleTicks < BYKConfig.IdleTicksBeforeBackoff() {
        this.m_idleTicks += 1;
      }
    }
    this.ScheduleSlowTick();
  }

  // ---- Diagnostics ------------------------------------------------------

  private cb func OnBYKKeyInput(event: ref<KeyInputEvent>) -> Void {
    let settings = BYKSettings();
    if !IsDefined(settings) || !settings.diagnosticsEnabled {
      return;
    }
    // One registration serves both keys. Registering a second Input/Key callback would mean
    // another handle to keep alive and release, for no benefit.
    if Equals(event.GetKey(), settings.ripKey) {
      if Equals(event.GetAction(), EInputAction.IACT_Release) {
        this.m_ripKeyDown = false;
        return;
      }
      this.OnBYKRipInput(event);
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

  // Second diagnostic key: read every iconic's real modifiers out of TweakDB into the log.
  //
  // Separate from the readout because it is a different kind of question. The readout says what
  // is applied right now; this says what the game actually holds for each iconic, which is how
  // the transcribed and approximated profile values get checked against the source.
  private cb func OnBYKRipInput(event: ref<KeyInputEvent>) -> Void {
    let settings = BYKSettings();
    if !IsDefined(settings) || !settings.diagnosticsEnabled {
      return;
    }
    if !Equals(event.GetKey(), settings.ripKey) {
      return;
    }
    if !Equals(event.GetAction(), EInputAction.IACT_Press) {
      return;
    }
    if this.m_ripKeyDown {
      return;
    }
    this.m_ripKeyDown = true;
    BYKRipAllProfiles(this.GetGameInstance());
  }

  public func GetBurst() -> ref<BYKBurstState> {
    return this.m_burst;
  }

  public func GetBaseline() -> ref<BYKBaselineState> {
    return this.m_baseline;
  }

  public func GetDash() -> ref<BYKDashWindow> {
    return this.m_dash;
  }

  public func GetBleed() -> ref<BYKBleedWindow> {
    return this.m_bleed;
  }

  // Does either arm's current profile declare a bleed window?
  //
  // Read from the victim's hit hook, which is why it is a cached Bool rather than a walk of both
  // profiles. The hook runs on every cyberarm hit that lands, so the cost of asking has to be one
  // field read. Recomputed whenever profiles are synced.
  public func WantsBleedSignal() -> Bool {
    return this.m_wantsBleed;
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
