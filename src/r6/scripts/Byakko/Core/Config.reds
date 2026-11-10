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

  // The resting target for the blades.
  //
  // Deliberately NOT the Byakko's 2.1, even though matching the katana was the original idea.
  // See AnimationSafeCeilingDefault below. 1.85 leaves room for the default burst to land just
  // under the ceiling: 1.85 x 1.175 = 2.174.
  public static func RestingAttackSpeedDefault() -> Float = 1.85

  // ---- The animation-safe ceiling ---------------------------------------
  //
  // Vanilla sets BaseStats.AttackSpeed.max to 2.0, and that clamp is load-bearing rather than
  // arbitrary. Mantis Blade light attacks are a chain that alternates arms, and the chain is
  // driven by the animation graph, not by anything in TweakDB or reachable from script. Push
  // the speed far enough past 2.0 and the graph stops advancing through the chain: every swing
  // replays the first attack, so V slashes with the same arm over and over.
  //
  // On a stock install this never comes up, because the game clamps it for you. It only becomes
  // reachable with a cap-raising mod installed, which is exactly the setup this mod recommends
  // for getting the most out of the burst. So the mod has to hold the line itself.
  //
  // Both the resting target and the burst are held under this. Set it to 0 to switch the
  // limiting off and accept the animation artefact.
  //
  // 2.2 rather than the vanilla 2.0, and that number is a judgement call rather than a measured
  // threshold. What is actually known: 2.0 is where vanilla clamps and behaves, and about 2.47
  // is where the arm alternation was reported breaking (a 2.1 resting target times the 1.175
  // burst). Where between those two it actually goes wrong has not been measured. 2.2 takes
  // most of the available headroom while staying well clear of the known-bad figure. If the
  // same-arm slashing comes back, this is the number to bring down.
  public static func AnimationSafeCeilingDefault() -> Float = 2.2

  // ---- Sihil's dash window ----------------------------------------------
  // Unlimited combo attacks for a short time after dashing. The duration is a judgement call:
  // the in-game effect is described as "a bit", with no number anywhere, and this is short
  // enough to feel like a reward for dashing rather than a permanent state.
  public static func DashWindowSecondsDefault() -> Float = 5.0

  // No attack speed by default, only the combo flag. Speed here would compose with a kill
  // burst's multiplier, and two multipliers on the same stat is exactly how the
  // arm-alternation animation bug happened. Opt in if you want it.
  public static func DashWindowSpeedDefault() -> Float = 1.0

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

  // The vanilla melee attack speed clamp, BaseStats.AttackSpeed.max. Reported by the
  // diagnostic so a player can see whether their bonuses are being discarded, and the default
  // value of the animation-safe ceiling above.
  public static func VanillaMeleeSpeedCap() -> Float = 2.0
}
