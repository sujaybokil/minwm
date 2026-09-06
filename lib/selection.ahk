SelectTileableWindows(layout, windows, area, gap) {
    if (layout = "maximized" || layout = "monocle")
        return { tiled: windows, floating: [], floatingDetails: [] }
    usableWidth := area.right - area.left - 2 * gap
    usableHeight := area.bottom - area.top - 2 * gap
    candidates := []
    forcedFloating := []
    for hwnd in windows {
        if IsWindowForcedFloating(hwnd)
            forcedFloating.Push(hwnd)
        else
            candidates.Push(hwnd)
    }
    minimums := []
    for hwnd in candidates
        minimums.Push(GetVisibleMinimumSize(hwnd))
    indices := SelectTileableMinimumSizeIndices(
        layout, minimums, usableWidth, usableHeight, gap)

    tiled := []
    for _, index in indices.tiled
        tiled.Push(candidates[index])
    floating := []
    floatingDetails := []
    for _, index in indices.floating {
        hwnd := candidates[index]
        floating.Push(hwnd)
        floatingDetails.Push({ hwnd: hwnd, minimum: minimums[index] })
    }
    for _, hwnd in forcedFloating {
        floating.Push(hwnd)
        floatingDetails.Push({ hwnd: hwnd, minimum: GetVisibleMinimumSize(hwnd) })
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
