<#
.SYNOPSIS
  Build a hardened, obfuscated release App Bundle for the Play Store.

.DESCRIPTION
  Runs `flutter build appbundle` with Dart obfuscation enabled. Obfuscation
  mangles class/method/field names in the compiled Dart so the app's logic is
  far harder to reverse-engineer. (It does NOT hide Firebase API keys - those
  are public client identifiers by design; security comes from Firestore rules
  + Firebase Auth + App Check, not from secrecy.)

  Obfuscation renames everything, so crash stack traces become unreadable
  symbols. The matching symbol files are written to debug-symbols/<version>/
  and are COMMITTED to the repo (small, ~15 MB/release) so a release's crash
  reports can always be decoded. After building, just commit the new folder.

.PARAMETER Flavor
  Build flavor (default: prod).

.EXAMPLE
  ./scripts/build_release.ps1
  ./scripts/build_release.ps1 -Flavor prod
#>
param(
  [string]$Flavor = "prod"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

# Derive version from pubspec (e.g. "1.0.0+3") for the symbol folder name.
$versionLine = (Get-Content "$repoRoot/pubspec.yaml" | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
$version = ($versionLine -replace '^version:\s*', '').Trim()
if ([string]::IsNullOrWhiteSpace($version)) { $version = "unversioned" }
$safeVersion = $version -replace '[^0-9A-Za-z._+-]', '_'

$symbolDir = Join-Path $repoRoot "debug-symbols/$safeVersion"
New-Item -ItemType Directory -Force -Path $symbolDir | Out-Null

Write-Host "Building obfuscated release App Bundle" -ForegroundColor Cyan
Write-Host "  flavor : $Flavor"
Write-Host "  version: $version"
Write-Host "  symbols: $symbolDir"
Write-Host ""

flutter build appbundle `
  --release `
  --flavor $Flavor `
  --obfuscate `
  --split-debug-info="$symbolDir"

if ($LASTEXITCODE -ne 0) {
  Write-Host "Build FAILED (exit $LASTEXITCODE)." -ForegroundColor Red
  exit $LASTEXITCODE
}

$aab = "$repoRoot/build/app/outputs/bundle/${Flavor}Release/app-$Flavor-release.aab"
Write-Host ""
if (Test-Path $aab) {
  $sizeMb = [math]::Round((Get-Item $aab).Length / 1MB, 1)
  Write-Host "Built: $aab ($sizeMb MB)" -ForegroundColor Green
} else {
  Write-Host "Build reported success but the .aab was not found at $aab" -ForegroundColor Yellow
}
Write-Host "Symbols saved to: $symbolDir" -ForegroundColor Green
Write-Host "Next: archive debug-symbols/$safeVersion privately (it is git-ignored; never publish it - it reverses --obfuscate)." -ForegroundColor Yellow
