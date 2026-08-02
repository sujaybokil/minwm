# minwm

[![CI](https://github.com/sujaybokil/minwm/actions/workflows/ci.yml/badge.svg)](https://github.com/sujaybokil/minwm/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0.26-334455.svg)](https://github.com/AutoHotkey/AutoHotkey)

`minwm` is a small, keyboard-driven tiling window manager for Windows, written
in AutoHotkey v2. It was created for personal use and is released under the
MIT License for anyone to use, modify, and share.

> [!NOTE]
> This is a stable personal project rather than an actively developed product.
> It is provided as-is; please use the issue tracker for reproducible defects.

## Why minwm?

- Vertical and horizontal master-stack layouts, a maximized mode, and a
  non-interfering floating mode
- Native application minimum-size handling
- Constraint-aware reflow: if every window cannot fit, the largest constrained
  window floats and the remaining set is tiled again
- DWM visible-frame positioning for Electron and other custom-framed windows
- Physical-pixel geometry across mixed-DPI monitors
- Stable keyboard reordering and master promotion
- Six Windows virtual-desktop workspaces with independent tiling state
- Configurable 1px white focused-window border (`0` disables it)
- Lightweight tray controls, including a hotkey reference, and optional
  startup-at-logon setup
- Opt-in, size-limited diagnostic logging

## Requirements

- Windows 10 version 1809 or later, or Windows 11, on x64
- [AutoHotkey v2.0.26](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.26)

AutoHotkey is an external dependency and is **not vendored or copied by
minwm**. The installer locates and uses the runtime already installed on the
user's machine. Its separate GPL-2.0 license is documented in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

The release installer offers an optional **Direct virtual-desktop switching**
component. When selected (the default), it installs the MIT-licensed
[VirtualDesktop V1.21](https://github.com/MScholtes/VirtualDesktop/releases/tag/V1.21)
helper for direct, non-animated Windows 11 switches. It is not required:
deselect it to use minwm with the standard Windows shortcut switching instead.
The helper binaries are not stored in this repository; release builds download
their pinned versions and verify SHA-256 hashes before packaging them.

## Install

Download the latest `minwm-setup.exe` from the project's GitHub Releases page,
or build the installer locally from source.

### Local installer

Build `minwm-setup.exe` with `.\tools\installer.ps1`. The installer:

- requires an existing AutoHotkey v2 installation;
- installs for the current user under `%LOCALAPPDATA%\minwm`;
- preserves an existing `config\config.toml` during upgrades;
- offers a default-on **Virtual desktops** option that installs the helper for
  direct, non-animated workspace jumps; deselect it to use Windows shortcut
  switching instead;
- offers a default-on checkbox to start minwm at logon;
- uses a limited scheduled task when Windows permits it, otherwise a Startup
  folder shortcut; and
- can launch minwm immediately after setup.

The build script downloads the optional VirtualDesktop helper only into the
ignored `dependencies\` build directory, verifies its pinned SHA-256 hashes,
and never adds its binaries to the repository.

The resulting installer is not currently code-signed, so Windows SmartScreen may show an
unknown-publisher warning. Verify release downloads against the SHA-256 digest
you calculate for the local build before sharing it.

Uninstalling removes the installation directory, including its configuration
and logs. Copy the `config` directory elsewhere first if you want to keep it.

### Run from source

Install AutoHotkey v2.0.26, clone this repository, then run:

```powershell
& "$(scoop prefix autohotkey)\v2\AutoHotkey64.exe" .\minwm.ahk
```

Scoop is optional; pass the path to your own AutoHotkey v2 executable if you
installed it another way.

## Keybindings

All bindings except the fixed workspace selectors are configurable in
`config\config.toml`. Restart minwm after editing the file.

Only normal, resizable, unowned top-level windows are tiled. Start, Windows
Search, standard dialogs, modal frames, tool windows, owned transient windows,
and `WS_POPUP` windows are always excluded.

| Default | Action |
| --- | --- |
| `Win+T` | Cycle vertical, horizontal, maximized, and floating layouts |
| `Win+1` … `Win+6` | Switch to virtual desktop D1 … D6 |
| `Win+R` | Re-tile the active monitor |
| `Win+[` / `Win+]` | Decrease / increase gaps |
| `Win+Shift+[` / `Win+Shift+]` | Decrease / increase the master area |
| `Win+J` / `Win+K` | Focus next / previous tiled window |
| `Win+Shift+J` / `Win+Shift+K` | Move the focused window in tiling order |
| `Win+M` | Promote the focused window to master |
| `Win+W` | Close the focused window |
| `Win+H` | Show the configured hotkey reference |

On startup, minwm preserves existing Windows virtual desktops and creates only
enough new desktops to reach six. Each desktop keeps its own layout, gaps,
master ratio, window order, and constraint-float state. A small translucent
`D1`–`D6` indicator stays over the bottom-left of the primary taskbar. The workspace shortcuts
are fixed; other bindings remain configurable. On supported Windows 11 builds,
switching directly from (for example) D1 to D6 does not visit intermediate
desktops or play their transitions.

Floating mode is intentionally hands-off: minwm does not resize, maximize,
reorder, or focus windows through tiling controls, and hides the focused-window
border. Maximized mode instead enforces maximization for every eligible window
on the active monitor.

## Configuration

`config\config.toml` supports the settings below. The parser intentionally implements
only the TOML subset used by this file: strings, booleans, numbers, arrays of
strings, and the `[hotkeys]` table.

| Setting | Default | Purpose |
| --- | ---: | --- |
| `minWidth` | `320` | Ignore windows currently narrower than this |
| `minHeight` | `220` | Ignore windows currently shorter than this |
| `pollInterval` | `400` | Window refresh interval in milliseconds |
| `defaultGap` | `12` | Initial outer and inner gap in pixels |
| `gapStep` | `4` | Gap adjustment per hotkey press |
| `minGap` | `0` | Lowest permitted gap |
| `defaultLayout` | `vertical` | Initial layout for each virtual desktop: `vertical`, `horizontal`, `maximized`, or `floating` |
| `virtualDesktopsEnabled` | `true` | Manage six Windows virtual-desktop workspaces and enable `Win+1` … `Win+6`; set `false` to disable this feature |
| `masterRatio` | `0.58` | Initial master share |
| `masterRatioStep` | `0.04` | Master-share adjustment per hotkey press |
| `minMasterRatio` | `0.30` | Lowest permitted master share |
| `maxMasterRatio` | `0.75` | Highest permitted master share |
| `debugLogPath` | `minwm-debug.log` | Diagnostic log path |
| `debugMaxSizeMb` | `5` | Rotate the diagnostic log at this size |
| `focusBorderWidth` | `1` | Focus border thickness; `0` disables it; tracks live moves and resizes |
| `focusBorderColor` | `FFFFFF` | Focus border color as six-digit RGB hex |
| `excludedClasses` | Windows shell/dialog classes | Window classes never tiled |

Invalid values fall back to safe defaults. Those corrections are written to the
debug log when debug mode is enabled.

### Custom hotkeys

Create `config\custom-hotkeys.ahk` beside `config.toml` to add custom bindings,
such as shortcuts that launch applications. If the file is absent, minwm does
not start a custom-hotkeys process.

For example:

```ahk
#Requires AutoHotkey v2.0
#n::Run("notepad.exe")
```

The script runs through the user's installed AutoHotkey runtime in a supervised
companion process and exits with minwm. Bindings reserved by minwm's `[hotkeys]`
table, plus the fixed `Win+1` … `Win+6` workspace shortcuts, are disabled in
the companion process, so built-in behavior can only be changed through TOML.
It is arbitrary executable code, so only configure a script you trust.

## How constraint-aware tiling works

For each eligible window, minwm asks Windows for the application's native
minimum tracking size. It then:

1. reserves the configured outer and inner gaps;
2. checks the master and stack dimensions against every native minimum;
3. redistributes spare space to constrained windows;
4. keeps the master and stack categories fixed while resizing within them;
5. if the arrangement cannot fit, floats the window with the largest minimum
   area;
6. repeats until all remaining windows fit.

Floating-by-constraint is not permanent. Windows are reconsidered whenever the
eligible window set changes. While excluded from tiling, they are resized as
to their native minimum and centered in the active monitor's work area.

Tile targets use DWM extended frame bounds, not the larger invisible resize
border reported by many custom-framed applications. After a move, minwm
re-measures once and corrects any residual caused by DPI changes or application
`WM_SIZE` handling.

## Debugging

Launch with diagnostic logging enabled:

```powershell
& "$(scoop prefix autohotkey)\v2\AutoHotkey64.exe" .\minwm.ahk --debug true
```

Logs are written beside the script by default and rotate to
`minwm-debug.log.1`. They record layout decisions, native constraints, and
failed window moves. Window titles are not logged, but window handles can still
help identify your session; review excerpts before posting them publicly.

For a useful bug report, include:

- Windows version and monitor/DPI arrangement;
- application name and version;
- active layout and relevant configuration;
- exact reproduction steps; and
- the smallest relevant debug-log excerpt.

## Development

Run syntax validation and unit tests:

```powershell
.\tools\Test.ps1
```

Build the installer with AutoHotkey v2.0.26 or newer v2 and Inno Setup 6
installed:

```powershell
.\tools\installer.ps1
```

Generated installers live under `dist\`, which is ignored by Git. CI installs
the pinned AutoHotkey dependency in its disposable runner; it is not copied
into the repository or installer.

The main modules are:

| Path | Responsibility |
| --- | --- |
| `minwm.ahk` | Controller, hotkeys, tray, and refresh lifecycle |
| `minwm-check.ahk` | Test-only module and configuration smoke-test entry point |
| `config.ahk` | Minimal TOML loading and defaults |
| `lib/windows.ahk` | Win32 discovery, geometry, DPI, and minimum sizes |
| `lib/virtual-desktops.ahk` | Windows desktop discovery, provisioning, switching, and membership |
| `lib/workspace-state.ahk` | Independent tiling state for each virtual desktop |
| `lib/desktop-indicator.ahk` | Primary-taskbar workspace indicator |
| `lib/layout-notification.ahk` | Transient layout-change confirmation |
| `lib/constraints.ahk` | Pure fit and constrained-allocation algorithms |
| `lib/selection.ahk` | Maps constraint decisions to real windows |
| `lib/layouts.ahk` | Master-stack layout and window movement |
| `lib/debug.ahk` | Opt-in diagnostics and log rotation |
| `lib/custom-hotkeys.ahk` | Supervised loading of custom hotkey scripts |

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Current limitations

- minwm reflows only the monitor containing the focused window; this also
  scopes maximized-mode enforcement.
- Elevated windows cannot be controlled by a non-elevated minwm process.
- Some applications ignore or dynamically change their Win32 minimum-size
  contract.
- The installer is not code-signed.

## License

minwm source code is available under the [MIT License](LICENSE). AutoHotkey is a
separate GPL-2.0 dependency; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
