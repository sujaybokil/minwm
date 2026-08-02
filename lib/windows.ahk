WithPerMonitorDpiAwareness(callback) {
    ; AutoHotkey is system-DPI-aware by default. DWM extended frame bounds are
    ; physical pixels, so temporarily put every geometry API in the same
    ; coordinate space. Restore the old context before any GUI work can run.
    oldContext := DllCall("User32\SetThreadDpiAwarenessContext", "ptr", -4, "ptr")
    if !oldContext
        oldContext := DllCall("User32\SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !oldContext
        return callback.Call()

    try return callback.Call()
    finally DllCall("User32\SetThreadDpiAwarenessContext", "ptr", oldContext, "ptr")
}

InitializeWindowsState() {
    global WindowMinimumSizeCache
    WindowMinimumSizeCache := Map()
}

GetRawWindowRect(hwnd) {
    rectBuffer := Buffer(16, 0)
    if !DllCall("User32\GetWindowRect", "ptr", hwnd, "ptr", rectBuffer, "int")
        throw OSError(A_LastError, "GetWindowRect")
    return {
        left: NumGet(rectBuffer, 0, "int"),
        top: NumGet(rectBuffer, 4, "int"),
        right: NumGet(rectBuffer, 8, "int"),
        bottom: NumGet(rectBuffer, 12, "int")
    }
}

TryGetDwmVisibleWindowRect(hwnd) {
    static DWMWA_EXTENDED_FRAME_BOUNDS := 9
    rectBuffer := Buffer(16, 0)
    result := DllCall("Dwmapi\DwmGetWindowAttribute",
        "ptr", hwnd,
        "uint", DWMWA_EXTENDED_FRAME_BOUNDS,
        "ptr", rectBuffer,
        "uint", rectBuffer.Size,
        "int")
    if (result != 0)
        return ""

    rect := {
        left: NumGet(rectBuffer, 0, "int"),
        top: NumGet(rectBuffer, 4, "int"),
        right: NumGet(rectBuffer, 8, "int"),
        bottom: NumGet(rectBuffer, 12, "int")
    }
    return (RectWidth(rect) > 0 && RectHeight(rect) > 0) ? rect : ""
}

GetWindowGeometry(hwnd) {
    raw := GetRawWindowRect(hwnd)
    visible := TryGetDwmVisibleWindowRect(hwnd)
    return {
        raw: raw,
        visible: IsObject(visible) ? visible : raw,
        usedDwm: IsObject(visible)
    }
}

GetVisibleWindowRect(hwnd) {
    return GetWindowGeometry(hwnd).visible
}

GetVisibleMinimumSize(hwnd) {
    global WindowMinimumSizeCache
    dpi := DllCall("User32\GetDpiForWindow", "ptr", hwnd, "uint")
    if WindowMinimumSizeCache.Has(hwnd) {
        cached := WindowMinimumSizeCache[hwnd]
        if (cached.dpi = dpi)
            return cached.size
    }

    static WM_GETMINMAXINFO := 0x0024
    static SMTO_BLOCK := 0x0001
    static SMTO_ABORTIFHUNG := 0x0002
    minMaxBuffer := Buffer(40, 0)
    messageResult := 0
    succeeded := DllCall("User32\SendMessageTimeoutW",
        "ptr", hwnd,
        "uint", WM_GETMINMAXINFO,
        "ptr", 0,
        "ptr", minMaxBuffer,
        "uint", SMTO_BLOCK | SMTO_ABORTIFHUNG,
        "uint", 100,
        "uptr*", &messageResult,
        "ptr")
    if !succeeded
    {
        size := { width: 0, height: 0 }
        WindowMinimumSizeCache[hwnd] := { dpi: dpi, size: size }
        DebugLog("Minimum size query timed out or was blocked for hwnd=" hwnd)
        return size
    }

    rawWidth := NumGet(minMaxBuffer, 24, "int")
    rawHeight := NumGet(minMaxBuffer, 28, "int")
    geometry := GetWindowGeometry(hwnd)
    margins := GetInvisibleFrameMargins(geometry.raw, geometry.visible)
    size := {
        width: Max(0, rawWidth - margins.left - margins.right),
        height: Max(0, rawHeight - margins.top - margins.bottom)
    }
    WindowMinimumSizeCache[hwnd] := { dpi: dpi, size: size }
    return size
}

PruneWindowMinimumSizeCache(windows) {
    global WindowMinimumSizeCache
    current := Map()
    for hwnd in windows
        current[hwnd] := true
    stale := []
    for hwnd, _ in WindowMinimumSizeCache {
        if !current.Has(hwnd)
            stale.Push(hwnd)
    }
    for hwnd in stale
        WindowMinimumSizeCache.Delete(hwnd)
}

GetActiveMonitorArea() {
    hwnd := WinExist("A")
    if !hwnd
        return GetPrimaryMonitorArea()

    rect := GetVisibleWindowRect(hwnd)
    centerX := rect.left + RectWidth(rect) // 2
    centerY := rect.top + RectHeight(rect) // 2

    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        if (centerX >= left && centerX < right && centerY >= top && centerY < bottom)
            return { index: A_Index, left: left, top: top, right: right, bottom: bottom }
    }
    return GetPrimaryMonitorArea()
}

GetPrimaryMonitorArea() {
    index := MonitorGetPrimary()
    MonitorGetWorkArea(index, &left, &top, &right, &bottom)
    return { index: index, left: left, top: top, right: right, bottom: bottom }
}

GetEligibleWindows(area) {
    windows := []
    for hwnd in WinGetList() {
        if (IsEligibleWindow(hwnd) && IsWindowOnCurrentVirtualDesktop(hwnd)
            && IsWindowOnArea(hwnd, area))
            windows.Push(hwnd)
    }
    PruneWindowMinimumSizeCache(windows)
    return windows
}

IsEligibleWindow(hwnd) {
    global Config
    title := "ahk_id " hwnd

    try {
        if !DllCall("IsWindowVisible", "ptr", hwnd, "int")
            return false
        if (WinGetMinMax(title) = -1)
            return false

        style := WinGetStyle(title)
        exStyle := WinGetExStyle(title)
        if !(style & 0x10000000) ; WS_VISIBLE
            return false
        className := WinGetClass(title)
        if IsWindowsStartMenuOrSearch(WinGetProcessName(title))
            return false
        ownerHwnd := DllCall(
            "User32\GetWindow", "ptr", hwnd, "uint", 4, "ptr") ; GW_OWNER
        if HasDialogOrPopupSemantics(
            style, exStyle, className, ownerHwnd)
            return false
        if !(style & 0x40000) ; WS_THICKFRAME: filters most dialogs and fixed popups.
            return false

        if Config["excludedClasses"].Has(className)
            return false

        rect := GetVisibleWindowRect(hwnd)
        return RectWidth(rect) >= Config["minWidth"] && RectHeight(rect) >= Config["minHeight"]
    } catch {
        return false
    }
}

IsWindowOnArea(hwnd, area) {
    try rect := GetVisibleWindowRect(hwnd)
    catch
        return false
    centerX := rect.left + RectWidth(rect) // 2
    centerY := rect.top + RectHeight(rect) // 2
    return centerX >= area.left && centerX < area.right && centerY >= area.top && centerY < area.bottom
}

FindWindowIndex(windows, hwnd) {
    for index, candidate in windows {
        if (candidate = hwnd)
            return index
    }
    return 0
}

WrapWindowIndex(index, count) {
    if (count <= 0)
        return 0
    return Mod(Mod(index - 1, count) + count, count) + 1
}
