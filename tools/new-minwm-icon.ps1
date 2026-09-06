param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\assets\minwm.ico')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# A 32px icon showing a master pane and two stacked panes. It deliberately uses
# the same 4px outer and inner spacing as minwm's default visual language.
$resolvedOutput = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$parent = Split-Path -Parent $resolvedOutput
New-Item -ItemType Directory -Force -Path $parent | Out-Null

$size = 32
$xorBytes = $size * $size * 4
$andStride = [int]([Math]::Ceiling($size / 32.0) * 4)
$imageSize = 40 + $xorBytes + ($andStride * $size)
$stream = [System.IO.File]::Open($resolvedOutput, [System.IO.FileMode]::Create)
$writer = [System.IO.BinaryWriter]::new($stream)

try {
    # ICONDIR and its single ICONDIRENTRY.
    $writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]1)
    $writer.Write([byte]$size); $writer.Write([byte]$size); $writer.Write([byte]0); $writer.Write([byte]0)
    $writer.Write([UInt16]1); $writer.Write([UInt16]32); $writer.Write([UInt32]$imageSize); $writer.Write([UInt32]22)

    # BITMAPINFOHEADER. ICO height includes the XOR and AND bitmaps.
    $writer.Write([UInt32]40); $writer.Write([Int32]$size); $writer.Write([Int32]($size * 2))
    $writer.Write([UInt16]1); $writer.Write([UInt16]32); $writer.Write([UInt32]0); $writer.Write([UInt32]$xorBytes)
    $writer.Write([Int32]0); $writer.Write([Int32]0); $writer.Write([UInt32]0); $writer.Write([UInt32]0)

    function Get-Pixel([int]$x, [int]$y) {
        $master = $x -ge 4 -and $x -le 13 -and $y -ge 4 -and $y -le 27
        $topStack = $x -ge 18 -and $x -le 27 -and $y -ge 4 -and $y -le 13
        $bottomStack = $x -ge 18 -and $x -le 27 -and $y -ge 18 -and $y -le 27
        if ($master -or $topStack -or $bottomStack) { return @(212, 238, 94, 255) } # BGRA teal
        return @(31, 41, 55, 255) # BGRA slate background
    }

    # DIB pixel rows are bottom-up.
    for ($y = $size - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $size; $x++) {
            foreach ($channel in (Get-Pixel $x $y)) { $writer.Write([byte]$channel) }
        }
    }
    # Fully opaque AND mask.
    $writer.Write((New-Object byte[] ($andStride * $size)))
} finally {
    $writer.Dispose()
    $stream.Dispose()
}
