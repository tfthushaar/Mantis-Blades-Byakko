// Byakko - Localization, via Codeware localization.
//
// This file carries a module header so it can import Codeware's localization types. The
// provider registers itself (ModLocalizationProvider queues its own registration), so
// nothing has to call into here. Keys follow Byakko-<Id>.
//
// English is the fallback. A translator adds a package and a branch in GetPackage.

module Byakko.Localization

import Codeware.Localization.*

public class BYKLocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    if Equals(language, n"en-us") {
      return new BYKLocalizationEnUs();
    }
    return null;
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class BYKLocalizationEnUs extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    // ---- Categories -----------------------------------------------------
    this.Text("Byakko-Category-General", "General");
    this.Text("Byakko-Category-Burst", "On-kill burst");
    this.Text("Byakko-Category-Profiles", "Iconic profiles");
    this.Text("Byakko-Category-Dash", "Dash combo (Sihil)");
    this.Text("Byakko-Category-Resting", "Resting attack speed");
    this.Text("Byakko-Category-Diagnostics", "Diagnostics");

    // ---- General --------------------------------------------------------
    this.Text("Byakko-Enabled", "Enable the overhaul");
    this.Text("Byakko-Enabled-Desc",
      "Master switch. Off removes every stat change the mod applies, immediately. The data layer (reach, leap, bleed, armour penetration) is TweakXL and stays until the mod is uninstalled.");

    // ---- Burst ----------------------------------------------------------
    this.Text("Byakko-BurstEnabled", "Burst on kill");
    this.Text("Byakko-BurstEnabled-Desc",
      "Killing an enemy with the blades opens a short window of extra attack speed. Killing again inside it starts the window over.");

    this.Text("Byakko-BurstMult", "Burst attack speed");
    this.Text("Byakko-BurstMult-Desc",
      "Attack speed multiplier during the window. 1.175 is the Byakko's reported +17.5%. Note that vanilla discards melee attack speed above 200% unless Melee Attack Speed Cap Fix is installed.");

    this.Text("Byakko-BurstSeconds", "Burst duration (seconds)");
    this.Text("Byakko-BurstSeconds-Desc",
      "How long the window lasts after a kill. 10 seconds is the Byakko's reported duration. The clock pauses in menus.");

    this.Text("Byakko-BurstCombo", "Remove light combo pause");
    this.Text("Byakko-BurstCombo-Desc",
      "During the window, remove the pause between light attack combos, which is the other half of the Byakko's iconic. This is the part you feel most, and it keeps working even on patches where arm cyberware ignores attack speed.");

    this.Text("Byakko-BurstPlayer", "Also buff V, not just the blades");
    this.Text("Byakko-BurstPlayer-Desc",
      "Apply the burst to V as well as to the blades. On by default: it is not certain which of the two the melee animation reads for arm cyberware on every patch, and covering both costs nothing. Turn off if it conflicts with another melee mod.");

    this.Text("Byakko-BurstToast", "Show a message on burst");
    this.Text("Byakko-BurstToast-Desc",
      "Print a short line on screen when the window opens or refreshes. Off by default - useful while tuning, noisy in a fight.");

    // ---- Resting --------------------------------------------------------
    // ---- Profiles -------------------------------------------------------
    this.Text("Byakko-ProfilesEnabled", "Enable iconic profiles");
    this.Text("Byakko-ProfilesEnabled-Desc",
      "Put an iconic melee weapon's stats onto your cyberarms. Turn this off to leave your arms with only the mod's own effects.");

    this.Text("Byakko-MantisProfile", "Mantis Blades profile");
    this.Text("Byakko-MantisProfile-Desc",
      "Which iconic's stats your Mantis Blades carry. The blade profiles are transcribed from the game's own data. The blunt ones are approximations of described effects, because no source gives their real values, and the readout tells you which is which.");

    this.Text("Byakko-GorillaProfile", "Gorilla Arms profile");
    this.Text("Byakko-GorillaProfile-Desc",
      "Which iconic's stats your Gorilla Arms carry. Katanas are deliberately offered here too: there are only a handful of iconic blunt weapons, and the blade stats transplant perfectly well.");

    this.Text("Byakko-Transplant", "Transplant real iconic abilities");
    this.Text("Byakko-Transplant-Desc",
      "Hands your cyberarm the iconic's actual ability package instead of an imitation of it. Only three melee iconics in the game carry one: Sihil, Gwynbleidd and Sasquatch's Hammer. Off by default, because a package's contents cannot be read from script, so this is the one part of the mod that applies something it cannot fully inspect. It is removed when you put the arm away, change profile, or load a save.");

    this.Text("Byakko-AllowNerf", "Allow damage reductions");
    this.Text("Byakko-AllowNerf-Desc",
      "Some iconics carry a damage multiplier below 1.0, balanced against the rest of their kit. Satori, Errata and Cocktail Stick are all x0.9. Off by default, so picking a profile for its bleed does not quietly cost you damage. Turn on for the full transplant.");

    // ---- Dash window ----------------------------------------------------
    this.Text("Byakko-DashEnabled", "Combo after dashing");
    this.Text("Byakko-DashEnabled-Desc",
      "Sihil's effect: dashing gives you unlimited combo attacks for a few seconds, with the pause between light attacks removed. Dodging counts as dashing, since the Dash perk is what turns one into the other. Works on both Mantis Blades and Gorilla Arms.");

    this.Text("Byakko-DashSeconds", "Dash combo duration (seconds)");
    this.Text("Byakko-DashSeconds-Desc",
      "How long the window lasts after a dash, refreshed by dashing again. The in-game effect gives no number, so 5 seconds is a judgement call rather than a measured value.");

    this.Text("Byakko-DashSpeed", "Dash combo attack speed");
    this.Text("Byakko-DashSpeed-Desc",
      "Extra attack speed during the dash window, on top of removing the combo pause. 1.0 means none, which is the default: speed here stacks with the on-kill burst, and two multipliers on the same stat is what breaks the attack animations. Held under the animation ceiling either way.");

    this.Text("Byakko-RestingEnabled", "Lift resting attack speed");
    this.Text("Byakko-RestingEnabled-Desc",
      "Bring the blades up to a target attack speed while they are equipped, so the burst starts from a katana-like baseline rather than a slow one.");

    this.Text("Byakko-RestingSpeed", "Resting attack speed target");
    this.Text("Byakko-RestingSpeed-Desc",
      "The attack speed the blades are brought up to. Held under the animation ceiling below, so raising this past that has no effect until you raise the ceiling too. This only ever speeds the blades up: if your build is already faster than the target, nothing is applied.");

    this.Text("Byakko-SpeedCeiling", "Animation ceiling");
    this.Text("Byakko-SpeedCeiling-Desc",
      "Highest attack speed the blades will be pushed to, by the resting lift and the burst together. Mantis Blade light attacks alternate arms through a chain held in the animation graph, and push the speed far enough past it and the chain stops advancing, so V slashes with the same arm over and over. Vanilla clamps melee attack speed to 2.0 for what is probably this reason; a cap-raising mod removes that clamp, which is why this exists. The default of 2.2 takes most of the headroom while staying clear of where the problem was reported. If same-arm slashing turns up, bring this down. Set to 0 to switch the limiting off entirely.");

    // ---- Diagnostics ----------------------------------------------------
    this.Text("Byakko-DiagEnabled", "Enable diagnostic key");
    this.Text("Byakko-DiagEnabled-Desc",
      "Let the diagnostic key print the blades' live stats on screen and to the log.");

    this.Text("Byakko-DiagKey", "Diagnostic key");
    this.Text("Byakko-DiagKey-Desc",
      "Equip the blades and press this to see what the game actually reports: both attack speed stats, whether the data layer landed, whether you are over the vanilla melee cap, and whether a burst is live.");

    this.Text("Byakko-RipKey", "Read iconic stats key");
    this.Text("Byakko-RipKey-Desc",
      "Writes every iconic's real stat modifiers, read from the game's own data, to the redscript log. The blade profiles here are transcribed from modding documentation and the blunt ones are approximations, so this is how you check them against what the game actually has.");

    this.Text("Byakko-LogLevel", "Log level");
    this.Text("Byakko-LogLevel-Desc",
      "How much this mod writes to the redscript log. Verbose logs every burst refresh.");
  }
}
