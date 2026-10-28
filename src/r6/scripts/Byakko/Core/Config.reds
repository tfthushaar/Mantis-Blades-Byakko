// Byakko - Tuning constants
//
// Anything a player is meant to change lives in Mod Settings instead (Settings/
// ByakkoSettings.reds). What is left here is internal pacing and the safety margins, kept in
// one place so none of them is buried as a literal at a call site.

public abstract class BYKConfig {
  // ---- The Byakko's numbers ---------------------------------------------
  // Community-reported: about +17.5% attack speed for about 10 seconds on a kill, with the
  // light-combo pause removed. These are the defaults the Mod Settings sliders start at.
  // They come from wikis, not from the game files, so they are a starting point to tune
  // from rather than a measured truth.
  public static func BurstMultDefault() -> Float = 1.175
  public static func BurstSecondsDefault() -> Float = 10.0

  // The Byakko's displayed attack speed. The resting target for the blades.
  public static func RestingAttackSpeedDefault() -> Float = 2.1

  // ---- Burst tick -------------------------------------------------------
  // How often the expiry tick runs while a burst is live. It only runs while one is live,
  // so this costs nothing in normal play. Fine enough that the window ends when it says it
  // does, coarse enough not to matter.
  public static func BurstTickSeconds() -> Float = 0.25

  // ---- Baseline tick ----------------------------------------------------
  // The cadence while the blades are in hand. Fast enough that dragging a settings slider
  // takes effect while the menu is still open.
  public static func SlowTickSeconds() -> Float = 2.0

  // The cadence once the blades have been put away for a while. Most players are not holding
  // Mantis Blades most of the time, and while they are not there is nothing for this tick to
  // do but notice when that changes. Backing off cuts the idle cost to a third and shrinks
  // the window in which the tick can coincide with world streaming.
  public static func IdleTickSeconds() -> Float = 6.0

  // Consecutive blade-free ticks before backing off to the idle cadence.
  public static func IdleTicksBeforeBackoff() -> Int32 = 3

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
