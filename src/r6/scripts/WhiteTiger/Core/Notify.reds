// White Tiger - On-screen text
//
// One helper, so the one blackboard write this mod performs for UI lives in a single place.

public func WTShowMessage(game: GameInstance, text: String, duration: Float) -> Void {
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
