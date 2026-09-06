; Temporary floats are intentionally session-only: they preserve a convenient
; ad-hoc placement without turning a live HWND into persisted configuration.
GetTiledEligibleWindows(windows) {
    tiled := []
    for hwnd in windows {
        if !IsTemporarilyFloating(hwnd) && !IsScratchpadWindow(hwnd)
            tiled.Push(hwnd)
    }
    return tiled
}

IsTemporarilyFloating(hwnd) {
    global Manager
    return Manager.temporaryFloats.Has(hwnd)
        && Manager.temporaryFloats[hwnd].isFloating
}

ToggleTemporaryFloat(*) {
    global Manager
    area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), area)
    hwnd := WinExist("A")
    if !hwnd || !IsEligibleWindow(hwnd) {
        DebugLog("Temporary float ignored; no eligible focused window")
        return
    }
    if IsWindowForcedFloating(hwnd) {
        DebugLog("Temporary float ignored; window is forced floating by a rule; hwnd=" hwnd)
        return
    }

    if IsTemporarilyFloating(hwnd) {
        state := Manager.temporaryFloats[hwnd]
        state.isFloating := false
        insertIndex := Min(Max(1, state.orderIndex), Manager.order.Length + 1)
        if !FindWindowIndex(Manager.order, hwnd)
            Manager.order.InsertAt(insertIndex, hwnd)
        DebugLog("Temporary float tiled; hwnd=" hwnd "; order-index=" insertIndex)
        RefreshLayout()
        return
    }

    index := FindWindowIndex(Manager.order, hwnd)
    if !index {
        DebugLog("Temporary float ignored; focused window is not tiled; hwnd=" hwnd)
        return
    }
    state := Manager.temporaryFloats.Has(hwnd)
        ? Manager.temporaryFloats[hwnd] : { isFloating: false, orderIndex: 0, rect: "" }
    state.orderIndex := index
    state.rect := GetVisibleWindowRect(hwnd)
    state.isFloating := true
    Manager.temporaryFloats[hwnd] := state
    Manager.order.RemoveAt(index)
    DebugLog("Temporary float enabled; hwnd=" hwnd "; order-index=" index
        "; rect=" RectDescription(state.rect))
    RefreshLayout()
    try MoveWindowToRect(hwnd, state.rect.left, state.rect.top,
        RectWidth(state.rect), RectHeight(state.rect))
    catch Error as err
        DebugLog("Temporary float placement failed; hwnd=" hwnd "; " ErrorDescription(err))
}
