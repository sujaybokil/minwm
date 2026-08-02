#Requires AutoHotkey v2.0

SetTimer(RunVirtualDesktopProbe, -1)

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

RunVirtualDesktopProbe() {
    global Config, VirtualDesktops
    originalIndex := 0
    try {
        InitializeConfig()
        ValidateConfig()
        Config["debugEnabled"] := true
        Config["debugLogPath"] := A_ScriptDir "\test-results\virtual-desktop-probe.log"
        InitializeDebugLog()
        InitializeWorkspaceStateStore()
        InitializeVirtualDesktopState()
        InitializeFocusBorderState()
        RefreshVirtualDesktopSnapshot()
        originalIndex := FindVirtualDesktopIndex(
            VirtualDesktops.desktopIds, VirtualDesktops.currentId)
        if !originalIndex
            throw Error("could not determine the current virtual desktop")
        targetIndex := (originalIndex = 1) ? Min(6, VirtualDesktops.desktopIds.Length) : 1
        if (targetIndex = originalIndex)
            throw Error("at least two virtual desktops are required for this probe")
        helperPath := GetVirtualDesktopSwitcherPath()
        if (helperPath = "")
            throw Error("the direct virtual-desktop helper is not available")
        DebugLog("Probe starting; original=" originalIndex "; target=" targetIndex
            . "; helper=" helperPath)
        if !SwitchToVirtualDesktopIndex(targetIndex)
            throw Error("SwitchToVirtualDesktopIndex returned false")
        if !WaitForVirtualDesktopIndex(targetIndex, 2000)
            throw Error("the direct switch did not reach desktop " targetIndex)
        DebugLog("Probe direct switch confirmed; current=" targetIndex)
        FileAppend("PASS direct switch: D" originalIndex " -> D" targetIndex "`n", "**")
    } catch Error as err {
        DebugLog("Probe failed: " ErrorDescription(err))
        FileAppend("FAIL virtual desktop probe: " err.Message "`n", "**")
        ExitCode := 1
    } finally {
        if originalIndex {
            try {
                RefreshVirtualDesktopSnapshot()
                if (FindVirtualDesktopIndex(
                    VirtualDesktops.desktopIds, VirtualDesktops.currentId) != originalIndex) {
                    DebugLog("Probe restoring desktop=" originalIndex)
                    SwitchToVirtualDesktopIndex(originalIndex)
                    if !WaitForVirtualDesktopIndex(originalIndex, 2000)
                        throw Error("could not restore the original virtual desktop")
                }
            } catch Error as restoreErr {
                DebugLog("Probe restore failed: " ErrorDescription(restoreErr))
                FileAppend("FAIL virtual desktop probe restore: " restoreErr.Message "`n", "**")
                ExitCode := 1
            }
        }
    }
    ExitApp(IsSet(ExitCode) ? ExitCode : 0)
}

WaitForVirtualDesktopIndex(expectedIndex, timeoutMs) {
    global VirtualDesktops
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        RefreshVirtualDesktopSnapshot()
        if (FindVirtualDesktopIndex(
            VirtualDesktops.desktopIds, VirtualDesktops.currentId) = expectedIndex)
            return true
        Sleep(25)
    }
    return false
}
