; Configuration is intentionally forgiving: invalid user values fall back to
; known-safe defaults and are recorded in the debug log when it is enabled.
ValidateConfig() {
    global Config, ConfigLoadMessages
    defaults := BuildDefaultConfig()

    ValidateIntegerSetting("pollInterval", 50, 60000, defaults)
    ValidateIntegerSetting("windowRefreshEventDebounceMs", 10, 1000, defaults)
    ValidateIntegerSetting("minWidth", 1, 10000, defaults)
    ValidateIntegerSetting("minHeight", 1, 10000, defaults)
    ValidateIntegerSetting("defaultGap", 0, GetMaximumGap(), defaults)
    ValidateIntegerSetting("gapStep", 1, 1000, defaults)
    ValidateIntegerSetting("minGap", 0, 1000, defaults)
    ValidateIntegerSetting("debugMaxSizeMb", 1, 100, defaults)
    ValidateIntegerSetting("focusBorderWidth", 0, 10, defaults)
    ValidateIntegerSetting("desktopIndicatorX", -100000, 100000, defaults)
    ValidateIntegerSetting("desktopIndicatorY", -100000, 100000, defaults)
    ValidateIntegerSetting("desktopIndicatorWidth", 1, 10000, defaults)
    ValidateIntegerSetting("desktopIndicatorHeight", 1, 10000, defaults)
    ValidateIntegerSetting("desktopIndicatorOpacity", 0, 255, defaults)
    ValidateIntegerSetting("desktopIndicatorFontSize", 6, 48, defaults)
    ValidateIntegerSetting("desktopIndicatorPollInterval", 100, 60000, defaults)
    ValidateIntegerSetting("focusBorderPollInterval", 10, 1000, defaults)
    ValidateIntegerSetting("virtualDesktopPollInterval", 25, 5000, defaults)
    ValidateIntegerSetting("layoutCycleDebounceMs", 1, 1000, defaults)
    ValidateIntegerSetting("layoutStateSaveDebounceMs", 1, 10000, defaults)
    ValidateIntegerSetting("layoutNotificationDurationMs", 100, 60000, defaults)
    ValidateDefaultLayout(defaults)
    ValidateDesktopLayouts(defaults)
    ValidateBooleanSetting("virtualDesktopsEnabled", defaults)
    ValidateBooleanSetting("smartGapsEnabled", defaults)
    ValidateBooleanSetting("layoutNotificationsEnabled", defaults)
    ValidateBooleanSetting("customHotkeysEnabled", defaults)
    ; Workspace selectors use Win+1 through Win+9, so each configured
    ; desktop can have a direct fixed hotkey.
    ValidateIntegerSetting("virtualDesktopCount", 1, 9, defaults)
    ValidateIntegerSetting("startupVirtualDesktop", 1, 9, defaults)
    if (Config["startupVirtualDesktop"] > Config["virtualDesktopCount"]) {
        ConfigLoadMessages.Push("startupVirtualDesktop must be within virtualDesktopCount; using "
            defaults["startupVirtualDesktop"])
        Config["startupVirtualDesktop"] := defaults["startupVirtualDesktop"]
    }

    ValidateNumberSetting("masterRatio", 0.05, 0.95, defaults)
    ValidateNumberSetting("masterRatioStep", 0.01, 0.50, defaults)
    ValidateNumberSetting("minMasterRatio", 0.05, 0.95, defaults)
    ValidateNumberSetting("maxMasterRatio", 0.05, 0.95, defaults)

    if (Config["minGap"] > Config["defaultGap"]) {
        ConfigLoadMessages.Push("minGap exceeds defaultGap; defaultGap was raised to minGap")
        Config["defaultGap"] := Config["minGap"]
    }

    if (Config["minMasterRatio"] > Config["maxMasterRatio"]) {
        ConfigLoadMessages.Push("minMasterRatio exceeds maxMasterRatio; ratio limits were reset")
        Config["minMasterRatio"] := defaults["minMasterRatio"]
        Config["maxMasterRatio"] := defaults["maxMasterRatio"]
    }
    Config["masterRatio"] := Min(
        Config["maxMasterRatio"],
        Max(Config["minMasterRatio"], Config["masterRatio"]))

    if (Type(Config["logPath"]) != "String" || Trim(Config["logPath"]) = "") {
        ConfigLoadMessages.Push("logPath must be a non-empty string; using the default")
        Config["logPath"] := defaults["logPath"]
    }

    ValidateColorSetting("focusBorderColor", defaults)
    ValidateColorSetting("desktopIndicatorBackgroundColor", defaults)
    ValidateColorSetting("desktopIndicatorTextColor", defaults)
    ValidateStringSetting("desktopIndicatorFontName", defaults)

    if !IsObject(Config["excludedClasses"]) {
        ConfigLoadMessages.Push("excludedClasses must be an array of strings; using the default")
        Config["excludedClasses"] := defaults["excludedClasses"]
    }
    for _, name in ["ignoredProcesses", "floatingClasses", "floatingProcesses", "floatingTitles"]
        ValidateStringSetSetting(name, defaults)
    ValidateLayoutListSetting("layoutCycle", 2, defaults)
    ValidateLayoutListSetting("focusBorderLayouts", 0, defaults)
    ValidateWindowRules()

    ValidateHotkeySettings(defaults["hotkeys"])
}

GetMaximumGap() {
    return 1000
}

ClampGap(value) {
    global Config
    return Min(GetMaximumGap(), Max(Config["minGap"], value))
}

IsSupportedGap(value) {
    global Config
    return (Type(value) = "Integer" && value >= Config["minGap"]
        && value <= GetMaximumGap())
}

ValidateStringSetting(name, defaults) {
    global Config, ConfigLoadMessages
    if (Type(Config[name]) = "String" && Trim(Config[name]) != "")
        return
    ConfigLoadMessages.Push(name " must be a non-empty string; using the default")
    Config[name] := defaults[name]
}

ValidateLayoutListSetting(name, minimumLength, defaults) {
    global Config, ConfigLoadMessages
    if !IsObject(Config[name]) || Config[name].Length < minimumLength {
        ConfigLoadMessages.Push(name " must contain at least " minimumLength
            " supported layout names; using the default")
        Config[name] := defaults[name]
        return
    }
    valid := []
    seen := Map()
    for _, layout in Config[name] {
        layout := Type(layout) = "String" ? StrLower(Trim(layout)) : ""
        if !IsSupportedLayout(layout) {
            ConfigLoadMessages.Push(name " contains an unsupported layout; using the default")
            Config[name] := defaults[name]
            return
        }
        if !seen.Has(layout) {
            valid.Push(layout)
            seen[layout] := true
        }
    }
    if (valid.Length < minimumLength) {
        ConfigLoadMessages.Push(name " must contain " minimumLength " distinct layouts; using the default")
        Config[name] := defaults[name]
        return
    }
    Config[name] := valid
}

ValidateStringSetSetting(name, defaults) {
    global Config, ConfigLoadMessages
    if IsObject(Config[name])
        return
    ConfigLoadMessages.Push(name " must be an array of strings; using the default")
    Config[name] := defaults[name]
}

ValidateWindowRules() {
    global Config, ConfigLoadMessages
    valid := []
    for index, rule in Config["windowRules"] {
        if !IsObject(rule) {
            ConfigLoadMessages.Push("window rule " index " ignored: invalid table")
            continue
        }
        hasMatch := rule.Has("process") || rule.Has("class") || rule.Has("title")
        if !hasMatch {
            ConfigLoadMessages.Push("window rule " index " ignored: needs process, class, or title")
            continue
        }
        if !HasValidWindowRuleMatchValues(rule) {
            ConfigLoadMessages.Push("window rule " index " ignored: match values must be non-empty strings")
            continue
        }
        state := rule.Has("initialState") ? StrLower(rule["initialState"]) : "tile"
        if !(state = "tile" || state = "floating" || state = "ignore") {
            ConfigLoadMessages.Push("window rule " index " ignored: invalid initialState")
            continue
        }
        rule["initialState"] := state
        if rule.Has("desktop") && (Type(rule["desktop"]) != "Integer"
            || rule["desktop"] < 1 || rule["desktop"] > Config["virtualDesktopCount"]) {
            ConfigLoadMessages.Push("window rule " index " ignored: desktop must be 1 through "
                Config["virtualDesktopCount"])
            continue
        }
        if rule.Has("monitor") && !(rule["monitor"] = "primary"
            || Type(rule["monitor"]) = "Integer") {
            ConfigLoadMessages.Push("window rule " index " ignored: monitor must be primary or an index")
            continue
        }
        valid.Push(rule)
    }
    Config["windowRules"] := valid
}

HasValidWindowRuleMatchValues(rule) {
    for _, name in ["process", "class", "title"] {
        if rule.Has(name) && (Type(rule[name]) != "String" || Trim(rule[name]) = "")
            return false
    }
    return true
}

ValidateColorSetting(name, defaults) {
    global Config, ConfigLoadMessages
    value := Config[name]
    if (Type(value) = "String") {
        value := Trim(value)
        if (SubStr(value, 1, 1) = "#")
            value := SubStr(value, 2)
        if RegExMatch(value, "i)^[0-9a-f]{6}$") {
            Config[name] := StrUpper(value)
            return
        }
    }
    ConfigLoadMessages.Push(name " must be a six-digit RGB hex color; using "
        defaults[name])
    Config[name] := defaults[name]
}

ValidateDefaultLayout(defaults) {
    global Config, ConfigLoadMessages
    value := Config["defaultLayout"]
    if (Type(value) = "String") {
        value := StrLower(Trim(value))
        if IsSupportedLayout(value) {
            Config["defaultLayout"] := value
            return
        }
    }
    ConfigLoadMessages.Push("defaultLayout must be vertical, horizontal, grid, monocle, maximized, or floating; using "
        defaults["defaultLayout"])
    Config["defaultLayout"] := defaults["defaultLayout"]
}

ValidateDesktopLayouts(defaults) {
    global Config, ConfigLoadMessages
    Loop 9 {
        name := "desktop" A_Index "Layout"
        value := Config[name]
        if (Type(value) = "String") {
            value := StrLower(Trim(value))
            if IsSupportedLayout(value) {
                Config[name] := value
                continue
            }
        }
        ConfigLoadMessages.Push(name " must be vertical, horizontal, grid, monocle, maximized, or floating; using "
            defaults[name])
        Config[name] := defaults[name]
    }
}

IsSupportedLayout(value) {
    return value = "vertical" || value = "horizontal" || value = "grid"
        || value = "monocle" || value = "maximized" || value = "floating"
}

ValidateBooleanSetting(name, defaults) {
    global Config, ConfigLoadMessages
    if (Type(Config[name]) = "Integer"
        && (Config[name] = true || Config[name] = false))
        return
    ConfigLoadMessages.Push(name " must be true or false; using " defaults[name])
    Config[name] := defaults[name]
}

ValidateIntegerSetting(name, minimum, maximum, defaults) {
    global Config, ConfigLoadMessages
    value := Config[name]
    if (Type(value) = "Integer" && value >= minimum && value <= maximum)
        return
    ConfigLoadMessages.Push(name " must be an integer from " minimum " to " maximum
        "; using " defaults[name])
    Config[name] := defaults[name]
}

ValidateNumberSetting(name, minimum, maximum, defaults) {
    global Config, ConfigLoadMessages
    value := Config[name]
    if ((Type(value) = "Integer" || Type(value) = "Float")
        && value >= minimum && value <= maximum)
        return
    ConfigLoadMessages.Push(name " must be a number from " minimum " to " maximum
        "; using " defaults[name])
    Config[name] := defaults[name]
}

ValidateHotkeySettings(defaults) {
    global Config, ConfigLoadMessages
    seen := Map()
    for action, defaultBinding in defaults {
        binding := Config["hotkeys"][action]
        if (Type(binding) != "String" || Trim(binding) = "") {
            ConfigLoadMessages.Push("hotkey " action " must be a non-empty string; using "
                defaultBinding)
            Config["hotkeys"][action] := defaultBinding
            binding := defaultBinding
        }

        normalized := StrLower(binding)
        if seen.Has(normalized) {
            ConfigLoadMessages.Push("hotkey " action " duplicates " seen[normalized]
                "; using " defaultBinding)
            Config["hotkeys"][action] := defaultBinding
            normalized := StrLower(defaultBinding)
        }
        seen[normalized] := action
    }
}
