; Tiling state is local to both a Windows virtual desktop and a physical
; monitor.  Manager remains the focused monitor's state so the command layer
; can stay small, while refreshes visit every monitor in the workspace.
InitializeWorkspaceStateStore() {
    global WorkspaceStates
    WorkspaceStates := Map()
}

CreateWorkspaceManagerState(desktopId := "") {
    global Config
    return {
        layout: GetInitialWorkspaceLayout(desktopId),
        gap: Config["defaultGap"],
        smartGaps: Config["smartGapsEnabled"],
        masterRatio: Config["masterRatio"],
        order: [],
        temporaryFloats: Map(),
        scratchpad: { hwnd: 0, rect: "", visible: false, orderIndex: 0 },
        constraintFloats: [],
        lastConstraintStatus: "",
        lastLayoutState: "",
        lastRefreshStatus: ""
    }
}

ActivateWorkspace(desktopId, area := "") {
    global Manager
    if (desktopId = "")
        return false
    if !IsObject(area)
        area := GetActiveMonitorArea()
    Manager := GetWorkspaceMonitorState(desktopId, area)
    return true
}

GetWorkspaceManagerState(desktopId) {
    global WorkspaceStates
    if !WorkspaceStates.Has(desktopId)
        WorkspaceStates[desktopId] := Map()
    return WorkspaceStates[desktopId]
}

GetWorkspaceMonitorState(desktopId, area) {
    workspace := GetWorkspaceManagerState(desktopId)
    identity := GetMonitorIdentity(area)
    if !workspace.Has(identity)
        workspace[identity] := CreateWorkspaceManagerState(desktopId)
    return workspace[identity]
}

GetInitialWorkspaceLayout(desktopId) {
    global Config, VirtualDesktops
    if !VirtualDesktops.enabled
        return Config["defaultLayout"]
    for index, candidateId in VirtualDesktops.desktopIds {
        if (candidateId = desktopId)
            return Config["desktop" index "Layout"]
    }
    return Config["defaultLayout"]
}

GetMonitorIdentity(area) {
    try return MonitorGetName(area.index)
    catch
        return "monitor-" area.index
}

PruneWorkspaceStates(desktopIds) {
    global WorkspaceStates
    live := Map()
    for _, desktopId in desktopIds
        live[desktopId] := true
    stale := []
    for desktopId, _ in WorkspaceStates {
        if !live.Has(desktopId)
            stale.Push(desktopId)
    }
    for _, desktopId in stale
        WorkspaceStates.Delete(desktopId)
}

IsTilingModeActive() {
    global Manager
    return (Manager.layout != "floating")
}
