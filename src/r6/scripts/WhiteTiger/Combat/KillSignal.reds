// White Tiger - Knowing a kill happened
//
// Two hooks, both on the victim, both as cheap as they can be made.
//
// ---------------------------------------------------------------------------
// Why not the player
//
// PlayerPuppet.OnHit is the obvious place to notice that V hit something, and it is the
// wrong one: V's damage path is the hottest path in the game, and wrapping it puts this
// mod's code in front of every bullet, every tick of every damage-over-time and every
// quickhack in the fight. Hooking the victim instead means the work only happens on an
// enemy that got hit, and the kill check only happens on an enemy that died.
//
// ---------------------------------------------------------------------------
// Why a hit hook is needed at all
//
// gameDeathEvent does carry an instigator, so "V killed this" is answerable at death time
// without any per-hit work. What it cannot answer is "V killed this *with the blades*".
// Checking what V happens to be holding when something dies is not the same question: a
// grenade kill or a quickhack kill while the blades are out would both pass. So OnHit
// records the one fact that is only available per-hit - that this damage came from V's
// Mantis Blades - and does nothing else.
//
// The flag lives on the victim and dies with it. It is a plain Bool on a puppet that is
// about to despawn, so there is nothing to clean up and nothing to persist.

@addField(ScriptedPuppet)
public let wtHitByMantis: Bool;

@wrapMethod(ScriptedPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let result = wrappedMethod(evt);
  WTNoteMantisHit(this, evt);
  return result;
}

@wrapMethod(ScriptedPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let result = wrappedMethod(evt);
  WTNoteDeath(this);
  return result;
}

// Record whether this damage came from V swinging Mantis Blades.
//
// Ordered cheapest-check-first so the overwhelming majority of hits - enemies shooting each
// other, enemies shooting V - leave after one or two comparisons.
func WTNoteMantisHit(puppet: ref<ScriptedPuppet>, evt: ref<gameHitEvent>) -> Void {
  if !IsDefined(evt) || !IsDefined(evt.attackData) {
    return;
  }
  let instigator = evt.attackData.GetInstigator();
  if !IsDefined(instigator) || !instigator.IsPlayer() {
    return;
  }
  // The weapon that dealt it, straight off the attack. More reliable than asking what V is
  // holding now, which can already have changed by the time the victim dies.
  let weapon = evt.attackData.GetWeapon() as WeaponObject;
  if !IsDefined(weapon) {
    return;
  }
  if WTIsMantisWeapon(weapon) {
    // Sticky on purpose. A bleed tick started by the blades lands as a later hit with no
    // weapon attached to it, so the kill still has to count as a blade kill when the enemy
    // finally drops - which is the whole reason this is a flag and not a per-hit decision.
    puppet.wtHitByMantis = true;
  }
}

// An enemy died. If the blades had a hand in it, open or refresh the window.
func WTNoteDeath(puppet: ref<ScriptedPuppet>) -> Void {
  if !puppet.wtHitByMantis {
    return;   // not a blade kill; nothing to do
  }
  if !WTEnabled() {
    return;
  }
  let game = puppet.GetGame();
  let sys = WhiteTigerSystem.Get(game);
  if !IsDefined(sys) {
    return;
  }
  sys.OnMantisKill();
}
