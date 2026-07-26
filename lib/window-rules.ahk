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
