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

$runningAutoHotkey = Get-Process -Name 'AutoHotkey*' -ErrorAction SilentlyContinue
if ($runningAutoHotkey) {
    throw 'Refusing to run integration test while an AutoHotkey process is running; minwm uses #SingleInstance Force.'
}

$resultsDirectory = Join-Path $projectRoot 'test-results'
New-Item -ItemType Directory -Force -Path $resultsDirectory | Out-Null
$logPath = Join-Path $resultsDirectory 'minwm-integration.log'
$configDirectory = Join-Path $resultsDirectory ('minwm-integration-config-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force -Path $configDirectory | Out-Null
Remove-Item -LiteralPath $logPath -ErrorAction SilentlyContinue

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $AutoHotkeyPath
$startInfo.WorkingDirectory = $projectRoot
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in @('/ErrorStdOut', '/force',
    (Join-Path $projectRoot 'minwm.ahk'), '--integration-test', '--config-directory', $configDirectory,
    '--log-path', $logPath)) {
    [void]$startInfo.ArgumentList.Add($argument)
}

$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
[void]$process.Start()
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
if (!$process.WaitForExit(10000)) {
    $process.Kill($true)
    $process.WaitForExit()
    throw 'Integration manager did not shut down within 10 seconds.'
}
$stdout.Result | Set-Content -LiteralPath (Join-Path $resultsDirectory 'minwm-integration.stdout.log') -NoNewline
$stderr.Result | Set-Content -LiteralPath (Join-Path $resultsDirectory 'minwm-integration.stderr.log') -NoNewline
if ($process.ExitCode -ne 0) {
    throw "Integration manager failed with exit code $($process.ExitCode)."
}

$log = Get-Content -Raw -LiteralPath $logPath -ErrorAction Stop
foreach ($message in @('minwm starting', 'Window refresh event tracking enabled',
    'integration test manager lifecycle completed', 'minwm exiting')) {
    if (!$log.Contains($message)) {
        throw "Integration manager log did not contain: $message"
    }
}
if ($log.Contains('Could not save layout state:')) {
    throw 'Integration manager could not persist its isolated layout state.'
}
Write-Host 'Reversible manager integration test passed.'
