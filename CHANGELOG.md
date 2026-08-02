# Changelog

All notable changes to minwm are documented here. The project follows
[Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-08-02

### Added

- Vertical and horizontal master-stack layouts, a maximized mode, and a floating mode.
- Six Windows virtual-desktop workspaces with independent tiling state,
  fixed `Win+1` through `Win+6` navigation, and a taskbar-adjacent indicator.
- Transient notification when the layout mode changes.
- Keyboard focus, reordering, master promotion, gap, and ratio controls.
- Native minimum-size discovery and constraint-aware fallback to floating.
- DWM visible-frame positioning and per-monitor physical-DPI geometry.
- Tray controls, configurable hotkeys, and opt-in diagnostic logging.
- Current-user installer with optional startup-at-logon registration.
- Configurable click-through focused-window border.
- Explicit exclusion of owned windows, dialogs, modal frames, and popups.
- Optional supervised AutoHotkey v2 script for custom application-launching
  hotkeys.
- Hotkey reference action in the tray menu.
- Syntax validation, unit tests, and Windows CI.
- Reversible virtual-desktop integration probe, pinned optional helper download,
  and installer hash verification.

### Changed

- Installer upgrades now preserve the user's existing `config.toml`.
- The default promote-to-master binding is now `Win+M`.
- The default hotkey-reference binding is now `Win+H`.
- Constraint-floated windows are centered without changing which windows are
  in the master and stack categories.
- Direct Windows 11 desktop jumps use the optional helper without animations;
  shortcut switching is used only when that optional installer component is not
  selected.

[0.1.0]: https://github.com/sujaybokil/minwm/releases/tag/v0.1.0
