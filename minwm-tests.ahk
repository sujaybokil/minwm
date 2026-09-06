#Requires AutoHotkey v2.0

LogPathWasSpecified := false
StartupMessages := []
SetTimer(RunTestEntryPoint, -1)

#Include "config.ahk"
#Include "lib\config-validation.ahk"
#Include "lib\debug.ahk"
#Include "lib\geometry.ahk"
#Include "lib\window-rules.ahk"
#Include "lib\windows.ahk"
#Include "lib\workspace-state.ahk"
#Include "lib\smart-gaps.ahk"
#Include "lib\temporary-float.ahk"
#Include "lib\scratchpad.ahk"
#Include "lib\workspace-refresh.ahk"
#Include "lib\window-refresh-events.ahk"
#Include "tests\controller-stubs.ahk"
#Include "lib\virtual-desktops.ahk"
#Include "lib\focus-border.ahk"
#Include "lib\desktop-indicator.ahk"
#Include "lib\layout-notification.ahk"
#Include "lib\layout-cycle.ahk"
#Include "lib\navigation.ahk"
#Include "lib\layout-state.ahk"
#Include "lib\constraints.ahk"
#Include "lib\selection.ahk"
#Include "lib\layouts.ahk"
#Include "lib\custom-hotkeys.ahk"
#Include "tests\geometry-tests.ahk"
#Include "tests\config-tests.ahk"

RunTestEntryPoint() {
    try {
        InitializeConfig()
        ValidateConfig()
        InitializeWindowsState()
        InitializeWindowRefreshEventsState()
        InitializeWorkspaceStateStore()
        InitializeVirtualDesktopState()
        InitializeFocusBorderState()
        InitializeDesktopIndicatorState()
        InitializeLayoutNotificationState()
        RunGeometryTests()
        RunConfigTests()
    } catch Error as err {
        FileAppend("tests failed: " err.Message "`n", "**")
        ExitApp(1)
    }
    ExitApp()
}
