$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$installDirectories = @()
$scoopCurrent = Join-Path $env:USERPROFILE 'scoop\apps\autohotkey\current'
if (Test-Path -LiteralPath $scoopCurrent) {
    $installDirectories += $scoopCurrent
}
foreach ($registryPath in @(
    'HKCU:\SOFTWARE\AutoHotkey',
    'HKLM:\SOFTWARE\AutoHotkey',
    'HKLM:\SOFTWARE\WOW6432Node\AutoHotkey'
)) {
    $registration = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
    if ($registration -and $registration.InstallDir) {
        $installDirectories += [string]$registration.InstallDir
    }
}

$installDirectories += @(
    (Join-Path $env:LOCALAPPDATA 'Programs\AutoHotkey'),
    (Join-Path $env:ProgramFiles 'AutoHotkey')
)

foreach ($directory in ($installDirectories | Select-Object -Unique)) {
    foreach ($relativePath in @(
        'v2\AutoHotkey64.exe',
        'AutoHotkey64.exe'
    )) {
        $candidate = Join-Path $directory $relativePath
        if (Test-Path -LiteralPath $candidate) {
            (Resolve-Path -LiteralPath $candidate).Path
            return
        }
    }

    $versionDirectories = Get-ChildItem -LiteralPath $directory `
        -Directory -Filter 'v2*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending
    foreach ($versionDirectory in $versionDirectories) {
        $candidate = Join-Path $versionDirectory.FullName 'AutoHotkey64.exe'
        if (Test-Path -LiteralPath $candidate) {
            (Resolve-Path -LiteralPath $candidate).Path
            return
        }
    }

    $launcher = Join-Path $directory 'AutoHotkey.exe'
    if (Test-Path -LiteralPath $launcher) {
        (Resolve-Path -LiteralPath $launcher).Path
        return
    }
}

$command = Get-Command AutoHotkey.exe -ErrorAction SilentlyContinue
if ($command) {
    $command.Source
    return
}

throw 'AutoHotkey v2 was not found. Install it from https://www.autohotkey.com/.'
