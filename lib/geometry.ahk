RectFromXYWH(x, y, width, height) {
    return { left: x, top: y, right: x + width, bottom: y + height }
}

RectWidth(rect) {
    return rect.right - rect.left
}

RectHeight(rect) {
    return rect.bottom - rect.top
}

RectDescription(rect) {
    return rect.left "," rect.top " " RectWidth(rect) "x" RectHeight(rect)
}

RectsMatch(first, second, tolerance := 1) {
    return Abs(first.left - second.left) <= tolerance
        && Abs(first.top - second.top) <= tolerance
        && Abs(first.right - second.right) <= tolerance
        && Abs(first.bottom - second.bottom) <= tolerance
}

RectsOverlap(first, second) {
    return first.left < second.right && first.right > second.left
        && first.top < second.bottom && first.bottom > second.top
}

GetInvisibleFrameMargins(raw, visible) {
    return {
        left: visible.left - raw.left,
        top: visible.top - raw.top,
        right: raw.right - visible.right,
        bottom: raw.bottom - visible.bottom
    }
}

CalculateRawRectForVisibleTarget(raw, visible, target) {
    margins := GetInvisibleFrameMargins(raw, visible)
    return {
        left: target.left - margins.left,
        top: target.top - margins.top,
        right: target.right + margins.right,
        bottom: target.bottom + margins.bottom
    }
}

CalculateCenteredFloatingRect(area, current, minimum, gap) {
    availableWidth := Max(1, RectWidth(area) - 2 * gap)
    availableHeight := Max(1, RectHeight(area) - 2 * gap)
    width := (minimum.width > 0)
        ? minimum.width
        : Min(RectWidth(current), availableWidth)
    height := (minimum.height > 0)
        ? minimum.height
        : Min(RectHeight(current), availableHeight)
    x := area.left + Floor((RectWidth(area) - width) / 2)
    y := area.top + Floor((RectHeight(area) - height) / 2)
    return RectFromXYWH(x, y, width, height)
}

CalculateFocusBorderRects(rect, thickness) {
    thickness := Min(
        thickness,
        Floor(RectWidth(rect) / 2),
        Floor(RectHeight(rect) / 2))
    if (thickness <= 0)
        return []
    middleHeight := RectHeight(rect) - 2 * thickness
    return [
        RectFromXYWH(rect.left, rect.top, RectWidth(rect), thickness),
        RectFromXYWH(
            rect.left, rect.bottom - thickness, RectWidth(rect), thickness),
        RectFromXYWH(
            rect.left, rect.top + thickness, thickness, middleHeight),
        RectFromXYWH(
            rect.right - thickness, rect.top + thickness,
            thickness, middleHeight)
    ]
}
