// Byakko - Logging
//
// Everything goes through BYKLog so the one call into the game's log function is isolated
// here. Categories (CName): Core, Data, Burst, Kill, Diag.

public func BYKLogLevelOff() -> Int32 = 0
public func BYKLogLevelInfo() -> Int32 = 1
public func BYKLogLevelVerbose() -> Int32 = 2

public abstract class BYKLog {
  public static func Info(category: CName, message: String) -> Void {
    BYKWriteLog(BYKLogLevelInfo(), category, message);
  }

  public static func Warn(category: CName, message: String) -> Void {
    BYKWriteLog(BYKLogLevelInfo(), category, s"[WARN] \(message)");
  }

  public static func Error(category: CName, message: String) -> Void {
    // Errors are always surfaced, whatever the configured level.
    BYKEmitLogLine(category, s"[ERROR] \(message)");
  }

  public static func Verbose(category: CName, message: String) -> Void {
    BYKWriteLog(BYKLogLevelVerbose(), category, message);
  }
}

// Defaults to Info before the runtime service exists (very early script init).
func BYKCurrentLogLevel() -> Int32 {
  let rt = ByakkoRuntime.Get();
  if IsDefined(rt) {
    return rt.GetLogLevel();
  }
  return BYKLogLevelInfo();
}

func BYKWriteLog(level: Int32, category: CName, message: String) -> Void {
  if level > BYKCurrentLogLevel() {
    return;
  }
  BYKEmitLogLine(category, message);
}

func BYKEmitLogLine(category: CName, message: String) -> Void {
  FTLog(s"[Byakko][\(NameToString(category))] \(message)");
}
