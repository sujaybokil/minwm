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
