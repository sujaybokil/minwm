; Workspace-local tiling state.  The controller assigns Manager to the state
; for the active Windows virtual desktop, so existing layout code remains
; deliberately unaware of desktop switching.
InitializeWorkspaceStateStore() {
    global WorkspaceStates
    WorkspaceStates := Map()
}

CreateWorkspaceManagerState() {
    global Config
    return {
        layout: Config["defaultLayout"],
        gap: Config["defaultGap"],
        masterRatio: Config["masterRatio"],
        order: [],
        constraintFloats: [],
        lastConstraintStatus: "",
        lastLayoutState: "",
        lastRefreshStatus: ""
    }
}

ActivateWorkspace(desktopId) {
    global Manager, WorkspaceStates
    if (desktopId = "")
        return false
    if !WorkspaceStates.Has(desktopId)
        WorkspaceStates[desktopId] := CreateWorkspaceManagerState()
    Manager := WorkspaceStates[desktopId]
    return true
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
