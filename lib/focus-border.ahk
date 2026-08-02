; Four click-through, non-activating tool windows form a thin border inside the
; focused window's visible DWM frame. They never participate in tiling.
InitializeFocusBorderState() {
    global FocusBorder
    FocusBorder := {
        edges: [],
        lastState: "",
        enabled: false,
        locationEventHook: 0,
        locationEventCallback: 0,
        foregroundEventHook: 0,
        foregroundEventCallback: 0
    }
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
        StartFocusBorderLocationTracking()
        ; Location-change events provide immediate updates while dragging.
        ; This short polling fallback covers applications which do not emit
        ; them consistently during live resize.
        SetTimer(UpdateFocusBorder, 33)
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
    StopFocusBorderLocationTracking()
    for edge in FocusBorder.edges {
        try edge.Destroy()
    }
    FocusBorder.edges := []
    FocusBorder.enabled := false
    FocusBorder.lastState := ""
}

StartFocusBorderLocationTracking() {
    global FocusBorder
    static EVENT_OBJECT_LOCATIONCHANGE := 0x800B
    static EVENT_SYSTEM_FOREGROUND := 0x0003
    static WINEVENT_OUTOFCONTEXT := 0
    static WINEVENT_SKIPOWNPROCESS := 0x2

    try {
        FocusBorder.locationEventCallback := CallbackCreate(
            HandleFocusBorderLocationChange, , 7)
        FocusBorder.locationEventHook := DllCall(
            "User32\SetWinEventHook",
            "uint", EVENT_OBJECT_LOCATIONCHANGE,
            "uint", EVENT_OBJECT_LOCATIONCHANGE,
            "ptr", 0,
            "ptr", FocusBorder.locationEventCallback,
            "uint", 0,
            "uint", 0,
            "uint", WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS,
            "ptr")
        if !FocusBorder.locationEventHook
            throw OSError(A_LastError, "SetWinEventHook focus border")
        FocusBorder.foregroundEventCallback := CallbackCreate(
            HandleFocusBorderForegroundChange, , 7)
        FocusBorder.foregroundEventHook := DllCall(
            "User32\SetWinEventHook",
            "uint", EVENT_SYSTEM_FOREGROUND,
            "uint", EVENT_SYSTEM_FOREGROUND,
            "ptr", 0,
            "ptr", FocusBorder.foregroundEventCallback,
            "uint", 0,
            "uint", 0,
            "uint", WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS,
            "ptr")
        if !FocusBorder.foregroundEventHook
            throw OSError(A_LastError, "SetWinEventHook focus foreground")
        DebugLog("Focus border location tracking enabled")
    } catch Error as err {
        if FocusBorder.locationEventHook {
            try DllCall("User32\UnhookWinEvent",
                "ptr", FocusBorder.locationEventHook)
        }
        if FocusBorder.locationEventCallback {
            try CallbackFree(FocusBorder.locationEventCallback)
            FocusBorder.locationEventCallback := 0
        }
        FocusBorder.locationEventHook := 0
        if FocusBorder.foregroundEventHook {
            try DllCall("User32\UnhookWinEvent",
                "ptr", FocusBorder.foregroundEventHook)
        }
        if FocusBorder.foregroundEventCallback {
            try CallbackFree(FocusBorder.foregroundEventCallback)
            FocusBorder.foregroundEventCallback := 0
        }
        FocusBorder.foregroundEventHook := 0
        DebugLog("Focus border location tracking unavailable: "
            ErrorDescription(err))
    }
}

StopFocusBorderLocationTracking() {
    global FocusBorder
    if FocusBorder.locationEventHook {
        try DllCall("User32\UnhookWinEvent",
            "ptr", FocusBorder.locationEventHook)
    }
    if FocusBorder.foregroundEventHook {
        try DllCall("User32\UnhookWinEvent",
            "ptr", FocusBorder.foregroundEventHook)
    }
    if FocusBorder.locationEventCallback {
        try CallbackFree(FocusBorder.locationEventCallback)
    }
    if FocusBorder.foregroundEventCallback {
        try CallbackFree(FocusBorder.foregroundEventCallback)
    }
    FocusBorder.locationEventHook := 0
    FocusBorder.locationEventCallback := 0
    FocusBorder.foregroundEventHook := 0
    FocusBorder.foregroundEventCallback := 0
}

HandleFocusBorderLocationChange(eventHook, event, hwnd, idObject, idChild,
    eventThread, eventTime) {
    global FocusBorder
    static OBJID_WINDOW := 0
    if !FocusBorder.enabled || (idObject != OBJID_WINDOW) || idChild
        return
    if (hwnd != WinExist("A"))
        return
    ; Schedule instead of drawing from the system callback, which coalesces a
    ; burst of move/resize notifications into one normal AutoHotkey thread.
    SetTimer(UpdateFocusBorder, -1)
}

HandleFocusBorderForegroundChange(eventHook, event, hwnd, idObject, idChild,
    eventThread, eventTime) {
    global FocusBorder
    if !FocusBorder.enabled
        return
    ; A close or activation can change the focused window without generating a
    ; location event for the next target.
    SetTimer(UpdateFocusBorder, -1)
}

UpdateFocusBorder(*) {
    global FocusBorder
    if !FocusBorder.enabled
        return

    if !IsTilingModeActive() {
        HideFocusBorder("floating-layout")
        return
    }

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
    static SWP_FRAMECHANGED := 0x0020
    ; Reapply the frame styles while showing each edge. This prevents Windows
    ; from leaving a reused tool window behind its newly focused target.
    flags := SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_NOOWNERZORDER | SWP_FRAMECHANGED
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
