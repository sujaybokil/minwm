# Third-party notices

## AutoHotkey

minwm depends on AutoHotkey v2.0.26. AutoHotkey is developed by the AutoHotkey
project and is licensed separately under the GNU General Public License,
version 2.

- Project: <https://github.com/AutoHotkey/AutoHotkey>
- Release used by minwm: <https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.26>
- Corresponding source: <https://github.com/AutoHotkey/AutoHotkey/tree/v2.0.26>
- License: <https://github.com/AutoHotkey/AutoHotkey/blob/v2.0.26/license.txt>

AutoHotkey source code and binaries are not committed to the minwm repository
or copied into the minwm installer. Users install AutoHotkey independently and
minwm invokes that existing runtime.

AutoHotkey is not covered by minwm's MIT License.

## VirtualDesktop

The release build downloads and hash-verifies the Windows 11 executables from
VirtualDesktop V1.21, then the installer offers them as an optional component
for direct, non-animated Windows virtual-desktop switching. The binaries are
not committed to this repository. Deselecting that installer option leaves
minwm fully usable with Windows keyboard shortcut switching.

- Project and source: <https://github.com/MScholtes/VirtualDesktop>
- Release used by minwm: <https://github.com/MScholtes/VirtualDesktop/releases/tag/V1.21>
- License: MIT, Copyright (c) 2017 Markus Scholtes

The generated installer executables are pinned and verified by
`tools\Prepare-Dependencies.ps1`:

- `VirtualDesktop11.exe`: `F6532DB79F6F0E4018CE77F08805D3FD3F7BB076CBFBAC0AC8189FE5376D9E82`
- `VirtualDesktop11-24H2.exe`: `8334B529D19E71662950821C91ED996A0E92DF41C8D0A077E95151AA7041CB35`
