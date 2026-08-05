import AppKit

@MainActor
final class LauncherResultsView: FadingScrollView, NSTableViewDataSource, NSTableViewDelegate {
    var onSelectionChange: ((CommandItem?) -> Void)?
    var onActivate: ((CommandItem) -> Void)?

    private let tableView = NSTableView()
    private var items: [CommandItem] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    var selectedItem: CommandItem? {
        let row = tableView.selectedRow
        return items.indices.contains(row) && items[row].isSelectable ? items[row] : nil
    }

    func display(_ items: [CommandItem]) {
        self.items = items
        tableView.reloadData()
        selectFirst()
    }

    func selectFirst() {
        guard let row = items.firstIndex(where: \.isSelectable) else {
            tableView.deselectAll(nil)
            onSelectionChange?(nil)
            return
        }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        onSelectionChange?(items[row])
    }

    func moveSelection(direction: Int) {
        guard !items.isEmpty else { return }
        var row = tableView.selectedRow
        if row < 0 { row = direction > 0 ? -1 : items.count }
        repeat {
            row += direction
        } while items.indices.contains(row) && !items[row].isSelectable
        guard items.indices.contains(row) else { return }
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    func scrollToLastItem() {
        guard !items.isEmpty else { return }
        tableView.scrollRowToVisible(items.count - 1)
    }

    func redrawSelection() {
        tableView.reloadData()
        tableView.needsDisplay = true
    }

    private func configure() {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        column.width = 714
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 42
        tableView.intercellSpacing = .zero
        tableView.backgroundColor = .clear
        tableView.style = .plain
        tableView.selectionHighlightStyle = .regular
        tableView.dataSource = self
        tableView.delegate = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelection)

        documentView = tableView
        verticalScroller = ThumbOnlyScroller()
        hasVerticalScroller = true
        scrollerStyle = .overlay
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 18, right: 0)
        drawsBackground = false
        contentView.drawsBackground = false
    }

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        items[row].isSelectable ? 48 : 26
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        items[row].isSelectable
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        LauncherRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelectionChange?(selectedItem)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = items[row]
        if !item.isSelectable {
            let cell = (tableView.makeView(
                withIdentifier: LauncherSectionCell.reuseIdentifier,
                owner: self
            ) as? LauncherSectionCell) ?? LauncherSectionCell()
            cell.configure(title: item.title)
            return cell
        }
        let cell = (tableView.makeView(
            withIdentifier: LauncherResultCell.reuseIdentifier,
            owner: self
        ) as? LauncherResultCell) ?? LauncherResultCell()
        cell.configure(with: item)
        return cell
    }

    @objc private func activateSelection() {
        guard let selectedItem else { return }
        onActivate?(selectedItem)
    }
}
