; Layout-cycle helpers are kept separate so a burst can be resolved to one
; final mode before the controller performs any window moves or notifications.
LayoutAfterCycles(layout, cycles) {
    global Config
    layouts := Config["layoutCycle"]
    startIndex := 1
    for index, candidate in layouts {
        if (candidate = layout) {
            startIndex := index
            break
        }
    }
    return layouts[Mod(startIndex - 1 + cycles, layouts.Length) + 1]
}
