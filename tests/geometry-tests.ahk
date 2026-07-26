#Requires AutoHotkey v2.0

#Include "%A_ScriptDir%\..\lib\geometry.ahk"
#Include "%A_ScriptDir%\..\lib\constraints.ahk"

try {
    RunGeometryTests()
    ExitApp
} catch Error as err {
    FileAppend("geometry tests failed: " err.Message "`n", "**")
    ExitApp(1)
}

AssertRect(actual, expected, description) {
    if !RectsMatch(actual, expected, 0)
        throw Error(description ": expected " RectDescription(expected)
            ", got " RectDescription(actual))
}

RunGeometryTests() {
    raw := { left: 93, top: 100, right: 507, bottom: 507 }
    visible := { left: 100, top: 100, right: 500, bottom: 500 }
    target := RectFromXYWH(20, 30, 320, 240)
    AssertRect(
        CalculateRawRectForVisibleTarget(raw, visible, target),
        { left: 13, top: 30, right: 347, bottom: 277 },
        "symmetric invisible borders")

    raw := { left: -1010, top: 50, right: -490, bottom: 670 }
    visible := { left: -1000, top: 55, right: -500, bottom: 660 }
    target := { left: -1900, top: 100, right: -1300, bottom: 900 }
    AssertRect(
        CalculateRawRectForVisibleTarget(raw, visible, target),
        { left: -1910, top: 95, right: -1290, bottom: 910 },
        "asymmetric borders and negative coordinates")

    raw := RectFromXYWH(10, 20, 300, 200)
    target := RectFromXYWH(40, 50, 600, 500)
    AssertRect(
        CalculateRawRectForVisibleTarget(raw, raw, target),
        target,
        "frameless window")

    AssertRect(
        CalculateCenteredFloatingRect(
            RectFromXYWH(0, 0, 2560, 1528),
            RectFromXYWH(100, 100, 1600, 1000),
            { width: 1200, height: 900 },
            12),
        RectFromXYWH(680, 314, 1200, 900),
        "constraint-floating window should use its minimum size and center")

    AssertRect(
        CalculateCenteredFloatingRect(
            RectFromXYWH(0, 0, 1000, 800),
            RectFromXYWH(0, 0, 1400, 1200),
            { width: 0, height: 0 },
            20),
        RectFromXYWH(20, 20, 960, 760),
        "window without native minimums should clamp to the available area")

    borderRects := CalculateFocusBorderRects(
        RectFromXYWH(10, 20, 100, 80), 2)
    if (borderRects.Length != 4)
        throw Error("focus border should contain four edge rectangles")
    AssertRect(
        borderRects[1], RectFromXYWH(10, 20, 100, 2),
        "focus border top edge")
    AssertRect(
        borderRects[2], RectFromXYWH(10, 98, 100, 2),
        "focus border bottom edge")
    AssertRect(
        borderRects[3], RectFromXYWH(10, 22, 2, 76),
        "focus border left edge")
    AssertRect(
        borderRects[4], RectFromXYWH(108, 22, 2, 76),
        "focus border right edge")
    if CalculateFocusBorderRects(
        RectFromXYWH(0, 0, 100, 100), 0).Length
        throw Error("zero-width focus border should be disabled")

    if !RectsMatch(
        { left: 9, top: 11, right: 109, bottom: 111 },
        { left: 10, top: 10, right: 110, bottom: 110 })
        throw Error("one-pixel tolerance should match")

    if RectsMatch(
        { left: 8, top: 10, right: 110, bottom: 110 },
        { left: 10, top: 10, right: 110, bottom: 110 })
        throw Error("differences over one pixel should not match")

    if (ConstrainSplitSize(1000, 580, 200, 500) != 500)
        throw Error("split should reserve the second window's minimum")

    if (ConstrainSplitSize(1000, 580, 700, 200) != 700)
        throw Error("split should reserve the first window's minimum")

    sizes := AllocateConstrainedSizes(1000, [600, 100])
    if (sizes[1] != 600 || sizes[2] != 400)
        throw Error("constrained sizes should water-fill remaining space")

    sizes := AllocateConstrainedSizes(1001, [100, 100])
    if (sizes[1] != 501 || sizes[2] != 500)
        throw Error("constrained sizes should assign rounding remainder")

    if IsObject(AllocateConstrainedSizes(500, [300, 250]))
        throw Error("impossible minimum sizes should fail allocation")

    verticalSizes := [
        { width: 700, height: 400 },
        { width: 1200, height: 750 },
        { width: 900, height: 500 }
    ]
    if !CanTileMinimumSizes("vertical", verticalSizes, 2524, 1504, 12)
        throw Error("vertical layout should account for stack width and heights")

    verticalSizes.Push({ width: 800, height: 300 })
    if CanTileMinimumSizes("vertical", verticalSizes, 2524, 1504, 12)
        throw Error("vertical layout should reject excessive stack heights")

    horizontalSizes := [
        { width: 700, height: 500 },
        { width: 900, height: 600 },
        { width: 800, height: 500 }
    ]
    if !CanTileMinimumSizes("horizontal", horizontalSizes, 2524, 1504, 12)
        throw Error("horizontal layout should account for stack widths and height")

    horizontalSizes.Push({ width: 900, height: 400 })
    if CanTileMinimumSizes("horizontal", horizontalSizes, 2524, 1504, 12)
        throw Error("horizontal layout should reject excessive stack widths")

    if (FindLargestMinimumSizeIndex([
        { width: 700, height: 500 },
        { width: 1200, height: 750 },
        { width: 900, height: 600 }
    ]) != 2)
        throw Error("largest constrained window should be selected for floating")

    selection := SelectTileableMinimumSizeIndices("vertical", [
        { width: 700, height: 400 },
        { width: 1200, height: 900 },
        { width: 900, height: 700 }
    ], 2000, 1000, 12)
    if (selection.floating.Length != 1 || selection.floating[1] != 2)
        throw Error("selection should float the largest blocking window first")
    if (selection.tiled.Length != 2
        || selection.tiled[1] != 1
        || selection.tiled[2] != 3)
        throw Error("selection should preserve remaining window order")

    selection := SelectTileableMinimumSizeIndices("vertical", [
        { width: 3000, height: 2000 },
        { width: 500, height: 400 },
        { width: 500, height: 400 }
    ], 2000, 1000, 12)
    if (selection.floating.Length != 1 || selection.floating[1] != 1)
        throw Error("an oversized master should float before re-tiling")
    if (selection.tiled.Length != 2)
        throw Error("remaining windows should tile after an oversized master floats")

    selection := SelectTileableMinimumSizeIndices("vertical", [
        { width: 714, height: 124 },
        { width: 1200, height: 750 },
        { width: 700, height: 300 },
        { width: 1200, height: 900 }
    ], 2512, 1480, 24)
    if (selection.floating.Length != 1 || selection.floating[1] != 4)
        throw Error("an impossible stack should float its largest blocker")
    if (selection.tiled[1] != 1)
        throw Error("constraint solving must not change the master category")

    selection := SelectTileableMinimumSizeIndices("horizontal", [
        { width: 1900, height: 900 },
        { width: 1800, height: 800 },
        { width: 1700, height: 700 }
    ], 1000, 600, 12)
    if selection.tiled.Length
        throw Error("all impossible windows should be allowed to float")
}
