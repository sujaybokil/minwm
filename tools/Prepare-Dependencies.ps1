[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent $PSScriptRoot
$dependencyDirectory = Join-Path $projectRoot 'dependencies\virtualdesktop'
$releaseBaseUrl = 'https://github.com/MScholtes/VirtualDesktop/releases/download/V1.21'
$files = @{
    'VirtualDesktop11.exe' = 'F6532DB79F6F0E4018CE77F08805D3FD3F7BB076CBFBAC0AC8189FE5376D9E82'
    'VirtualDesktop11-24H2.exe' = '8334B529D19E71662950821C91ED996A0E92DF41C8D0A077E95151AA7041CB35'
}

New-Item -ItemType Directory -Force -Path $dependencyDirectory | Out-Null
foreach ($file in $files.GetEnumerator()) {
    $path = Join-Path $dependencyDirectory $file.Key
    if (Test-Path -LiteralPath $path) {
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
        if ($hash -eq $file.Value) {
            Write-Host "Using verified dependency: $($file.Key)"
            continue
        }
        throw "Existing dependency hash mismatch: $path"
    }
    $uri = "$releaseBaseUrl/$($file.Key)"
    Write-Host "Downloading pinned optional dependency: $($file.Key)"
    Invoke-WebRequest -Uri $uri -OutFile $path
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash
    if ($hash -ne $file.Value) {
        Remove-Item -LiteralPath $path -Force
        throw "Downloaded dependency hash mismatch: $($file.Key)"
    }
}
