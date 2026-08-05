import AppKit

@MainActor
final class CustomCommandsWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let table = NSTableView()
    private let titleField = NSTextField()
    private let categoryField = NSTextField()
    private let symbolField = NSTextField()
    private let aliasesField = NSTextField()
    private let actionPopup = NSPopUpButton()
    private let targetField = NSTextField()
    private let argumentsField = NSTextField()
    private let directoryField = NSTextField()
    private let shellSwitch = NSSwitch()
    private let editor = NSView()
    private var sidebarWidth: NSLayoutConstraint!
    private var commands: [CatalystCommand] = []
    private var editingIndex: Int?
    private var selectedIndex: Int? { table.selectedRow >= 0 ? table.selectedRow : nil }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 500),
            styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false
        )
        window.title = "Custom Commands"
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
        build()
        reload()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        reload()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func show(editingCommandID id: String) {
        reload()
        guard let index = commands.firstIndex(where: { $0.id == id }) else {
            show()
            return
        }
        table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        editingIndex = index
        loadSelection()
        showEditor()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(titleField)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { commands.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let label = NSTextField(labelWithString: commands[row].title)
        label.font = .systemFont(ofSize: 14)
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {}

    private func build() {
        guard let content = window?.contentView else { return }
        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(split)

        let sidebar = NSView()
        split.addArrangedSubview(sidebar)
        split.addArrangedSubview(editor)
        sidebarWidth = sidebar.widthAnchor.constraint(equalToConstant: 220)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("commands"))
        column.title = "Commands"
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 34
        table.dataSource = self
        table.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(scroll)

        let add = NSButton(title: "Add", target: self, action: #selector(addCommand))
        let edit = NSButton(title: "Edit", target: self, action: #selector(editCommand))
        let remove = NSButton(title: "Remove", target: self, action: #selector(removeCommand))
        for button in [add, edit, remove] { button.translatesAutoresizingMaskIntoConstraints = false; sidebar.addSubview(button) }

        let form = NSStackView()
        form.orientation = .vertical
        form.alignment = .width
        form.spacing = 10
        form.translatesAutoresizingMaskIntoConstraints = false
        editor.addSubview(form)

        configure(titleField, placeholder: "Deploy Website")
        configure(categoryField, placeholder: "Development")
        configure(symbolField, placeholder: "terminal.fill")
        configure(aliasesField, placeholder: "deploy, publish")
        actionPopup.addItems(withTitles: ["Run Executable", "Open URL"])
        configure(targetField, placeholder: "/usr/bin/env or https://example.com")
        configure(argumentsField, placeholder: "npm run deploy")
        configure(directoryField, placeholder: "~/Developer/my-site")
        form.addArrangedSubview(row("Name", titleField))
        form.addArrangedSubview(row("Category", categoryField))
        form.addArrangedSubview(row("SF Symbol", symbolField))
        form.addArrangedSubview(row("Aliases", aliasesField))
        form.addArrangedSubview(row("Action", actionPopup))
        form.addArrangedSubview(row("Executable / URL", targetField))
        form.addArrangedSubview(row("Arguments", argumentsField))
        form.addArrangedSubview(row("Working Directory", directoryField))
        form.addArrangedSubview(row("Run through zsh", shellSwitch))

        let save = NSButton(title: "Save", target: self, action: #selector(saveCommand))
        save.keyEquivalent = "\r"
        let test = NSButton(title: "Test", target: self, action: #selector(testCommand))
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelEditing))
        let buttons = NSStackView(views: [test, cancel, save])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8
        form.addArrangedSubview(buttons)

        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.topAnchor.constraint(equalTo: content.topAnchor),
            split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -8),
            scroll.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: add.topAnchor, constant: -8),
            add.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 8),
            add.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -8),
            edit.leadingAnchor.constraint(equalTo: add.trailingAnchor, constant: 6),
            edit.centerYAnchor.constraint(equalTo: add.centerYAnchor),
            remove.leadingAnchor.constraint(equalTo: edit.trailingAnchor, constant: 6),
            remove.centerYAnchor.constraint(equalTo: add.centerYAnchor),
            form.leadingAnchor.constraint(equalTo: editor.leadingAnchor, constant: 24),
            form.trailingAnchor.constraint(equalTo: editor.trailingAnchor, constant: -24),
            form.topAnchor.constraint(equalTo: editor.topAnchor, constant: 24)
        ])
        hideEditor()
    }

    private func configure(_ field: NSTextField, placeholder: String) {
        field.placeholderString = placeholder
    }

    private func row(_ title: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.widthAnchor.constraint(equalToConstant: 120).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 250).isActive = true
        return row
    }

    private func reload() {
        commands = CustomCommandStore.shared.commands
        table.reloadData()
        if !commands.isEmpty { table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false) }
        else { clearEditor() }
        hideEditor()
    }

    private func loadSelection() {
        guard let selectedIndex, commands.indices.contains(selectedIndex) else { return }
        let command = commands[selectedIndex]
        titleField.stringValue = command.title
        categoryField.stringValue = command.category
        symbolField.stringValue = command.symbolName
        aliasesField.stringValue = command.aliases.joined(separator: ", ")
        switch command.action {
        case .runProcess(let process):
            actionPopup.selectItem(at: 0)
            targetField.stringValue = process.executable
            argumentsField.stringValue = process.arguments.joined(separator: " ")
            directoryField.stringValue = process.workingDirectory ?? ""
            shellSwitch.state = process.runsThroughShell ? .on : .off
        case .openURL(let url):
            actionPopup.selectItem(at: 1)
            targetField.stringValue = url
            argumentsField.stringValue = ""
            directoryField.stringValue = ""
            shellSwitch.state = .off
        case .native: break
        }
    }

    private func clearEditor() {
        for field in [titleField, categoryField, symbolField, aliasesField, targetField, argumentsField, directoryField] {
            field.stringValue = ""
        }
    }

    @objc private func addCommand() {
        editingIndex = nil
        clearEditor()
        categoryField.stringValue = "Custom"
        symbolField.stringValue = "terminal.fill"
        targetField.stringValue = "/usr/bin/env"
        actionPopup.selectItem(at: 0)
        showEditor()
        window?.makeFirstResponder(titleField)
    }

    @objc private func editCommand() {
        guard let selectedIndex, commands.indices.contains(selectedIndex) else { return }
        editingIndex = selectedIndex
        loadSelection()
        showEditor()
        window?.makeFirstResponder(titleField)
    }

    @objc private func removeCommand() {
        guard let selectedIndex, commands.indices.contains(selectedIndex) else { return }
        commands.remove(at: selectedIndex)
        CustomCommandStore.shared.commands = commands
        reload()
    }

    @objc private func saveCommand() {
        guard !titleField.stringValue.isEmpty else { return }
        let id = editingIndex.flatMap { commands.indices.contains($0) ? commands[$0].id : nil }
            ?? UUID().uuidString
        let command = commandFromEditor(id: id)
        if let editingIndex, commands.indices.contains(editingIndex) {
            commands[editingIndex] = command
        } else {
            commands.append(command)
        }
        CustomCommandStore.shared.commands = commands
        table.reloadData()
        if let index = commands.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        }
        hideEditor()
    }

    @objc private func testCommand() {
        guard !titleField.stringValue.isEmpty else { return }
        let command = commandFromEditor(id: editingIndex.flatMap {
            commands.indices.contains($0) ? commands[$0].id : nil
        } ?? UUID().uuidString)
        _ = CommandExecutor().execute(.defined(command), previousApplication: nil)
    }

    @objc private func cancelEditing() { hideEditor() }

    private func commandFromEditor(id: String) -> CatalystCommand {
        let action: CatalystCommandAction = actionPopup.indexOfSelectedItem == 1
            ? .openURL(targetField.stringValue)
            : .runProcess(ProcessConfiguration(
                executable: targetField.stringValue,
                arguments: argumentsField.stringValue.split(separator: " ").map(String.init),
                workingDirectory: directoryField.stringValue.isEmpty ? nil : directoryField.stringValue,
                runsThroughShell: shellSwitch.state == .on
            ))
        return CatalystCommand(
            id: id,
            title: titleField.stringValue,
            category: categoryField.stringValue.isEmpty ? "Custom" : categoryField.stringValue,
            symbolName: symbolField.stringValue.isEmpty ? "terminal.fill" : symbolField.stringValue,
            aliases: aliasesField.stringValue.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            },
            action: action
        )
    }

    private func showEditor() {
        editor.isHidden = false
        sidebarWidth.isActive = true
    }

    private func hideEditor() {
        editingIndex = nil
        sidebarWidth?.isActive = false
        editor.isHidden = true
    }
}
