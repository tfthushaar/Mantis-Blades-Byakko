// White Tiger - Tuning constants
//
// Anything a player is meant to change lives in Mod Settings instead (Settings/
// WhiteTigerSettings.reds). What is left here is internal pacing and the safety margins,
// kept in one place so none of them is buried as a literal at a call site.

public abstract class WTConfig {
  // ---- Byakko's numbers -------------------------------------------------
  // Community-reported: about +17.5% attack speed for about 10 seconds on a kill, with the
  // light-combo pause removed. These are the defaults the Mod Settings sliders start at.
  // They come from wikis, not from the game files, so they are a starting point to tune
  // from rather than a measured truth.
  public static func BurstMultDefault() -> Float = 1.175
  public static func BurstSecondsDefault() -> Float = 10.0

  // Byakko's displayed attack speed. The resting target for the blades.
  public static func RestingAttackSpeedDefault() -> Float = 2.1

  // ---- Burst tick -------------------------------------------------------
  // How often the expiry tick runs while a burst is live. It only runs while one is live,
  // so this costs nothing in normal play. Fine enough that the window ends when it says it
  // does, coarse enough not to matter.
  public static func BurstTickSeconds() -> Float = 0.25

  // Ticks to stay stood down after the world stops being stable. Re-equipping, a load or a
  // scene leaves the streaming system busy for a moment after it reports itself ready, and
  // reading the equipped weapon during that window is what reads a half-built entity.
  public static func SettleTicks() -> Int32 = 4

  // ---- Guard rails ------------------------------------------------------
  // Never ask for more than this as a resting attack speed, whatever a setting says. A
  // corrupt or hand-edited settings file should not be able to drive the swing animation
  // into a state the game was never built to play.
  public static func MaxRestingAttackSpeed() -> Float = 6.0
  public static func MaxBurstMult() -> Float = 3.0
  public static func MaxBurstSeconds() -> Float = 60.0

  // The vanilla melee attack speed ceiling. Nothing here enforces it - the game does - but
  // the diagnostic readout compares against it to tell the player whether their bonuses are
  // being thrown away (see Diagnostics/Readout.reds).
  public static func VanillaMeleeSpeedCap() -> Float = 2.0
}
