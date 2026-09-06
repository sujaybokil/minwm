; Use Windows' notification surface for layout confirmation.  It manages the
; dismissal itself, avoiding a custom GUI that can remain visible unexpectedly.
InitializeLayoutNotificationState() {
}

ShowLayoutNotification(layout) {
    global Config
    if !Config["layoutNotificationsEnabled"]
        return
    try {
        TrayTip(LayoutNotificationLabel(layout), "minwm layout", 1)
        SetTimer(HideLayoutNotification, -Config["layoutNotificationDurationMs"])
    } catch Error as err {
        DebugLog("Layout notification failed: " ErrorDescription(err))
    }
}

StopLayoutNotification(*) {
    SetTimer(HideLayoutNotification, 0)
    try TrayTip()
}

HideLayoutNotification(*) {
    try TrayTip()
}

LayoutNotificationLabel(layout) {
    if (layout = "vertical")
        return "Vertical master-stack"
    if (layout = "horizontal")
        return "Horizontal master-stack"
    if (layout = "maximized")
        return "Maximized"
    if (layout = "grid")
        return "Grid"
    if (layout = "monocle")
        return "Monocle"
    return "Floating — tiling disabled"
}
