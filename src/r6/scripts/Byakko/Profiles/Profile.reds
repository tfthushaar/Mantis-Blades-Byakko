// Byakko - Iconic profiles
//
// A profile is one iconic melee weapon's stats, ready to be put onto a cyberarm. The player
// picks one per arm in the settings menu.
//
// ---------------------------------------------------------------------------
// Where these numbers come from, and why that is stated per profile
//
// The blade profiles are transcribed from the CDPR modding documentation's iconic-effects
// table, which gives each weapon's stat modifiers verbatim. Every stat name in it was checked
// against this build; the values were not, and that table is dated April 2024.
//
// The blunt profiles are NOT transcribed, because no source has their modifiers. The modding
// table lists blunt tweak ids and nothing else, and the wikis give only the *displayed*
// percentages. Those cannot be transplanted: Byakko and Satori both carry
// BleedingApplicationRate +10, but display +30% and +17% bleed chance respectively, because
// the displayed figure is the rate after the weapon's tier scaling. Transplanting the
// percentage instead of the rate would make every profile wrong in a way that looks plausible.
//
// So blunt profiles are authored to match the described behaviour, and every profile carries a
// `fidelity` the menu shows. A player comparing notes with the wiki deserves to know which kind
// they are looking at.
//
// `tools/probes/ApiSurface.reds` has the record walk that can read an iconic's real modifiers
// out of TweakDB. Running it over these records is how the authored ones become transcribed.

public func BYKFidelityTranscribed() -> Int32 = 0
public func BYKFidelityAuthored() -> Int32 = 1

public func BYKFamilyBlade() -> Int32 = 0
public func BYKFamilyBlunt() -> Int32 = 1

// Conditions a profile's extra modifiers can key off. See Combat/Conditions.reds.
public func BYKCondNone() -> Int32 = 0
public func BYKCondCamo() -> Int32 = 1
public func BYKCondSandevistan() -> Int32 = 2

// One stat modifier in a profile.
public class BYKStatMod {
  public let stat: gamedataStatType;
  public let kind: gameStatModifierType;
  public let value: Float;
}

func BYKMod(stat: gamedataStatType, kind: gameStatModifierType, value: Float) -> ref<BYKStatMod> {
  let m = new BYKStatMod();
  m.stat = stat;
  m.kind = kind;
  m.value = value;
  return m;
}

func BYKAdd(stat: gamedataStatType, value: Float) -> ref<BYKStatMod> {
  return BYKMod(stat, gameStatModifierType.Additive, value);
}

func BYKMul(stat: gamedataStatType, value: Float) -> ref<BYKStatMod> {
  return BYKMod(stat, gameStatModifierType.Multiplier, value);
}

public class BYKProfile {
  public let id: Int32;
  public let name: String;        // the weapon, for the diagnostic
  public let source: String;      // its record id
  public let family: Int32;
  public let fidelity: Int32;
  public let mods: array<ref<BYKStatMod>>;
  public let condition: Int32;              // when non-None, condMods apply while it holds
  public let condMods: array<ref<BYKStatMod>>;

  // A profile's own timed windows. Empty mods means this profile has no such window and the
  // global setting decides instead.
  //
  // This is where the speed and combo effects live. Several iconics are *defined* by one: the
  // Byakko's rapid combo on a kill, Sihil's combo after a dash. Leaving those out of profiles
  // made picking a profile feel gutted, and made the global windows incoherent besides, since
  // picking Scalpel still handed you the Byakko's combo.
  public let killWindowSeconds: Float;
  public let killWindowMods: array<ref<BYKStatMod>>;
  public let dashWindowSeconds: Float;
  public let dashWindowMods: array<ref<BYKStatMod>>;

  public let note: String;                  // what is not included, shown by the diagnostic
}

public func BYKProfileHasKillWindow(p: ref<BYKProfile>) -> Bool {
  return IsDefined(p) && ArraySize(p.killWindowMods) > 0;
}

public func BYKProfileHasDashWindow(p: ref<BYKProfile>) -> Bool {
  return IsDefined(p) && ArraySize(p.dashWindowMods) > 0;
}

func BYKNewProfile(id: Int32, name: String, source: String, family: Int32, fidelity: Int32) -> ref<BYKProfile> {
  let p = new BYKProfile();
  p.id = id;
  p.name = name;
  p.source = source;
  p.family = family;
  p.fidelity = fidelity;
  p.condition = BYKCondNone();
  return p;
}

// Build a profile by id, or null for None or anything unrecognised.
//
// A switch rather than a table built at init: this runs when the player changes the setting or
// swaps arms, not on a tick, so the cost is irrelevant and nothing has to be kept alive.
//
// Returning null for an unknown id matters. The id comes from a Mod Settings ini that survives
// mod updates, so a value written by a future version can be read back by an older one. An
// unknown id must mean "no profile", never an out-of-range index.
public func BYKMakeProfile(id: Int32) -> ref<BYKProfile> {
  let p: ref<BYKProfile>;

  // ---- Blades, transcribed ---------------------------------------------

  if id == EnumInt(EBYKProfile.Byakko) {
    p = BYKNewProfile(id, "Byakko", "Items.Preset_Katana_Wakako", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.Range, 1.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanMeleeLeap, 1.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanMeleeLeapInAir, 1.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 10.0));
    // The effect the weapon is known for: killing someone grants a short burst of speed with
    // the light-combo pause gone. Reported as about +17.5% for about 10 seconds.
    p.killWindowSeconds = 10.0;
    ArrayPush(p.killWindowMods, BYKMul(gamedataStatType.AttackSpeed, 1.175));
    ArrayPush(p.killWindowMods, BYKAdd(gamedataStatType.CanWeaponInfinitlyCombo, 1.0));
    p.note = "Kills open a combo window, which is the Byakko's signature.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Satori) {
    p = BYKNewProfile(id, "Satori", "Items.Preset_Katana_Saburo", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 10.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanMeleeLeap, 1.0));
    ArrayPush(p.mods, BYKMul(gamedataStatType.DamagePerHit, 0.9));
    p.note = "Sheathed quickdraw attack not included; it needs an animation that cyberarms do not have.";
    return p;
  }
  if id == EnumInt(EBYKProfile.JinchuMaru) {
    p = BYKNewProfile(id, "Jinchu-Maru", "Items.Preset_Katana_Takemura", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BonusDmgVsRaresAndElites, 10.0));
    p.condition = BYKCondCamo();
    ArrayPush(p.condMods, BYKAdd(gamedataStatType.CritChance, 1.0));
    ArrayPush(p.condMods, BYKAdd(gamedataStatType.CanMeleeLeap, 1.0));
    p.note = "Guaranteed crits and the leap while Optical Camo is active.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Scalpel) {
    p = BYKNewProfile(id, "Scalpel", "Items.Preset_Katana_Surgeon", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectrocutedApplicationRate, 10.0));
    p.condition = BYKCondSandevistan();
    ArrayPush(p.condMods, BYKAdd(gamedataStatType.CritChance, 0.5));
    ArrayPush(p.condMods, BYKAdd(gamedataStatType.BleedingApplicationRate, 10.0));
    p.note = "Crit chance and bleed while a Sandevistan is running.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Tsumetogi) {
    p = BYKNewProfile(id, "Tsumetogi", "Items.Preset_Katana_Hiromi", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectricResistance, 10.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectrocutedApplicationRate, 5.0));
    ArrayPush(p.mods, BYKMul(gamedataStatType.DamagePerHit, 1.1));
    return p;
  }
  if id == EnumInt(EBYKProfile.CocktailStick) {
    p = BYKNewProfile(id, "Cocktail Stick", "Items.Preset_Katana_Cocktail", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKMul(gamedataStatType.DamagePerHit, 0.9));
    p.condition = BYKCondCamo();
    ArrayPush(p.condMods, BYKAdd(gamedataStatType.BleedingApplicationRate, 10.0));
    p.note = "Bleed while Optical Camo is active, which is how the original works.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Errata) {
    p = BYKNewProfile(id, "Errata", "Items.Preset_Katana_E3", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanMeleeLeap, 1.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BurningApplicationRate, 10.0));
    ArrayPush(p.mods, BYKMul(gamedataStatType.DamagePerHit, 0.9));
    p.note = "Guaranteed crits against burning enemies not included.";
    return p;
  }
  if id == EnumInt(EBYKProfile.BlackUnicorn) {
    p = BYKNewProfile(id, "Black Unicorn", "Items.Preset_Katana_GoG", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanIgnoreWeaponStaminaPenaties, 1.0));
    p.note = "Attack speed stops sagging as stamina drains. One flag, large change, and the one iconic whose signature really is a raw speed stat.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Gwynbleidd) {
    p = BYKNewProfile(id, "Gwynbleidd", "Items.Preset_Sword_Witcher", BYKFamilyBlade(), BYKFidelityTranscribed());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BonusDamageAgainstBosses, 10.0));
    p.note = "Kill-streak and low-health crit behaviour not included.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Sihil) {
    // Authored, unusually for a blade: Sihil is absent from the modding table and no reachable
    // source gives its modifiers. Its effect record Witcher_Sihil_Iconic exists in the game, so
    // the ripper can replace these.
    p = BYKNewProfile(id, "Sihil", "Items.Preset_Sword_Sihil", BYKFamilyBlade(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 8.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.25));
    // Sihil's actual effect: unlimited combo attacks for a while after dashing.
    p.dashWindowSeconds = 5.0;
    ArrayPush(p.dashWindowMods, BYKAdd(gamedataStatType.CanWeaponInfinitlyCombo, 1.0));
    p.note = "Dashing opens a combo window, which is Sihil's signature.";
    return p;
  }

  if id == EnumInt(EBYKProfile.ButchersCleaver) {
    // A blade by family even though the original is a knife, because what is being
    // transplanted is its behaviour, not its weapon class. Authored: the modding table has no
    // stat rows for any knife.
    p = BYKNewProfile(id, "Butcher's Cleaver", "Items.Preset_Butchers_Knife_Iconic", BYKFamilyBlade(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.25));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 14.0));
    // The original attacks faster and uses less stamina while the enemy is bleeding. "Is the
    // target bleeding" is not state this mod tracks, and with a bleed rate this high a kill is
    // a close stand-in for it, so the speed is offered on a kill window instead. Said plainly
    // in the note rather than passed off as the real condition.
    p.killWindowSeconds = 6.0;
    ArrayPush(p.killWindowMods, BYKMul(gamedataStatType.AttackSpeed, 1.15));
    ArrayPush(p.killWindowMods, BYKAdd(gamedataStatType.MantisBladesStaminaCostReduction, 0.25));
    p.note = "The original speeds up while the target bleeds. That condition is not tracked, so the speed is on a kill window instead.";
    return p;
  }

  // ---- Blunt, authored -------------------------------------------------
  //
  // Rates below are chosen against the one calibration point available: Byakko's
  // BleedingApplicationRate of 10 displays as +30% bleed chance at Tier 5. They are not the
  // game's values.

  if id == EnumInt(EBYKProfile.GoldPlatedBat) {
    p = BYKNewProfile(id, "Gold-Plated Baseball Bat", "Items.Preset_Baseball_Bat_Denny", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.25));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 12.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 10.0));
    return p;
  }
  if id == EnumInt(EBYKProfile.SasquatchHammer) {
    p = BYKNewProfile(id, "Sasquatch's Hammer", "Items.w_melee_boss_hammer", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.75));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 8.0));
    p.note = "The original trades stamina for damage. Only the armour penetration and stun carry over.";
    return p;
  }
  if id == EnumInt(EBYKProfile.TinkerBell) {
    p = BYKNewProfile(id, "Tinker Bell", "Items.sq021_peter_pan_baton", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.5));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 8.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectrocutedApplicationRate, 12.0));
    return p;
  }
  if id == EnumInt(EBYKProfile.CaretakersSpade) {
    p = BYKNewProfile(id, "Caretaker's Spade", "Items.Preset_Shovel_Caretaker", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.25));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 10.0));
    p.note = "Health return on kills not included.";
    return p;
  }
  if id == EnumInt(EBYKProfile.Cottonmouth) {
    p = BYKNewProfile(id, "Cottonmouth", "Items.Preset_Cane_Fingers", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.25));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 6.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectrocutedApplicationRate, 8.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.PoisonedApplicationRate, 8.0));
    return p;
  }
  if id == EnumInt(EBYKProfile.MurphysLaw) {
    p = BYKNewProfile(id, "Murphy's Law", "Items.Preset_Baton_Murphy", BYKFamilyBlunt(), BYKFidelityAuthored());
    ArrayPush(p.mods, BYKAdd(gamedataStatType.CanWeaponIgnoreArmor, 0.5));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.BleedingApplicationRate, 6.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.StunApplicationRate, 6.0));
    ArrayPush(p.mods, BYKAdd(gamedataStatType.ElectrocutedApplicationRate, 6.0));
    return p;
  }

  return null;
}

// Highest profile id the registry knows. Used by the ripper to walk them all.
public func BYKLastProfileId() -> Int32 = 17

public func BYKProfileFidelityName(fidelity: Int32) -> String {
  if fidelity == BYKFidelityTranscribed() {
    return "from the game's own data";
  }
  return "approximated, not the game's values";
}

public func BYKProfileConditionName(condition: Int32) -> String {
  if condition == BYKCondCamo() {
    return "Optical Camo";
  }
  if condition == BYKCondSandevistan() {
    return "Sandevistan";
  }
  return "none";
}

// Is this condition true right now?
public func BYKConditionHolds(game: GameInstance, condition: Int32) -> Bool {
  if condition == BYKCondCamo() {
    return BYKCamoActive(game);
  }
  if condition == BYKCondSandevistan() {
    return BYKSandevistanActive(game);
  }
  return false;
}
