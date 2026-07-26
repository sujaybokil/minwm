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

function Invoke-AutoHotkey([string[]]$Arguments, [string]$FailureMessage) {
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $AutoHotkeyPath
    $startInfo.UseShellExecute = $false
    foreach ($argument in $Arguments) {
        [void]$startInfo.ArgumentList.Add($argument)
    }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    [void]$process.Start()
    $process.WaitForExit()
    if ($process.ExitCode -ne 0) {
        throw "$FailureMessage with exit code $($process.ExitCode)."
    }
}

Invoke-AutoHotkey `
    @('/force', '/ErrorStdOut', '/Validate', (Join-Path $projectRoot 'minwm.ahk')) `
    'AutoHotkey syntax validation failed'

Invoke-AutoHotkey `
    @('/force', '/ErrorStdOut', (Join-Path $projectRoot 'minwm.ahk'), '--check') `
    'Module and configuration smoke test failed'

Invoke-AutoHotkey `
    @('/force', '/ErrorStdOut', (Join-Path $projectRoot 'tests\geometry-tests.ahk')) `
    'Unit tests failed'

Write-Host "Validation and unit tests passed with AutoHotkey $actualVersion."
