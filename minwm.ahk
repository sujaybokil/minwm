#Requires AutoHotkey v2.0
#SingleInstance Force

#Include "config.ahk"
#Include "lib\config-validation.ahk"
#Include "lib\debug.ahk"
#Include "lib\geometry.ahk"
#Include "lib\window-rules.ahk"
#Include "lib\windows.ahk"
#Include "lib\focus-border.ahk"
#Include "lib\constraints.ahk"
#Include "lib\selection.ahk"
#Include "lib\layouts.ahk"

; Loads all modules without starting the manager; useful for a syntax smoke test.
if (A_Args.Length && A_Args[1] = "--check")
    ExitApp

; Controller state is intentionally workspace-agnostic. A future virtual-desktop
; provider only needs to filter GetEligibleWindows before SyncWindowOrder.
global Manager := { layout: "vertical", gap: Config["defaultGap"], masterRatio: Config["masterRatio"], order: [], constraintFloats: [], lastConstraintStatus: "", lastLayoutState: "", lastRefreshStatus: "" }
global StartupMessages := []
global HotkeyHelpGui := ""

ApplyCommandLineOptions()
InitializeDebugLog()
DebugLog("minwm starting; debug=" Config["debugEnabled"] ", poll=" Config["pollInterval"] "ms")
for message in ConfigLoadMessages
    DebugLog("Config: " message)
for message in StartupMessages
    DebugLog("Startup: " message)
try {
    RegisterHotkeys()
    InitializeTray()
    StartFocusBorder()
    OnExit(HandleManagerExit)
    SetTimer(RefreshLayout, Config["pollInterval"])
    RefreshLayout()
} catch Error as err {
    HandleStartupFailure(err)
}

HandleManagerExit(*) {
    StopFocusBorder()
    DebugLog("minwm exiting")
}

HandleStartupFailure(err) {
    message := "minwm could not start: " ErrorDescription(err)
    DebugLog(message)
    try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " | " message "`n",
        A_ScriptDir "\minwm-startup-error.log", "UTF-8")
    try MsgBox(message "`n`nCheck config.toml and minwm-startup-error.log.",
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
    Hotkey(keys["moveNext"], (*) => MoveRelative(1))
    Hotkey(keys["movePrevious"], (*) => MoveRelative(-1))
    Hotkey(keys["swapMaster"], (*) => SwapFocusedWithMaster())
    Hotkey(keys["closeWindow"], (*) => CloseFocusedWindow())
    Hotkey(keys["showHotkeys"], (*) => ShowHotkeyHelp())
    DebugLog("Hotkeys registered")
}

InitializeTray() {
    global Manager
    try TraySetIcon(A_ScriptDir "\assets\minwm.ico")
    A_IconHidden := false
    A_IconTip := "minwm — " Manager.layout " layout"
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Re-tile active monitor", (*) => RefreshLayout())
    A_TrayMenu.Add("Cycle layout", (*) => CycleLayout())
    A_TrayMenu.Add("Open config.toml", (*) => Run("notepad.exe " Chr(34) A_ScriptDir "\config.toml" Chr(34)))
    A_TrayMenu.Add()
    A_TrayMenu.Add("Exit minwm", (*) => ExitApp())
    DebugLog("System tray initialized")
}

UpdateTrayTip() {
    global Manager
    A_IconTip := "minwm — " Manager.layout " layout"
}

ShowHotkeyHelp() {
    global HotkeyHelpGui
    CloseHotkeyHelp()

    helpGui := Gui("+AlwaysOnTop +ToolWindow", "minwm hotkeys")
    helpGui.SetFont("s10", "Segoe UI")
    helpGui.MarginX := 18
    helpGui.MarginY := 16
    helpGui.AddText("w430", "minwm keybindings")
    helpGui.SetFont("s9", "Segoe UI")
    helpGui.AddText("w430", "These values are read from config.toml. Restart minwm after editing it.")
    helpGui.AddText("w430", "")
    helpGui.AddText("w430", BuildHotkeyHelpText())
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

BuildHotkeyHelpText() {
    global Config
    labels := Map(
        "cycleLayout", "Cycle vertical, horizontal, and floating layouts",
        "retile", "Re-tile the active monitor",
        "increaseGap", "Increase gaps",
        "decreaseGap", "Decrease gaps",
        "increaseMaster", "Increase master area",
        "decreaseMaster", "Decrease master area",
        "focusNext", "Focus next tiled window",
        "focusPrevious", "Focus previous tiled window",
        "moveNext", "Move focused window forward",
        "movePrevious", "Move focused window backward",
        "swapMaster", "Promote focused window to master",
        "closeWindow", "Close focused window",
        "showHotkeys", "Show this hotkey reference"
    )
    text := ""
    for action, binding in Config["hotkeys"] {
        if labels.Has(action)
            text .= HumanizeHotkey(binding) "`t" labels[action] "`n"
    }
    return RTrim(text, "`n")
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
    global Config, StartupMessages
    for index, argument in A_Args {
        if (argument != "--debug")
            continue
        if (index = A_Args.Length) {
            StartupMessages.Push("--debug requires true or false; debug remains disabled")
            return
        }
        value := StrLower(A_Args[index + 1])
        if (value = "true" || value = "1") {
            Config["debugEnabled"] := true
            StartupMessages.Push("debug logging enabled from command line")
        } else if (value = "false" || value = "0") {
            Config["debugEnabled"] := false
        } else {
            StartupMessages.Push("invalid --debug value '" value "'; debug remains disabled")
        }
        return
    }
}

RefreshLayout(*) {
    global Manager
    if (Manager.layout = "floating")
        return
    try {
        WithPerMonitorDpiAwareness((*) => RefreshLayoutPhysical())
    } catch Error as err {
        LogRefreshStatus("refresh error: " ErrorDescription(err))
    }
}

RefreshLayoutPhysical() {
    global Manager
    area := GetActiveMonitorArea()
    if !IsObject(area) {
        LogRefreshStatus("no active monitor; active hwnd=" WinExist("A"))
        return
    }
    windows := GetEligibleWindows(area)
    SyncWindowOrder(windows)
    selection := SelectTileableWindows(Manager.layout, Manager.order, area, Manager.gap)
    Manager.order := selection.tiled
    Manager.constraintFloats := selection.floating
    LogConstraintSelection(selection)
    LogRefreshStatus("monitor=" area.index
        "; eligible=" windows.Length
        "; tiled=" Manager.order.Length
        "; constraint-floating=" Manager.constraintFloats.Length
        "; top-level=" WinGetList().Length)
    LogLayoutChange(area)
    ApplyLayout(Manager.layout, Manager.order, area, Manager.gap, Manager.masterRatio)
    CenterConstraintFloatingWindows(
        Manager.constraintFloats, area, Manager.gap)
}

LogConstraintSelection(selection) {
    global Manager
    status := ConstraintSelectionDescription(selection.floatingDetails)
    if (status != Manager.lastConstraintStatus) {
        DebugLog("Constraint decision: " status)
        Manager.lastConstraintStatus := status
    }
}

LogRefreshStatus(status) {
    global Manager
    if (status != Manager.lastRefreshStatus) {
        DebugLog("Refresh: " status)
        Manager.lastRefreshStatus := status
    }
}

LogLayoutChange(area) {
    global Manager
    state := Manager.layout
        . "|monitor=" area.index
        . "|gap=" Manager.gap
        . "|ratio=" Manager.masterRatio
        . "|windows=" WindowListDescription(Manager.order)
        . "|constraint-floating=" WindowListDescription(Manager.constraintFloats)
    if (state != Manager.lastLayoutState) {
        DebugLog("Reflow " state)
        Manager.lastLayoutState := state
    }
}

SyncWindowOrder(currentWindows) {
    global Manager
    current := Map()
    for hwnd in currentWindows
        current[hwnd] := true

    ordered := []
    for hwnd in Manager.order {
        if current.Has(hwnd)
            ordered.Push(hwnd)
    }
    for hwnd in currentWindows {
        if !FindWindowIndex(ordered, hwnd)
            ordered.Push(hwnd)
    }
    Manager.order := ordered
}

CycleLayout() {
    global Manager
    previous := Manager.layout
    Manager.layout := (Manager.layout = "vertical") ? "horizontal" : (Manager.layout = "horizontal") ? "floating" : "vertical"
    Manager.lastLayoutState := ""
    DebugLog("Layout changed: " previous " -> " Manager.layout)
    UpdateTrayTip()
    RefreshLayout()
}

ChangeGap(delta) {
    global Config, Manager
    Manager.gap := Max(Config["minGap"], Manager.gap + delta)
    DebugLog("Gap changed to " Manager.gap)
    RefreshLayout()
}

ChangeMasterRatio(delta) {
    global Config, Manager
    Manager.masterRatio := Min(Config["maxMasterRatio"], Max(Config["minMasterRatio"], Manager.masterRatio + delta))
    DebugLog("Master ratio changed to " Manager.masterRatio)
    RefreshLayout()
}

FocusRelative(delta) {
    global Manager
    index := FindWindowIndex(Manager.order, WinExist("A"))
    if !index || Manager.order.Length < 2
        return
    next := Mod(index - 1 + delta, Manager.order.Length) + 1
    DebugLog("Focus moved: hwnd=" Manager.order[index] " -> hwnd=" Manager.order[next])
    WinActivate("ahk_id " Manager.order[next])
}

MoveRelative(delta) {
    global Manager
    index := FindWindowIndex(Manager.order, WinExist("A"))
    if !index || Manager.order.Length < 2
        return
    other := Mod(index - 1 + delta, Manager.order.Length) + 1
    temp := Manager.order[index]
    Manager.order[index] := Manager.order[other]
    Manager.order[other] := temp
    DebugLog("Tiling order swapped: hwnd=" Manager.order[other] " <-> hwnd=" Manager.order[index])
    RefreshLayout()
}

SwapFocusedWithMaster() {
    global Manager
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
