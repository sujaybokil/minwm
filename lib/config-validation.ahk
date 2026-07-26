; Configuration is intentionally forgiving: invalid user values fall back to
; known-safe defaults and are recorded in the debug log when it is enabled.
ValidateConfig() {
    global Config, ConfigLoadMessages
    defaults := BuildDefaultConfig()

    ValidateIntegerSetting("pollInterval", 50, 60000, defaults)
    ValidateIntegerSetting("minWidth", 1, 10000, defaults)
    ValidateIntegerSetting("minHeight", 1, 10000, defaults)
    ValidateIntegerSetting("defaultGap", 0, 1000, defaults)
    ValidateIntegerSetting("gapStep", 1, 1000, defaults)
    ValidateIntegerSetting("minGap", 0, 1000, defaults)
    ValidateIntegerSetting("debugMaxSizeMb", 1, 100, defaults)
    ValidateIntegerSetting("focusBorderWidth", 0, 10, defaults)

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

    if (Type(Config["debugLogPath"]) != "String" || Trim(Config["debugLogPath"]) = "") {
        ConfigLoadMessages.Push("debugLogPath must be a non-empty string; using the default")
        Config["debugLogPath"] := defaults["debugLogPath"]
    }

    ValidateColorSetting("focusBorderColor", defaults)

    if !IsObject(Config["excludedClasses"]) {
        ConfigLoadMessages.Push("excludedClasses must be an array of strings; using the default")
        Config["excludedClasses"] := defaults["excludedClasses"]
    }

    ValidateHotkeySettings(defaults["hotkeys"])
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
