; Keyboard navigation is isolated from the controller so its geometry policy
; can be unit-tested without the timer, tray, or virtual-desktop lifecycle.
FocusDirectional(direction) {
    global Manager
    area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), area)
    SyncWindowOrder(GetTiledEligibleWindows(GetEligibleWindows(area)))
    hwnd := WinExist("A")
    target := FindDirectionalWindow(Manager.order, hwnd, direction)
    if target {
        WinActivate("ahk_id " target)
        return
    }
    adjacent := GetAdjacentMonitorArea(area, direction)
    if !IsObject(adjacent)
        return
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), adjacent)
    SyncWindowOrder(GetTiledEligibleWindows(GetEligibleWindows(adjacent)))
    if Manager.order.Length
        WinActivate("ahk_id " Manager.order[1])
}

MoveDirectional(direction) {
    global Manager
    area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(GetActiveWorkspaceId(), area)
    SyncWindowOrder(GetTiledEligibleWindows(GetEligibleWindows(area)))
    hwnd := WinExist("A")
    index := FindWindowIndex(Manager.order, hwnd)
    if !index
        return
    target := FindDirectionalWindow(Manager.order, hwnd, direction)
    if target {
        other := FindWindowIndex(Manager.order, target)
        Manager.order[index] := target
        Manager.order[other] := hwnd
        RefreshLayout()
        return
    }
    destinationArea := GetAdjacentMonitorArea(area, direction)
    if !IsObject(destinationArea)
        return
    destination := GetWorkspaceMonitorState(GetActiveWorkspaceId(), destinationArea)
    Manager.order.RemoveAt(index)
    destination.order.Push(hwnd)
    try MoveWindowToRect(hwnd, destinationArea.left, destinationArea.top, 1, 1)
    RefreshLayout()
}

FindDirectionalWindow(windows, hwnd, direction) {
    if !hwnd
        return 0
    try source := GetVisibleWindowRect(hwnd)
    catch
        return 0
    sourceX := source.left + RectWidth(source) / 2
    sourceY := source.top + RectHeight(source) / 2
    best := 0
    bestScore := ""
    for _, candidate in windows {
        if (candidate = hwnd)
            continue
        try rect := GetVisibleWindowRect(candidate)
        catch
            continue
        x := rect.left + RectWidth(rect) / 2
        y := rect.top + RectHeight(rect) / 2
        dx := x - sourceX
        dy := y - sourceY
        if ((direction = "left" && dx >= 0)
            || (direction = "right" && dx <= 0)
            || (direction = "up" && dy >= 0)
            || (direction = "down" && dy <= 0))
            continue
        primary := (direction = "left" || direction = "right") ? Abs(dx) : Abs(dy)
        secondary := (direction = "left" || direction = "right") ? Abs(dy) : Abs(dx)
        score := primary * 100000 + secondary
        if !best || score < bestScore {
            best := candidate
            bestScore := score
        }
    }
    return best
}
