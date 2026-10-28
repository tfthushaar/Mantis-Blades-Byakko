// Byakko - Settings, via Mod Settings.
//
// Mod Settings finds this class by reflection: any field carrying the "ModSettings.mod"
// runtimeProperty becomes a menu entry. ByakkoSystem creates and registers one instance
// per session, and everything else reads the live values through BYKSettings().
//
// Defaults are Byakko's reported numbers, so a fresh install is already the thing the mod
// set out to be and nothing has to be configured to get the intended feel.

enum EBYKLogLevel {
  Off = 0,
  Info = 1,
  Verbose = 2,
}

public class ByakkoSettings {
  // ---- General ----------------------------------------------------------
  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-General")
  @runtimeProperty("ModSettings.displayName", "Byakko-Enabled")
  @runtimeProperty("ModSettings.description", "Byakko-Enabled-Desc")
  public let enabled: Bool = true;

  // ---- The on-kill window -----------------------------------------------
  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstEnabled")
  @runtimeProperty("ModSettings.description", "Byakko-BurstEnabled-Desc")
  public let burstEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstMult")
  @runtimeProperty("ModSettings.description", "Byakko-BurstMult-Desc")
  @runtimeProperty("ModSettings.step", "0.025")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "3.0")
  public let burstMult: Float = 1.175;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstSeconds")
  @runtimeProperty("ModSettings.description", "Byakko-BurstSeconds-Desc")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "1.0")
  @runtimeProperty("ModSettings.max", "30.0")
  public let burstSeconds: Float = 10.0;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstCombo")
  @runtimeProperty("ModSettings.description", "Byakko-BurstCombo-Desc")
  public let burstRemovesComboPause: Bool = true;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstPlayer")
  @runtimeProperty("ModSettings.description", "Byakko-BurstPlayer-Desc")
  public let burstAlsoBuffsPlayer: Bool = true;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Burst")
  @runtimeProperty("ModSettings.displayName", "Byakko-BurstToast")
  @runtimeProperty("ModSettings.description", "Byakko-BurstToast-Desc")
  public let showBurstToast: Bool = false;

  // ---- Resting speed ----------------------------------------------------
  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Resting")
  @runtimeProperty("ModSettings.displayName", "Byakko-RestingEnabled")
  @runtimeProperty("ModSettings.description", "Byakko-RestingEnabled-Desc")
  public let restingSpeedEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Resting")
  @runtimeProperty("ModSettings.displayName", "Byakko-RestingSpeed")
  @runtimeProperty("ModSettings.description", "Byakko-RestingSpeed-Desc")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.5")
  @runtimeProperty("ModSettings.max", "6.0")
  public let restingAttackSpeed: Float = 2.1;

  // ---- Diagnostics ------------------------------------------------------
  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "Byakko-DiagEnabled")
  @runtimeProperty("ModSettings.description", "Byakko-DiagEnabled-Desc")
  public let diagnosticsEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "Byakko-DiagKey")
  @runtimeProperty("ModSettings.description", "Byakko-DiagKey-Desc")
  public let diagnosticKey: EInputKey = EInputKey.IK_F8;

  @runtimeProperty("ModSettings.mod", "Byakko - Mantis Blades Overhaul")
  @runtimeProperty("ModSettings.category", "Byakko-Category-Diagnostics")
  @runtimeProperty("ModSettings.displayName", "Byakko-LogLevel")
  @runtimeProperty("ModSettings.description", "Byakko-LogLevel-Desc")
  public let logLevel: EBYKLogLevel = EBYKLogLevel.Info;

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
    let rt = ByakkoRuntime.Get();
    if IsDefined(rt) {
      rt.SetEnabled(this.enabled);
      rt.SetLogLevel(EnumInt(this.logLevel));
    }
  }
}
