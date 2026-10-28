// White Tiger - Runtime service (session-only flags)
//
// Codeware ScriptableService. Holds state that must be reachable without a GameInstance,
// so low-level helpers such as WTLog can read it. It stores nothing in saves, and it holds
// no references to game objects (Codeware guidance).

public class WhiteTigerRuntime extends ScriptableService {
  private let m_enabled: Bool = true;
  private let m_logLevel: Int32 = 1;   // WTLogLevelInfo
  private let m_settings: ref<WhiteTigerSettings>;

  public static func Get() -> ref<WhiteTigerRuntime> {
    // The service container is null during world transitions (load, fast travel, Skip Time,
    // braindance entry). Calling GetService on a null container reads a null context and
    // crashes, so bail out and let callers treat the runtime as not-yet-available.
    let container = GameInstance.GetScriptableServiceContainer();
    if !IsDefined(container) {
      return null;
    }
    return container.GetService(n"WhiteTigerRuntime") as WhiteTigerRuntime;
  }

  public func GetSettings() -> ref<WhiteTigerSettings> {
    return this.m_settings;
  }

  public func SetSettings(settings: ref<WhiteTigerSettings>) -> Void {
    this.m_settings = settings;
  }

  public func HasSettings() -> Bool {
    return IsDefined(this.m_settings);
  }

  public func IsEnabled() -> Bool {
    return this.m_enabled;
  }

  public func SetEnabled(value: Bool) -> Void {
    this.m_enabled = value;
  }

  public func GetLogLevel() -> Int32 {
    return this.m_logLevel;
  }

  public func SetLogLevel(value: Int32) -> Void {
    this.m_logLevel = value;
  }
}

// Convenience: the live settings, or null if Mod Settings has not registered yet. Callers
// must handle null - during very early init there is genuinely nothing to read.
public func WTSettings() -> ref<WhiteTigerSettings> {
  let rt = WhiteTigerRuntime.Get();
  if IsDefined(rt) && rt.HasSettings() {
    return rt.GetSettings();
  }
  return null;
}

// Is the mod switched on? Treated as on when the runtime is not up yet, because the only
// thing that reads this before then is logging.
public func WTEnabled() -> Bool {
  let rt = WhiteTigerRuntime.Get();
  if !IsDefined(rt) {
    return true;
  }
  if !rt.IsEnabled() {
    return false;
  }
  let s = rt.GetSettings();
  if IsDefined(s) {
    return s.enabled;
  }
  return true;
}
