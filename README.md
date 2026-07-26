# minwm

[![CI](https://github.com/sujaybokil/minwm/actions/workflows/ci.yml/badge.svg)](https://github.com/sujaybokil/minwm/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2.0.26-334455.svg)](https://github.com/AutoHotkey/AutoHotkey)

`minwm` is a small, keyboard-driven tiling window manager for Windows, written
in AutoHotkey v2.

> [!WARNING]
> **Work in progress.** minwm is usable, but it is still pre-1.0 software.
> Configuration keys, tiling behavior, and installer details may change between
> releases. Please report reproducible problems with a short debug-log excerpt.

## Why minwm?

- Vertical and horizontal master-stack layouts, plus a floating mode
- Native application minimum-size handling
- Constraint-aware reflow: if every window cannot fit, the largest constrained
  window floats and the remaining set is tiled again
- DWM visible-frame positioning for Electron and other custom-framed windows
- Physical-pixel geometry across mixed-DPI monitors
- Stable keyboard reordering and master promotion
- Lightweight tray controls and optional startup-at-logon setup
- Opt-in, size-limited diagnostic logging

The project deliberately does not draw focus borders or other window
decorations.

## Requirements

- Windows 10 version 1809 or later, or Windows 11, on x64
- [AutoHotkey v2.0.26](https://github.com/AutoHotkey/AutoHotkey/releases/tag/v2.0.26)

AutoHotkey is an external dependency and is **not vendored or copied by
minwm**. The installer locates and uses the runtime already installed on the
user's machine. Its separate GPL-2.0 license is documented in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Install

There is no published binary release yet. Run minwm from source or build the
installer locally while the project is in its work-in-progress phase.

### Local installer

Build `minwm-setup.exe` with `.\tools\Build-Installer.ps1`. The installer:

- requires an existing AutoHotkey v2 installation;
- installs for the current user under `%LOCALAPPDATA%\minwm`;
- preserves an existing `config.toml` during upgrades;
- offers a default-on checkbox to start minwm at logon;
- uses a limited scheduled task when Windows permits it, otherwise a Startup
  folder shortcut; and
- can launch minwm immediately after setup.

The resulting installer is not currently code-signed, so Windows SmartScreen may show an
unknown-publisher warning. Verify release downloads against the SHA-256 digest
you calculate for the local build before sharing it.

Uninstalling removes the installation directory, including its configuration
and logs. Copy `config.toml` elsewhere first if you want to keep it.

### Run from source

Install AutoHotkey v2.0.26, clone this repository, then run:

```powershell
& "$(scoop prefix autohotkey)\v2\AutoHotkey64.exe" .\minwm.ahk
```

Scoop is optional; pass the path to your own AutoHotkey v2 executable if you
installed it another way.

## Keybindings

All bindings are configurable in `config.toml`. Restart minwm after editing the
file.

| Default | Action |
| --- | --- |
| `Win+T` | Cycle vertical, horizontal, and floating layouts |
| `Win+R` | Re-tile the active monitor |
| `Win+[` / `Win+]` | Decrease / increase gaps |
| `Win+Shift+[` / `Win+Shift+]` | Decrease / increase the master area |
| `Win+J` / `Win+K` | Focus next / previous tiled window |
| `Win+Shift+J` / `Win+Shift+K` | Move the focused window in tiling order |
| `Win+Enter` | Promote the focused window to master |
| `Win+W` | Close the focused window |
| `Win+I` | Show the configured hotkey reference |

## Configuration

`config.toml` supports the settings below. The parser intentionally implements
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
| `masterRatio` | `0.58` | Initial master share |
| `masterRatioStep` | `0.04` | Master-share adjustment per hotkey press |
| `minMasterRatio` | `0.30` | Lowest permitted master share |
| `maxMasterRatio` | `0.75` | Highest permitted master share |
| `debugLogPath` | `minwm-debug.log` | Diagnostic log path |
| `debugMaxSizeMb` | `5` | Rotate the diagnostic log at this size |
| `excludedClasses` | Windows shell/dialog classes | Window classes never tiled |

Invalid values fall back to safe defaults. Those corrections are written to the
debug log when debug mode is enabled.

## How constraint-aware tiling works

For each eligible window, minwm asks Windows for the application's native
minimum tracking size. It then:

1. reserves the configured outer and inner gaps;
2. checks the master and stack dimensions against every native minimum;
3. redistributes spare space to constrained windows;
4. if the set is impossible, floats the window with the largest minimum area;
5. repeats until all remaining windows fit.

Floating-by-constraint is not permanent. Windows are reconsidered whenever the
eligible window set changes.

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
.\tools\Build-Installer.ps1
```

Generated installers live under `dist\`, which is ignored by Git. CI installs
the pinned AutoHotkey dependency in its disposable runner; it is not copied
into the repository or installer.

The main modules are:

| Path | Responsibility |
| --- | --- |
| `minwm.ahk` | Controller, hotkeys, tray, and refresh lifecycle |
| `config.ahk` | Minimal TOML loading and defaults |
| `lib/windows.ahk` | Win32 discovery, geometry, DPI, and minimum sizes |
| `lib/constraints.ahk` | Pure fit and constrained-allocation algorithms |
| `lib/selection.ahk` | Maps constraint decisions to real windows |
| `lib/layouts.ahk` | Master-stack layout and window movement |
| `lib/debug.ahk` | Opt-in diagnostics and log rotation |

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Current limitations

- minwm reflows the monitor containing the focused window; it is not yet a
  virtual-desktop workspace manager.
- Elevated windows cannot be controlled by a non-elevated minwm process.
- Some applications ignore or dynamically change their Win32 minimum-size
  contract.
- The installer is not code-signed.

## License

minwm source code is available under the [MIT License](LICENSE). AutoHotkey is a
separate GPL-2.0 dependency; see [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
