; AutoHotkey includes are resolved before execution, so an optional custom
; script must run as a companion process. The generated wrapper watches the
; minwm parent process and exits even if minwm is terminated without OnExit.
StartCustomHotkeys(reservedHotkeys := "") {
    global Config, ConfigDirectory
    state := GetCustomHotkeysState()
    scriptPath := ConfigDirectory "\custom-hotkeys.ahk"
    if !FileExist(scriptPath) {
        DebugLog("Custom hotkeys script not present")
        return
    }

    try {
        SplitPath(scriptPath, , &workingDirectory)
        wrapperPath := ConfigDirectory "\minwm-custom-hotkeys-wrapper.ahk"
        if !IsObject(reservedHotkeys)
            reservedHotkeys := Config["hotkeys"]
        wrapperText := BuildCustomHotkeysWrapperText(
            scriptPath, ProcessExist(), reservedHotkeys)
        if FileExist(wrapperPath)
            FileDelete(wrapperPath)
        FileAppend(wrapperText, wrapperPath, "UTF-8")

        command := Chr(34) A_AhkPath Chr(34)
            . " " Chr(34) wrapperPath Chr(34)
        Run(command, workingDirectory, , &pid)
        state.pid := pid
        state.scriptPath := scriptPath
        state.wrapperPath := wrapperPath
        DebugLog("Custom hotkeys script started; pid=" pid
            . "; path=" scriptPath)
    } catch Error as err {
        DebugLog("Custom hotkeys script failed to start: "
            . ErrorDescription(err))
        StopCustomHotkeys()
    }
}

StopCustomHotkeys(*) {
    state := GetCustomHotkeysState()
    pid := state.pid
    if pid && ProcessExist(pid) {
        try ProcessClose(pid)
    }
    if (state.wrapperPath != "" && FileExist(state.wrapperPath)) {
        try FileDelete(state.wrapperPath)
    }
    state.pid := 0
    state.scriptPath := ""
    state.wrapperPath := ""
}

GetCustomHotkeysState() {
    global CustomHotkeys
    try return CustomHotkeys
    catch UnsetError {
        CustomHotkeys := { pid: 0, scriptPath: "", wrapperPath: "" }
        return CustomHotkeys
    }
}

BuildCustomHotkeysWrapperText(scriptPath, parentPid, reservedHotkeys := []) {
    reservedArray := BuildAhkStringArray(reservedHotkeys)
    return "#Requires AutoHotkey v2.0`r`n"
        . "#SingleInstance Force`r`n"
        . "#NoTrayIcon`r`n"
        . "global MinwmParentPid := " parentPid "`r`n"
        . "global MinwmReservedHotkeys := " reservedArray "`r`n"
        . "SetTimer(MinwmCheckParent, 1000)`r`n"
        . "SetTimer(MinwmDisableReservedHotkeys, 100)`r`n"
        . "MinwmDisableReservedHotkeys()`r`n"
        . "MinwmCheckParent() {`r`n"
        . "    global MinwmParentPid`r`n"
        . "    if !ProcessExist(MinwmParentPid)`r`n"
        . "        ExitApp()`r`n"
        . "}`r`n"
        . "MinwmDisableReservedHotkeys() {`r`n"
        . "    global MinwmReservedHotkeys`r`n"
        . "    for binding in MinwmReservedHotkeys {`r`n"
        . "        try Hotkey(binding, " Chr(34) "Off" Chr(34) ")`r`n"
        . "    }`r`n"
        . "}`r`n"
        . "#Include " Chr(34) scriptPath Chr(34) "`r`n"
}

BuildAhkStringArray(values) {
    text := "["
    position := 0
    for _, value in values {
        position += 1
        escaped := StrReplace(value, "``", "````")
        escaped := StrReplace(escaped, Chr(34), Chr(34) Chr(34))
        text .= (position > 1 ? ", " : "")
            . Chr(34) escaped Chr(34)
    }
    return text "]"
}
