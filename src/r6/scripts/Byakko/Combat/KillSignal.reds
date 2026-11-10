// Byakko - Knowing a kill happened
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
public let bykHitByCyberarm: Bool;

@wrapMethod(ScriptedPuppet)
protected cb func OnHit(evt: ref<gameHitEvent>) -> Bool {
  let result = wrappedMethod(evt);
  BYKNoteCyberarmHit(this, evt);
  return result;
}

@wrapMethod(ScriptedPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let result = wrappedMethod(evt);
  BYKNoteDeath(this);
  return result;
}

// Record whether this damage came from V swinging a cyberarm.
//
// Either arm. This was Mantis-only, which meant the kill burst never fired on Gorilla Arms:
// the profile and its ability went on, the window never opened, and nothing said why. Picking
// the Byakko profile for Gorilla Arms got you its stats and none of its signature effect.
//
// Ordered cheapest-check-first so the overwhelming majority of hits - enemies shooting each
// other, enemies shooting V - leave after one or two comparisons.
func BYKNoteCyberarmHit(puppet: ref<ScriptedPuppet>, evt: ref<gameHitEvent>) -> Void {
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
  if IsDefined(weapon) {
    if BYKIsCyberarmWeapon(weapon) {
      // Sticky on purpose. A bleed tick started by the blades lands as a later hit with no
      // weapon attached to it, so the kill still has to count as a blade kill when the enemy
      // finally drops. That is why this is a flag rather than a per-hit decision.
      puppet.bykHitByCyberarm = true;
      BYKNoteBleedingTarget(puppet);
    }
    return;
  }

  // No weapon on the attack data. Arm cyberware does not always carry one, so falling back
  // to what V is holding is the difference between the burst working and the burst never
  // arming at all. Narrowed to melee attacks so a grenade or a quickhack thrown while the
  // blades happen to be drawn cannot be mistaken for a blade kill.
  if !Equals(evt.attackData.GetAttackType(), gamedataAttackType.Melee) {
    return;
  }
  let held = GameObject.GetActiveWeapon(instigator);
  if IsDefined(held) && BYKIsCyberarmWeapon(held) {
    puppet.bykHitByCyberarm = true;
    BYKNoteBleedingTarget(puppet);
  }
}

// This cyberarm hit landed. If the thing it landed on is bleeding, tell the system.
//
// Butcher's Cleaver's condition. Split out of the two call sites above so the status-effect query
// happens in exactly one place, and ordered so that the overwhelmingly common case costs almost
// nothing:
//
//   1. Is any profile asking for this at all? One cached Bool on the system. Every install that
//      has not picked the Cleaver stops here, which is nearly all of them.
//   2. Is the victim bleeding? One tagged status-effect query, and only now.
//
// Reaching the system before asking about the status effect is deliberate. The query is the
// expensive half, and on a hot path the right order is cheapest discriminator first.
func BYKNoteBleedingTarget(puppet: ref<ScriptedPuppet>) -> Void {
  let sys = ByakkoSystem.Get(puppet.GetGame());
  if !IsDefined(sys) || !sys.WantsBleedSignal() {
    return;
  }
  if BYKTargetIsBleeding(puppet) {
    sys.OnBleedingTargetHit();
  }
}

// An enemy died. If a cyberarm had a hand in it, open or refresh the window.
func BYKNoteDeath(puppet: ref<ScriptedPuppet>) -> Void {
  if !puppet.bykHitByCyberarm {
    return;   // not a blade kill; nothing to do
  }
  if !BYKEnabled() {
    return;
  }
  let game = puppet.GetGame();
  let sys = ByakkoSystem.Get(game);
  if !IsDefined(sys) {
    return;
  }
  sys.OnCyberarmKill();
}
