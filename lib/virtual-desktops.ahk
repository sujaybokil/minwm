; Windows exposes desktop ordering and the selected desktop in Explorer's
; per-user VirtualDesktops registry key. Creation uses the documented Ctrl+Win
; desktop shortcut. Navigation prefers the bundled VirtualDesktop utility for
; direct, non-animated switching and falls back to Ctrl+Win shortcuts if the
; utility is unavailable or fails. Window membership uses IVirtualDesktopManager,
; the public API.
InitializeVirtualDesktopState() {
    global VirtualDesktops
    VirtualDesktops := {
        enabled: false,
        desktopIds: [],
        currentId: "",
        pendingFocusHwnd: 0,
        pendingFocusDesktopId: "",
        lastFocusByDesktopId: Map(),
        foregroundEventHook: 0,
        foregroundEventCallback: 0,
        lastStatus: ""
    }
}

StartVirtualDesktopService() {
    global Config, VirtualDesktops
    try {
        originalId := GetCurrentVirtualDesktopId()
        if (originalId = "")
            throw Error("Windows did not report a current virtual desktop")
        EnsureVirtualDesktopCount(Config["virtualDesktopCount"])
        RefreshVirtualDesktopSnapshot()
        originalIndex := FindVirtualDesktopIndex(VirtualDesktops.desktopIds, originalId)
        if !originalIndex
            throw Error("the original virtual desktop disappeared during setup")
        if !SwitchToVirtualDesktopIndex(originalIndex)
            throw Error("could not restore the original virtual desktop")
        RefreshVirtualDesktopSnapshot()
        VirtualDesktops.enabled := true
        StartVirtualDesktopFocusTracking()
        ; Explorer has no desktop-change event. Keep this short so both minwm
        ; selectors and Ctrl+Win+Arrow restore focus without a visible pause.
        SetTimer(PollVirtualDesktopChange, Config["virtualDesktopPollInterval"])
        if (Config["startupVirtualDesktop"] != originalIndex) {
            if !SwitchToVirtualDesktopIndex(Config["startupVirtualDesktop"])
                throw Error("could not switch to configured startup virtual desktop")
            DebugLog("Startup virtual desktop requested: D"
                Config["startupVirtualDesktop"])
        }
        DebugLog("Virtual desktops started; count=" VirtualDesktops.desktopIds.Length
            . "; current=" FindVirtualDesktopIndex(
                VirtualDesktops.desktopIds, VirtualDesktops.currentId))
        return true
    } catch Error as err {
        VirtualDesktops.enabled := false
        StopVirtualDesktopFocusTracking()
        SetTimer(PollVirtualDesktopChange, 0)
        DebugLog("Virtual desktops unavailable: " ErrorDescription(err))
        return false
    }
}

StopVirtualDesktopService(*) {
    global VirtualDesktops
    SetTimer(PollVirtualDesktopChange, 0)
    StopVirtualDesktopFocusTracking()
    VirtualDesktops.enabled := false
}

RefreshVirtualDesktopSnapshot() {
    global VirtualDesktops
    ids := GetVirtualDesktopIds()
    currentId := GetCurrentVirtualDesktopId()
    if !ids.Length || (currentId = "")
        throw Error("Windows virtual-desktop registry data is unavailable")
    if !FindVirtualDesktopIndex(ids, currentId)
        throw Error("the selected virtual desktop is missing from the desktop list")
    VirtualDesktops.desktopIds := ids
    VirtualDesktops.currentId := currentId
    PruneWorkspaceStates(ids)
}

EnsureVirtualDesktopCount(requiredCount) {
    ids := GetVirtualDesktopIds()
    if !ids.Length
        throw Error("Windows did not return a virtual-desktop list")
    if (ids.Length >= requiredCount)
        return

    MoveToVirtualDesktopBoundary(1)
    while (GetVirtualDesktopIds().Length < requiredCount) {
        beforeCount := GetVirtualDesktopIds().Length
        SendInput("^#d")
        if !WaitForVirtualDesktopCount(beforeCount + 1, 1500)
            throw Error("Windows did not create a virtual desktop")
    }
}

SwitchToVirtualWorkspace(workspaceNumber) {
    global VirtualDesktops
    if !VirtualDesktops.enabled || workspaceNumber < 1
        return
    RefreshVirtualDesktopSnapshot()
    if (workspaceNumber > VirtualDesktops.desktopIds.Length)
        return
    if !SwitchToVirtualDesktopIndex(workspaceNumber) {
        DebugLog("Virtual desktop switch failed; workspace=" workspaceNumber)
        return
    }
    currentIndex := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if (currentIndex = workspaceNumber)
        SynchronizeActiveVirtualWorkspace()
    else
        DebugLog("Virtual desktop switch accepted; awaiting desktop-change poll")
}

MoveFocusedWindowToVirtualWorkspace(workspaceNumber) {
    global VirtualDesktops
    if !VirtualDesktops.enabled || workspaceNumber < 1
        return
    hwnd := WinExist("A")
    if !hwnd || !IsEligibleWindow(hwnd) {
        DebugLog("Virtual desktop move ignored; no eligible focused window")
        return
    }
    try RefreshVirtualDesktopSnapshot()
    catch Error as err {
        DebugLog("Virtual desktop move could not refresh state; " ErrorDescription(err))
        return
    }
    if !IsWindowOnCurrentVirtualDesktop(hwnd) {
        DebugLog("Virtual desktop move ignored; focused window is not on the current desktop")
        return
    }
    if (workspaceNumber > VirtualDesktops.desktopIds.Length)
        return
    targetId := VirtualDesktops.desktopIds[workspaceNumber]
    if (targetId = VirtualDesktops.currentId)
        return
    sourceArea := GetActiveMonitorArea()
    try {
        MoveWindowToVirtualDesktop(hwnd, targetId)

        destination := GetWorkspaceMonitorState(targetId, sourceArea)
        existingIndex := FindWindowIndex(destination.order, hwnd)
        if existingIndex
            destination.order.RemoveAt(existingIndex)
        destination.order.InsertAt(1, hwnd)
        constraintIndex := FindWindowIndex(destination.constraintFloats, hwnd)
        if constraintIndex
            destination.constraintFloats.RemoveAt(constraintIndex)
        destination.lastLayoutState := ""
        VirtualDesktops.pendingFocusHwnd := hwnd
        VirtualDesktops.pendingFocusDesktopId := targetId
        DebugLog("Virtual desktop move succeeded; hwnd=" hwnd "; workspace=" workspaceNumber)

        if !SwitchToVirtualDesktopIndex(workspaceNumber) {
            ClearPendingVirtualDesktopFocus()
            DebugLog("Virtual desktop move switch failed; workspace=" workspaceNumber)
            return
        }
    }
    catch Error as err {
        DebugLog("Virtual desktop move failed; hwnd=" hwnd "; workspace=" workspaceNumber
            . "; " ErrorDescription(err))
        return
    }
    currentIndex := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if (currentIndex = workspaceNumber)
        SynchronizeActiveVirtualWorkspace()
    else
        DebugLog("Virtual desktop move switch accepted; awaiting desktop-change poll")
}

SwitchToVirtualDesktopIndex(targetIndex) {
    global VirtualDesktops
    RefreshVirtualDesktopSnapshot()
    currentIndex := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if !currentIndex
        return false
    if (currentIndex = targetIndex)
        return true

    RememberForegroundVirtualDesktopFocus()
    HideFocusBorder("virtual-desktop-switch")
    switcherPath := GetVirtualDesktopSwitcherPath()
    if (switcherPath != "")
        return TrySwitchToVirtualDesktopDirect(
            switcherPath, targetIndex, VirtualDesktops.currentId)

    DebugLog("Direct virtual desktop helper not installed; using shortcut fallback")
    RefreshVirtualDesktopSnapshot()
    currentIndex := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if !currentIndex
        return false

    direction := (targetIndex > currentIndex) ? 1 : -1
    key := (direction > 0) ? "^#{Right}" : "^#{Left}"
    while (currentIndex != targetIndex) {
        previousId := VirtualDesktops.currentId
        SendInput(key)
        if !WaitForVirtualDesktopIdChange(previousId, 1000)
            return false
        RefreshVirtualDesktopSnapshot()
        currentIndex := FindVirtualDesktopIndex(
            VirtualDesktops.desktopIds, VirtualDesktops.currentId)
        if !currentIndex
            return false
    }
    return true
}

TrySwitchToVirtualDesktopDirect(switcherPath, targetIndex, previousId) {
    try {
        DebugLog("Direct virtual desktop switch starting; target=" targetIndex
            . "; helper=" switcherPath)
        processId := 0
        Run(BuildVirtualDesktopSwitchCommand(switcherPath, targetIndex),,
            "Hide", &processId)
        DebugLog("Direct virtual desktop helper launched; pid=" processId)
        ; Do not wait here: the helper switches asynchronously and Explorer can
        ; publish its registry snapshot later. The 50 ms poller confirms it and
        ; synchronizes focus without blocking this hotkey thread or falling back
        ; to animated Ctrl+Win navigation.
        DebugLog("Direct virtual desktop switch accepted; awaiting registry update; target="
            . targetIndex)
        return true
    } catch Error as err {
        DebugLog("Direct virtual desktop switch failed; " ErrorDescription(err))
    }
    return false
}

GetVirtualDesktopSwitcherPath() {
    filename := GetVirtualDesktopSwitcherFilename(GetWindowsBuildNumber())
    if (filename = "")
        return ""
    installedPath := A_ScriptDir "\bin\" filename
    if FileExist(installedPath)
        return installedPath
    sourcePath := A_ScriptDir "\dependencies\virtualdesktop\" filename
    return FileExist(sourcePath) ? sourcePath : ""
}

GetVirtualDesktopSwitcherFilename(buildNumber) {
    if (buildNumber < 22000)
        return ""
    return (buildNumber >= 26100)
        ? "VirtualDesktop11-24H2.exe" : "VirtualDesktop11.exe"
}

GetWindowsBuildNumber() {
    try return Integer(RegRead(
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion",
        "CurrentBuildNumber"))
    catch
        return 0
}

BuildVirtualDesktopSwitchCommand(switcherPath, targetIndex) {
    return Chr(34) switcherPath Chr(34)
        . " /Animation:Off /Switch:" (targetIndex - 1)
}

IsVirtualDesktopSwitchExitSuccessful(exitCode, targetIndex) {
    ; Retained as a unit-tested parser rule for the helper's documented result:
    ; /Switch returns its zero-based destination, not conventional zero-success.
    return (exitCode = targetIndex - 1)
}

MoveToVirtualDesktopBoundary(direction) {
    global VirtualDesktops
    key := (direction > 0) ? "^#{Right}" : "^#{Left}"
    Loop 64 {
        RefreshVirtualDesktopSnapshot()
        previousId := VirtualDesktops.currentId
        SendInput(key)
        if !WaitForVirtualDesktopIdChange(previousId, 700)
            return
    }
    throw Error("virtual-desktop boundary was not reached")
}

WaitForVirtualDesktopCount(expectedCount, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        if (GetVirtualDesktopIds().Length >= expectedCount)
            return true
        Sleep(25)
    }
    return false
}

WaitForVirtualDesktopIdChange(previousId, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    while (A_TickCount < deadline) {
        currentId := GetCurrentVirtualDesktopId()
        if (currentId != "" && currentId != previousId)
            return true
        Sleep(25)
    }
    return false
}

PollVirtualDesktopChange(*) {
    global VirtualDesktops
    if !VirtualDesktops.enabled
        return
    try {
        previousId := VirtualDesktops.currentId
        RefreshVirtualDesktopSnapshot()
        if (VirtualDesktops.currentId = previousId)
            return
        SynchronizeActiveVirtualWorkspace()
    } catch Error as err {
        DebugLog("Virtual desktop polling failed: " ErrorDescription(err))
    }
}

SynchronizeActiveVirtualWorkspace() {
    global VirtualDesktops
    ActivateWorkspace(VirtualDesktops.currentId)
    UpdateDesktopIndicator()
    UpdateTrayTip()
    RefreshLayout()
    FocusVirtualDesktopWindow()
    DebugLog("Virtual desktop changed; current=" FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId))
}

FocusVirtualDesktopWindow() {
    global Manager, VirtualDesktops
    rememberedHwnd := VirtualDesktops.lastFocusByDesktopId.Has(VirtualDesktops.currentId)
        ? VirtualDesktops.lastFocusByDesktopId[VirtualDesktops.currentId] : 0
    pendingHwnd := 0
    if (VirtualDesktops.pendingFocusDesktopId = VirtualDesktops.currentId) {
        pendingHwnd := VirtualDesktops.pendingFocusHwnd
        ClearPendingVirtualDesktopFocus()
    }
    for hwnd in BuildVirtualDesktopFocusCandidates(
        pendingHwnd, rememberedHwnd, Manager.order) {
        if IsVirtualDesktopFocusCandidate(hwnd) {
            WinActivate("ahk_id " hwnd)
            RememberVirtualDesktopFocus(hwnd)
            source := (hwnd = pendingHwnd) ? "moved-window"
                : (hwnd = rememberedHwnd) ? "remembered" : "workspace-order"
            DebugLog("Virtual desktop focus restored; source=" source "; hwnd=" hwnd)
            return true
        }
    }
    ; An empty workspace must leave Windows' focus choice alone. Forcing the
    ; Explorer shell foreground during a desktop transition can race Explorer
    ; and briefly destabilize the manager, especially after Discord/Electron
    ; windows have been active on the source desktop.
    DebugLog("Virtual desktop focus unchanged; no eligible window")
    return false
}

BuildVirtualDesktopFocusCandidates(pendingHwnd, rememberedHwnd, order) {
    candidates := []
    AddVirtualDesktopFocusCandidate(candidates, pendingHwnd)
    AddVirtualDesktopFocusCandidate(candidates, rememberedHwnd)
    for hwnd in order
        AddVirtualDesktopFocusCandidate(candidates, hwnd)
    return candidates
}

AddVirtualDesktopFocusCandidate(candidates, hwnd) {
    if !hwnd || FindWindowIndex(candidates, hwnd)
        return
    candidates.Push(hwnd)
}

ClearPendingVirtualDesktopFocus() {
    global VirtualDesktops
    VirtualDesktops.pendingFocusHwnd := 0
    VirtualDesktops.pendingFocusDesktopId := ""
}

StartVirtualDesktopFocusTracking() {
    global VirtualDesktops
    static EVENT_SYSTEM_FOREGROUND := 0x0003
    static WINEVENT_OUTOFCONTEXT := 0
    static WINEVENT_SKIPOWNPROCESS := 0x2
    try {
        VirtualDesktops.foregroundEventCallback := CallbackCreate(
            HandleVirtualDesktopForegroundChange, , 7)
        VirtualDesktops.foregroundEventHook := DllCall(
            "User32\SetWinEventHook",
            "uint", EVENT_SYSTEM_FOREGROUND,
            "uint", EVENT_SYSTEM_FOREGROUND,
            "ptr", 0,
            "ptr", VirtualDesktops.foregroundEventCallback,
            "uint", 0,
            "uint", 0,
            "uint", WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS,
            "ptr")
        if !VirtualDesktops.foregroundEventHook
            throw OSError(A_LastError, "SetWinEventHook virtual desktop focus")
        RememberForegroundVirtualDesktopFocus()
        DebugLog("Virtual desktop focus tracking enabled")
    } catch Error as err {
        StopVirtualDesktopFocusTracking()
        DebugLog("Virtual desktop focus tracking unavailable: "
            . ErrorDescription(err))
    }
}

StopVirtualDesktopFocusTracking() {
    global VirtualDesktops
    if VirtualDesktops.foregroundEventHook {
        try DllCall("User32\UnhookWinEvent",
            "ptr", VirtualDesktops.foregroundEventHook)
    }
    if VirtualDesktops.foregroundEventCallback {
        try CallbackFree(VirtualDesktops.foregroundEventCallback)
    }
    VirtualDesktops.foregroundEventHook := 0
    VirtualDesktops.foregroundEventCallback := 0
}

HandleVirtualDesktopForegroundChange(eventHook, event, hwnd, idObject, idChild,
    eventThread, eventTime) {
    global VirtualDesktops
    if !VirtualDesktops.enabled
        return
    ; Query from a normal AHK timer thread, after Windows has completed the
    ; foreground transition, rather than from the WinEvent callback.
    SetTimer(RememberForegroundVirtualDesktopFocus, -1)
}

RememberForegroundVirtualDesktopFocus(*) {
    global VirtualDesktops
    if !VirtualDesktops.enabled
        return false
    hwnd := WinExist("A")
    if !hwnd || !IsFocusableWindow(hwnd)
        return false
    try desktopId := GetWindowVirtualDesktopId(hwnd)
    catch Error as err {
        DebugLog("Virtual desktop focus memory query failed; hwnd=" hwnd
            . "; " ErrorDescription(err))
        return false
    }
    if !FindVirtualDesktopIndex(VirtualDesktops.desktopIds, desktopId)
        return false
    VirtualDesktops.lastFocusByDesktopId[desktopId] := hwnd
    return true
}

RememberVirtualDesktopFocus(hwnd) {
    global VirtualDesktops
    if !hwnd || (VirtualDesktops.currentId = "")
        return false
    VirtualDesktops.lastFocusByDesktopId[VirtualDesktops.currentId] := hwnd
    return true
}

IsVirtualDesktopFocusCandidate(hwnd) {
    return hwnd && WinExist("ahk_id " hwnd)
        && IsFocusableWindow(hwnd)
        && IsWindowOnCurrentVirtualDesktop(hwnd)
}

GetVirtualDesktopIds() {
    buffer := ReadVirtualDesktopRegistryValue("VirtualDesktopIDs")
    ids := []
    if (Type(buffer) = "String") {
        if !StrLen(buffer) || Mod(StrLen(buffer), 32)
            return ids
        Loop StrLen(buffer) // 32
            ids.Push(VirtualDesktopIdFromBuffer(buffer, (A_Index - 1) * 16))
        return ids
    }
    if !IsObject(buffer) || !buffer.Size
        return ids
    if Mod(buffer.Size, 16)
        return ids
    Loop buffer.Size // 16
        ids.Push(VirtualDesktopIdFromBuffer(buffer, (A_Index - 1) * 16))
    return ids
}

GetCurrentVirtualDesktopId() {
    buffer := ReadVirtualDesktopRegistryValue("CurrentVirtualDesktop")
    if (Type(buffer) = "String")
        return VirtualDesktopIdFromBuffer(buffer)
    return (IsObject(buffer) && buffer.Size = 16)
        ? VirtualDesktopIdFromBuffer(buffer) : ""
}

ReadVirtualDesktopRegistryValue(name) {
    static key := "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops"
    try return RegRead(key, name)
    catch
        return ""
}

VirtualDesktopIdFromBuffer(buffer, offset := 0) {
    if (Type(buffer) = "String") {
        position := offset * 2 + 1
        return (StrLen(buffer) >= position + 31)
            ? StrUpper(SubStr(buffer, position, 32)) : ""
    }
    if !IsObject(buffer) || (buffer.Size < offset + 16)
        return ""
    id := ""
    Loop 16
        id .= Format("{:02X}", NumGet(buffer, offset + A_Index - 1, "UChar"))
    return id
}

VirtualDesktopIdToBuffer(desktopId) {
    if (Type(desktopId) != "String" || !RegExMatch(desktopId, "i)^[0-9a-f]{32}$"))
        throw Error("invalid virtual desktop id")
    guidBuffer := Buffer(16, 0)
    Loop 16
        NumPut("UChar", Integer("0x" SubStr(desktopId, (A_Index - 1) * 2 + 1, 2)),
            guidBuffer, A_Index - 1)
    return guidBuffer
}

FindVirtualDesktopIndex(ids, desktopId) {
    for index, candidate in ids {
        if (candidate = desktopId)
            return index
    }
    return 0
}

IsWindowOnCurrentVirtualDesktop(hwnd) {
    global VirtualDesktops
    if !VirtualDesktops.enabled
        return true
    try {
        windowDesktopId := GetWindowVirtualDesktopId(hwnd)
        if (windowDesktopId = VirtualDesktops.currentId)
            return true
        DebugLog("Virtual desktop membership mismatch; hwnd=" hwnd
            . "; window=" windowDesktopId
            . "; current=" VirtualDesktops.currentId)
        return false
    } catch Error as err {
        DebugLog("Virtual desktop membership query failed; hwnd=" hwnd
            . "; " ErrorDescription(err))
        return false
    }
}

GetWindowVirtualDesktopId(hwnd) {
    static CLSID_VirtualDesktopManager := "{AA509086-5CA9-4C25-8F95-589D3C07B48A}"
    static IID_IVirtualDesktopManager := "{A5CD92FF-29BE-454C-8D04-D82879FB3F1B}"
    manager := CreateComInterface(CLSID_VirtualDesktopManager,
        IID_IVirtualDesktopManager)
    desktopId := Buffer(16, 0)
    try {
        result := ComCall(4, manager, "ptr", hwnd, "ptr", desktopId, "int")
        if (result != 0)
            throw OSError(result, "IVirtualDesktopManager.GetWindowDesktopId")
        return VirtualDesktopIdFromBuffer(desktopId)
    } finally ObjRelease(manager)
}

MoveWindowToVirtualDesktop(hwnd, desktopId) {
    static CLSID_VirtualDesktopManager := "{AA509086-5CA9-4C25-8F95-589D3C07B48A}"
    static IID_IVirtualDesktopManager := "{A5CD92FF-29BE-454C-8D04-D82879FB3F1B}"
    manager := CreateComInterface(CLSID_VirtualDesktopManager,
        IID_IVirtualDesktopManager)
    desktopGuid := VirtualDesktopIdToBuffer(desktopId)
    try {
        result := ComCall(5, manager, "ptr", hwnd, "ptr", desktopGuid, "int")
        if (result != 0)
            throw OSError(result, "IVirtualDesktopManager.MoveWindowToDesktop")
    } finally ObjRelease(manager)
}

CreateComInterface(classId, interfaceId) {
    classGuid := GuidBuffer(classId)
    interfaceGuid := GuidBuffer(interfaceId)
    pointer := 0
    result := DllCall("Ole32\CoCreateInstance",
        "ptr", classGuid,
        "ptr", 0,
        "uint", 1,
        "ptr", interfaceGuid,
        "ptr*", &pointer,
        "int")
    if (result != 0 || !pointer)
        throw OSError(result, "CoCreateInstance virtual desktop manager")
    return pointer
}

GuidBuffer(value) {
    guid := Buffer(16, 0)
    result := DllCall("Ole32\CLSIDFromString", "wstr", value,
        "ptr", guid, "int")
    if (result != 0)
        throw OSError(result, "CLSIDFromString")
    return guid
}
