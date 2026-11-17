import CoreGraphics
import Foundation

let args = CommandLine.arguments
let point = CGPoint(x: Double(args[1])!, y: Double(args[2])!)
let delta = Int32(args[3])!
CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
usleep(300_000)
for _ in 0..<20 {
    CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: delta, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
    usleep(50_000)
}
