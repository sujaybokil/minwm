; Defaults plus a deliberately small TOML reader. The user-facing configuration
; lives in config.toml so settings can be changed without editing manager code.
global ConfigLoadMessages := []
global Config := BuildDefaultConfig()
LoadConfigFile(A_ScriptDir "\config.toml")

BuildDefaultConfig() {
    return Map(
        "pollInterval", 400,
        "minWidth", 320,
        "minHeight", 220,
        "defaultGap", 12,
        "gapStep", 4,
        "minGap", 0,
        "masterRatio", 0.58,
        "masterRatioStep", 0.04,
        "minMasterRatio", 0.30,
        "maxMasterRatio", 0.75,
        "debugEnabled", false,
        "debugLogPath", A_ScriptDir "\minwm-debug.log",
        "debugMaxSizeMb", 5,
        "focusBorderWidth", 1,
        "focusBorderColor", "FFFFFF",
        "excludedClasses", Map("Progman", true, "WorkerW", true, "Shell_TrayWnd", true, "#32770", true),
        "hotkeys", Map(
            "cycleLayout", "#t",
            "retile", "#r",
            "increaseGap", "#]",
            "decreaseGap", "#[",
            "increaseMaster", "#+]",
            "decreaseMaster", "#+[",
            "focusNext", "#j",
            "focusPrevious", "#k",
            "moveNext", "#+j",
            "movePrevious", "#+k",
            "swapMaster", "#m",
            "closeWindow", "#w"
            , "showHotkeys", "#i"
        )
    )
}

LoadConfigFile(path) {
    global Config, ConfigLoadMessages
    if !FileExist(path) {
        ConfigLoadMessages.Push("config.toml not found; built-in defaults are active")
        return
    }

    section := ""
    try lines := StrSplit(FileRead(path, "UTF-8"), "`n", "`r")
    catch Error as err {
        ConfigLoadMessages.Push("could not read config.toml: " err.Message)
        return
    }

    for lineNumber, line in lines {
        line := Trim(line)
        if (line = "" || SubStr(line, 1, 1) = "#")
            continue
        if RegExMatch(line, "^\[([A-Za-z0-9_]+)\]$", &table) {
            section := table[1]
            if (section != "hotkeys")
                ConfigLoadMessages.Push("line " lineNumber ": unknown TOML table [" section "]")
            continue
        }
        if !RegExMatch(line, "^(.+?)\s*=\s*(.+)$", &pair) {
            ConfigLoadMessages.Push("line " lineNumber ": expected key = value")
            continue
        }
        if (section != "" && section != "hotkeys") {
            ConfigLoadMessages.Push("line " lineNumber ": setting ignored in unknown table [" section "]")
            continue
        }

        key := Trim(pair[1], " `t`"")
        value := ParseTomlValue(Trim(pair[2]), lineNumber)
        if (!IsObject(value) && value = "__MINWM_INVALID__")
            continue
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
        if (key = "excludedClasses") {
            if !IsObject(value) {
                ConfigLoadMessages.Push("line " lineNumber ": excludedClasses must be an array")
                continue
            }
            classes := Map()
            for _, className in value
                classes[className] := true
            target[key] := classes
        } else if (key = "debugLogPath") {
            target[key] := InStr(value, ":") ? value : A_ScriptDir "\" value
        } else {
            target[key] := value
        }
    }
    ConfigLoadMessages.Push("loaded config.toml")
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
