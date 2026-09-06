; Defaults plus a deliberately small TOML reader. The versioned default file
; ships with minwm; the per-user file contains only deliberate overrides.
InitializeConfig() {
    global ConfigDirectory, DefaultConfigPath, UserConfigPath, ConfigLoadMessages, Config
    ConfigDirectory := ResolveConfigDirectory()
    DefaultConfigPath := A_ScriptDir "\config\default-config.toml"
    UserConfigPath := ConfigDirectory "\config.toml"
    ConfigLoadMessages := []
    Config := BuildDefaultConfig()
    LoadConfigFile(DefaultConfigPath, "default configuration")
    LoadConfigFile(UserConfigPath, "user configuration", true)
}

ResolveConfigDirectory() {
    index := 1
    while (index <= A_Args.Length) {
        if (A_Args[index] = "--config-directory" && index < A_Args.Length
            && Trim(A_Args[index + 1]) != "")
            return A_Args[index + 1]
        index += 1
    }
    return A_AppData "\minwm"
}

BuildDefaultConfig() {
    return Map(
        "pollInterval", 400,
        "windowRefreshEventDebounceMs", 50,
        "minWidth", 320,
        "minHeight", 220,
        "defaultGap", 12,
        "gapStep", 4,
        "minGap", 0,
        "smartGapsEnabled", true,
        "defaultLayout", "vertical",
        "desktop1Layout", "vertical",
        "desktop2Layout", "vertical",
        "desktop3Layout", "vertical",
        "desktop4Layout", "vertical",
        "desktop5Layout", "vertical",
        "desktop6Layout", "vertical",
        "desktop7Layout", "vertical",
        "desktop8Layout", "vertical",
        "desktop9Layout", "vertical",
        "virtualDesktopsEnabled", true,
        "virtualDesktopCount", 6,
        "startupVirtualDesktop", 1,
        "desktopIndicatorX", 8,
        "desktopIndicatorY", 12,
        "desktopIndicatorWidth", 44,
        "desktopIndicatorHeight", 22,
        "desktopIndicatorBackgroundColor", "202020",
        "desktopIndicatorTextColor", "FFFFFF",
        "desktopIndicatorOpacity", 185,
        "desktopIndicatorFontSize", 11,
        "desktopIndicatorFontName", "Segoe UI Semibold",
        "desktopIndicatorPollInterval", 1000,
        "masterRatio", 0.58,
        "masterRatioStep", 0.04,
        "minMasterRatio", 0.30,
        "maxMasterRatio", 0.75,
        "logPath", A_Temp "\minwm.log",
        "debugMaxSizeMb", 5,
        "focusBorderWidth", 1,
        "focusBorderColor", "FFFFFF",
        "focusBorderLayouts", ["vertical", "horizontal"],
        "focusBorderPollInterval", 33,
        "virtualDesktopPollInterval", 50,
        "layoutCycle", ["vertical", "horizontal", "grid", "monocle", "maximized", "floating"],
        "layoutCycleDebounceMs", 120,
        "layoutStateSaveDebounceMs", 250,
        "layoutNotificationsEnabled", true,
        "layoutNotificationDurationMs", 1000,
        "customHotkeysEnabled", true,
        "excludedClasses", Map("Progman", true, "WorkerW", true, "Shell_TrayWnd", true, "#32770", true),
        "ignoredProcesses", Map(
            "StartMenuExperienceHost.exe", true,
            "SearchHost.exe", true,
            "SearchApp.exe", true,
            "SearchUI.exe", true),
        "floatingClasses", Map(),
        "floatingProcesses", Map(),
        "floatingTitles", Map(),
        "windowRules", [],
        "hotkeys", Map(
            "cycleLayout", "#t",
            "retile", "#r",
            "increaseGap", "#]",
            "decreaseGap", "#[",
            "increaseMaster", "#+]",
            "decreaseMaster", "#+[",
            "focusNext", "#j",
            "focusPrevious", "#k",
            "focusLeft", "#!Left",
            "focusRight", "#!Right",
            "focusUp", "#!Up",
            "focusDown", "#!Down",
            "moveNext", "#+j",
            "movePrevious", "#+k",
            "moveLeft", "#!+Left",
            "moveRight", "#!+Right",
            "moveUp", "#!+Up",
            "moveDown", "#!+Down",
            "swapMaster", "#m",
            "closeWindow", "#w",
            "toggleTemporaryFloat", "#f",
            "toggleScratchpad", "!s",
            "restoreScratchpad", "!t",
            "toggleSmartGaps", "#y",
            "showHotkeys", "#h",
            "toggleDesktopIndicator", "#d"
        )
    )
}

LoadConfigFile(path, description, optional := false) {
    global Config, ConfigLoadMessages
    if !FileExist(path) {
        if !optional
            ConfigLoadMessages.Push(description " not found; built-in fallback defaults are active")
        return
    }

    section := ""
    currentRule := ""
    try lines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
    catch Error as err {
        ConfigLoadMessages.Push("could not read " description ": " err.Message)
        return
    }

    for lineNumber, line in lines {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "^\[\[windowRules\]\]$") {
            section := "windowRules"
            currentRule := Map()
            Config["windowRules"].Push(currentRule)
            continue
        }
        if RegExMatch(line, "^\[([A-Za-z0-9_]+)\]$", &table) {
            section := table[1]
            currentRule := ""
            if (section != "hotkeys")
                ConfigLoadMessages.Push("line " lineNumber ": unknown TOML table [" section "]")
            continue
        }
        if !RegExMatch(line, "^(.+?)\s*=\s*(.+)$", &pair) {
            ConfigLoadMessages.Push("line " lineNumber ": expected key = value")
            continue
        }
        key := Trim(pair[1], " `t`"")
        value := ParseTomlValue(Trim(pair[2]), lineNumber)
        if (!IsObject(value) && value = "__MINWM_INVALID__")
            continue
        if (section = "windowRules") {
            if !IsObject(currentRule) {
                ConfigLoadMessages.Push("line " lineNumber ": window rule has no table")
                continue
            }
            if !(key = "process" || key = "class" || key = "title"
                || key = "initialState" || key = "desktop" || key = "monitor") {
                ConfigLoadMessages.Push("line " lineNumber ": unknown window rule setting " key)
                continue
            }
            currentRule[key] := value
            continue
        }
        if (section != "" && section != "hotkeys") {
            ConfigLoadMessages.Push("line " lineNumber ": setting ignored in unknown table [" section "]")
            continue
        }

        ; Upgrade migrations may append a newly introduced global setting
        ; after the existing [hotkeys] table. Route known hotkeys to that
        ; table and recognized global keys back to the root configuration.
        target := (section = "hotkeys" && Config["hotkeys"].Has(key))
            ? Config["hotkeys"]
            : Config
        if !target.Has(key) {
            ConfigLoadMessages.Push("line " lineNumber ": unknown setting " key)
            continue
        }
        if (key = "excludedClasses" || key = "ignoredProcesses"
            || key = "floatingClasses" || key = "floatingProcesses"
            || key = "floatingTitles") {
            if !IsObject(value) {
                ConfigLoadMessages.Push("line " lineNumber ": " key " must be an array")
                continue
            }
            classes := Map()
            for _, className in value
                classes[className] := true
            target[key] := classes
        } else if (key = "logPath") {
            target[key] := ResolveConfigPath(value)
        } else {
            target[key] := value
        }
    }
    ConfigLoadMessages.Push("loaded " description " from " path)
}

ResolveConfigPath(path) {
    global ConfigDirectory
    if RegExMatch(path, "i)^%TEMP%(.*)$", &temporaryPath)
        return A_Temp temporaryPath[1]
    return InStr(path, ":") ? path : ConfigDirectory "\" path
}

ParseTomlValue(value, lineNumber) {
    global ConfigLoadMessages
    if RegExMatch(value, '^"(.*)"$', &quoted)
        return quoted[1]
    if (value = "true")
        return true
    if (value = "false")
        return false
    if RegExMatch(value, "^-?\d+$")
        return Integer(value)
    if RegExMatch(value, "^-?(\d+\.\d*|\d*\.\d+)$")
        return Float(value)
    if RegExMatch(value, "^\[(.*)\]$", &array) {
        values := []
        if (Trim(array[1]) = "")
            return values
        for _, item in StrSplit(array[1], ",") {
            item := Trim(item)
            if !RegExMatch(item, '^"(.*)"$', &arrayString) {
                ConfigLoadMessages.Push("line " lineNumber ": arrays may contain only quoted strings")
                return "__MINWM_INVALID__"
            }
            values.Push(arrayString[1])
        }
        return values
    }
    ConfigLoadMessages.Push("line " lineNumber ": unsupported TOML value")
    return "__MINWM_INVALID__"
}
