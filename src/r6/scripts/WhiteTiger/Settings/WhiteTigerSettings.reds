// White Tiger - Settings, via Mod Settings.
//
// Mod Settings finds this class by reflection: any field carrying the "ModSettings.mod"
// runtimeProperty becomes a menu entry. WhiteTigerSystem creates and registers one instance
// per session, and everything else reads the live values through WTSettings().
//
// Defaults are Byakko's reported numbers, so a fresh install is already the thing the mod
// set out to be and nothing has to be configured to get the intended feel.

enum EWTLogLevel {
  Off = 0,
  Info = 1,
  Verbose = 2,
}

public class WhiteTigerSettings {
  // ---- General ----------------------------------------------------------
  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-General")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-Enabled")
  @runtimeProperty("ModSettings.description", "WhiteTiger-Enabled-Desc")
  public let enabled: Bool = true;

  // ---- The on-kill window -----------------------------------------------
  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstEnabled")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstEnabled-Desc")
  public let burstEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstMult")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstMult-Desc")
  @runtimeProperty("ModSettings.step", "0.025")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "3.0")
  public let burstMult: Float = 1.175;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstSeconds")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstSeconds-Desc")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "30.0")
  public let burstSeconds: Float = 10.0;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstCombo")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstCombo-Desc")
  public let burstRemovesComboPause: Bool = true;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstPlayer")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstPlayer-Desc")
  public let burstAlsoBuffsPlayer: Bool = true;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-BurstToast")
  @runtimeProperty("ModSettings.description", "WhiteTiger-BurstToast-Desc")
  public let showBurstToast: Bool = false;

  // ---- Resting speed ----------------------------------------------------
  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Resting")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-RestingEnabled")
  @runtimeProperty("ModSettings.description", "WhiteTiger-RestingEnabled-Desc")
  public let restingSpeedEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Resting")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-RestingSpeed")
  @runtimeProperty("ModSettings.description", "WhiteTiger-RestingSpeed-Desc")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.5")
  @runtimeProperty("ModSettings.max", "6.0")
  public let restingAttackSpeed: Float = 2.1;

  // ---- Diagnostics ------------------------------------------------------
  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-DiagEnabled")
  @runtimeProperty("ModSettings.description", "WhiteTiger-DiagEnabled-Desc")
  public let diagnosticsEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-DiagKey")
  @runtimeProperty("ModSettings.description", "WhiteTiger-DiagKey-Desc")
  public let diagnosticKey: EInputKey = EInputKey.IK_F8;

  @runtimeProperty("ModSettings.mod", "White Tiger")
  @runtimeProperty("ModSettings.category", "WhiteTiger-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "WhiteTiger-LogLevel")
  @runtimeProperty("ModSettings.description", "WhiteTiger-LogLevel-Desc")
  public let logLevel: EWTLogLevel = EWTLogLevel.Info;

  public func Register() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
    this.Push();
  }

  public func Unregister() -> Void {
    ModSettings.UnregisterListenerToClass(this);
    ModSettings.UnregisterListenerToModifications(this);
  }

  // Mod Settings calls this after any of the values above changes in the menu.
  public func OnModSettingsChange() -> Void {
    this.Push();
  }

  // Mirror the handful of values the low-level helpers need into the runtime, which they can
  // reach without a GameInstance. Everything else is read straight off this object.
  private func Push() -> Void {
    let rt = WhiteTigerRuntime.Get();
    if IsDefined(rt) {
      rt.SetEnabled(this.enabled);
      rt.SetLogLevel(EnumInt(this.logLevel));
    }
  }
}
