// Byakko - A tracked set of stat modifiers
//
// The burst proved out a contract for applying stat modifiers without leaking them. Every
// feature from here on needs the same contract over a variable number of modifiers rather than
// a fixed two or three, so it lives in one place.
//
// The contract, unchanged from the burst:
//
//   - Every modifier that goes on is remembered by its handle, so it can come back off.
//   - Nothing is written to, or removed from, an entity that is not currently attached. The
//     modifiers on a weapon entity die with that entity, so a weapon that has gone away needs
//     its handles dropped, not removed.
//   - Clear touches the stats system. Forget does not. Across a load or a teardown the world
//     those modifiers lived on has already gone, so Forget is the correct call and Clear would
//     be a native world query during exactly the window to avoid.
//   - A set belongs to one entity. Applying to a different entity clears first, because the
//     handles from the old one are no longer removable from the new one.
//
// Why an array and not a few named fields: a profile carries however many modifiers the iconic
// it came from carries. The risk an array adds is a partial release, so there is exactly one
// place that empties it and it always empties all of it.

public class BYKModSet {
  private let m_entity: EntityID;
  private let m_mods: array<ref<gameStatModifierData>>;

  public func IsEmpty() -> Bool {
    return ArraySize(this.m_mods) == 0;
  }

  public func Count() -> Int32 {
    return ArraySize(this.m_mods);
  }

  public func Entity() -> EntityID {
    return this.m_entity;
  }

  // Is this set attached to this entity? False for an empty set, so a caller cannot mistake
  // "nothing applied" for "applied to the thing you asked about".
  public func IsOn(entity: EntityID) -> Bool {
    if ArraySize(this.m_mods) == 0 {
      return false;
    }
    return BYKSameEntity(this.m_entity, entity);
  }

  // Add one modifier and remember it. Returns whether it landed.
  //
  // The caller passes the entity so this can refuse to mix two entities in one set, which is
  // the one way an array of handles could end up unremovable.
  public func Add(game: GameInstance, entity: EntityID, statType: gamedataStatType,
                  modType: gameStatModifierType, value: Float) -> Bool {
    if !EntityID.IsDefined(entity) {
      return false;
    }
    if ArraySize(this.m_mods) > 0 && !BYKSameEntity(this.m_entity, entity) {
      // Refuse rather than silently orphan what is already held. A caller that wants to move
      // to a new entity clears first; that is its decision, not this one's.
      BYKLog.Warn(n"Mods", "Refused to mix two entities in one modifier set.");
      return false;
    }
    let stats = GameInstance.GetStatsSystem(game);
    if !IsDefined(stats) {
      return false;
    }
    let mod = RPGManager.CreateStatModifier(statType, modType, value);
    if !IsDefined(mod) {
      return false;
    }
    stats.AddModifier(Cast<StatsObjectID>(entity), mod);
    ArrayPush(this.m_mods, mod);
    this.m_entity = entity;
    return true;
  }

  // Take everything back off. Safe when nothing is applied, and safe when the entity it was
  // applied to no longer exists. Only call while the world is stable; see Forget otherwise.
  public func Clear(game: GameInstance) -> Void {
    if ArraySize(this.m_mods) > 0 && BYKEntityAlive(game, this.m_entity) {
      let stats = GameInstance.GetStatsSystem(game);
      if IsDefined(stats) {
        let sid = Cast<StatsObjectID>(this.m_entity);
        for mod in this.m_mods {
          if IsDefined(mod) {
            stats.RemoveModifier(sid, mod);
          }
        }
      }
    }
    this.Forget();
  }

  // Drop every handle without touching the stats system or the entity registry. For loads,
  // respawns and teardown. Using this while the target is still alive would orphan the
  // modifiers, so it is only ever called where the world is on its way out.
  public func Forget() -> Void {
    ArrayClear(this.m_mods);
    this.m_entity = BYKNoEntity();
  }
}
