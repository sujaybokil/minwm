# Changelog

All notable changes to minwm will be documented here. The project follows
[Semantic Versioning](https://semver.org/) while it remains pre-1.0.

## [Unreleased]

### Added

- Vertical and horizontal master-stack layouts and a floating mode.
- Keyboard focus, reordering, master promotion, gap, and ratio controls.
- Native minimum-size discovery and constraint-aware fallback to floating.
- DWM visible-frame positioning and per-monitor physical-DPI geometry.
- Tray controls, configurable hotkeys, and opt-in diagnostic logging.
- Current-user installer with optional startup-at-logon registration.
- Configurable click-through focused-window border.
- Explicit exclusion of owned windows, dialogs, modal frames, and popups.
- Syntax validation, unit tests, and Windows CI.

### Changed

- Installer upgrades now preserve the user's existing `config.toml`.
- Constraint-floated windows are centered without changing which windows are
  in the master and stack categories.

[Unreleased]: https://github.com/sujaybokil/minwm/commits/main
