# minwm agent notes

## Test and build workflow

- `tools\Test.ps1` runs the AutoHotkey source test entry points with the
  installed AutoHotkey v2 interpreter. It does **not** run or inspect the
  generated installer executable.
- `minwm-check.ahk` is a module/configuration smoke test. It initializes state
  only and does not start the single-instance window-manager process.
- `minwm-tests.ahk` is the root-level unit-test entry point. It loads modules
  using the same root-relative include pattern as `minwm-check.ahk`, then loads
  test cases from `tests\geometry-tests.ahk`.
- `tests\geometry-tests.ahk` contains assertions only; it must not be launched
  as a standalone test entry point. AutoHotkey resolves `#Include` paths during
  launch in a way that made the former nested entry point block on missing
  include files.
- Use `tools\Probe-AutoHotkeyTest.ps1 -ScriptPath <path>` to run one AHK entry
  point with captured stdout/stderr and a timeout. Its `-ValidateOnly` option
  checks that AutoHotkey can load the script without executing it.
- `tools\installer.ps1` runs the test suite before compiling
  `dist\minwm-setup.exe` with Inno Setup. It calls
  `tools\Prepare-Dependencies.ps1` to download and SHA-256 verify the optional
  VirtualDesktop release files in the ignored `dependencies\` directory. This
  is the end-to-end source-test and installer-build command.
- `minwm-virtual-desktop-probe.ahk` is the reversible integration probe for the
  real Windows desktop backend. It logs to `test-results\virtual-desktop-probe.log`,
  invokes the same direct-switch function used by `Win+number`, asserts the
  target desktop, and restores the original desktop. Stop a running manager
  before using it so its polling does not confound the probe.

## Code map

- `minwm.ahk` is the production entry point and controller. It initializes
  services, registers built-in hotkeys and tray actions, owns the active
  `Manager` workspace state, and coordinates refresh/focus/reordering.
- `config.ahk` supplies defaults and parses `config\config.toml`.
  `lib\config-validation.ahk` normalizes and validates those values. Update
  both when adding a configuration setting.
- `lib\windows.ahk` contains Win32/DWM window geometry, minimum-size queries,
  monitor selection, eligibility filtering, and DPI handling.
  `lib\window-rules.ahk` holds reusable window-exclusion predicates.
  `lib\geometry.ahk` holds pure rectangle helpers.
- `lib\constraints.ahk` solves minimum-size feasibility;
  `lib\selection.ahk` decides which windows tile or constraint-float; and
  `lib\layouts.ahk` turns those decisions into master-stack/maximized/floating
  window placement.
- `lib\workspace-state.ahk` stores independent layout state for each Windows
  virtual desktop. `lib\virtual-desktops.ahk` discovers, switches, and polls
  those desktops, then activates the appropriate workspace state. The feature
  is controlled by `virtualDesktopsEnabled`, which defaults to `true`.
  AutoHotkey may return the Windows virtual-desktop registry values as either
  binary buffers or 32-character hexadecimal strings; preserve support for both
  forms when changing discovery code, otherwise the service disables itself as
  though no current desktop existed.
  AutoHotkey string literals do not escape backslashes: Win32 DLL function
  names must use a single separator (for example, `Ole32\CoCreateInstance`).
  A doubled separator causes `DllCall` to fail and makes every window appear
  outside the active virtual desktop.
  Workspace navigation prefers the MIT `VirtualDesktop` V1.21 helper in
  `dependencies\virtualdesktop`
  for direct, non-animated switching on Windows 11. `VirtualDesktop11.exe` is
  selected for builds 22000–26099 and `VirtualDesktop11-24H2.exe` for builds
  26100+. The helper uses zero-based desktop indexes, so minwm must pass
  `targetIndex - 1`. It is an OS-version-sensitive private-API dependency:
  use the current `Ctrl+Win+Left/Right` implementation only when the optional
  helper is absent (the installer task was deselected). Do not silently fall
  back after a helper invocation fails, since that reintroduces animations and
  obscures the failure. Launch the helper with `Run`, not `RunWait`: waiting
  from the AHK manager can block after the helper moves the desktop. Its exit code
  is the result of its final command: `/Switch`
  returns the zero-based target index (and `/Count` returns the number of
  desktops), not conventional zero-success.
  Windows' supported `IVirtualDesktopManager` API is limited to
  `GetWindowDesktopId`, `IsWindowOnCurrentVirtualDesktop`, and
  `MoveWindowToDesktop`; it has no public direct-switch/create/list method.
  After every detected desktop change, `SynchronizeActiveVirtualWorkspace()`
  reflows then calls `FocusVirtualDesktopWindow()`: it activates the first
  still-eligible window in the destination workspace order, while an empty
  workspace deliberately leaves focus untouched. Direct helper telemetry logs
  both the attempted helper path and the confirmed destination.
  A successful helper exit code is authoritative even if Explorer's registry
  snapshot has not updated yet: do not fall back to `Ctrl+Win` in that case,
  because it can reintroduce sequential desktop animations. Leave the existing
  poller to observe the registry change and synchronize the workspace.
  The helper selection reads `CurrentBuildNumber` from the registry. AutoHotkey
  does not escape `\`, so this path (and `A_ScriptDir` helper paths) must use
  single backslashes. Doubled separators made the lookup return `0`, causing
  minwm to wrongly classify the installed helper as unavailable and always use
  the animated fallback. `minwm-virtual-desktop-probe.ahk` catches this before
  installation.
  The probe passed on this host using the 24H2 helper: D1→D6 was confirmed and
  then restored to D1. It runs the helper asynchronously; use `Run(..., &pid)`
  for an AHK v2 process-ID log rather than assuming `Run` returns that ID.
  Hide the focus border before a virtual-desktop transition begins; otherwise
  its always-on-top edge windows can remain visibly drawn over a window on the
  desktop that has just been left. The foreground hook redraws it only after a
  destination window becomes active.
  `tools\Prepare-Dependencies.ps1` verifies both pinned SHA-256 hashes before
  creating an installer; keep the hash, `THIRD_PARTY_NOTICES.md`, installer
  file entries, and the generated `dependencies\virtualdesktop` contents in
  sync on upgrade. The dependency binaries must remain ignored and must never
  be committed; only the fetch script and installed license are versioned. Inno Setup removes `{app}` on
  uninstall, including the bundled helpers. The installer task
  `virtualdesktophelper` is default-on and optional; its description must state
  that it enables direct non-animated switching and that deselecting retains
  the built-in shortcut fallback. On an upgrade where it is deselected, delete
  any previously installed helper files.
- `lib\focus-border.ahk`, `lib\desktop-indicator.ahk`, and
  `lib\layout-notification.ahk` own non-activating presentation GUIs.
  `lib\custom-hotkeys.ahk` launches and supervises the optional companion
  custom-hotkey script.
- Layout changes use `TrayTip` in `lib\layout-notification.ahk`, so Windows
  provides the notification surface; minwm clears it after one second. Do not
  reintroduce a custom transient overlay without explicit lifecycle/visibility
  coverage. Focus-border edges
  are click-through topmost tool windows positioned by
  `SetFocusBorderEdgeRect`; retain its frame-change/topmost flags when editing
  the border path.
- The virtual-desktop indicator is a non-activating GUI positioned with
  `Gui.Show` over the bottom-left of the primary taskbar, using full monitor
  bounds and a uniform 12px left/bottom inset rather than the work area. Avoid raw
  `SetWindowPos` for this transient overlay; it was unreliable on the target
  desktop session.
- Focus-border tracking uses both location-change and foreground-change WinEvent
  hooks, with polling as a fallback. Preserve both hooks so the border recovers
  after windows open, close, or take focus.
- `lib\debug.ahk` provides diagnostic logging and shared error/list formatting.
- `tests\geometry-tests.ahk` is the current pure/unit assertion suite;
  `tests\controller-stubs.ahk` supplies controller callbacks required when the
  virtual-desktop module is loaded outside the production entry point.
- `installer\minwm.iss` defines packaged files, installation, startup, and
  uninstall behavior. `tools\installer.ps1` prepares assets, validates source,
  and invokes Inno Setup.

## Current test environment

- The repository requires AutoHotkey v2 at least as new as `AUTOHOTKEY_VERSION`
  and below v3. The current local validation used AutoHotkey 2.0.26.
- The manager does not need to be running for smoke tests, unit tests, or the
  installer build.
