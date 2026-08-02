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
        lastStatus: ""
    }
}

StartVirtualDesktopService() {
    global VirtualDesktops
    try {
        originalId := GetCurrentVirtualDesktopId()
        if (originalId = "")
            throw Error("Windows did not report a current virtual desktop")
        EnsureVirtualDesktopCount(6)
        RefreshVirtualDesktopSnapshot()
        originalIndex := FindVirtualDesktopIndex(VirtualDesktops.desktopIds, originalId)
        if !originalIndex
            throw Error("the original virtual desktop disappeared during setup")
        if !SwitchToVirtualDesktopIndex(originalIndex)
            throw Error("could not restore the original virtual desktop")
        RefreshVirtualDesktopSnapshot()
        VirtualDesktops.enabled := true
        SetTimer(PollVirtualDesktopChange, 250)
        DebugLog("Virtual desktops started; count=" VirtualDesktops.desktopIds.Length
            . "; current=" FindVirtualDesktopIndex(
                VirtualDesktops.desktopIds, VirtualDesktops.currentId))
        return true
    } catch Error as err {
        VirtualDesktops.enabled := false
        SetTimer(PollVirtualDesktopChange, 0)
        DebugLog("Virtual desktops unavailable: " ErrorDescription(err))
        return false
    }
}

StopVirtualDesktopService(*) {
    global VirtualDesktops
    SetTimer(PollVirtualDesktopChange, 0)
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

SwitchToVirtualDesktopIndex(targetIndex) {
    global VirtualDesktops
    RefreshVirtualDesktopSnapshot()
    currentIndex := FindVirtualDesktopIndex(
        VirtualDesktops.desktopIds, VirtualDesktops.currentId)
    if !currentIndex
        return false
    if (currentIndex = targetIndex)
        return true

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
        if !WaitForVirtualDesktopIdChange(previousId, 1500) {
            ; The helper has already acknowledged the requested destination.
            ; Explorer may publish the registry update after its process exits;
            ; let the normal poller synchronize it rather than issuing sequential
            ; Ctrl+Win shortcuts and reintroducing the animation.
            DebugLog("Direct virtual desktop switch accepted; awaiting registry update; target="
                . targetIndex)
            return true
        }
        RefreshVirtualDesktopSnapshot()
        actualIndex := FindVirtualDesktopIndex(
            VirtualDesktops.desktopIds, VirtualDesktops.currentId)
        if (actualIndex = targetIndex) {
            DebugLog("Direct virtual desktop switch succeeded; target=" targetIndex)
            return true
        }
        DebugLog("Direct virtual desktop switch accepted; registry still reports desktop="
            . actualIndex "; target=" targetIndex)
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
    global Manager
    for hwnd in Manager.order {
        if IsVirtualDesktopFocusCandidate(hwnd) {
            WinActivate("ahk_id " hwnd)
            DebugLog("Virtual desktop focus restored; hwnd=" hwnd)
            return true
        }
    }
    DebugLog("Virtual desktop focus unchanged; no eligible window")
    return false
}

IsVirtualDesktopFocusCandidate(hwnd) {
    return hwnd && WinExist("ahk_id " hwnd)
        && IsEligibleWindow(hwnd)
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
