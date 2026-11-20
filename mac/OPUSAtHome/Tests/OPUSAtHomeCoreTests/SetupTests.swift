import XCTest
@testable import OPUSAtHomeCore

final class SetupTests: XCTestCase {
    func testPlanDeduplicatesCommandsAndSkipsOptionalTools() {
        let requirements = [
            Prerequisite(name: "Git", ok: false, required: true, detail: "", setup: [.developerTools]),
            Prerequisite(name: "Python", ok: false, required: true, detail: "", setup: [.developerTools]),
            Prerequisite(name: "GitHub CLI", ok: false, required: false, detail: "", setup: [.githubCLI, .githubLogin]),
            Prerequisite(name: "Claude Code", ok: true, required: true, detail: "", setup: [.claudeLogin]),
            Prerequisite(name: "LilyPond", ok: false, required: true, detail: "", setup: [.lilypond])
        ]
        XCTAssertEqual(SetupPlan(requirements, hasBrew: false).steps, [.developerTools, .homebrew, .lilypond])
        XCTAssertEqual(SetupPlan(requirements, hasBrew: true).steps, [.developerTools, .lilypond])
    }
}
