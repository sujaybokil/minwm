RunConfigTests() {
    global Config, ConfigLoadMessages
    Config := BuildDefaultConfig()
    ConfigLoadMessages := []
    LoadConfigFile(A_ScriptDir "\config\default-config.toml", "test default")
    LoadConfigFile(A_ScriptDir "\tests\config-override.toml", "test user")
    ValidateConfig()

    AssertEqual(Config["pollInterval"], 750,
        "sparse user config should override a default value")
    AssertEqual(Config["defaultGap"], 12,
        "unspecified user config should retain the shipped default")
    AssertEqual(Config["desktop1Layout"], "vertical",
        "unspecified desktop layouts should retain the shipped defaults")
    AssertEqual(Config["desktop3Layout"], "monocle",
        "a user config should override one desktop's initial layout")
    AssertEqual(Config["logPath"], A_Temp "\minwm.log",
        "the shipped log path should resolve to the temporary directory")
    AssertEqual(Config["hotkeys"]["retile"], "#q",
        "user config should override a hotkey")
    AssertEqual(Config["hotkeys"]["toggleTemporaryFloat"], "#f",
        "temporary float should have its default hotkey when not overridden")
    AssertEqual(Config["hotkeys"]["toggleScratchpad"], "!s",
        "scratchpad should have its default hotkey when not overridden")
    AssertEqual(Config["hotkeys"]["restoreScratchpad"], "!t",
        "scratchpad restore should have its default hotkey when not overridden")
    AssertEqual(Config["floatingClasses"].Count, 0,
        "empty arrays should be accepted")
    AssertEqual(Config["focusBorderLayouts"][1], "grid",
        "layout arrays should be loaded from the user config")
    AssertEqual(Config["windowRules"].Length, 1,
        "window-rule tables should be loaded from the user config")
    AssertEqual(Config["windowRules"][1]["initialState"], "floating",
        "window-rule values should be parsed")

    Config["windowRules"] := [Map("process", 123, "initialState", "tile")]
    ValidateWindowRules()
    AssertEqual(Config["windowRules"].Length, 0,
        "window rules with non-string match values should be rejected")
}
