// White Tiger - Logging
//
// Everything goes through WTLog so the one call into the game's log function is isolated
// here. Categories (CName): Core, Data, Burst, Kill, Diag.

public func WTLogLevelOff() -> Int32 = 0
public func WTLogLevelInfo() -> Int32 = 1
public func WTLogLevelVerbose() -> Int32 = 2

public abstract class WTLog {
  public static func Info(category: CName, message: String) -> Void {
    WTWriteLog(WTLogLevelInfo(), category, message);
  }

  public static func Warn(category: CName, message: String) -> Void {
    WTWriteLog(WTLogLevelInfo(), category, s"[WARN] \(message)");
  }

  public static func Error(category: CName, message: String) -> Void {
    // Errors are always surfaced, whatever the configured level.
    WTEmitLogLine(category, s"[ERROR] \(message)");
  }

  public static func Verbose(category: CName, message: String) -> Void {
    WTWriteLog(WTLogLevelVerbose(), category, message);
  }
}

// Defaults to Info before the runtime service exists (very early script init).
func WTCurrentLogLevel() -> Int32 {
  let rt = WhiteTigerRuntime.Get();
  if IsDefined(rt) {
    return rt.GetLogLevel();
  }
  return WTLogLevelInfo();
}

func WTWriteLog(level: Int32, category: CName, message: String) -> Void {
  if level > WTCurrentLogLevel() {
    return;
  }
  WTEmitLogLine(category, message);
}

func WTEmitLogLine(category: CName, message: String) -> Void {
  FTLog(s"[WhiteTiger][\(NameToString(category))] \(message)");
}
