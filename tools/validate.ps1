<#
.SYNOPSIS
  Compile-validates the Byakko redscript against an installed Cyberpunk 2077.

.DESCRIPTION
  Builds an isolated sandbox containing the mod plus its redscript dependencies
  (Codeware and Mod Settings, read from the game's RED4ext plugins) and compiles
  it with the game's own scc.exe against a private copy of the vanilla script
  cache. Nothing in the game folder is modified. Prints any compile errors.

  Use -ExtraDir to compile a throwaway probe module alongside the mod, which is how
  an uncertain API call is confirmed to exist without launching the game.

.PARAMETER GameDir
  Path to the Cyberpunk 2077 install (the folder containing bin, r6, engine).

.PARAMETER ExtraDir
  Optional extra script folder to compile alongside the mod (probe modules).

.PARAMETER OnlyExtra
  Compile only -ExtraDir, leaving the mod itself out. Useful when probing an API
  before any of the mod exists.

.PARAMETER WithoutModSettings
  Compile as if Mod Settings were not installed. Should still succeed, because every call
  into it is isolated behind ModuleExists.

.PARAMETER WithoutCodeware
  Compile as if Codeware were not installed. Expected to fail: Codeware is a hard
  requirement.

.PARAMETER DependencyMatrix
  Compile all four dependency combinations and check each behaves as documented. A missing
  dependency fails the whole redscript compile and takes every script mod down with it, so
  this is worth re-checking whenever the dependency surface changes.

.EXAMPLE
  ./tools/validate.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077"

.EXAMPLE
  ./tools/validate.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077" -DependencyMatrix
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$GameDir,
  [string]$ExtraDir,
  [switch]$OnlyExtra,
  [switch]$WithoutModSettings,
  [switch]$WithoutCodeware,
  [switch]$DependencyMatrix
)

$ErrorActionPreference = 'Stop'

$root      = Split-Path -Parent $PSScriptRoot
$src       = Join-Path $root 'src/r6/scripts/Byakko'
$scc       = Join-Path $GameDir 'engine/tools/scc.exe'
$vanilla   = Join-Path $GameDir 'r6/cache/final.redscripts'
$cwScripts = Join-Path $GameDir 'red4ext/plugins/Codeware/Scripts'
$msDir     = Join-Path $GameDir 'red4ext/plugins/mod_settings'

foreach ($p in @($scc, $vanilla, $cwScripts, $msDir)) {
  if (-not (Test-Path $p)) { throw "Required path not found: $p" }
}

# One compile in a throwaway sandbox. Returns $true when it produced a cache.
function Invoke-SccCompile {
  param([bool]$Codeware, [bool]$ModSettings, [bool]$Quiet)
  $sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ("byakko-validate-" + [Guid]::NewGuid().ToString('N'))
  $scriptsDir = Join-Path $sandbox 'scripts'
  try {
    New-Item -ItemType Directory -Path $scriptsDir -Force | Out-Null
    if ($Codeware) { Copy-Item $cwScripts (Join-Path $scriptsDir 'Codeware') -Recurse }
    if ($ModSettings) {
      New-Item -ItemType Directory -Path (Join-Path $scriptsDir 'mod_settings') -Force | Out-Null
      Copy-Item (Join-Path $msDir '*.reds') (Join-Path $scriptsDir 'mod_settings')
    }
    if (-not $OnlyExtra) {
      if (-not (Test-Path $src)) { throw "Mod source not found: $src" }
      Copy-Item $src (Join-Path $scriptsDir 'Byakko') -Recurse
    }
    if ($ExtraDir) {
      if (-not (Test-Path $ExtraDir)) { throw "ExtraDir not found: $ExtraDir" }
      Copy-Item $ExtraDir (Join-Path $scriptsDir (Split-Path -Leaf $ExtraDir)) -Recurse
    }
    $base = Join-Path $sandbox 'base.redscripts'
    Copy-Item $vanilla $base
    $outCache = Join-Path $sandbox 'out.redscripts'
    # scc is ALWAYS run with its output redirected to files, never into a PowerShell pipeline.
    #
    # Two separate hangs and one false failure came out of doing it the other way:
    #
    #   - `2>&1` on a native command in Windows PowerShell 5.1 wraps each stderr line in an
    #     ErrorRecord, and under ErrorActionPreference = Stop that turns the compiler's first
    #     progress line into a terminating error. That produced compile "failures" a plain
    #     build did not reproduce.
    #   - Piping scc into anything that stops early, such as `Select-Object -First n`, stops
    #     draining its output. scc then blocks on a full pipe buffer and never exits: the
    #     process sits at zero CPU forever and the build appears to hang.
    #
    # Redirecting to files cannot do either, whatever the caller does with this script's own
    # output, so the footgun is gone rather than merely documented.
    $outLog = Join-Path $sandbox 'scc.out'
    $errLog = Join-Path $sandbox 'scc.err'
    Start-Process -FilePath $scc -ArgumentList @('-compile', $scriptsDir, '-outputCacheFile', $outCache, $base) `
      -NoNewWindow -Wait -RedirectStandardOutput $outLog -RedirectStandardError $errLog | Out-Null

    $produced = Test-Path $outCache
    $logLines = @()
    foreach ($f in @($outLog, $errLog)) {
      if (Test-Path $f) { $logLines += @(Get-Content -Path $f) }
    }
    if ($Quiet) {
      if (-not $produced) {
        $logLines | Where-Object { $_ -match 'ERROR|unresolved|syntax' } |
          Select-Object -First 4 | ForEach-Object { Write-Host ("      " + $_.Trim()) }
      }
    } else {
      # Print the compiler's own diagnostics, which is what the caller came for.
      #
      # Print every line once an error has been seen rather than matching on keywords. scc puts
      # the location on one line and the reason on the next, and a keyword filter keeps the
      # location while dropping the reason. A TYPE_ERR's reason is the half that matters: it
      # names the type that was expected and the type that was found, which is the only way to
      # discover an unfamiliar return type from script. The old filter cost a full compile cycle
      # every time one of those came up, having already hidden a real error once.
      $seen = $false
      foreach ($line in $logLines) {
        if ($line -match 'ERROR|WARN') { $seen = $true }
        if ($seen -and $line.Trim().Length -gt 0) { Write-Host $line.Trim() }
      }
    }
    return $produced
  }
  finally {
    if (Test-Path $sandbox) { Remove-Item $sandbox -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

# The dependency matrix.
#
# A missing dependency is not a quiet failure: an unresolved reference fails the whole
# redscript compile, which takes down every script mod the player has, with a message naming
# Byakko as the cause. Mod Settings is therefore isolated behind ModuleExists and must keep
# compiling without it. Codeware is a genuine hard requirement, because the localization
# provider needs a module-level import and redscript cannot guard an import or name a type by
# its qualified path. Both of those limits were established against this compiler, not assumed.
if ($DependencyMatrix) {
  $cases = @(
    @{ Name = 'Codeware + Mod Settings (shipping config)'; CW = $true;  MS = $true;  Expect = $true  },
    @{ Name = 'Codeware only, no Mod Settings';            CW = $true;  MS = $false; Expect = $true  },
    @{ Name = 'Mod Settings only, no Codeware';            CW = $false; MS = $true;  Expect = $false },
    @{ Name = 'neither';                                   CW = $false; MS = $false; Expect = $false }
  )
  $bad = 0
  foreach ($c in $cases) {
    $got = Invoke-SccCompile -Codeware $c.CW -ModSettings $c.MS -Quiet $true
    if ($got) { $okText = 'compiles' } else { $okText = 'fails' }
    if ($got -eq $c.Expect) {
      Write-Host ("  as expected ({0,-8}) : {1}" -f $okText, $c.Name) -ForegroundColor Green
    } else {
      Write-Host ("  UNEXPECTED  ({0,-8}) : {1}" -f $okText, $c.Name) -ForegroundColor Red
      $bad++
    }
  }
  if ($bad -gt 0) { throw "$bad dependency case(s) did not behave as documented." }
  Write-Host "`nOK: dependency matrix behaves as documented." -ForegroundColor Green
  # Explicit, because the expected-to-fail cases leave scc.exe's non-zero code behind and the
  # script would otherwise inherit it and look like it had failed.
  exit 0
}

Write-Host "Compiling against $vanilla ..."
if (Invoke-SccCompile -Codeware (-not $WithoutCodeware) -ModSettings (-not $WithoutModSettings) -Quiet $false) {
  Write-Host "`nOK: Byakko compiles cleanly against this game version." -ForegroundColor Green
  exit 0
} else {
  throw "Compilation failed (no output produced). See the errors above."
}
