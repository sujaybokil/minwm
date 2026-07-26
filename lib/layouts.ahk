ApplyLayout(layout, windows, area, gap, masterRatio) {
    if (layout = "floating" || windows.Length = 0)
        return

    if (windows.Length = 1) {
        MoveWindowToRect(windows[1], area.left + gap, area.top + gap,
            area.right - area.left - 2 * gap, area.bottom - area.top - 2 * gap)
        return
    }

    if (layout = "vertical")
        ApplyVerticalMasterStack(windows, area, gap, masterRatio)
    else if (layout = "horizontal")
        ApplyHorizontalMasterStack(windows, area, gap, masterRatio)
}

ApplyVerticalMasterStack(windows, area, gap, masterRatio) {
    ; Reserve one gap at each outer edge, then one gap for every internal gutter.
    ; This makes the screen edge and every window-to-window gap exactly equal.
    usableWidth := area.right - area.left - 2 * gap
    usableHeight := area.bottom - area.top - 2 * gap
    columnWidth := usableWidth - gap
    masterMinimum := GetVisibleMinimumSize(windows[1])
    stackMinimumWidth := 0
    stackMinimumHeights := []
    Loop windows.Length - 1 {
        minimum := GetVisibleMinimumSize(windows[A_Index + 1])
        stackMinimumWidth := Max(stackMinimumWidth, minimum.width)
        stackMinimumHeights.Push(minimum.height)
    }
    masterWidth := ConstrainSplitSize(columnWidth,
        Floor(columnWidth * masterRatio),
        masterMinimum.width,
        stackMinimumWidth)
    stackWidth := columnWidth - masterWidth
    MoveWindowToRect(windows[1], area.left + gap, area.top + gap, masterWidth, usableHeight)

    stackCount := windows.Length - 1
    availableStackHeight := usableHeight - gap * (stackCount - 1)
    stackHeights := AllocateConstrainedSizes(availableStackHeight, stackMinimumHeights)
    if !IsObject(stackHeights) {
        DebugLog("Stack minimum heights exceed available tile height; using equal allocation")
        stackHeights := AllocateConstrainedSizes(availableStackHeight, RepeatValue(0, stackCount))
    }
    y := area.top + gap
    Loop stackCount {
        height := stackHeights[A_Index]
        MoveWindowToRect(windows[A_Index + 1],
            area.left + gap + masterWidth + gap, y, stackWidth, height)
        y += height + gap
    }
}

ApplyHorizontalMasterStack(windows, area, gap, masterRatio) {
    ; The same invariant applies horizontally and vertically: outer gap = inner gap.
    usableWidth := area.right - area.left - 2 * gap
    usableHeight := area.bottom - area.top - 2 * gap
    rowHeight := usableHeight - gap
    masterMinimum := GetVisibleMinimumSize(windows[1])
    stackMinimumHeight := 0
    stackMinimumWidths := []
    Loop windows.Length - 1 {
        minimum := GetVisibleMinimumSize(windows[A_Index + 1])
        stackMinimumHeight := Max(stackMinimumHeight, minimum.height)
        stackMinimumWidths.Push(minimum.width)
    }
    masterHeight := ConstrainSplitSize(rowHeight,
        Floor(rowHeight * masterRatio),
        masterMinimum.height,
        stackMinimumHeight)
    stackHeight := rowHeight - masterHeight
    MoveWindowToRect(windows[1], area.left + gap, area.top + gap, usableWidth, masterHeight)

    stackCount := windows.Length - 1
    availableStackWidth := usableWidth - gap * (stackCount - 1)
    stackWidths := AllocateConstrainedSizes(availableStackWidth, stackMinimumWidths)
    if !IsObject(stackWidths) {
        DebugLog("Stack minimum widths exceed available tile width; using equal allocation")
        stackWidths := AllocateConstrainedSizes(availableStackWidth, RepeatValue(0, stackCount))
    }
    x := area.left + gap
    Loop stackCount {
        width := stackWidths[A_Index]
        MoveWindowToRect(windows[A_Index + 1],
            x, area.top + gap + masterHeight + gap, width, stackHeight)
        x += width + gap
    }
}

RepeatValue(value, count) {
    values := []
    Loop count
        values.Push(value)
    return values
}

MoveWindowToRect(hwnd, x, y, width, height) {
    if (width <= 0 || height <= 0) {
        DebugLog("Skipped invalid tile rectangle for hwnd=" hwnd " (" width "x" height ")")
        return
    }
    try {
        title := "ahk_id " hwnd
        if (WinGetMinMax(title) = 1) {
            DebugLog("Restoring maximized tiled window hwnd=" hwnd)
            WinRestore(title)
        }

        target := RectFromXYWH(x, y, width, height)
        geometry := GetWindowGeometry(hwnd)
        if RectsMatch(geometry.visible, target)
            return

        rawTarget := CalculateRawRectForVisibleTarget(geometry.raw, geometry.visible, target)
        margins := GetInvisibleFrameMargins(geometry.raw, geometry.visible)
        DebugLog("Move hwnd=" hwnd
            " requested-visible=" RectDescription(target)
            " frame-margins=" margins.left "," margins.top "," margins.right "," margins.bottom
            (geometry.usedDwm ? "" : " dwm-fallback=raw"))
        SetRawWindowRect(hwnd, rawTarget)

        ; Moving across a DPI boundary or an application handling WM_SIZE can
        ; change the frame margins. Re-measure and correct the residual once.
        geometry := GetWindowGeometry(hwnd)
        if !RectsMatch(geometry.visible, target) {
            rawTarget := CalculateRawRectForVisibleTarget(geometry.raw, geometry.visible, target)
            SetRawWindowRect(hwnd, rawTarget)
            geometry := GetWindowGeometry(hwnd)
        }

        if !RectsMatch(geometry.visible, target)
            DebugLog("Move residual hwnd=" hwnd
                " requested-visible=" RectDescription(target)
                " actual-visible=" RectDescription(geometry.visible))
    }
    catch Error as err
        DebugLog("Window move failed for hwnd=" hwnd ": " ErrorDescription(err))
}

SetRawWindowRect(hwnd, rect) {
    static SWP_NOZORDER := 0x0004
    static SWP_NOACTIVATE := 0x0010
    static SWP_NOOWNERZORDER := 0x0200
    flags := SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER
    if !DllCall("User32\SetWindowPos",
        "ptr", hwnd,
        "ptr", 0,
        "int", rect.left,
        "int", rect.top,
        "int", RectWidth(rect),
        "int", RectHeight(rect),
        "uint", flags,
        "int")
        throw OSError(A_LastError, "SetWindowPos")
}
