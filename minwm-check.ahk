#Requires AutoHotkey v2.0

RunTestEntryPoint()

; Test-only entry point. It verifies the shipped configuration and every module
; without invoking minwm's single-instance manager process.
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
    } catch Error as err {
        FileAppend("smoke test failed: " err.Message "`n", "**")
        ExitApp(1)
    }
    ExitApp()
}
