#Requires AutoHotkey v2.0

RunTestEntryPoint()

#Include "config.ahk"
#Include "lib\config-validation.ahk"
#Include "lib\debug.ahk"
#Include "lib\geometry.ahk"
#Include "lib\window-rules.ahk"
#Include "lib\windows.ahk"
#Include "lib\workspace-state.ahk"
#Include "tests\controller-stubs.ahk"
#Include "lib\virtual-desktops.ahk"
#Include "lib\focus-border.ahk"
#Include "lib\desktop-indicator.ahk"
#Include "lib\layout-notification.ahk"
#Include "lib\constraints.ahk"
#Include "lib\selection.ahk"
#Include "lib\layouts.ahk"
#Include "lib\custom-hotkeys.ahk"
#Include "tests\geometry-tests.ahk"

RunTestEntryPoint() {
    try {
        InitializeConfig()
        ValidateConfig()
        InitializeWindowsState()
        InitializeWorkspaceStateStore()
        InitializeVirtualDesktopState()
        InitializeFocusBorderState()
        InitializeDesktopIndicatorState()
        InitializeLayoutNotificationState()
        RunGeometryTests()
    } catch Error as err {
        FileAppend("tests failed: " err.Message "`n", "**")
        ExitApp(1)
    }
    ExitApp()
}
