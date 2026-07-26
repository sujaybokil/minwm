; Four click-through, non-activating tool windows form a thin border inside the
; focused window's visible DWM frame. They never participate in tiling.
global FocusBorder := {
    edges: [],
    lastState: "",
    enabled: false
}

StartFocusBorder() {
    global Config, FocusBorder
    if (Config["focusBorderWidth"] = 0) {
        DebugLog("Focus border disabled by configuration")
        return
    }

    try {
        Loop 4 {
            edge := Gui(
                "+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
            edge.BackColor := Config["focusBorderColor"]
            edge.Show("NA x-32000 y-32000 w1 h1")
            DllCall("User32\ShowWindow", "ptr", edge.Hwnd, "int", 0)
            FocusBorder.edges.Push(edge)
        }
        FocusBorder.enabled := true
        SetTimer(UpdateFocusBorder, Config["pollInterval"])
        UpdateFocusBorder()
        DebugLog("Focus border started; width=" Config["focusBorderWidth"]
            "; color=#" Config["focusBorderColor"])
    } catch Error as err {
        DebugLog("Focus border initialization failed: " ErrorDescription(err))
        StopFocusBorder()
    }
}

StopFocusBorder(*) {
    global FocusBorder
    try SetTimer(UpdateFocusBorder, 0)
    for edge in FocusBorder.edges {
        try edge.Destroy()
    }
    FocusBorder.edges := []
    FocusBorder.enabled := false
    FocusBorder.lastState := ""
}

UpdateFocusBorder(*) {
    global FocusBorder
    if !FocusBorder.enabled
        return

    hwnd := WinExist("A")
    if !hwnd || !IsHighlightableWindow(hwnd) {
        HideFocusBorder("hidden")
        return
    }

    try WithPerMonitorDpiAwareness(
        (*) => PositionFocusBorderPhysical(hwnd))
    catch Error as err {
        HideFocusBorder("error")
        DebugLog("Focus border update failed for hwnd=" hwnd ": "
            ErrorDescription(err))
    }
}

IsHighlightableWindow(hwnd) {
    global Config
    try {
        if !DllCall("User32\IsWindowVisible", "ptr", hwnd, "int")
            return false
        if (WinGetMinMax("ahk_id " hwnd) = -1)
            return false
        if (WinGetExStyle("ahk_id " hwnd) & 0x80) ; WS_EX_TOOLWINDOW
            return false
        if Config["excludedClasses"].Has(WinGetClass("ahk_id " hwnd))
            return false
        rect := GetVisibleWindowRect(hwnd)
        return RectWidth(rect) > 0 && RectHeight(rect) > 0
    } catch {
        return false
    }
}

PositionFocusBorderPhysical(hwnd) {
    global Config, FocusBorder
    rect := GetVisibleWindowRect(hwnd)
    edgeRects := CalculateFocusBorderRects(
        rect, Config["focusBorderWidth"])
    if (edgeRects.Length != FocusBorder.edges.Length) {
        HideFocusBorder("invalid")
        return
    }

    for index, edgeRect in edgeRects
        SetFocusBorderEdgeRect(FocusBorder.edges[index].Hwnd, edgeRect)

    state := hwnd "|" RectDescription(rect)
    if (state != FocusBorder.lastState) {
        DebugLog("Focus border target hwnd=" hwnd
            "; visible=" RectDescription(rect))
        FocusBorder.lastState := state
    }
}

SetFocusBorderEdgeRect(hwnd, rect) {
    static HWND_TOPMOST := -1
    static SWP_NOACTIVATE := 0x0010
    static SWP_SHOWWINDOW := 0x0040
    static SWP_NOOWNERZORDER := 0x0200
    flags := SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_NOOWNERZORDER
    if !DllCall("User32\SetWindowPos",
        "ptr", hwnd,
        "ptr", HWND_TOPMOST,
        "int", rect.left,
        "int", rect.top,
        "int", RectWidth(rect),
        "int", RectHeight(rect),
        "uint", flags,
        "int")
        throw OSError(A_LastError, "SetWindowPos focus-border edge")
}

HideFocusBorder(state := "hidden") {
    global FocusBorder
    for edge in FocusBorder.edges
        DllCall("User32\ShowWindow", "ptr", edge.Hwnd, "int", 0)
    FocusBorder.lastState := state
}
