on run argv
    set buttonName to item 1 of argv
    tell application "System Events" to tell process "OPUSAtHome"
        if (count of windows) is 0 then click menu bar item 1 of menu bar 2
        repeat 20 times
            repeat with panel in windows
                repeat with element in (entire contents of panel)
                    if role of element is "AXButton" then
                        if name of element is buttonName or description of element is buttonName then
                            perform action "AXPress" of element
                            return
                        end if
                    end if
                end repeat
            end repeat
            delay 0.5
        end repeat
        error "Could not find setup button: " & buttonName
    end tell
end run
