# Test-suite investigation notes

Status: resolved on 2026-09-06. The bounded suite is green, including the
reversible production-manager integration test. This document records the
failure and resolution for future regressions.

## Goal

`tools\tests.ps1` should run, in order:

1. `minwm-check.ahk`: a smoke test that loads the complete production module
   graph and initializes only state (no manager process, hooks, tray, polling,
   or custom-hotkey process).
2. `minwm-tests.ahk`: unit tests for pure configuration, geometry, layout,
   smart-gap, temporary-float, scratchpad, persistence, and event-state logic.

Both must terminate with an exit code and never leave an AutoHotkey process
behind.

## Safety improvement already made

`tools\tests.ps1` now delegates both entry points to
`tools\probe-autohotkey-test.ps1` with `-Force -TimeoutSeconds 15`.

The probe redirects stdout/stderr, writes a report under `test-results\`, and
kills the launched process tree if it exceeds the timeout. Do not replace it
with a direct `AutoHotkey64.exe` invocation while this investigation is open:
the former direct runner used an unbounded `WaitForExit()` and left resident
`minwm-check.ahk` / `minwm-tests.ahk` processes after failures.

## Observations

- `tools\tests.ps1` currently times out in the smoke stage, so unit tests do
  not run.
- The failure is silent: probe stdout and stderr are empty. It is likely an
  AutoHotkey load-time/modal error or persistence condition, rather than a
  PowerShell failure.
- `lib\debug.ahk` was the first module found to make an otherwise passive test
  root remain resident. This is expected only if the test root does not reach
  its explicit `ExitApp()` callback; it does not by itself prove that logging
  is defective.
- The older roots called their test function before the include list. That is
  unsafe because module declarations and controller stubs may not yet be
  available at the call site.
- A test root that has only `config.ahk` and `config-validation.ahk` loaded
  exits successfully through the probe. Adding the debug module resulted in a
  timeout during the investigation.
- An earlier smoke root called `InitializeLayoutCycleState()`, but that routine
  remains in `minwm.ahk` rather than a library module. It must not be called by
  the standalone smoke root unless it is extracted first.
- `tests\controller-stubs.ahk` now provides only `UpdateTrayTip()`. Stubs for
  refresh/workspace functions were intentionally removed after those functions
  moved into `lib\workspace-refresh.ahk`; smoke/unit roots must include that
  module when they load virtual-desktop code.

## Current relevant implementation changes

- The manager has new modules for smart gaps, temporary floats, scratchpads,
  workspace refresh, and event-driven refresh.
- Logging now uses `logPath`, always logs actions/errors, and creates a
  session-specific filename unless `--log-path` is supplied.
- `CreateDiagnosticSessionId()` in `lib\debug.ahk` was changed during the
  investigation from direct `Ole32` GUID calls to `Scriptlet.TypeLib` GUID
  creation. This change has not yet been validated by a passing test suite.

## Resolution

The test roots loaded `lib\debug.ahk`, whose logging initialization expects
`LogPathWasSpecified` and `StartupMessages` to exist. The production controller
creates those globals before it initializes logging, but the standalone roots
did not. Initialize the same harmless test globals before their one-shot timer
so both roots can enter and terminate reliably.

`tools\tests.ps1` now also invokes `tools\integration-test.ps1`. That test
starts the real manager with an isolated configuration directory and a safe
`--integration-test` mode, verifies its event-hook and shutdown log markers,
and refuses to run while any AutoHotkey process is active.

## Historical restart procedure

1. Keep using `tools\probe-autohotkey-test.ps1`; use a 3--10 second timeout
   while isolating. Verify `Get-Process AutoHotkey64` is empty after each
   timeout before trying again.
2. Restore `minwm-check.ahk` to a complete module list matching `minwm.ahk`,
   plus `tests\controller-stubs.ahk`, but do not start services.
3. Build a minimal executable smoke entry point that demonstrably reaches
   `ExitApp()`. Add temporary `FileAppend` stage markers in `%TEMP%` only while
   debugging, then remove them before committing.
4. If module loading is still silent, bisect the include list. Keep the debug
   module in the graph or explicitly explain/test any stubbed alternative;
   do not quietly drop logging coverage.
5. Once smoke passes, repair `minwm-tests.ahk` with the same lifecycle and run
   `tools\tests.ps1` end-to-end.
6. Add focused unit tests for the new pure behavior and retain integration-only
   Windows interactions in smoke/probe tests. Do not use the real manager for
   unit tests.

## Commands

Run the bounded full suite:

```powershell
.\tools\tests.ps1
```

Run one bounded entry point:

```powershell
.\tools\probe-autohotkey-test.ps1 -ScriptPath .\minwm-check.ahk -Force -TimeoutSeconds 10
```

Inspect the latest probe report:

```powershell
Get-Content .\test-results\minwm-check.probe.txt
```
