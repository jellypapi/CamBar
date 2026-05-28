import AppKit

final class CameraManagerWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let settings = CameraSettings.shared
    private let tableView = NSTableView()
    private let nameField = NSTextField()
    private let urlField = NSTextField()
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let saveButton = NSButton()
    private let doneButton = NSButton()
    private var streams: [CameraStream]

    init() {
        streams = settings.cameraStreams

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Cameras"
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.center()

        super.init(window: window)
        buildUI(in: window)
        selectCamera(settings.selectedCameraIndex)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func reloadFromSettings() {
        streams = settings.cameraStreams
        tableView.reloadData()
        selectCamera(settings.selectedCameraIndex)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        streams.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("cameraCell")
        let cell = tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView ?? NSTableCellView()
        cell.identifier = id

        let label: NSTextField
        if let existing = cell.textField {
            label = existing
        } else {
            label = NSTextField(labelWithString: "")
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            cell.addSubview(label)
            cell.textField = label
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        label.stringValue = streams[row].name
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        loadSelectedCameraIntoFields()
    }

    private func buildUI(in window: NSWindow) {
        let contentView = NSView()
        window.contentView = contentView

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        contentView.addSubview(scrollView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = false
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.title = "Camera"
        column.width = 178
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        let titleLabel = NSTextField(labelWithString: "Camera")
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        contentView.addSubview(titleLabel)

        let nameLabel = NSTextField(labelWithString: "Name")
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.textColor = .secondaryLabelColor
        contentView.addSubview(nameLabel)

        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.placeholderString = "Nursery"
        contentView.addSubview(nameField)

        let urlLabel = NSTextField(labelWithString: "RTSP URL")
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.textColor = .secondaryLabelColor
        contentView.addSubview(urlLabel)

        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.placeholderString = "rtsp://user:password@192.168.0.45:554/stream1"
        urlField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        contentView.addSubview(urlField)

        addButton.title = ""
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")
        addButton.toolTip = "Add camera"
        addButton.target = self
        addButton.action = #selector(addCamera)
        styleIconButton(addButton)
        contentView.addSubview(addButton)

        removeButton.title = ""
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove")
        removeButton.toolTip = "Remove selected camera"
        removeButton.target = self
        removeButton.action = #selector(removeCamera)
        styleIconButton(removeButton)
        contentView.addSubview(removeButton)

        saveButton.title = "Save"
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveCamera)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(saveButton)

        doneButton.title = "Done"
        doneButton.bezelStyle = .rounded
        doneButton.target = self
        doneButton.action = #selector(closeWindow)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(doneButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -10),
            scrollView.widthAnchor.constraint(equalToConstant: 190),

            addButton.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 34),
            addButton.heightAnchor.constraint(equalToConstant: 30),

            removeButton.leadingAnchor.constraint(equalTo: addButton.trailingAnchor, constant: 8),
            removeButton.centerYAnchor.constraint(equalTo: addButton.centerYAnchor),
            removeButton.widthAnchor.constraint(equalTo: addButton.widthAnchor),
            removeButton.heightAnchor.constraint(equalTo: addButton.heightAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: 24),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            nameLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            nameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),
            nameLabel.widthAnchor.constraint(equalToConstant: 72),

            nameField.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 12),
            nameField.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            nameField.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),

            urlLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            urlLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 22),
            urlLabel.widthAnchor.constraint(equalTo: nameLabel.widthAnchor),

            urlField.leadingAnchor.constraint(equalTo: nameField.leadingAnchor),
            urlField.trailingAnchor.constraint(equalTo: nameField.trailingAnchor),
            urlField.centerYAnchor.constraint(equalTo: urlLabel.centerYAnchor),

            doneButton.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            doneButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            doneButton.widthAnchor.constraint(equalToConstant: 82),

            saveButton.trailingAnchor.constraint(equalTo: doneButton.leadingAnchor, constant: -10),
            saveButton.centerYAnchor.constraint(equalTo: doneButton.centerYAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 82)
        ])
    }

    private func selectCamera(_ index: Int) {
        guard !streams.isEmpty else {
            return
        }

        let selected = min(max(index, 0), streams.count - 1)
        tableView.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
        tableView.scrollRowToVisible(selected)
        loadSelectedCameraIntoFields()
    }

    private func loadSelectedCameraIntoFields() {
        let row = tableView.selectedRow
        guard streams.indices.contains(row) else {
            nameField.stringValue = ""
            urlField.stringValue = ""
            return
        }

        nameField.stringValue = streams[row].name
        urlField.stringValue = streams[row].url
        removeButton.isEnabled = streams.count > 1
    }

    @objc private func addCamera() {
        saveCamera()
        let nextNumber = streams.count + 1
        let url = defaultURL(for: nextNumber)
        streams.append(CameraStream(name: "CAM\(nextNumber)", url: url))
        tableView.reloadData()
        persist(selectedIndex: streams.count - 1)
        selectCamera(streams.count - 1)
        window?.makeFirstResponder(nameField)
        nameField.currentEditor()?.selectAll(nil)
    }

    @objc private func removeCamera() {
        let row = tableView.selectedRow
        guard streams.count > 1, streams.indices.contains(row) else {
            return
        }

        streams.remove(at: row)
        tableView.reloadData()
        persist(selectedIndex: min(row, streams.count - 1))
        selectCamera(settings.selectedCameraIndex)
    }

    @objc private func saveCamera() {
        let row = tableView.selectedRow
        guard streams.indices.contains(row) else {
            return
        }

        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        streams[row] = CameraStream(name: name.isEmpty ? "CAM\(row + 1)" : name, url: url)
        tableView.reloadData()
        persist(selectedIndex: row)
        selectCamera(row)
    }

    @objc private func closeWindow() {
        saveCamera()
        close()
    }

    private func persist(selectedIndex: Int) {
        settings.cameraStreams = streams
        settings.selectedCameraIndex = selectedIndex
    }

    private func defaultURL(for cameraNumber: Int) -> String {
        let selectedURL = settings.streamURL
        if !selectedURL.isEmpty,
           let range = selectedURL.range(of: #"stream\d+$"#, options: .regularExpression) {
            return selectedURL.replacingCharacters(in: range, with: "stream\(cameraNumber)")
        }

        return "rtsp://user:password@192.168.0.45:554/stream\(cameraNumber)"
    }

    private func styleIconButton(_ button: NSButton) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
    }
}
