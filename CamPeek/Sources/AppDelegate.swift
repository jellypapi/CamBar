import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var previewController: CameraPopoverViewController!
    private var previewPanel: NSPanel!
    private let previewPanelSize = NSSize(width: 460, height: 410)
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private var statusHoverController: StatusItemHoverController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        FileLogger.write("applicationDidFinishLaunching")
        NSApp.mainMenu = makeEditMenu()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(streamStatusDidChange(_:)),
            name: .streamStatusDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(largeCameraDidOpen),
            name: .largeCameraDidOpen,
            object: nil
        )
        previewController = CameraPopoverViewController()
        previewPanel = makePreviewPanel()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = ""
        statusItem.button?.image = makeBabyStatusIcon(status: .idle)
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePreviewPanel)
        statusItem.button?.toolTip = "CamPeek"
        if let button = statusItem.button {
            statusHoverController = StatusItemHoverController(button: button)
        }
        FileLogger.write("status item configured: button=\(statusItem.button != nil)")
    }

    @objc private func largeCameraDidOpen() {
        if previewPanel.isVisible {
            previewPanel.orderOut(nil)
            removeClickMonitors()
            statusHoverController?.setActive(false)
        }
    }

    private func makePreviewPanel() -> NSPanel {
        let panel = EditablePreviewPanel(
            contentRect: NSRect(origin: .zero, size: previewPanelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = previewController
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.delegate = self
        return panel
    }

    @objc private func streamStatusDidChange(_ notification: Notification) {
        guard let rawValue = notification.userInfo?["status"] as? String,
              let status = StreamStatus(rawValue: rawValue)
        else {
            return
        }

        statusItem.button?.image = makeBabyStatusIcon(status: status)
        switch status {
        case .idle:
            statusItem.button?.toolTip = "CamPeek"
        case .connecting:
            statusItem.button?.toolTip = "CamPeek - connecting"
        case .playing:
            statusItem.button?.toolTip = "CamPeek - live"
        }
    }

    private func makeBabyStatusIcon(status: StreamStatus) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22))
        image.lockFocus()

        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: 22, height: 22).fill()

        NSColor.white.setStroke()
        let face = NSBezierPath(ovalIn: NSRect(x: 4, y: 3, width: 14, height: 14))
        face.lineWidth = 1.7
        face.stroke()

        let curl = NSBezierPath()
        curl.move(to: NSPoint(x: 10, y: 18))
        curl.curve(
            to: NSPoint(x: 13.5, y: 18.3),
            controlPoint1: NSPoint(x: 10.8, y: 20.4),
            controlPoint2: NSPoint(x: 14.8, y: 20.0)
        )
        curl.lineWidth = 1.5
        curl.stroke()

        let leftEye = NSBezierPath(ovalIn: NSRect(x: 8, y: 10, width: 1.7, height: 1.7))
        let rightEye = NSBezierPath(ovalIn: NSRect(x: 12.4, y: 10, width: 1.7, height: 1.7))
        NSColor.white.setFill()
        leftEye.fill()
        rightEye.fill()

        let mouth = NSBezierPath()
        mouth.move(to: NSPoint(x: 9, y: 7.8))
        mouth.curve(
            to: NSPoint(x: 13, y: 7.8),
            controlPoint1: NSPoint(x: 10, y: 6.7),
            controlPoint2: NSPoint(x: 12, y: 6.7)
        )
        mouth.lineWidth = 1.2
        mouth.stroke()

        statusColor(for: status).setFill()
        NSBezierPath(ovalIn: NSRect(x: 15.2, y: 2.8, width: 5.4, height: 5.4)).fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func statusColor(for status: StreamStatus) -> NSColor {
        switch status {
        case .idle:
            return .secondaryLabelColor
        case .connecting:
            return .systemYellow
        case .playing:
            return .systemGreen
        }
    }

    private func makeEditMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu

        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        mainMenu.addItem(editItem)
        return mainMenu
    }

    @objc private func togglePreviewPanel() {
        guard let button = statusItem.button else {
            return
        }

        if previewPanel.isVisible {
            closePreviewPanel()
            return
        }

        positionPreviewPanel(relativeTo: button)
        previewPanel.orderFrontRegardless()
        statusHoverController?.setActive(true)
        installClickMonitors()
        previewController.cancelScheduledStop()
        previewController.startIfPossible()
    }

    private func positionPreviewPanel(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else {
            return
        }

        let buttonFrameInWindow = button.convert(button.bounds, to: nil)
        let buttonFrameOnScreen = buttonWindow.convertToScreen(buttonFrameInWindow)
        let screenFrame = buttonWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var originX = buttonFrameOnScreen.midX - previewPanelSize.width / 2
        originX = max(screenFrame.minX + 8, min(originX, screenFrame.maxX - previewPanelSize.width - 8))

        let originY = buttonFrameOnScreen.minY - previewPanelSize.height
        previewPanel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func closePreviewPanel() {
        previewPanel.orderOut(nil)
        removeClickMonitors()
        statusHoverController?.setActive(false)
        previewController.scheduleStopPreview()
    }

    private func installClickMonitors() {
        removeClickMonitors()

        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.closePreviewPanelIfClickIsOutside(event: event)
            return event
        }

        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.closePreviewPanelIfGlobalClickIsOutside()
            }
        }
    }

    private func removeClickMonitors() {
        if let localClickMonitor {
            NSEvent.removeMonitor(localClickMonitor)
            self.localClickMonitor = nil
        }

        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }
    }

    private func closePreviewPanelIfClickIsOutside(event: NSEvent) {
        guard previewPanel.isVisible else {
            return
        }

        if event.window === previewPanel {
            return
        }

        closePreviewPanel()
    }

    private func closePreviewPanelIfGlobalClickIsOutside() {
        guard previewPanel.isVisible else {
            return
        }

        if previewPanelContainsMouseLocation() {
            return
        }

        closePreviewPanel()
    }

    private func previewPanelContainsMouseLocation() -> Bool {
        mouseLocationCandidates().contains { previewPanel.frame.contains($0) }
    }

    private func mouseLocationCandidates() -> [NSPoint] {
        let point = NSEvent.mouseLocation
        var points = [point]

        for screen in NSScreen.screens {
            let flippedY = screen.frame.maxY - point.y + screen.frame.minY
            points.append(NSPoint(x: point.x, y: flippedY))
        }

        return points
    }

    func windowDidResignKey(_ notification: Notification) {
        guard notification.object as? NSWindow === previewPanel else {
            return
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard notification.object as? NSWindow === previewPanel else {
            return
        }

        previewController.scheduleStopPreview()
    }
}

enum FileLogger {
    static func write(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = URL(fileURLWithPath: "/tmp/CamPeek.log")

        guard let data = line.data(using: .utf8) else {
            return
        }

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}

final class EditablePreviewPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }
}

final class StatusItemHoverController: NSObject {
    private weak var button: NSStatusBarButton?
    private var trackingArea: NSTrackingArea?
    private var isActive = false
    private var isHovering = false

    init(button: NSStatusBarButton) {
        self.button = button
        super.init()
        installTrackingArea()
    }

    func setActive(_ isActive: Bool) {
        self.isActive = isActive
        refreshHighlight()
    }

    private func installTrackingArea() {
        guard let button else {
            return
        }

        if let trackingArea {
            button.removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: button.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        button.addTrackingArea(area)
        trackingArea = area
    }

    func mouseEntered(with event: NSEvent) {
        isHovering = true
        refreshHighlight()
    }

    func mouseExited(with event: NSEvent) {
        isHovering = false
        refreshHighlight()
    }

    private func refreshHighlight() {
        button?.isHighlighted = isActive || isHovering
    }
}
