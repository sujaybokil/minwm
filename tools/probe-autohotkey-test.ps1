[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ScriptPath,
    [string]$AutoHotkeyPath = "",
    [int]$TimeoutSeconds = 15,
    [switch]$Force,
    [switch]$ValidateOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$scriptFullPath = [IO.Path]::GetFullPath((Join-Path $projectRoot $ScriptPath))
if (!(Test-Path -LiteralPath $scriptFullPath)) {
    throw "Test script was not found: $scriptFullPath"
}
if (!$AutoHotkeyPath) {
    $AutoHotkeyPath = & (Join-Path $PSScriptRoot 'get-autohotkey-path.ps1')
}

$reportDirectory = Join-Path $projectRoot 'test-results'
New-Item -ItemType Directory -Force -Path $reportDirectory | Out-Null
$stem = [IO.Path]::GetFileNameWithoutExtension($scriptFullPath)
$stdoutPath = Join-Path $reportDirectory "$stem.stdout.log"
$stderrPath = Join-Path $reportDirectory "$stem.stderr.log"
$reportPath = Join-Path $reportDirectory "$stem.probe.txt"
$includePath = Join-Path $reportDirectory "$stem.includes.ahk"
Remove-Item -LiteralPath $stdoutPath,$stderrPath,$reportPath,$includePath -ErrorAction SilentlyContinue

$arguments = @('/ErrorStdOut')
if ($Force) { $arguments += '/force' }
if ($ValidateOnly) { $arguments += @('/iLib', $includePath) }
$arguments += $scriptFullPath
$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $AutoHotkeyPath
$startInfo.WorkingDirectory = Split-Path -Parent $scriptFullPath
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in $arguments) { [void]$startInfo.ArgumentList.Add($argument) }

$process = [Diagnostics.Process]::new()
$process.StartInfo = $startInfo
[void]$process.Start()
$stdout = $process.StandardOutput.ReadToEndAsync()
$stderr = $process.StandardError.ReadToEndAsync()
$completed = $process.WaitForExit($TimeoutSeconds * 1000)
if (!$completed) {
    $process.Kill($true)
    $process.WaitForExit()
}
$stdout.Result | Set-Content -LiteralPath $stdoutPath -NoNewline
$stderr.Result | Set-Content -LiteralPath $stderrPath -NoNewline

$result = @(
    "script=$scriptFullPath"
    "arguments=$($arguments -join ' ')"
    "completed=$completed"
    "exitCode=$($process.ExitCode)"
    "stdout=$stdoutPath"
    "stderr=$stderrPath"
    "includes=$includePath"
)
$result | Set-Content -LiteralPath $reportPath
Get-Content -LiteralPath $reportPath
if (!$completed) { throw "AutoHotkey test timed out; see $reportPath" }
if ($process.ExitCode -ne 0) { throw "AutoHotkey test failed; see $reportPath" }
