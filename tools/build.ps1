<#
.SYNOPSIS
  Builds the White Tiger release archive.

.DESCRIPTION
  - Writes the version into src/r6/scripts/WhiteTiger/Core/Version.reds.
  - Fails the build if any .reds file still contains the marker TODO-RELEASE.
  - Produces dist/WhiteTiger-<Version>.zip laid out from the game root, so it installs
    with Vortex or by extracting over the Cyberpunk 2077 folder:

      r6/scripts/WhiteTiger/...
      r6/tweaks/WhiteTiger/...

.PARAMETER Version
  Semantic version, e.g. 1.0.0.

.PARAMETER GameDir
  Optional. When given, the mod is compile-validated against that install before packaging,
  and the build fails if it does not compile.

.EXAMPLE
  ./tools/build.ps1 -Version 0.1.0 -GameDir "D:\SteamLibrary\steamapps\common\Cyberpunk 2077"
#>
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^\d+\.\d+\.\d+$')]
  [string]$Version,
  [string]$GameDir
)

$ErrorActionPreference = 'Stop'

$root    = Split-Path -Parent $PSScriptRoot
$srcDir  = Join-Path $root 'src'
$distDir = Join-Path $root 'dist'
$verFile = Join-Path $srcDir 'r6/scripts/WhiteTiger/Core/Version.reds'

# --- version code: major*10000 + minor*100 + patch -------------------------
$parts = $Version.Split('.')
$code  = [int]$parts[0] * 10000 + [int]$parts[1] * 100 + [int]$parts[2]

# --- release-blocker check -------------------------------------------------
Write-Host "Checking for TODO-RELEASE markers..."
$offenders = Get-ChildItem -Path $srcDir -Recurse -Filter *.reds |
  Select-String -Pattern 'TODO-RELEASE' -List
if ($offenders) {
  $offenders | ForEach-Object { Write-Host "  $($_.Path)" }
  throw "Build aborted: TODO-RELEASE marker(s) present."
}

# --- compile gate ----------------------------------------------------------
# A release that does not compile takes the whole script layer down with it on launch, so
# this is checked before anything is packaged rather than after.
if ($GameDir) {
  Write-Host "Validating against $GameDir ..."
  & (Join-Path $PSScriptRoot 'validate.ps1') -GameDir $GameDir
  if ($LASTEXITCODE -ne 0) { throw "Build aborted: the mod does not compile." }
}

# --- stamp the version -----------------------------------------------------
# Read/write as UTF-8 without BOM via .NET so the file's encoding is preserved. Windows
# PowerShell 5.1's Get-Content/Set-Content would add a BOM, which the redscript compiler
# should not have to tolerate.
Write-Host "Stamping version $Version (code $code) into Version.reds..."
$verText = [System.IO.File]::ReadAllText($verFile)
$verText = [regex]::Replace($verText, 'WhiteTigerVersion\(\) -> String = "[^"]*"', "WhiteTigerVersion() -> String = `"$Version`"")
$verText = [regex]::Replace($verText, 'WhiteTigerVersionCode\(\) -> Int32 = \d+', "WhiteTigerVersionCode() -> Int32 = $code")
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($verFile, $verText, $utf8NoBom)

# --- package ---------------------------------------------------------------
# Zip with forward-slash entry paths so mod managers (Vortex) and every extractor read the
# game-root layout correctly. Windows PowerShell 5.1's Compress-Archive writes backslash
# separators, which some extractors flatten into a single folder, so the archive is built
# explicitly with System.IO.Compression instead.
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-ModZip {
  param([string]$SourceDir, [string]$ZipPath)
  if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
  $base = (Resolve-Path $SourceDir).Path.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
      $rel = $_.FullName.Substring($base.Length) -replace '\\', '/'
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
        $zip, $_.FullName, $rel, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
  } finally {
    $zip.Dispose()
  }
}

if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir | Out-Null }

$mainZip = Join-Path $distDir "WhiteTiger-$Version.zip"
Write-Host "Packaging $mainZip..."
New-ModZip -SourceDir $srcDir -ZipPath $mainZip

Write-Host "Done. Output in $distDir"
