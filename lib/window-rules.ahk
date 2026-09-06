HasDialogOrPopupSemantics(style, exStyle, className, ownerHwnd) {
    static WS_POPUP := 0x80000000
    static WS_EX_DLGMODALFRAME := 0x00000001
    static WS_EX_TOOLWINDOW := 0x00000080
    static WS_EX_NOACTIVATE := 0x08000000

    return ownerHwnd != 0
        || className = "#32770"
        || (style & WS_POPUP)
        || (exStyle & WS_EX_DLGMODALFRAME)
        || (exStyle & WS_EX_TOOLWINDOW)
        || (exStyle & WS_EX_NOACTIVATE)
}

IsWindowsStartMenuOrSearch(processName) {
    ; These shell surfaces have resizable top-level windows, so style checks
    ; alone can mistake them for normal application windows. SearchApp and
    ; SearchUI cover older supported Windows builds.
    static shellProcesses := Map(
        "startmenuexperiencehost.exe", true,
        "searchhost.exe", true,
        "searchapp.exe", true,
        "searchui.exe", true
    )
    return shellProcesses.Has(StrLower(processName))
}

GetMatchingWindowRule(hwnd) {
    global Config
    try {
        title := "ahk_id " hwnd
        process := WinGetProcessName(title)
        className := WinGetClass(title)
        windowTitle := WinGetTitle(title)
        for _, rule in Config["windowRules"] {
            if WindowRuleMatches(rule, {
                process: process, class: className, title: windowTitle
            })
                return rule
        }
    } catch {
    }
    return ""
}

WindowRuleMatches(rule, window) {
    return (!rule.Has("process")
        || StrLower(rule["process"]) = StrLower(window.process))
        && (!rule.Has("class")
            || StrLower(rule["class"]) = StrLower(window.class))
        && (!rule.Has("title")
            || StrLower(rule["title"]) = StrLower(window.title))
}

IsWindowIgnoredByRule(hwnd) {
    rule := GetMatchingWindowRule(hwnd)
    return IsObject(rule) && rule["initialState"] = "ignore"
}

IsWindowIgnoredByConfig(processName) {
    global Config
    return StringSetHas(Config["ignoredProcesses"], processName)
}

IsWindowForcedFloating(hwnd) {
    global Config
    rule := GetMatchingWindowRule(hwnd)
    if IsObject(rule)
        return rule["initialState"] = "floating"
    try {
        title := "ahk_id " hwnd
        return StringSetHas(Config["floatingProcesses"], WinGetProcessName(title))
            || StringSetHas(Config["floatingClasses"], WinGetClass(title))
            || StringSetHas(Config["floatingTitles"], WinGetTitle(title))
    } catch {
        return false
    }
}

StringSetHas(values, candidate) {
    for value, _ in values {
        if (StrLower(value) = StrLower(candidate))
            return true
    }
    return false
}
