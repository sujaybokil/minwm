SelectTileableWindows(layout, windows, area, gap) {
    usableWidth := area.right - area.left - 2 * gap
    usableHeight := area.bottom - area.top - 2 * gap
    minimums := []
    for hwnd in windows
        minimums.Push(GetVisibleMinimumSize(hwnd))
    indices := SelectTileableMinimumSizeIndices(
        layout, minimums, usableWidth, usableHeight, gap)

    tiled := []
    for _, index in indices.tiled
        tiled.Push(windows[index])
    floating := []
    floatingDetails := []
    for _, index in indices.floating {
        hwnd := windows[index]
        floating.Push(hwnd)
        floatingDetails.Push({ hwnd: hwnd, minimum: minimums[index] })
    }
    return {
        tiled: tiled,
        floating: floating,
        floatingDetails: floatingDetails
    }
}

ConstraintSelectionDescription(details) {
    description := "floating="
    if !details.Length
        description .= "none"
    for index, detail in details {
        minimum := detail.minimum
        description .= (index > 1 ? "," : "")
            . detail.hwnd "(" minimum.width "x" minimum.height ")"
    }
    return description
}
