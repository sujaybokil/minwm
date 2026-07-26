InitializeDebugLog() {
    global Config
    if !Config["debugEnabled"] || !FileExist(Config["debugLogPath"])
        return
    try {
        maximumBytes := Config["debugMaxSizeMb"] * 1024 * 1024
        if (FileGetSize(Config["debugLogPath"]) <= maximumBytes)
            return
        archivePath := Config["debugLogPath"] ".1"
        if FileExist(archivePath)
            FileDelete(archivePath)
        FileMove(Config["debugLogPath"], archivePath)
    }
}

DebugLog(message) {
    global Config
    if !Config["debugEnabled"]
        return
    try {
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        FileAppend(timestamp " | " message "`n", Config["debugLogPath"], "UTF-8")
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
