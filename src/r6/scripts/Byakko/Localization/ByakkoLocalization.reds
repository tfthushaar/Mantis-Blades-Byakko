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
    this.Text("Byakko-RestingEnabled", "Lift resting attack speed");
    this.Text("Byakko-RestingEnabled-Desc",
      "Bring the blades up to a target attack speed while they are equipped, so the burst starts from a katana-like baseline rather than a slow one.");

    this.Text("Byakko-RestingSpeed", "Resting attack speed target");
    this.Text("Byakko-RestingSpeed-Desc",
      "The attack speed the blades are brought up to. 2.1 is the Byakko's. This only ever speeds the blades up - if your build is already faster than the target, nothing is applied.");

    // ---- Diagnostics ----------------------------------------------------
    this.Text("Byakko-DiagEnabled", "Enable diagnostic key");
    this.Text("Byakko-DiagEnabled-Desc",
      "Let the diagnostic key print the blades' live stats on screen and to the log.");

    this.Text("Byakko-DiagKey", "Diagnostic key");
    this.Text("Byakko-DiagKey-Desc",
      "Equip the blades and press this to see what the game actually reports: both attack speed stats, whether the data layer landed, whether you are over the vanilla melee cap, and whether a burst is live.");

    this.Text("Byakko-LogLevel", "Log level");
    this.Text("Byakko-LogLevel-Desc",
      "How much this mod writes to the redscript log. Verbose logs every burst refresh.");
  }
}
