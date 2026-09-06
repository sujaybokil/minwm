# Builds the minwm setup executable.
param(
    [string]$AutoHotkeyPath = "",
    [string]$InnoCompilerPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$virtualDesktopDependencyPath = Join-Path $projectRoot 'dependencies\virtualdesktop'
$virtualDesktopFiles = @{
    'VirtualDesktop11.exe' = 'F6532DB79F6F0E4018CE77F08805D3FD3F7BB076CBFBAC0AC8189FE5376D9E82'
    'VirtualDesktop11-24H2.exe' = '8334B529D19E71662950821C91ED996A0E92DF41C8D0A077E95151AA7041CB35'
}
& (Join-Path $PSScriptRoot 'prepare-dependencies.ps1')
foreach ($file in $virtualDesktopFiles.GetEnumerator()) {
    $path = Join-Path $virtualDesktopDependencyPath $file.Key
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($hash -ne $file.Value) { throw "VirtualDesktop dependency hash mismatch: $path" }
}
$version = (Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'VERSION')).Trim()
$autoHotkeyVersion = (Get-Content -Raw -LiteralPath (Join-Path $projectRoot 'AUTOHOTKEY_VERSION')).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "VERSION must contain a semantic version such as 0.1.0."
}

if (!$AutoHotkeyPath) {
    $AutoHotkeyPath = & (Join-Path $PSScriptRoot 'get-autohotkey-path.ps1')
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

& (Join-Path $PSScriptRoot 'new-minwm-icon.ps1')
& (Join-Path $PSScriptRoot 'tests.ps1') -AutoHotkeyPath $AutoHotkeyPath

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
