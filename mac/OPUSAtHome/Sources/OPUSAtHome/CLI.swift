import AppKit
import OPUSAtHomeCore

enum CLI {
    static func handle(_ args: [String]) -> Int32? {
        guard let cmd = args.first, cmd.hasPrefix("--"), !cmd.hasPrefix("-NS"), !cmd.hasPrefix("-Apple") else { return nil }
        let store = DataStore()
        var settings = store.loadSettings()
        if let i = args.firstIndex(of: "--agent"), i + 1 < args.count, let a = AgentKind(rawValue: args[i + 1]) { settings.switchAgent(to: a) }
        if let i = args.firstIndex(of: "--model"), i + 1 < args.count { settings.model = args[i + 1] }
        if let i = args.firstIndex(of: "--minutes"), i + 1 < args.count, let m = Int(args[i + 1]) { settings.maxRunMinutes = m }
        let tools = ToolEnvironment(preferProcessPath: true)
        switch cmd {
        case "--setup":
            return runSetup(settings, store: store)
        case "--setup-prompt":
            let plan = SetupPlan(Prerequisites.check(settings, tools: tools), hasBrew: tools.find("brew") != nil)
            print(plan.prompt(agent: settings.agent, executable: Bundle.main.executablePath ?? CommandLine.arguments[0]))
            return 0
        case "--status":
            print("Settings: \(store.settingsURL.path)")
            for p in Prerequisites.check(settings, tools: tools) {
                print("\(p.ok ? "ok  " : (p.required ? "MISSING" : "no  ")) \(p.name): \(p.detail)")
            }
            let charger = Power.onCharger()
            let idle = Power.idleSeconds()
            print("On charger: \(charger)  Idle: \(Int(idle)) s")
            let (u, err) = UsageReader.read(settings.agent, tools: tools)
            print("\(settings.agent.displayName) usage: \(u?.summary() ?? "unavailable (\(err ?? "?"))")")
            var s = settings
            s.enabled = true
            let d = Policy.decide(s, Conditions(onCharger: charger, idleSeconds: idle, usage: u))
            print("Would run now: \(d.run ? "yes" : "no") - \(d.reason)")
            return 0
        case "--prompt":
            let runner = ContributionRunner(store: store, tools: tools, settings: settings, options: RunOptions(openPullRequest: false, maxMinutes: settings.maxRunMinutes))
            print(runner.buildPrompt(skip: []))
            return 0
        case "--run-once":
            let open = !args.contains("--no-pr") && settings.openPullRequests
            let runner = ContributionRunner(store: store, tools: tools, settings: settings, options: RunOptions(openPullRequest: open, maxMinutes: settings.maxRunMinutes))
            runner.onStatus = { print($0) }
            let record = runner.run(shouldStop: { false })
            store.append(record)
            print("Outcome: \(record.outcome)")
            if let url = record.pullRequestURL { print("Pull request: \(url)") }
            print("Log: \(record.logPath ?? "")")
            return record.outcome.hasPrefix("Failed") ? 1 : 0
        case "--help":
            print("OPUS@Home\n  --status            show setup, power, usage and whether a run would start\n  --setup             install missing requirements and verify sign-in\n  --setup-prompt      print one setup prompt for your agent\n  --prompt            print the contribution prompt\n  --run-once [--no-pr] [--agent codex|claude] [--model M] [--minutes N]")
            return 0
        default:
            return nil
        }
    }
    static let setupFinished = Notification.Name("org.theopusproject.OPUSAtHome.setupFinished")

    private static func runSetup(_ settings: AppSettings, store: DataStore) -> Int32 {
        let fd = open(store.directory.appendingPathComponent("setup.lock").path, O_CREAT | O_RDWR, 0o600)
        guard fd >= 0 else { print("Could not open the OPUS@Home setup lock."); return 1 }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { print("Setup is already running in another terminal."); return 1 }
        defer { DistributedNotificationCenter.default().postNotificationName(setupFinished, object: nil, userInfo: nil, deliverImmediately: true) }
        print("Checking OPUS@Home setup for \(settings.agent.displayName)…")
        var attempted = Set<SetupStep>()
        while true {
            let tools = ToolEnvironment(preferProcessPath: true)
            let plan = SetupPlan(Prerequisites.check(settings, tools: tools), hasBrew: tools.find("brew") != nil)
            guard let step = plan.steps.first else {
                print("Setup complete. OPUS@Home is ready for \(settings.agent.displayName).")
                return 0
            }
            guard attempted.insert(step).inserted else {
                print("Setup still needs attention: " + plan.missing.map { "\($0.name) — \($0.detail)" }.joined(separator: ", "))
                return 1
            }
            print(step.command)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-o", "pipefail", "-c", step.command]
            process.environment = tools.environment
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Setup failed: \(error.localizedDescription)")
                return 1
            }
            if process.terminationStatus != 0 {
                print("Setup stopped. You can run it again to finish the remaining requirements.")
                return 1
            }
        }
    }

}
