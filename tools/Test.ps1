[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$AutoHotkeyPath) {
    $AutoHotkeyPath = & (Join-Path $PSScriptRoot 'Get-AutoHotkeyPath.ps1')
}
if (!(Test-Path -LiteralPath $AutoHotkeyPath)) {
    throw "AutoHotkey v2 was not found. Install it with Scoop or pass -AutoHotkeyPath."
}

$requiredVersion = (Get-Content -Raw `
    -LiteralPath (Join-Path $projectRoot 'AUTOHOTKEY_VERSION')).Trim()
$actualVersion =
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($AutoHotkeyPath).ProductVersion
if ([version]$actualVersion -lt [version]$requiredVersion -or
    [version]$actualVersion -ge [version]'3.0') {
    throw "AutoHotkey $requiredVersion or newer v2 is required; found $actualVersion."
}

& $AutoHotkeyPath /force /ErrorStdOut /Validate (Join-Path $projectRoot 'minwm.ahk')
if ($LASTEXITCODE -ne 0) {
    throw "AutoHotkey syntax validation failed with exit code $LASTEXITCODE."
}

& $AutoHotkeyPath /force /ErrorStdOut (Join-Path $projectRoot 'minwm.ahk') --check
if ($LASTEXITCODE -ne 0) {
    throw "Module and configuration smoke test failed with exit code $LASTEXITCODE."
}

& $AutoHotkeyPath /force /ErrorStdOut (Join-Path $projectRoot 'tests\geometry-tests.ahk')
if ($LASTEXITCODE -ne 0) {
    throw "Unit tests failed with exit code $LASTEXITCODE."
}

Write-Host "Validation and unit tests passed with AutoHotkey $actualVersion."
