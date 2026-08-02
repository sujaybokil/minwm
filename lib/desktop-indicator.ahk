; A lightweight, click-through status window.  It is deliberately separate
; from the focus border because it represents desktop state, not window focus.
InitializeDesktopIndicatorState() {
    global DesktopIndicator
    DesktopIndicator := { gui: "", text: "", enabled: false, lastPosition: "" }
}

StartDesktopIndicator() {
    global DesktopIndicator
    try {
        indicator := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
        indicator.BackColor := "202020"
        indicator.MarginX := 10
        indicator.MarginY := 5
        indicator.SetFont("s11 cFFFFFF", "Segoe UI Semibold")
        label := indicator.AddText("w44 Center", "D1")
        indicator.Show("NA x-32000 y-32000")
        WinSetTransparent(185, "ahk_id " indicator.Hwnd)
        DesktopIndicator.gui := indicator
        DesktopIndicator.text := label
        DesktopIndicator.enabled := true
        SetTimer(PositionDesktopIndicator, 1000)
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
    DesktopIndicator.lastPosition := ""
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
    if !DesktopIndicator.enabled
        return
    try WithPerMonitorDpiAwareness((*) => PositionDesktopIndicatorPhysical())
    catch Error as err {
        DebugLog("Desktop indicator positioning failed: " ErrorDescription(err))
    }
}

PositionDesktopIndicatorPhysical() {
    global DesktopIndicator
    index := MonitorGetPrimary()
    ; Use the full monitor bounds rather than the work area so the indicator
    ; sits over the bottom-left of the taskbar instead of above it.
    MonitorGet(index, &left, &top, &right, &bottom)
    WinGetPos(&x, &y, &width, &height, "ahk_id " DesktopIndicator.gui.Hwnd)
    targetX := left + 12
    targetY := bottom - height - 12
    state := targetX "|" targetY "|" width "|" height
    if (state = DesktopIndicator.lastPosition)
        return
    DesktopIndicator.gui.Show("NA x" targetX " y" targetY)
    DesktopIndicator.lastPosition := state
}
