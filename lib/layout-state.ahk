; Persist only durable layout preferences. Window handles and ordering are
; deliberately process-local and are rebuilt from the live desktop each run.
InitializeLayoutStatePersistence() {
    global LayoutStatePath
    LayoutStatePath := ConfigDirectory "\layout-state.ini"
}

LoadPersistedWorkspaceSettings() {
    global WorkspaceStates, LayoutStatePath, VirtualDesktops
    if !FileExist(LayoutStatePath)
        return
    try {
        version := IniRead(LayoutStatePath, "minwm", "version", "")
        if (version != "1")
            return
        desktopIds := VirtualDesktops.enabled ? VirtualDesktops.desktopIds : ["__default__"]
        for _, desktopId in desktopIds {
            for _, area in GetMonitorAreas() {
                state := GetWorkspaceMonitorState(desktopId, area)
                section := WorkspaceMonitorStateSection(desktopId, area)
                ApplyPersistedWorkspaceSettings(
                    state,
                    IniRead(LayoutStatePath, section, "layout", ""),
                    IniRead(LayoutStatePath, section, "gap", ""),
                    IniRead(LayoutStatePath, section, "masterRatio", ""),
                    IniRead(LayoutStatePath, section, "smartGaps", ""))
            }
        }
    } catch Error as err {
        DebugLog("Could not load layout state: " ErrorDescription(err))
    }
}

ApplyPersistedWorkspaceSettings(state, layout, gap, ratio, smartGaps := "") {
    global Config
    ; This file is user-owned and is read after config validation, so it must
    ; enforce the same operational bounds instead of trusting stale or edited
    ; values to be safe for the layout engine.
    layout := Type(layout) = "String" ? StrLower(Trim(layout)) : ""
    if IsSupportedLayout(layout)
        state.layout := layout

    if RegExMatch(gap, "^\d+$") {
        value := Integer(gap)
        if IsSupportedGap(value)
            state.gap := value
    }

    if RegExMatch(ratio, "^\d+(\.\d+)?$") {
        value := Float(ratio)
        if value >= Config["minMasterRatio"] && value <= Config["maxMasterRatio"]
            state.masterRatio := value
    }
    if (smartGaps = "0" || smartGaps = "1")
        state.smartGaps := Integer(smartGaps) = 1
}

ScheduleLayoutStateSave(*) {
    global Config
    SetTimer(SavePersistedWorkspaceSettings, -Config["layoutStateSaveDebounceMs"])
}

SavePersistedWorkspaceSettings(*) {
    global WorkspaceStates, LayoutStatePath
    try {
        IniWrite("1", LayoutStatePath, "minwm", "version")
        for desktopId, monitors in WorkspaceStates {
            for monitorId, state in monitors {
                section := desktopId "|" monitorId
                IniWrite(state.layout, LayoutStatePath, section, "layout")
                IniWrite(state.gap, LayoutStatePath, section, "gap")
                IniWrite(state.masterRatio, LayoutStatePath, section, "masterRatio")
                IniWrite(state.smartGaps ? "1" : "0", LayoutStatePath, section, "smartGaps")
            }
        }
    } catch Error as err {
        DebugLog("Could not save layout state: " ErrorDescription(err))
    }
}

WorkspaceMonitorStateSection(desktopId, area) {
    return desktopId "|" GetMonitorIdentity(area)
}
