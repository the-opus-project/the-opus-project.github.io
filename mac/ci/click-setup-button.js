function run([label]) {
    const app = Application("System Events").processes.byName("OPUSAtHome")
    const buttons = new Set()
    for (let attempt = 0; attempt < 20; attempt++) {
        const pending = app.windows()
        while (pending.length > 0) {
            const element = pending.pop()
            if (element.role() === "AXButton") {
                const name = element.name()
                const description = element.description()
                buttons.add(name || description)
                if (name === label || description === label) {
                    element.click()
                    return
                }
            } else {
                pending.push(...element.uiElements())
            }
        }
        delay(0.5)
    }
    throw new Error("Could not find " + label + ". Visible buttons: " + Array.from(buttons).join(", "))
}
