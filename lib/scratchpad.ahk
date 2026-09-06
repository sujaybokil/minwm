; Each workspace-monitor pair has one scratchpad slot. Its HWND and geometry
; are session-only, so closed applications never become persistent state.
ToggleScratchpad(*) {
    global Manager
    area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), area)
    if HasScratchpadWindow(Manager) {
        ToggleStoredScratchpad(Manager)
        return
    }
    StoreFocusedWindowAsScratchpad(Manager)
}

RestoreScratchpadToTiling(*) {
    global Manager
    area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), area)
    if !HasScratchpadWindow(Manager) {
        DebugLog("Scratchpad restore ignored; no scratchpad on the active workspace monitor")
        return
    }
    scratchpad := Manager.scratchpad
    hwnd := scratchpad.hwnd
    try {
        WinShow("ahk_id " hwnd)
        insertIndex := Min(Max(1, scratchpad.orderIndex), Manager.order.Length + 1)
        if !FindWindowIndex(Manager.order, hwnd)
            Manager.order.InsertAt(insertIndex, hwnd)
        Manager.scratchpad := { hwnd: 0, rect: "", visible: false, orderIndex: 0 }
        DebugLog("Scratchpad returned to tiling; hwnd=" hwnd
            "; order-index=" insertIndex)
        RefreshLayout()
        WinActivate("ahk_id " hwnd)
    } catch Error as err {
        DebugLog("Scratchpad restore failed; hwnd=" hwnd "; " ErrorDescription(err))
    }
}

HasScratchpadWindow(state) {
    if !state.scratchpad.hwnd
        return false
    if WinExist("ahk_id " state.scratchpad.hwnd)
        return true
    state.scratchpad := { hwnd: 0, rect: "", visible: false, orderIndex: 0 }
    return false
}

IsScratchpadWindow(hwnd) {
    global Manager
    return Manager.scratchpad.hwnd = hwnd
}

StoreFocusedWindowAsScratchpad(state) {
    hwnd := WinExist("A")
    if !hwnd || !IsEligibleWindow(hwnd) {
        DebugLog("Scratchpad ignored; no eligible focused window")
        return
    }
    if IsWindowForcedFloating(hwnd) || IsTemporarilyFloating(hwnd) {
        DebugLog("Scratchpad ignored; window is already floating; hwnd=" hwnd)
        return
    }
    index := FindWindowIndex(state.order, hwnd)
    if !index {
        DebugLog("Scratchpad ignored; focused window is not tiled; hwnd=" hwnd)
        return
    }
    state.scratchpad := {
        hwnd: hwnd,
        rect: GetVisibleWindowRect(hwnd),
        visible: false,
        orderIndex: index
    }
    state.order.RemoveAt(index)
    DebugLog("Scratchpad stored and hidden; hwnd=" hwnd "; order-index=" index)
    WinHide("ahk_id " hwnd)
    RefreshLayout()
}

ToggleStoredScratchpad(state) {
    hwnd := state.scratchpad.hwnd
    if state.scratchpad.visible {
        WinHide("ahk_id " hwnd)
        state.scratchpad.visible := false
        DebugLog("Scratchpad hidden; hwnd=" hwnd)
        RefreshLayout()
        return
    }
    try {
        WinShow("ahk_id " hwnd)
        rect := state.scratchpad.rect
        MoveWindowToRect(hwnd, rect.left, rect.top,
            RectWidth(rect), RectHeight(rect))
        WinActivate("ahk_id " hwnd)
        state.scratchpad.visible := true
        DebugLog("Scratchpad shown; hwnd=" hwnd
            "; rect=" RectDescription(rect))
    } catch Error as err {
        DebugLog("Scratchpad show failed; hwnd=" hwnd "; " ErrorDescription(err))
    }
}
