import Foundation

extension AgentKind {
    func isSignedIn(_ tools: ToolEnvironment) -> Bool {
        switch self {
        case .codex:
            return tools.run("codex", ["login", "status"], timeout: 15).ok
        case .claude:
            let result = tools.run("claude", ["auth", "status", "--json"], timeout: 15)
            guard result.ok, let status = try? JSONDecoder().decode(ClaudeAuth.self, from: Data(result.stdout.utf8)) else { return false }
            return status.loggedIn
        }
    }
}

private struct ClaudeAuth: Decodable {
    let loggedIn: Bool
}

public enum SetupStep: Hashable {
    case developerTools, homebrew, githubCLI, githubLogin, codex, codexLogin, claude, claudeLogin, lilypond

    var usesBrew: Bool { self == .githubCLI || self == .codex || self == .lilypond }

    public var command: String {
        switch self {
        case .developerTools:
            return """
            if ! xcode-select -p >/dev/null 2>&1; then
                xcode-select --install || exit 1
                echo 'Finish the Apple Command Line Tools installer, then press Return.'
                read -r
            fi
            git --version && python3 --version
            """
        case .homebrew:
            return #"installer=$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh) && /bin/bash -c "$installer""#
        case .githubCLI: return "brew install gh"
        case .githubLogin: return "gh auth login --hostname github.com"
        case .codex: return "brew install --cask codex"
        case .codexLogin: return "codex login"
        case .claude: return "curl -fsSL https://claude.ai/install.sh | /bin/bash"
        case .claudeLogin: return "claude auth login --claudeai"
        case .lilypond: return "brew install lilypond"
        }
    }
}

public struct SetupPlan {
    public let missing: [Prerequisite]
    public let steps: [SetupStep]

    public init(_ prerequisites: [Prerequisite], hasBrew: Bool) {
        missing = prerequisites.filter { $0.required && !$0.ok }
        var steps: [SetupStep] = []
        for step in missing.flatMap(\.setup) {
            if step.usesBrew && !hasBrew && !steps.contains(.homebrew) { steps.append(.homebrew) }
            if !steps.contains(step) { steps.append(step) }
        }
        self.steps = steps
    }

    public func prompt(agent: AgentKind, executable: String) -> String {
        let quoted = "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let requirements = missing.map { "\($0.name) (\($0.detail))" }.joined(separator: ", ")
        if missing.isEmpty { return "OPUS@Home setup for \(agent.displayName) is complete." }
        return """
        Set up OPUS@Home on this Mac to use \(agent.displayName). The app found these missing requirements: \(requirements).
        Run \(quoted) --setup --agent \(agent.rawValue) in a local interactive terminal. It installs the missing tools and checks sign-in. Let me complete any browser sign-in or macOS installer prompt. Finish when the setup check passes.
        """
    }
}
