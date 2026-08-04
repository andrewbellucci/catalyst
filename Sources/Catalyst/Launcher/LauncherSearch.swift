import AppKit

@MainActor
final class LauncherSearch {
    private let catalog: ApplicationCatalog
    private let calculator: Calculator
    private let settingsPanes: [SystemSettingsPane]
    private let usageHistory: UsageHistory
    private let aliases: ApplicationAliasStore
    private let runningApplications: RunningApplicationsMonitor
    private lazy var ranker = ResultRanker(usageHistory: usageHistory)
    var onRunningApplicationsChange: (() -> Void)?

    init(
        catalog: ApplicationCatalog = ApplicationCatalog(),
        calculator: Calculator = Calculator(),
        settingsPanes: [SystemSettingsPane] = SystemSettingsCatalog().panes(),
        usageHistory: UsageHistory = UsageHistory(),
        aliases: ApplicationAliasStore = ApplicationAliasStore(),
        runningApplications: RunningApplicationsMonitor = RunningApplicationsMonitor()
    ) {
        self.catalog = catalog
        self.calculator = calculator
        self.settingsPanes = settingsPanes
        self.usageHistory = usageHistory
        self.aliases = aliases
        self.runningApplications = runningApplications
    }

    func prepare() {
        catalog.load()
        runningApplications.onChange = { [weak self] in
            self?.onRunningApplicationsChange?()
        }
        runningApplications.start()
    }

    func reloadApplications() {
        catalog.load()
        runningApplications.reconcile()
    }

    func refreshRunningApplications() {
        runningApplications.reconcile()
    }

    func markApplicationStopped(at url: URL) {
        runningApplications.markQuitAccepted(
            bundleIdentifier: Bundle(url: url)?.bundleIdentifier,
            url: url
        )
    }

    func stop() {
        runningApplications.stop()
    }

    func recordUsage(of item: CommandItem) {
        guard item.isSelectable, item.usageIdentifier != "hint" else { return }
        usageHistory.record(item.usageIdentifier)
    }

    func applicationAliases(for url: URL) -> [String] {
        aliases.aliases(for: url, bundleIdentifier: Bundle(url: url)?.bundleIdentifier)
    }

    func setApplicationAliases(_ values: [String], for url: URL) {
        aliases.setAliases(
            values,
            for: url,
            bundleIdentifier: Bundle(url: url)?.bundleIdentifier
        )
    }

    func results(for rawQuery: String) -> [CommandItem] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        var applicationResults: [CommandItem] = []
        var commandResults = dynamicCommands(for: query)

        commandResults.append(contentsOf: CommandRegistry.builtIns
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
            .map(\.item))

        if !query.isEmpty {
            let paneItems = settingsPanes.map { pane in
                CommandItem(
                    title: pane.title,
                    subtitle: "System Settings",
                    icon: pane.icon,
                    kind: .systemSettings(pane.url),
                    aliases: pane.aliases
                )
            }
            commandResults.append(contentsOf: paneItems.filter { ranker.matches($0, query: query) })
        }

        let applications = query.isEmpty
            ? catalog.applications
            : catalog.search(
                query,
                aliases: { [aliases] app in
                    aliases.aliases(for: app.url, bundleIdentifier: app.bundleIdentifier)
                },
                limit: 50
            )
        applicationResults = applications.map { application in
            CommandItem(
                title: application.name,
                subtitle: "",
                icon: application.icon,
                kind: .application(application.url),
                isRunning: isRunning(application),
                aliases: aliases.aliases(
                    for: application.url,
                    bundleIdentifier: application.bundleIdentifier
                )
            )
        }

        var results: [CommandItem] = []
        if query.isEmpty {
            let suggestions = ranker.rank(applicationResults, query: query).prefix(5)
            if !suggestions.isEmpty {
                results.append(.section("Suggestions"))
                results.append(contentsOf: suggestions)
            }
            if !commandResults.isEmpty {
                results.append(.section("Commands"))
                results.append(contentsOf: ranker.rank(commandResults, query: query))
            }
        } else {
            let ranked = ranker.rank(applicationResults + commandResults, query: query)
            if !ranked.isEmpty {
                results.append(.section("Results"))
                results.append(contentsOf: ranked)
            }
        }

        if results.isEmpty {
            results = [CommandItem(
                title: "Try “define catalyst” or “20 percent of 85”",
                subtitle: "No Results",
                icon: NSImage(systemSymbolName: "lightbulb", accessibilityDescription: nil),
                kind: .hint
            )]
        }
        return Array(results.prefix(20))
    }

    private func dynamicCommands(for query: String) -> [CommandItem] {
        var commands: [CommandItem] = []
        if query.lowercased().hasPrefix("define ") {
            let term = String(query.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            commands.append(CommandItem(
                title: "Define “\(term)”",
                subtitle: "Dictionary",
                icon: NSImage(systemSymbolName: "character.book.closed", accessibilityDescription: nil),
                kind: .dictionary(term)
            ))
        }
        if let value = try? calculator.evaluate(query), !query.isEmpty {
            let formatted = calculator.format(value)
            commands.append(CommandItem(
                title: formatted,
                subtitle: "Calculation",
                icon: NSImage(systemSymbolName: "equal.circle", accessibilityDescription: nil),
                kind: .calculation(formatted)
            ))
        }
        return commands
    }

    private func isRunning(_ application: InstalledApplication) -> Bool {
        runningApplications.isRunning(
            bundleIdentifier: application.bundleIdentifier,
            url: application.url
        )
    }
}
