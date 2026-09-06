#Requires AutoHotkey v2.0
#SingleInstance Force

SetTimer(InitializeMinwm, -1)

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
#Include "lib\virtual-desktops.ahk"
#Include "lib\focus-border.ahk"
#Include "lib\desktop-indicator.ahk"
#Include "lib\layout-notification.ahk"
#Include "lib\layout-cycle.ahk"
#Include "lib\layout-state.ahk"
#Include "lib\navigation.ahk"
#Include "lib\constraints.ahk"
#Include "lib\selection.ahk"
#Include "lib\layouts.ahk"
#Include "lib\custom-hotkeys.ahk"

InitializeMinwm() {
    global IntegrationTestMode, LogPathWasSpecified, Manager, StartupMessages, HotkeyHelpGui
    InitializeConfig()
    ValidateConfig()
    InitializeWindowsState()
    InitializeWindowRefreshEventsState()
    InitializeWorkspaceStateStore()
    InitializeLayoutStatePersistence()
    InitializeVirtualDesktopState()
    InitializeFocusBorderState()
    InitializeDesktopIndicatorState()
    InitializeLayoutNotificationState()
    Manager := CreateWorkspaceManagerState()
    InitializeLayoutCycleState()
    StartupMessages := []
    LogPathWasSpecified := false
    HotkeyHelpGui := ""

    ApplyCommandLineOptions()
    InitializeDebugLog()
    DebugLog("minwm starting; poll=" Config["pollInterval"] "ms"
        "; log=" Config["logPath"])
    for message in ConfigLoadMessages
        DebugLog("Config: " message)
    for message in StartupMessages
        DebugLog("Startup: " message)
    try {
        workspaceReady := Config["virtualDesktopsEnabled"]
            ? StartVirtualDesktopService() : false
        if !workspaceReady && !Config["virtualDesktopsEnabled"]
            DebugLog("Virtual desktops disabled by configuration")
        LoadPersistedWorkspaceSettings()
        if workspaceReady
            ActivateWorkspace(VirtualDesktops.currentId)
        if !IntegrationTestMode {
            RegisterHotkeys()
            InitializeTray()
        }
        OnExit(HandleManagerExit)
        StartFocusBorder()
        if workspaceReady
            StartDesktopIndicator()
        StartCustomHotkeys(GetReservedHotkeys())
        StartWindowRefreshEvents()
        SetTimer(RefreshLayout, Config["pollInterval"])
        RefreshLayout()
        if IntegrationTestMode
            SetTimer(CompleteIntegrationTest, -500)
    } catch Error as err {
        HandleStartupFailure(err)
    }
}

HandleManagerExit(*) {
    SetTimer(ApplyQueuedLayoutCycle, 0)
    StopCustomHotkeys()
    StopWindowRefreshEvents()
    StopLayoutNotification()
    StopDesktopIndicator()
    StopFocusBorder()
    StopVirtualDesktopService()
    SavePersistedWorkspaceSettings()
    DebugLog("minwm exiting")
}

HandleStartupFailure(err) {
    message := "minwm could not start: " ErrorDescription(err)
    DebugLog(message)
    startupErrorPath := A_Temp "\minwm-startup-error.log"
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " message "`n",
        startupErrorPath, "UTF-8")
    try MsgBox(message "`n`nCheck " UserConfigPath " and " startupErrorPath ".",
        "minwm startup error", 0x10)
    ExitApp(1)
}

RegisterHotkeys() {
    global Config
    keys := Config["hotkeys"]
    Hotkey(keys["cycleLayout"], (*) => CycleLayout())
    Hotkey(keys["retile"], (*) => RefreshLayout())
    Hotkey(keys["increaseGap"], (*) => ChangeGap(Config["gapStep"]))
    Hotkey(keys["decreaseGap"], (*) => ChangeGap(-Config["gapStep"]))
    Hotkey(keys["increaseMaster"], (*) => ChangeMasterRatio(Config["masterRatioStep"]))
    Hotkey(keys["decreaseMaster"], (*) => ChangeMasterRatio(-Config["masterRatioStep"]))
    Hotkey(keys["focusNext"], (*) => FocusRelative(1))
    Hotkey(keys["focusPrevious"], (*) => FocusRelative(-1))
    Hotkey(keys["focusLeft"], (*) => FocusDirectional("left"))
    Hotkey(keys["focusRight"], (*) => FocusDirectional("right"))
    Hotkey(keys["focusUp"], (*) => FocusDirectional("up"))
    Hotkey(keys["focusDown"], (*) => FocusDirectional("down"))
    Hotkey(keys["moveNext"], (*) => MoveRelative(1))
    Hotkey(keys["movePrevious"], (*) => MoveRelative(-1))
    Hotkey(keys["moveLeft"], (*) => MoveDirectional("left"))
    Hotkey(keys["moveRight"], (*) => MoveDirectional("right"))
    Hotkey(keys["moveUp"], (*) => MoveDirectional("up"))
    Hotkey(keys["moveDown"], (*) => MoveDirectional("down"))
    Hotkey(keys["swapMaster"], (*) => SwapFocusedWithMaster())
    Hotkey(keys["closeWindow"], (*) => CloseFocusedWindow())
    Hotkey(keys["toggleTemporaryFloat"], (*) => ToggleTemporaryFloat())
    Hotkey(keys["toggleScratchpad"], (*) => ToggleScratchpad())
    Hotkey(keys["restoreScratchpad"], (*) => RestoreScratchpadToTiling())
    Hotkey(keys["toggleSmartGaps"], (*) => ToggleSmartGaps())
    Hotkey(keys["showHotkeys"], (*) => ShowHotkeyHelp())
    Hotkey(keys["toggleDesktopIndicator"], (*) => ToggleDesktopIndicator())
    if VirtualDesktops.enabled {
        Loop Config["virtualDesktopCount"]
            RegisterWorkspaceHotkey(A_Index)
    }
    DebugLog("Hotkeys registered")
}

RegisterWorkspaceHotkey(workspaceNumber) {
    Hotkey("#" workspaceNumber, (*) => SwitchToVirtualWorkspace(workspaceNumber))
    Hotkey("#+" workspaceNumber,
        (*) => MoveFocusedWindowToVirtualWorkspace(workspaceNumber))
}

GetReservedHotkeys() {
    global Config, VirtualDesktops
    reserved := []
    for _, binding in Config["hotkeys"]
        reserved.Push(binding)
    if VirtualDesktops.enabled {
        Loop Config["virtualDesktopCount"]
            reserved.Push("#" A_Index)
        Loop Config["virtualDesktopCount"]
            reserved.Push("#+" A_Index)
    }
    return reserved
}

InitializeTray() {
    global ConfigDirectory, DefaultConfigPath, UserConfigPath, Manager
    try TraySetIcon(A_ScriptDir "\assets\minwm.ico")
    A_IconHidden := false
    A_IconTip := "minwm — " Manager.layout " layout"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Re-tile active monitor", (*) => RefreshLayout())
    A_TrayMenu.Add("Cycle layout", (*) => CycleLayout())
    A_TrayMenu.Add("Show hotkeys", (*) => ShowHotkeyHelp())
    A_TrayMenu.Add("Open default configuration", OpenDefaultConfig)
    A_TrayMenu.Add("Open user configuration", OpenUserConfig)
    if !FileExist(UserConfigPath)
        A_TrayMenu.Disable("Open user configuration")
    A_TrayMenu.Add("Reload configuration", ReloadConfiguration)
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit minwm", (*) => ExitApp())
    UpdateTrayTip()
    DebugLog("System tray initialized")
}

OpenDefaultConfig(*) {
    global DefaultConfigPath
    Run("notepad.exe " Chr(34) DefaultConfigPath Chr(34))
}

OpenUserConfig(*) {
    global UserConfigPath
    if !FileExist(UserConfigPath)
        return
    Run("notepad.exe " Chr(34) UserConfigPath Chr(34))
}

ReloadConfiguration(*) {
    DebugLog("Reloading configuration")
    Reload()
}

UpdateTrayTip() {
    global Manager, VirtualDesktops
    desktop := ""
    if VirtualDesktops.enabled {
        index := FindVirtualDesktopIndex(
            VirtualDesktops.desktopIds, VirtualDesktops.currentId)
        if index
            desktop := " — D" index
    }
    A_IconTip := "minwm" desktop " — " Manager.layout " layout"
}

ShowHotkeyHelp() {
    global Config, HotkeyHelpGui
    CloseHotkeyHelp()

    helpGui := Gui("+AlwaysOnTop +ToolWindow", "minwm hotkeys")
    helpGui.SetFont("s10", "Segoe UI")
    helpGui.MarginX := 18
    helpGui.MarginY := 16
    helpGui.AddText("w560", "minwm keybindings")
    helpGui.SetFont("s9", "Segoe UI")
    helpGui.AddText(
        "w560", "User overrides are read from " ConfigDirectory "\config.toml. Restart minwm after editing it.")
    hotkeyList := helpGui.AddListView("w560 r18", ["Hotkey", "Behavior"])
    if VirtualDesktops.enabled {
        Loop Config["virtualDesktopCount"] {
            hotkeyList.Add("", "Win + " A_Index,
                "Switch to virtual desktop D" A_Index)
            hotkeyList.Add("", "Win + Shift + " A_Index,
                "Move focused window to D" A_Index " and follow it")
        }
    }
    labels := GetHotkeyHelpLabels()
    for action, binding in Config["hotkeys"] {
        if labels.Has(action)
            hotkeyList.Add("", HumanizeHotkey(binding), labels[action])
    }
    hotkeyList.ModifyCol(1, 130)
    hotkeyList.ModifyCol(2, 405)
    closeButton := helpGui.AddButton("w100 Default", "Close")
    closeButton.OnEvent("Click", CloseHotkeyHelp)
    helpGui.OnEvent("Close", CloseHotkeyHelp)
    HotkeyHelpGui := helpGui
    helpGui.Show()
    DebugLog("Opened hotkey help dialog")
}

CloseHotkeyHelp(*) {
    global HotkeyHelpGui
    if IsObject(HotkeyHelpGui) {
        try HotkeyHelpGui.Destroy()
        HotkeyHelpGui := ""
    }
}

GetHotkeyHelpLabels() {
    return Map(
        "cycleLayout", "Cycle vertical, horizontal, maximized, and floating layouts",
        "retile", "Re-tile the active monitor",
        "increaseGap", "Increase gaps",
        "decreaseGap", "Decrease gaps",
        "increaseMaster", "Increase master area",
        "decreaseMaster", "Decrease master area",
        "focusNext", "Focus next tiled window",
        "focusPrevious", "Focus previous tiled window",
        "focusLeft", "Focus tiled window to the left",
        "focusRight", "Focus tiled window to the right",
        "focusUp", "Focus tiled window above",
        "focusDown", "Focus tiled window below",
        "moveNext", "Move focused window forward",
        "movePrevious", "Move focused window backward",
        "moveLeft", "Move focused window left",
        "moveRight", "Move focused window right",
        "moveUp", "Move focused window up",
        "moveDown", "Move focused window down",
        "swapMaster", "Promote focused window to master",
        "closeWindow", "Close focused window",
        "toggleTemporaryFloat", "Temporarily float or tile the focused window",
        "toggleScratchpad", "Store or show/hide the workspace scratchpad",
        "restoreScratchpad", "Return the workspace scratchpad to tiling",
        "toggleSmartGaps", "Toggle gap removal for a single tiled window",
        "showHotkeys", "Show this hotkey reference",
        "toggleDesktopIndicator", "Show or hide the virtual-desktop indicator"
    )
}

HumanizeHotkey(binding) {
    modifiers := []
    Loop Parse binding {
        character := A_LoopField
        if (character = "#")
            modifiers.Push("Win")
        else if (character = "+")
            modifiers.Push("Shift")
        else if (character = "^")
            modifiers.Push("Ctrl")
        else if (character = "!")
            modifiers.Push("Alt")
        else {
            key := SubStr(binding, A_Index)
            break
        }
    }
    if !IsSet(key)
        key := binding
    return (modifiers.Length ? JoinText(modifiers, " + ") " + " : "") key
}

JoinText(values, separator) {
    text := ""
    for index, value in values
        text .= (index > 1 ? separator : "") value
    return text
}

ApplyCommandLineOptions() {
    global Config, IntegrationTestMode, LogPathWasSpecified, StartupMessages
    IntegrationTestMode := false
    index := 1
    while (index <= A_Args.Length) {
        argument := A_Args[index]
        if (argument = "--log-path") {
            if (index = A_Args.Length || Trim(A_Args[index + 1]) = "") {
                StartupMessages.Push("--log-path requires a non-empty file path; configured log path remains active")
            } else {
                index += 1
                Config["logPath"] := A_Args[index]
                LogPathWasSpecified := true
                StartupMessages.Push("log path set from command line")
            }
        } else if (argument = "--integration-test") {
            IntegrationTestMode := true
            Config["customHotkeysEnabled"] := false
            Config["defaultLayout"] := "floating"
            Config["focusBorderWidth"] := 0
            Config["layoutNotificationsEnabled"] := false
            Config["virtualDesktopsEnabled"] := false
            StartupMessages.Push("integration-test mode enabled: destructive desktop features are disabled")
        }
        index += 1
    }
}

CompleteIntegrationTest(*) {
    DebugLog("integration test manager lifecycle completed")
    ExitApp()
}

InitializeLayoutCycleState() {
    global LayoutCycleState
    LayoutCycleState := { pendingCycles: 0, manager: "" }
}

CycleLayout(*) {
    global Config, LayoutCycleState, Manager
    if IsObject(LayoutCycleState.manager)
        && (ObjPtr(LayoutCycleState.manager) != ObjPtr(Manager))
        ApplyQueuedLayoutCycle()
    LayoutCycleState.manager := Manager
    LayoutCycleState.pendingCycles += 1
    ; Restarting this one-shot timer debounces rapid hotkey auto-repeat and
    ; lets us tile directly to the final requested layout.
    SetTimer(ApplyQueuedLayoutCycle, -Config["layoutCycleDebounceMs"])
}

ApplyQueuedLayoutCycle(*) {
    global LayoutCycleState, Manager
    pendingCycles := LayoutCycleState.pendingCycles
    pendingManager := LayoutCycleState.manager
    LayoutCycleState.pendingCycles := 0
    LayoutCycleState.manager := ""
    if !pendingCycles || !IsObject(pendingManager)
        return

    previous := pendingManager.layout
    pendingManager.layout := LayoutAfterCycles(previous, pendingCycles)
    if (pendingManager.layout = previous) {
        DebugLog("Layout cycle burst left layout unchanged; presses=" pendingCycles)
        return
    }
    pendingManager.lastLayoutState := ""
    ScheduleLayoutStateSave()
    DebugLog("Layout changed: " previous " -> " pendingManager.layout
        "; coalesced presses=" pendingCycles)

    ; A desktop may have changed while the burst was being collected. Preserve
    ; its workspace state, but only disturb the currently visible workspace.
    if (ObjPtr(Manager) != ObjPtr(pendingManager))
        return
    UpdateTrayTip()
    if !IsFocusBorderLayoutActive()
        HideFocusBorder("non-tiled-layout")
    ShowLayoutNotification(pendingManager.layout)
    RefreshLayout()
}

ChangeGap(delta) {
    global Config, Manager
    if !IsTilingModeActive()
        return
    Manager.gap := ClampGap(Manager.gap + delta)
    ScheduleLayoutStateSave()
    DebugLog("Gap changed to " Manager.gap)
    RefreshLayout()
}

ChangeMasterRatio(delta) {
    global Config, Manager
    if !IsTilingModeActive()
        return
    Manager.masterRatio := Min(Config["maxMasterRatio"], Max(Config["minMasterRatio"], Manager.masterRatio + delta))
    ScheduleLayoutStateSave()
    DebugLog("Master ratio changed to " Manager.masterRatio)
    RefreshLayout()
}

FocusRelative(delta) {
    global Manager
    if !IsTilingModeActive()
        return
    index := FindWindowIndex(Manager.order, WinExist("A"))
    if !index || Manager.order.Length < 2
        return
    next := WrapWindowIndex(index + delta, Manager.order.Length)
    DebugLog("Focus moved: hwnd=" Manager.order[index] " -> hwnd=" Manager.order[next])
    WinActivate("ahk_id " Manager.order[next])
}

MoveRelative(delta) {
    global Manager
    if !IsTilingModeActive()
        return
    index := FindWindowIndex(Manager.order, WinExist("A"))
    if !index || Manager.order.Length < 2
        return
    other := WrapWindowIndex(index + delta, Manager.order.Length)
    temp := Manager.order[index]
    Manager.order[index] := Manager.order[other]
    Manager.order[other] := temp
    DebugLog("Tiling order swapped: hwnd=" Manager.order[other] " <-> hwnd=" Manager.order[index])
    RefreshLayout()
}

SwapFocusedWithMaster() {
    global Manager
    if !IsTilingModeActive()
        return
    index := FindWindowIndex(Manager.order, WinExist("A"))
    if !index || index = 1
        return
    temp := Manager.order[1]
    Manager.order[1] := Manager.order[index]
    Manager.order[index] := temp
    DebugLog("Promoted hwnd=" Manager.order[1] " to master")
    RefreshLayout()
}

CloseFocusedWindow() {
    hwnd := WinExist("A")
    if hwnd {
        DebugLog("Close requested for hwnd=" hwnd)
        WinClose("ahk_id " hwnd)
    }
}
