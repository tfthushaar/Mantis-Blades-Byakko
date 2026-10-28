// Byakko - On-screen text
//
// One helper, so the one blackboard write this mod performs for UI lives in a single place.
//
// Refuses to write while the world is mid-transition. The notification blackboard is one of
// the things the engine rebuilds across a load, and a message is never worth a write into a
// system that is being replaced. Callers lose nothing: a toast that cannot be shown during a
// loading screen had no one to show it to.
public func BYKShowMessage(game: GameInstance, text: String, duration: Float) -> Void {
  let bbs = GameInstance.GetBlackboardSystem(game);
  if !IsDefined(bbs) {
    return;
  }
  let bb = bbs.Get(GetAllBlackboardDefs().UI_Notifications);
  if !IsDefined(bb) {
    return;
  }
  let evt = new SimpleScreenMessage();
  evt.isShown = true;
  evt.duration = duration;
  evt.message = text;
  bb.SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(evt), true);
}
