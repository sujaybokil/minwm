AssertRect(actual, expected, description) {
    if !RectsMatch(actual, expected, 0)
        throw Error(description ": expected " RectDescription(expected)
            ", got " RectDescription(actual))
}

AssertEqual(actual, expected, description) {
    if (actual != expected)
        throw Error(description ": expected " expected ", got " actual)
}

RunGeometryTests() {
    if (WrapWindowIndex(0, 3) != 3)
        throw Error("previous focus from the first window should wrap to the last")
    if (WrapWindowIndex(4, 3) != 1)
        throw Error("next focus from the last window should wrap to the first")
    if WrapWindowIndex(1, 0)
        throw Error("empty window lists should not produce an index")
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

    normalWindowStyle := 0x16CF0000
    if HasDialogOrPopupSemantics(
        normalWindowStyle, 0, "Chrome_WidgetWin_0", 0)
        throw Error("normal Electron windows must remain eligible")
    if !HasDialogOrPopupSemantics(
        normalWindowStyle | 0x80000000, 0, "Popup", 0)
        throw Error("WS_POPUP windows must be excluded")
    if !HasDialogOrPopupSemantics(
        normalWindowStyle, 0, "Chrome_WidgetWin_0", 123)
        throw Error("owned transient windows must be excluded")
    if !HasDialogOrPopupSemantics(
        normalWindowStyle, 0x1, "CustomDialog", 0)
        throw Error("modal-frame windows must be excluded")
    if !HasDialogOrPopupSemantics(
        normalWindowStyle, 0, "#32770", 0)
        throw Error("standard dialog classes must be excluded")
    if !IsWindowsStartMenuOrSearch("StartMenuExperienceHost.exe")
        throw Error("Windows Start menu host should be excluded")
    if !IsWindowsStartMenuOrSearch("SearchHost.exe")
        throw Error("Windows Search host should be excluded")
    if !IsWindowsStartMenuOrSearch("SearchApp.exe")
        throw Error("legacy Windows Search host should be excluded")
    if IsWindowsStartMenuOrSearch("explorer.exe")
        throw Error("Explorer must not be treated as a shell surface")

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

    RunWorkspaceStateTests()
    RunVirtualDesktopHelperTests()
    RunPresentationAndCustomHotkeyTests()
    RunConfigValidationTests()
}

RunWorkspaceStateTests() {
    global Config, Manager
    InitializeWorkspaceStateStore()
    first := CreateWorkspaceManagerState()
    AssertEqual(first.layout, Config["defaultLayout"],
        "new workspaces should use the configured default layout")
    if (first.order.Length || first.constraintFloats.Length)
        throw Error("new workspaces should begin without windows")

    if !ActivateWorkspace("desktop-a")
        throw Error("a desktop id should activate a workspace")
    Manager.layout := "horizontal"
    Manager.order := [101, 202]
    ActivateWorkspace("desktop-b")
    AssertEqual(Manager.layout, Config["defaultLayout"],
        "each desktop should start with independent layout state")
    ActivateWorkspace("desktop-a")
    AssertEqual(Manager.layout, "horizontal",
        "returning to a desktop should restore its layout state")
    AssertEqual(Manager.order.Length, 2,
        "returning to a desktop should restore its window order")
    if ActivateWorkspace("")
        throw Error("an empty desktop id should not activate a workspace")
    PruneWorkspaceStates(["desktop-b"])
    ActivateWorkspace("desktop-a")
    AssertEqual(Manager.layout, Config["defaultLayout"],
        "pruned workspaces should be recreated with default state")
}

RunVirtualDesktopHelperTests() {
    bytes := Buffer(32, 0)
    Loop 16
        NumPut("UChar", A_Index - 1, bytes, A_Index - 1)
    Loop 16
        NumPut("UChar", 0xA0 + A_Index - 1, bytes, 16 + A_Index - 1)
    firstId := "000102030405060708090A0B0C0D0E0F"
    secondId := "A0A1A2A3A4A5A6A7A8A9AAABACADAEAF"
    AssertEqual(VirtualDesktopIdFromBuffer(bytes), firstId,
        "desktop ids should be encoded as uppercase hexadecimal")
    AssertEqual(VirtualDesktopIdFromBuffer(bytes, 16), secondId,
        "desktop ids should honor their buffer offset")
    AssertEqual(VirtualDesktopIdFromBuffer(firstId secondId, 16), secondId,
        "hexadecimal desktop ids should honor their byte offset")
    idsFromRegistryString := []
    registryText := firstId secondId
    Loop StrLen(registryText) // 32
        idsFromRegistryString.Push(VirtualDesktopIdFromBuffer(
            registryText, (A_Index - 1) * 16))
    AssertEqual(idsFromRegistryString.Length, 2,
        "registry desktop-id strings should split into desktop ids")
    AssertEqual(idsFromRegistryString[2], secondId,
        "registry desktop-id strings should preserve desktop ordering")
    if (VirtualDesktopIdFromBuffer(Buffer(15, 0)) != "")
        throw Error("short desktop-id buffers should be rejected")
    AssertEqual(FindVirtualDesktopIndex([firstId, secondId], secondId), 2,
        "desktop lookup should preserve Windows desktop ordering")
    AssertEqual(FindVirtualDesktopIndex([firstId], secondId), 0,
        "missing desktops should not have an index")
    AssertEqual(GetVirtualDesktopSwitcherFilename(19045), "",
        "Windows 10 should use shortcut workspace switching")
    AssertEqual(GetVirtualDesktopSwitcherFilename(22631), "VirtualDesktop11.exe",
        "Windows 11 should use the bundled direct switcher")
    AssertEqual(GetVirtualDesktopSwitcherFilename(26100), "VirtualDesktop11-24H2.exe",
        "Windows 11 24H2 should use its matching direct switcher")
    AssertEqual(BuildVirtualDesktopSwitchCommand("C:\minwm\bin\VirtualDesktop11.exe", 6),
        Chr(34) "C:\minwm\bin\VirtualDesktop11.exe" Chr(34) " /Animation:Off /Switch:5",
        "direct switcher commands should use zero-based desktop indices")
    if !IsVirtualDesktopSwitchExitSuccessful(5, 6)
        throw Error("direct switcher should accept its zero-based destination exit code")
    if IsVirtualDesktopSwitchExitSuccessful(0, 6)
        throw Error("direct switcher should reject an unexpected destination exit code")
}

RunPresentationAndCustomHotkeyTests() {
    AssertEqual(LayoutNotificationLabel("vertical"), "Vertical master-stack",
        "vertical layout notification label")
    AssertEqual(LayoutNotificationLabel("horizontal"), "Horizontal master-stack",
        "horizontal layout notification label")
    AssertEqual(LayoutNotificationLabel("maximized"), "Maximized",
        "maximized layout notification label")
    AssertEqual(LayoutNotificationLabel("floating"), "Floating — tiling disabled",
        "floating layout notification label")

    wrapper := BuildCustomHotkeysWrapperText(
        "C:\\minwm\\config\\custom-hotkeys.ahk", 4242, ["#t", "#h"])
    if !InStr(wrapper, "global MinwmParentPid := 4242")
        throw Error("custom-hotkey wrapper should track its parent process")
    reservedLine := "global MinwmReservedHotkeys := ["
        . Chr(34) "#t" Chr(34) ", " Chr(34) "#h" Chr(34) "]"
    if !InStr(wrapper, reservedLine)
        throw Error("custom-hotkey wrapper should include reserved hotkeys")
    includeLine := "#Include " Chr(34)
        . "C:\\minwm\\config\\custom-hotkeys.ahk" Chr(34)
    if !InStr(wrapper, includeLine)
        throw Error("custom-hotkey wrapper should include the user script")
}

RunConfigValidationTests() {
    global Config, ConfigLoadMessages
    Config["defaultLayout"] := " HORIZONTAL "
    ValidateConfig()
    AssertEqual(Config["defaultLayout"], "horizontal",
        "default layout should be normalized")
    Config["defaultLayout"] := "diagonal"
    ValidateConfig()
    AssertEqual(Config["defaultLayout"], "vertical",
        "invalid default layouts should fall back safely")
    if !InStr(ConfigLoadMessages[ConfigLoadMessages.Length], "defaultLayout")
        throw Error("invalid default layouts should produce a configuration message")
    Config["virtualDesktopsEnabled"] := false
    ValidateConfig()
    if Config["virtualDesktopsEnabled"]
        throw Error("virtual desktop workspaces should accept an explicit false setting")
    Config["virtualDesktopsEnabled"] := "enabled"
    ValidateConfig()
    if !Config["virtualDesktopsEnabled"]
        throw Error("invalid workspace settings should default to enabled")
}
