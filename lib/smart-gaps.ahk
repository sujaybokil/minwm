; Smart gaps affect only a single tiled window. Constraint-floated windows keep
; their normal placement inset, while the remaining tiled window can use the
; full monitor work area.
GetEffectiveLayoutGap(configuredGap, smartGapsEnabled, tiledWindowCount) {
    return (smartGapsEnabled && tiledWindowCount = 1) ? 0 : configuredGap
}

ToggleSmartGaps(*) {
    global Manager
    Manager.smartGaps := !Manager.smartGaps
    ScheduleLayoutStateSave()
    DebugLog("Smart gaps " (Manager.smartGaps ? "enabled" : "disabled"))
    RefreshLayout()
}
