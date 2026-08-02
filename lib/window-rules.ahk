HasDialogOrPopupSemantics(style, exStyle, className, ownerHwnd) {
    static WS_POPUP := 0x80000000
    static WS_EX_DLGMODALFRAME := 0x00000001
    static WS_EX_TOOLWINDOW := 0x00000080
    static WS_EX_NOACTIVATE := 0x08000000

    return ownerHwnd != 0
        || className = "#32770"
        || (style & WS_POPUP)
        || (exStyle & WS_EX_DLGMODALFRAME)
        || (exStyle & WS_EX_TOOLWINDOW)
        || (exStyle & WS_EX_NOACTIVATE)
}

IsWindowsStartMenuOrSearch(processName) {
    ; These shell surfaces have resizable top-level windows, so style checks
    ; alone can mistake them for normal application windows. SearchApp and
    ; SearchUI cover older supported Windows builds.
    static shellProcesses := Map(
        "startmenuexperiencehost.exe", true,
        "searchhost.exe", true,
        "searchapp.exe", true,
        "searchui.exe", true
    )
    return shellProcesses.Has(StrLower(processName))
}
