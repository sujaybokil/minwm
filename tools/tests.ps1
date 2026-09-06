[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
if (!$AutoHotkeyPath) {
    $AutoHotkeyPath = & (Join-Path $PSScriptRoot 'get-autohotkey-path.ps1')
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

function Invoke-AutoHotkeyTest([string]$ScriptName) {
    $probePath = Join-Path $PSScriptRoot 'probe-autohotkey-test.ps1'
    & $probePath -ScriptPath $ScriptName `
        -AutoHotkeyPath $AutoHotkeyPath -Force -TimeoutSeconds 15
}

function Assert-VirtualDesktopInstallerOption {
    $installerPath = Join-Path $projectRoot 'installer\minwm.iss'
    $installer = Get-Content -Raw -LiteralPath $installerPath
    $taskLine = 'Name: "virtualdesktophelper"; Description: "Install direct virtual-desktop switching (recommended: no intermediate animations)"; GroupDescription: "Virtual desktops:"; Flags: checkablealone'
    if (!$installer.Contains($taskLine)) {
        throw 'Installer must expose the default-on virtual-desktop helper task with its rationale.'
    }
    if ($installer -match 'Name: "virtualdesktophelper"[^\r\n]*Flags: [^\r\n]*\bunchecked\b') {
        throw 'Virtual-desktop helper task must default to selected.'
    }
    foreach ($file in @('VirtualDesktop11.exe', 'VirtualDesktop11-24H2.exe')) {
        if (!$installer.Contains("dependencies\virtualdesktop\$file") -or
            !$installer.Contains('Tasks: virtualdesktophelper')) {
            throw "Installer must conditionally package the VirtualDesktop dependency: $file"
        }
    }
    if (!$installer.Contains('licenses\LICENSE-VirtualDesktop.txt') -or
        !$installer.Contains('Tasks: virtualdesktophelper')) {
        throw 'Installer must conditionally package the VirtualDesktop license.'
    }
    if (!$installer.Contains("if not WizardIsTaskSelected('virtualdesktophelper') then") -or
        !$installer.Contains('DeleteFile(ExpandConstant(''{app}\bin\VirtualDesktop11.exe''));') -or
        !$installer.Contains('DeleteFile(ExpandConstant(''{app}\bin\VirtualDesktop11-24H2.exe''));')) {
        throw 'Installer must remove an existing helper when an upgrade deselects it.'
    }
}

Assert-VirtualDesktopInstallerOption

Invoke-AutoHotkeyTest 'minwm-check.ahk'
Invoke-AutoHotkeyTest 'minwm-tests.ahk'
& (Join-Path $PSScriptRoot 'integration-test.ps1') -AutoHotkeyPath $AutoHotkeyPath

Write-Host "Validation, unit, and integration tests passed with AutoHotkey $actualVersion."
