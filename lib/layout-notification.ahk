; Use Windows' notification surface for layout confirmation.  It manages the
; dismissal itself, avoiding a custom GUI that can remain visible unexpectedly.
InitializeLayoutNotificationState() {
}

ShowLayoutNotification(layout) {
    try {
        TrayTip(LayoutNotificationLabel(layout), "minwm layout", 1)
        SetTimer(HideLayoutNotification, -1000)
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
    return "Floating — tiling disabled"
}
