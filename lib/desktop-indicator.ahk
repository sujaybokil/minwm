; A lightweight, click-through status window.  It is deliberately separate
; from the focus border because it represents desktop state, not window focus.
InitializeDesktopIndicatorState() {
    global DesktopIndicator
    DesktopIndicator := {
        gui: "", text: "", enabled: false, visible: false, lastPosition: ""
    }
}

StartDesktopIndicator() {
    global Config, DesktopIndicator
    try {
        indicator := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        indicator.BackColor := Config["desktopIndicatorBackgroundColor"]
        indicator.MarginX := 0
        indicator.MarginY := 0
        indicator.SetFont("s" Config["desktopIndicatorFontSize"] " c"
            Config["desktopIndicatorTextColor"], Config["desktopIndicatorFontName"])
        label := indicator.AddText("x0 y0 w" Config["desktopIndicatorWidth"]
            " h" Config["desktopIndicatorHeight"] " Center +0x200", "D1")
        indicator.Show("NA x-32000 y-32000 w" Config["desktopIndicatorWidth"]
            " h" Config["desktopIndicatorHeight"])
        WinSetTransparent(Config["desktopIndicatorOpacity"], "ahk_id " indicator.Hwnd)
        DesktopIndicator.gui := indicator
        DesktopIndicator.text := label
        DesktopIndicator.enabled := true
        DesktopIndicator.visible := true
        SetTimer(PositionDesktopIndicator, Config["desktopIndicatorPollInterval"])
        UpdateDesktopIndicator()
        DebugLog("Desktop indicator started")
    } catch Error as err {
        DebugLog("Desktop indicator initialization failed: " ErrorDescription(err))
        StopDesktopIndicator()
    }
}

StopDesktopIndicator(*) {
    global DesktopIndicator
    SetTimer(PositionDesktopIndicator, 0)
    if IsObject(DesktopIndicator.gui) {
        try DesktopIndicator.gui.Destroy()
    }
    DesktopIndicator.gui := ""
    DesktopIndicator.text := ""
    DesktopIndicator.enabled := false
    DesktopIndicator.visible := false
    DesktopIndicator.lastPosition := ""
}

ToggleDesktopIndicator(*) {
    global DesktopIndicator
    if !DesktopIndicator.enabled
        return
    if DesktopIndicator.visible {
        WinSetTransparent(0, "ahk_id " DesktopIndicator.gui.Hwnd)
        DesktopIndicator.visible := false
        DebugLog("Desktop indicator hidden")
        return
    }
    DesktopIndicator.visible := true
    DesktopIndicator.lastPosition := ""
    WinSetTransparent(Config["desktopIndicatorOpacity"], "ahk_id " DesktopIndicator.gui.Hwnd)
    PositionDesktopIndicator()
    DebugLog("Desktop indicator shown")
}

UpdateDesktopIndicator(*) {
    global DesktopIndicator, VirtualDesktops
    if !DesktopIndicator.enabled || !VirtualDesktops.enabled
        return
    index := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if !index
        return
    DesktopIndicator.text.Text := "D" index
    PositionDesktopIndicator()
}

PositionDesktopIndicator(*) {
    global DesktopIndicator
    if !DesktopIndicator.enabled || !DesktopIndicator.visible
        return
    try WithPerMonitorDpiAwareness((*) => PositionDesktopIndicatorPhysical())
    catch Error as err {
        DebugLog("Desktop indicator positioning failed: " ErrorDescription(err))
    }
}

PositionDesktopIndicatorPhysical() {
    global Config, DesktopIndicator
    index := MonitorGetPrimary()
    ; Use the full monitor bounds rather than the work area so the indicator
    ; sits over the bottom-left of the taskbar instead of above it.
    MonitorGet(index, &left, &top, &right, &bottom)
    WinGetPos(&x, &y, &width, &height, "ahk_id " DesktopIndicator.gui.Hwnd)
    targetX := left + Config["desktopIndicatorX"]
    targetY := bottom - height - Config["desktopIndicatorY"]
    state := targetX "|" targetY "|" width "|" height
    if (state != DesktopIndicator.lastPosition) {
        DesktopIndicator.gui.Show("NA x" targetX " y" targetY)
        DesktopIndicator.lastPosition := state
    }
    ; The taskbar is itself topmost and can reclaim its z-order after shell
    ; updates. Reassert this click-through tool window above it without
    ; activating it; Gui.Show remains responsible for all positioning.
    WinSetAlwaysOnTop(1, "ahk_id " DesktopIndicator.gui.Hwnd)
}
