InitializeDebugLog() {
    global Config, LogPathWasSpecified, StartupMessages
    if !LogPathWasSpecified
        Config["logPath"] := CreateSessionLogPath(Config["logPath"])
    try {
        EnsureDebugLogDirectory(Config["logPath"])
        RotateDebugLog(Config["logPath"])
    } catch Error as err {
        requestedPath := Config["logPath"]
        fallbackPath := A_Temp "\minwm-log-fallback.log"
        try {
            EnsureDebugLogDirectory(fallbackPath)
            Config["logPath"] := fallbackPath
            StartupMessages.Push("could not use log path " requestedPath
                "; using " fallbackPath "; " ErrorDescription(err))
        } catch Error as fallbackErr {
            StartupMessages.Push("logging is unavailable: "
                ErrorDescription(fallbackErr))
            OutputDebug("minwm logging is unavailable: "
                ErrorDescription(fallbackErr))
        }
    }
}

CreateSessionLogPath(path) {
    SplitPath(path, &fileName, &directory, &extension, &nameWithoutExtension)
    suffix := "-" CreateDiagnosticSessionId()
    if (extension = "")
        return path suffix
    return directory "\" nameWithoutExtension suffix "." extension
}

CreateDiagnosticSessionId() {
    ; Scriptlet.TypeLib supplies a Windows GUID without requiring an in-process
    ; COM method declaration or a callback that could outlive the test runner.
    return StrLower(Trim(ComObject("Scriptlet.TypeLib").GUID, "{}"))
}

EnsureDebugLogDirectory(path) {
    SplitPath(path, , &directory)
    if (directory != "" && !DirExist(directory))
        DirCreate(directory)
}

RotateDebugLog(path) {
    global Config
    if !FileExist(path)
        return
    maximumBytes := Config["debugMaxSizeMb"] * 1024 * 1024
    if (FileGetSize(path) <= maximumBytes)
        return
    archivePath := path ".1"
    if FileExist(archivePath)
        FileDelete(archivePath)
    FileMove(path, archivePath)
}

DebugLog(message) {
    global Config
    try {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        FileAppend(timestamp " | " message "`n", Config["logPath"], "UTF-8")
    } catch Error as err {
        OutputDebug("minwm debug log write failed: " ErrorDescription(err))
    }
}

ErrorDescription(err) {
    location := (err.File != "" ? err.File : "unknown")
        . ":" (err.Line != "" ? err.Line : "?")
    operation := (err.What != "" ? " at " err.What : "")
    return err.Message operation " (" location ")"
}

WindowListDescription(windows) {
    description := ""
    for index, hwnd in windows
        description .= (index > 1 ? "," : "") hwnd
    return description
}
