; WinEvent hooks make common window lifecycle changes reflow immediately. The
; polling timer remains active as a fallback for applications that omit events.
InitializeWindowRefreshEventsState() {
    global WindowRefreshEvents
    WindowRefreshEvents := { hooks: [], callback: 0, enabled: false }
}

StartWindowRefreshEvents() {
    global WindowRefreshEvents
    static WINEVENT_OUTOFCONTEXT := 0
    static WINEVENT_SKIPOWNPROCESS := 0x2
    static events := [0x8000, 0x8001, 0x8002, 0x8003, 0x0003] ; create/destroy/show/hide/foreground
    try {
        WindowRefreshEvents.callback := CallbackCreate(HandleWindowRefreshEvent, , 7)
        for _, event in events {
            hook := DllCall("User32\SetWinEventHook",
                "uint", event, "uint", event, "ptr", 0,
                "ptr", WindowRefreshEvents.callback, "uint", 0, "uint", 0,
                "uint", WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS, "ptr")
            if !hook
                throw OSError(A_LastError, "SetWinEventHook layout refresh")
            WindowRefreshEvents.hooks.Push(hook)
        }
        WindowRefreshEvents.enabled := true
        DebugLog("Window refresh event tracking enabled")
    } catch Error as err {
        StopWindowRefreshEvents()
        DebugLog("Window refresh event tracking unavailable: " ErrorDescription(err))
    }
}

StopWindowRefreshEvents(*) {
    global WindowRefreshEvents
    try SetTimer(RunEventDrivenRefresh, 0)
    for _, hook in WindowRefreshEvents.hooks
        try DllCall("User32\UnhookWinEvent", "ptr", hook)
    if WindowRefreshEvents.callback
        try CallbackFree(WindowRefreshEvents.callback)
    WindowRefreshEvents.hooks := []
    WindowRefreshEvents.callback := 0
    WindowRefreshEvents.enabled := false
}

HandleWindowRefreshEvent(eventHook, event, hwnd, idObject, idChild,
    eventThread, eventTime) {
    global Config, WindowRefreshEvents
    if !WindowRefreshEvents.enabled || !hwnd || idObject || idChild
        return
    ; Coalesce bursts such as an application creating a window and its child
    ; surfaces. Location events are deliberately not observed: minwm's own
    ; reflow would otherwise schedule an endless feedback loop.
    SetTimer(RunEventDrivenRefresh, -Config["windowRefreshEventDebounceMs"])
}

RunEventDrivenRefresh(*) {
    global WindowRefreshEvents
    if WindowRefreshEvents.enabled
        RefreshLayout()
}
