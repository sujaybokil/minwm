ConstrainSplitSize(total, desiredFirst, minimumFirst, minimumSecond) {
    if (minimumFirst + minimumSecond > total)
        return Min(total, Max(0, desiredFirst))
    return Min(total - minimumSecond, Max(minimumFirst, desiredFirst))
}

AllocateConstrainedSizes(total, minimums) {
    count := minimums.Length
    if !count
        return []

    minimumTotal := 0
    sizes := []
    unassigned := []
    for index, minimum in minimums {
        minimumTotal += minimum
        sizes.Push(0)
        unassigned.Push(index)
    }
    if (minimumTotal > total)
        return ""

    remaining := total
    while unassigned.Length {
        share := Floor(remaining / unassigned.Length)
        nextUnassigned := []
        constrainedAny := false
        for _, index in unassigned {
            if (minimums[index] > share) {
                sizes[index] := minimums[index]
                remaining -= minimums[index]
                constrainedAny := true
            } else {
                nextUnassigned.Push(index)
            }
        }

        if !constrainedAny {
            share := Floor(remaining / nextUnassigned.Length)
            remainder := Mod(remaining, nextUnassigned.Length)
            for position, index in nextUnassigned
                sizes[index] := share + (position <= remainder ? 1 : 0)
            return sizes
        }
        unassigned := nextUnassigned
    }
    return sizes
}

CanTileMinimumSizes(layout, minimums, usableWidth, usableHeight, gap) {
    count := minimums.Length
    if !count
        return true
    if (usableWidth <= 0 || usableHeight <= 0)
        return false
    if (count = 1)
        return minimums[1].width <= usableWidth
            && minimums[1].height <= usableHeight

    master := minimums[1]
    stackCount := count - 1
    if (layout = "vertical") {
        stackWidth := 0
        stackHeight := 0
        Loop stackCount {
            minimum := minimums[A_Index + 1]
            stackWidth := Max(stackWidth, minimum.width)
            stackHeight += minimum.height
        }
        return master.width + stackWidth <= usableWidth - gap
            && master.height <= usableHeight
            && stackHeight <= usableHeight - gap * (stackCount - 1)
    }

    if (layout = "horizontal") {
        stackWidth := 0
        stackHeight := 0
        Loop stackCount {
            minimum := minimums[A_Index + 1]
            stackWidth += minimum.width
            stackHeight := Max(stackHeight, minimum.height)
        }
        return master.height + stackHeight <= usableHeight - gap
            && master.width <= usableWidth
            && stackWidth <= usableWidth - gap * (stackCount - 1)
    }
    return true
}

FindLargestMinimumSizeIndex(minimums) {
    largestIndex := 0
    largestArea := -1
    largestEdge := -1
    for index, minimum in minimums {
        area := minimum.width * minimum.height
        edge := Max(minimum.width, minimum.height)
        ; Prefer the later window on ties. A previously floated window is
        ; appended after the stable tiled order on the next discovery pass.
        if (area > largestArea || (area = largestArea && edge >= largestEdge)) {
            largestIndex := index
            largestArea := area
            largestEdge := edge
        }
    }
    return largestIndex
}

SelectTileableMinimumSizeIndices(layout, minimums, usableWidth, usableHeight, gap) {
    tiledIndices := []
    for index, _ in minimums
        tiledIndices.Push(index)
    floatingIndices := []

    while tiledIndices.Length {
        tiledMinimums := []
        for _, index in tiledIndices
            tiledMinimums.Push(minimums[index])
        if CanTileMinimumSizes(
            layout, tiledMinimums, usableWidth, usableHeight, gap)
            break

        largestLocalIndex := FindLargestMinimumSizeIndex(tiledMinimums)
        floatingIndices.Push(tiledIndices.RemoveAt(largestLocalIndex))
    }
    return { tiled: tiledIndices, floating: floatingIndices }
}
