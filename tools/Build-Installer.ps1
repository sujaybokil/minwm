param(
    [string]$AutoHotkeyPath = "",
    [string]$InnoCompilerPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'VERSION')).Trim()
$autoHotkeyVersion = (Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'AUTOHOTKEY_VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "VERSION must contain a semantic version such as 0.1.0."
}

if (!$AutoHotkeyPath) {
    $AutoHotkeyPath = & (Join-Path $PSScriptRoot 'Get-AutoHotkeyPath.ps1')
}
if (!(Test-Path -LiteralPath $AutoHotkeyPath)) {
    throw "AutoHotkey v2 was not found. Install it with Scoop or pass -AutoHotkeyPath."
}
$actualAutoHotkeyVersion =
    [System.Diagnostics.FileVersionInfo]::GetVersionInfo($AutoHotkeyPath).ProductVersion
if ([version]$actualAutoHotkeyVersion -lt [version]$autoHotkeyVersion -or
    [version]$actualAutoHotkeyVersion -ge [version]'3.0') {
    throw "AutoHotkey $autoHotkeyVersion or newer v2 is required; found $actualAutoHotkeyVersion."
}

& (Join-Path $PSScriptRoot 'New-MinwmIcon.ps1')
& (Join-Path $PSScriptRoot 'Test.ps1') -AutoHotkeyPath $AutoHotkeyPath

if (!$InnoCompilerPath) {
    $command = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($command) {
        $InnoCompilerPath = $command.Source
    } elseif (Test-Path -LiteralPath 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe') {
        $InnoCompilerPath = 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
    }
}
if (!(Test-Path -LiteralPath $InnoCompilerPath)) {
    throw "Inno Setup 6 was not found. Install it, then run this script again or pass -InnoCompilerPath."
}

& $InnoCompilerPath "/DMyAppVersion=$version" (Join-Path $projectRoot 'installer\minwm.iss')
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE."
}

Write-Host "Built minwm $version installer at $(Join-Path $projectRoot 'dist\minwm-setup.exe')"
