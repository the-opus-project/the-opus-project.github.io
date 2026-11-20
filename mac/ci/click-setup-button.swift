import CoreGraphics
import Foundation
import Vision

let screenshot = URL(fileURLWithPath: CommandLine.arguments[1])
let label = CommandLine.arguments[2]
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.minimumTextHeight = 0.005
request.customWords = ["OPUS", "setup"]
try VNImageRequestHandler(url: screenshot).perform([request])

let candidates = (request.results ?? []).compactMap { $0.topCandidates(1).first }
for candidate in candidates {
    guard let range = candidate.string.range(of: label, options: .caseInsensitive),
          let bounds = try candidate.boundingBox(for: range)?.boundingBox else { continue }
    let display = CGDisplayBounds(CGMainDisplayID())
    let point = CGPoint(x: display.minX + bounds.midX * display.width,
                        y: display.minY + (1 - bounds.midY) * display.height)
    print("Clicking \(label) at \(point)")
    for type: CGEventType in [.mouseMoved, .leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.1)
    }
    exit(0)
}
print("Could not locate \(label). Visible text: " + candidates.map(\.string).joined(separator: " | "))
exit(1)
