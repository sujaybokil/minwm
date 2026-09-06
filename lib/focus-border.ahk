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
        SetTimer(UpdateFocusBorder, Config["focusBorderPollInterval"])
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

    if !IsFocusBorderLayoutActive() {
        HideFocusBorder("non-tiled-layout")
        return
    }

    ; Read the foreground HWND directly. Some fullscreen, game, and remote-app
    ; windows can make AutoHotkey's active-window lookup lag behind the actual
    ; foreground transition, leaving a border over the previous tiled window.
    foregroundHwnd := DllCall("User32\GetForegroundWindow", "ptr")
    hwnd := GetFocusBorderTarget(foregroundHwnd)
    if !hwnd {
        HideFocusBorder("hidden")
        return
    }

    try WithPerMonitorDpiAwareness(
        (*) => PositionFocusBorderPhysical(hwnd, foregroundHwnd))
    catch Error as err {
        HideFocusBorder("error")
        DebugLog("Focus border update failed for hwnd=" hwnd ": "
            ErrorDescription(err))
    }
}

IsHighlightableWindow(hwnd) {
    global Manager
    try {
        ; Manager.order contains the windows selected for the current tiled
        ; layout.  Reuse the normal eligibility predicate as well, so dialogs,
        ; notifications, fixed/small windows, and excluded classes never gain
        ; a focus border even when they become foreground.
        return IsEligibleWindow(hwnd)
            && FindWindowIndex(Manager.order, hwnd) != 0
    } catch {
        return false
    }
}

GetFocusBorderTarget(foregroundHwnd) {
    ; Chromium-based browsers use a small owned popup for some context and
    ; dropdown menus. Windows makes that popup foreground, but it is still
    ; part of the browser interaction rather than a new tiled target. Keep the
    ; border on its eligible owner until the popup closes.
    if !foregroundHwnd
        return 0
    if IsHighlightableWindow(foregroundHwnd)
        return foregroundHwnd
    try {
        title := "ahk_id " foregroundHwnd
        className := WinGetClass(title)
        exStyle := WinGetExStyle(title)
        ownerHwnd := DllCall(
            "User32\GetWindow", "ptr", foregroundHwnd, "uint", 4, "ptr") ; GW_OWNER
        if !CanFocusBorderFollowOwner(className, exStyle, ownerHwnd)
            return 0
        return IsHighlightableWindow(ownerHwnd) ? ownerHwnd : 0
    } catch {
        return 0
    }
}

CanFocusBorderFollowOwner(className, exStyle, ownerHwnd) {
    ; Do not retain the border for genuine dialogs. Menu-like popups, including
    ; Chromium's owned menu windows, have neither dialog marker.
    static WS_EX_DLGMODALFRAME := 0x00000001
    return ownerHwnd
        && className != "#32770"
        && !(exStyle & WS_EX_DLGMODALFRAME)
}

IsFocusBorderLayoutActive() {
    global Config, Manager
    return LayoutListContains(Config["focusBorderLayouts"], Manager.layout)
}

LayoutListContains(layouts, candidate) {
    for _, layout in layouts {
        if (layout = candidate)
            return true
    }
    return false
}

PositionFocusBorderPhysical(hwnd, foregroundHwnd := 0) {
    global Config, FocusBorder
    rect := GetVisibleWindowRect(hwnd)
    ; The edges live in the topmost band so they remain visible above their
    ; tiled target.  Do not let them leak through a different window which is
    ; already above that target in the normal z-order.
    if IsFocusBorderOccluded(hwnd, rect, foregroundHwnd) {
        HideFocusBorder("occluded")
        return
    }
    edgeRects := CalculateFocusBorderRects(
        rect, Config["focusBorderWidth"])
    if (edgeRects.Length != FocusBorder.edges.Length) {
        HideFocusBorder("invalid")
        return
    }

    state := hwnd "|" RectDescription(rect)
    ; The timer is a fallback for applications that omit location events. Do
    ; not force four topmost frame changes on every tick when the target and
    ; its visible bounds did not change: Chromium/Electron applications emit
    ; enough incidental UI activity for that to visibly flicker the border.
    if (state = FocusBorder.lastState)
        return

    for index, edgeRect in edgeRects
        SetFocusBorderEdgeRect(FocusBorder.edges[index].Hwnd, edgeRect)

    DebugLog("Focus border target hwnd=" hwnd
        "; visible=" RectDescription(rect))
    FocusBorder.lastState := state
}

IsFocusBorderOccluded(targetHwnd, targetRect, ignoredHwnd := 0) {
    global FocusBorder
    return IsFocusBorderOccludedInZOrder(
        targetHwnd, targetRect, BuildFocusBorderZOrderSnapshot(), ignoredHwnd)
}

BuildFocusBorderZOrderSnapshot() {
    global FocusBorder
    windows := []
    for _, hwnd in WinGetList() {
        try {
            windows.Push({
                hwnd: hwnd,
                isFocusBorder: IsFocusBorderEdge(hwnd),
                visible: DllCall("User32\IsWindowVisible", "ptr", hwnd, "int") != 0,
                minimized: WinGetMinMax("ahk_id " hwnd) = -1,
                rect: GetVisibleWindowRect(hwnd)
            })
        } catch {
        }
    }
    return windows
}

IsFocusBorderOccludedInZOrder(targetHwnd, targetRect, windows, ignoredHwnd := 0) {
    ; The snapshot is ordered top-to-bottom. A fullscreen or topmost app can
    ; be in a different z-order band, so inspect every visible window before
    ; the target rather than assuming it shares minwm's normal window order.
    for _, window in windows {
        if (window.hwnd = targetHwnd)
            return false
        if (window.hwnd = ignoredHwnd) || window.isFocusBorder || !window.visible || window.minimized
            continue
        if RectsOverlap(targetRect, window.rect)
            return true
    }
    return false
}

IsFocusBorderEdge(hwnd) {
    global FocusBorder
    for _, edge in FocusBorder.edges {
        if (edge.Hwnd = hwnd)
            return true
    }
    return false
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
