<#
.SYNOPSIS
  Decode an obfuscated Flutter (Dart) crash stack trace into readable symbols.

.DESCRIPTION
  Release builds from build_release.ps1 are obfuscated, so crash traces from
  Crashlytics / Play Console / shared support logs come back as meaningless
  symbols. This wraps `flutter symbolize`, using the saved per-release symbol
  file in debug-symbols/<version>/ to turn them back into real names.

  IMPORTANT: you must use the symbol file from the SAME version + architecture
  the crash came from. Crashlytics shows the app version on each crash; the
  architecture is almost always arm64 for modern phones.

.PARAMETER TraceFile
  Path to a text file containing the raw obfuscated stack trace (copy it out
  of Crashlytics / the shared app_errors.log into a .txt file).

.PARAMETER Version
  Release version folder under debug-symbols/ (e.g. "1.0.0+20260424").
  Defaults to the version in pubspec.yaml.

.PARAMETER Arch
  CPU architecture of the crash: arm64 (default), arm, or x64.

.EXAMPLE
  ./scripts/symbolize.ps1 -TraceFile .\crash.txt
  ./scripts/symbolize.ps1 -TraceFile .\crash.txt -Version "1.0.0+20260424" -Arch arm64
#>
param(
  [Parameter(Mandatory = $true)]
  [string]$TraceFile,
  [string]$Version = "",
  [ValidateSet("arm64", "arm", "x64")]
  [string]$Arch = "arm64"
)

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

if (-not (Test-Path $TraceFile)) {
  Write-Host "Trace file not found: $TraceFile" -ForegroundColor Red
  exit 1
}

if ([string]::IsNullOrWhiteSpace($Version)) {
  $versionLine = (Get-Content "$repoRoot/pubspec.yaml" | Where-Object { $_ -match '^version:' } | Select-Object -First 1)
  $Version = ($versionLine -replace '^version:\s*', '').Trim()
}
$safeVersion = $Version -replace '[^0-9A-Za-z._+-]', '_'

$archFile = @{ "arm64" = "app.android-arm64.symbols"; "arm" = "app.android-arm.symbols"; "x64" = "app.android-x64.symbols" }[$Arch]
$symbolFile = Join-Path $repoRoot "debug-symbols/$safeVersion/$archFile"

if (-not (Test-Path $symbolFile)) {
  Write-Host "Symbol file not found: $symbolFile" -ForegroundColor Red
  Write-Host "Available versions:" -ForegroundColor Yellow
  Get-ChildItem (Join-Path $repoRoot "debug-symbols") -Directory -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  $($_.Name)" }
  exit 1
}

Write-Host "Symbolizing $TraceFile" -ForegroundColor Cyan
Write-Host "  version: $Version  arch: $Arch" -ForegroundColor Cyan
Write-Host ""

flutter symbolize -i "$TraceFile" -d "$symbolFile"
