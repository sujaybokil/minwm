; Reflow coordination is kept apart from startup, tray, and hotkey plumbing.
; It owns the transient Manager selection while visiting each monitor.
RefreshLayout(*) {
    try {
        WithPerMonitorDpiAwareness((*) => RefreshLayoutPhysical())
    } catch Error as err {
        LogRefreshStatus("refresh error: " ErrorDescription(err))
    }
}

RefreshLayoutPhysical() {
    global Manager
    activeArea := GetActiveMonitorArea()
    if !IsObject(activeArea) {
        LogRefreshStatus("no active monitor; active hwnd=" WinExist("A"))
        return
    }
    desktopId := GetActiveWorkspaceId()
    for _, area in GetMonitorAreas() {
        Manager := GetWorkspaceMonitorState(desktopId, area)
        RefreshMonitorLayout(area)
    }
    Manager := GetWorkspaceMonitorState(desktopId, activeArea)
    UpdateFocusBorder()
}

GetActiveWorkspaceId() {
    global VirtualDesktops
    return (VirtualDesktops.enabled && VirtualDesktops.currentId != "")
        ? VirtualDesktops.currentId : "__default__"
}

RefreshMonitorLayout(area) {
    global Manager
    if (Manager.layout = "floating")
        return
    windows := GetTiledEligibleWindows(GetEligibleWindows(area))
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
    layoutGap := GetEffectiveLayoutGap(
        Manager.gap, Manager.smartGaps, Manager.order.Length)
    ApplyLayout(Manager.layout, Manager.order, area, layoutGap, Manager.masterRatio)
    CenterConstraintFloatingWindows(Manager.constraintFloats, area, Manager.gap)
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
