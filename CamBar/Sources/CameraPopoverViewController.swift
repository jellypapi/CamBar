import AppKit
import VLCKit

final class CameraPopoverViewController: NSViewController, NSTextFieldDelegate {
    private let settings = CameraSettings.shared
    private var player = VLCMediaPlayer()
    private var previewPlayersByURL: [String: VLCMediaPlayer] = [:]
    private let videoView = VLCVideoView()
    private let containerView = NSView()
    private let backgroundView = NSVisualEffectView()
    private let cameraTabs = CameraTabBarView()
    private let addCameraButton = FirstMouseButton()
    private let loadingOverlay = NSVisualEffectView()
    private let loadingSpinner = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "Connecting...")
    private let videoOverlayView = VideoHoverOverlayView()
    private let videoClickButton = FirstMouseButton()
    private let previousCameraButton = FirstMouseButton()
    private let nextCameraButton = FirstMouseButton()
    private let urlField = FirstMouseTextField()
    private let statusLabel = NSTextField(labelWithString: "Enter your RTSP URL.")
    private let muteButton = FirstMouseButton()
    private let playButton = FirstMouseButton()
    private let reconnectButton = FirstMouseButton()
    private let volumeSlider = NSSlider(value: Double(CameraSettings.shared.volume), minValue: 0, maxValue: 100, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "\(CameraSettings.shared.volume)")
    private let quitButton = FirstMouseButton()
    private let buttonRow = NSView()
    private var cameraManagerWindowController: CameraManagerWindowController?
    private var scheduledStop: DispatchWorkItem?
    private var overlayClickMonitor: Any?
    private var overlayGlobalClickMonitor: Any?
    private var currentCameraIndex = CameraSettings.shared.selectedCameraIndex
    private var lastTabActionIndex: Int?
    private var lastTabActionAt = Date.distantPast

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 410))
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 18
        containerView.layer?.masksToBounds = true
        containerView.layer?.borderWidth = 1
        containerView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        view.addSubview(containerView)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = .underWindowBackground
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.03).cgColor
        containerView.addSubview(backgroundView)

        cameraTabs.translatesAutoresizingMaskIntoConstraints = false
        cameraTabs.onSelect = { [weak self] index in
            self?.switchToCamera(index)
        }
        cameraTabs.onClose = { [weak self] index in
            self?.deleteCameraTab(at: index)
        }
        containerView.addSubview(cameraTabs)

        addCameraButton.translatesAutoresizingMaskIntoConstraints = false
        addCameraButton.bezelStyle = .rounded
        addCameraButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add camera")
        addCameraButton.title = ""
        addCameraButton.target = self
        addCameraButton.action = #selector(addCameraTab)
        addCameraButton.toolTip = "Add camera"
        styleIconButton(addCameraButton)
        containerView.addSubview(addCameraButton)

        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.wantsLayer = true
        videoView.layer?.backgroundColor = NSColor.black.cgColor
        videoView.layer?.cornerRadius = 10
        videoView.layer?.borderWidth = 1
        videoView.layer?.borderColor = NSColor.white.withAlphaComponent(0.34).cgColor
        videoView.layer?.masksToBounds = true
        videoView.setContentHuggingPriority(.defaultLow, for: .vertical)
        videoView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        containerView.addSubview(videoView)

        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.material = .underWindowBackground
        loadingOverlay.blendingMode = .withinWindow
        loadingOverlay.state = .active
        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.cornerRadius = 8
        loadingOverlay.isHidden = true
        containerView.addSubview(loadingOverlay)

        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .small
        loadingOverlay.addSubview(loadingSpinner)

        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.textColor = .labelColor
        loadingLabel.font = .systemFont(ofSize: 12, weight: .medium)
        loadingOverlay.addSubview(loadingLabel)

        videoOverlayView.translatesAutoresizingMaskIntoConstraints = false
        videoOverlayView.wantsLayer = true
        videoOverlayView.layer?.backgroundColor = NSColor.clear.cgColor
        videoOverlayView.onHoverChanged = { [weak self] isHovering in
            self?.setVideoOverlayControlsVisible(isHovering)
        }
        containerView.addSubview(videoOverlayView)

        videoClickButton.translatesAutoresizingMaskIntoConstraints = false
        videoClickButton.title = ""
        videoClickButton.isBordered = false
        videoClickButton.bezelStyle = .shadowlessSquare
        videoClickButton.isEnabled = false
        videoClickButton.wantsLayer = true
        videoClickButton.layer?.backgroundColor = NSColor.clear.cgColor
        containerView.addSubview(videoClickButton)

        previousCameraButton.translatesAutoresizingMaskIntoConstraints = false
        previousCameraButton.bezelStyle = .rounded
        previousCameraButton.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Previous camera")
        previousCameraButton.title = ""
        previousCameraButton.target = self
        previousCameraButton.action = #selector(showPreviousCamera)
        previousCameraButton.toolTip = "Previous camera"
        styleOverlayButton(previousCameraButton)
        videoOverlayView.addSubview(previousCameraButton)

        nextCameraButton.translatesAutoresizingMaskIntoConstraints = false
        nextCameraButton.bezelStyle = .rounded
        nextCameraButton.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Next camera")
        nextCameraButton.title = ""
        nextCameraButton.target = self
        nextCameraButton.action = #selector(showNextCamera)
        nextCameraButton.toolTip = "Next camera"
        styleOverlayButton(nextCameraButton)
        videoOverlayView.addSubview(nextCameraButton)

        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.placeholderString = "rtsp://user:pass@192.168.0.45:554/stream1"
        urlField.stringValue = settings.streamURL
        urlField.lineBreakMode = .byTruncatingMiddle
        urlField.bezelStyle = .roundedBezel
        urlField.drawsBackground = true
        urlField.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.22)
        urlField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        urlField.isEditable = true
        urlField.isSelectable = true
        urlField.refusesFirstResponder = false
        urlField.focusRingType = .default
        urlField.target = self
        urlField.action = #selector(saveAndPlay)
        urlField.delegate = self
        containerView.addSubview(urlField)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(statusLabel)

        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(buttonRow)

        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.bezelStyle = .rounded
        playButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")
        playButton.title = ""
        styleIconButton(playButton)
        playButton.target = self
        playButton.action = #selector(saveAndPlay)
        playButton.toolTip = "Play preview"
        containerView.addSubview(playButton)

        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.bezelStyle = .rounded
        muteButton.target = self
        muteButton.action = #selector(toggleMute)
        muteButton.toolTip = "Mute"
        styleIconButton(muteButton)
        containerView.addSubview(muteButton)

        reconnectButton.translatesAutoresizingMaskIntoConstraints = false
        reconnectButton.bezelStyle = .rounded
        reconnectButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reconnect")
        reconnectButton.title = ""
        reconnectButton.target = self
        reconnectButton.action = #selector(reconnectCurrentCamera)
        reconnectButton.toolTip = "Reconnect"
        styleIconButton(reconnectButton)
        containerView.addSubview(reconnectButton)

        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.doubleValue = Double(settings.volume)
        volumeSlider.target = self
        volumeSlider.action = #selector(changeVolume)
        volumeSlider.toolTip = "Volume"
        containerView.addSubview(volumeSlider)

        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeLabel.alignment = .right
        volumeLabel.textColor = .secondaryLabelColor
        volumeLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        containerView.addSubview(volumeLabel)

        quitButton.title = ""
        quitButton.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit")
        quitButton.target = NSApp
        quitButton.action = #selector(NSApplication.terminate(_:))
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        quitButton.bezelStyle = .rounded
        quitButton.toolTip = "Quit"
        styleIconButton(quitButton)
        containerView.addSubview(quitButton)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            cameraTabs.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            cameraTabs.trailingAnchor.constraint(equalTo: addCameraButton.leadingAnchor, constant: -8),
            cameraTabs.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            cameraTabs.heightAnchor.constraint(equalToConstant: 24),

            addCameraButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            addCameraButton.centerYAnchor.constraint(equalTo: cameraTabs.centerYAnchor),
            addCameraButton.widthAnchor.constraint(equalToConstant: 28),
            addCameraButton.heightAnchor.constraint(equalToConstant: 24),

            videoView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            videoView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            videoView.topAnchor.constraint(equalTo: cameraTabs.bottomAnchor, constant: 10),
            videoView.heightAnchor.constraint(equalTo: videoView.widthAnchor, multiplier: 9.0 / 16.0),

            loadingOverlay.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            loadingOverlay.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            loadingOverlay.widthAnchor.constraint(equalToConstant: 150),
            loadingOverlay.heightAnchor.constraint(equalToConstant: 54),

            loadingSpinner.leadingAnchor.constraint(equalTo: loadingOverlay.leadingAnchor, constant: 14),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
            loadingSpinner.widthAnchor.constraint(equalToConstant: 16),
            loadingSpinner.heightAnchor.constraint(equalToConstant: 16),

            loadingLabel.leadingAnchor.constraint(equalTo: loadingSpinner.trailingAnchor, constant: 10),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingOverlay.trailingAnchor, constant: -12),
            loadingLabel.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),

            urlField.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            urlField.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            urlField.topAnchor.constraint(equalTo: videoView.bottomAnchor, constant: 10),

            statusLabel.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            statusLabel.topAnchor.constraint(equalTo: urlField.bottomAnchor, constant: 8),

            videoOverlayView.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            videoOverlayView.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            videoOverlayView.topAnchor.constraint(equalTo: videoView.topAnchor),
            videoOverlayView.bottomAnchor.constraint(equalTo: videoView.bottomAnchor),

            videoClickButton.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            videoClickButton.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            videoClickButton.topAnchor.constraint(equalTo: videoView.topAnchor),
            videoClickButton.bottomAnchor.constraint(equalTo: videoView.bottomAnchor),

            previousCameraButton.leadingAnchor.constraint(equalTo: videoOverlayView.leadingAnchor, constant: 10),
            previousCameraButton.centerYAnchor.constraint(equalTo: videoOverlayView.centerYAnchor),
            previousCameraButton.widthAnchor.constraint(equalToConstant: 38),
            previousCameraButton.heightAnchor.constraint(equalToConstant: 38),

            nextCameraButton.trailingAnchor.constraint(equalTo: videoOverlayView.trailingAnchor, constant: -10),
            nextCameraButton.centerYAnchor.constraint(equalTo: videoOverlayView.centerYAnchor),
            nextCameraButton.widthAnchor.constraint(equalToConstant: 38),
            nextCameraButton.heightAnchor.constraint(equalToConstant: 38),

            buttonRow.leadingAnchor.constraint(equalTo: videoView.leadingAnchor),
            buttonRow.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            buttonRow.trailingAnchor.constraint(equalTo: quitButton.leadingAnchor, constant: -10),
            buttonRow.heightAnchor.constraint(equalToConstant: 30),

            playButton.leadingAnchor.constraint(equalTo: buttonRow.leadingAnchor),
            playButton.topAnchor.constraint(equalTo: buttonRow.topAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 42),
            playButton.heightAnchor.constraint(equalToConstant: 30),

            muteButton.leadingAnchor.constraint(equalTo: playButton.trailingAnchor, constant: 8),
            muteButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            muteButton.widthAnchor.constraint(equalToConstant: 42),
            muteButton.heightAnchor.constraint(equalTo: playButton.heightAnchor),

            reconnectButton.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 8),
            reconnectButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            reconnectButton.widthAnchor.constraint(equalToConstant: 42),
            reconnectButton.heightAnchor.constraint(equalTo: playButton.heightAnchor),

            volumeSlider.leadingAnchor.constraint(equalTo: reconnectButton.trailingAnchor, constant: 12),
            volumeSlider.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            volumeSlider.trailingAnchor.constraint(equalTo: volumeLabel.leadingAnchor, constant: -8),

            volumeLabel.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            volumeLabel.widthAnchor.constraint(equalToConstant: 28),
            volumeLabel.trailingAnchor.constraint(equalTo: buttonRow.trailingAnchor),

            quitButton.trailingAnchor.constraint(equalTo: videoView.trailingAnchor),
            quitButton.centerYAnchor.constraint(equalTo: playButton.centerYAnchor),
            quitButton.heightAnchor.constraint(equalTo: playButton.heightAnchor),
            quitButton.widthAnchor.constraint(equalToConstant: 42)
        ])

        configureCameraTabs()
        player = playerForURL(currentCamera.url)
        player.drawable = videoView
        ensurePreviewPlayersStarted()
        setVideoOverlayControlsVisible(false)
        updateMuteButton()
        updateVolumeControls()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(cameraStreamsDidChange),
            name: .cameraStreamsDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        if let overlayClickMonitor {
            NSEvent.removeMonitor(overlayClickMonitor)
        }
        if let overlayGlobalClickMonitor {
            NSEvent.removeMonitor(overlayGlobalClickMonitor)
        }
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installOverlayClickMonitorIfNeeded()
    }

    func startIfPossible() {
        installOverlayClickMonitorIfNeeded()
        configureCameraTabs()
        ensurePreviewPlayersStarted()
        guard !currentCamera.url.isEmpty else {
            return
        }

        player.drawable = videoView

        if player.isPlaying {
            hideLoading()
            statusLabel.stringValue = "Playing \(currentCamera.name)."
            return
        }

        if player.media != nil {
            player.play()
            hideLoading()
            statusLabel.stringValue = "Playing \(currentCamera.name)."
            StreamStatusCenter.post(.playing)
            return
        }

        playCurrentCamera()
    }

    func scheduleStopPreview() {
        scheduledStop?.cancel()

        guard let delay = settings.previewStopDelay else {
            scheduledStop = nil
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.stopPreview()
        }
        scheduledStop = workItem

        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancelScheduledStop() {
        scheduledStop?.cancel()
        scheduledStop = nil
    }

    private func stopPreview() {
        stopAllPreviewPlayers()
        statusLabel.stringValue = "Preview stopped."
        hideLoading()
        StreamStatusCenter.post(.idle)
    }

    func focusURLField() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            NSApp.activate(ignoringOtherApps: true)
            self.view.window?.makeKeyAndOrderFront(nil)
            self.view.window?.makeFirstResponder(self.urlField)
            self.urlField.currentEditor()?.selectAll(nil)
        }
    }

    @objc private func saveAndPlay() {
        let value = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        updateCurrentCameraURL(value)
        playCurrentCamera()
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              field === urlField
        else {
            return
        }

        updateCurrentCameraURL(urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField,
              field === urlField
        else {
            return
        }

        let value = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != currentCamera.url else {
            return
        }

        updateCurrentCameraURL(value)
        playCurrentCamera()
    }

    @objc private func toggleMute() {
        settings.isMuted.toggle()
        for player in previewPlayersByURL.values {
            player.audio?.isMuted = settings.isMuted
        }
        updateMuteButton()
    }

    @objc private func reconnectCurrentCamera() {
        let urlString = currentCamera.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            statusLabel.stringValue = "Invalid RTSP URL."
            return
        }

        let cachedPlayer = playerForURL(urlString)
        cachedPlayer.stop()
        cachedPlayer.media = nil
        cachedPlayer.drawable = nil
        player = cachedPlayer
        player.drawable = videoView
        play(urlString: urlString)
    }

    @objc private func changeVolume() {
        settings.volume = Int(volumeSlider.doubleValue.rounded())
        if settings.volume > 0 {
            settings.isMuted = false
        }

        for player in previewPlayersByURL.values {
            player.audio?.volume = Int32(settings.volume)
            player.audio?.isMuted = settings.isMuted
        }

        updateMuteButton()
        updateVolumeControls()
    }

    @objc private func selectCameraFromTabs() {
        let index = cameraTabs.selectedSegment
        if shouldRenameFromTabAction(index: index) {
            renameCameraTab(at: index)
            return
        }

        switchToCamera(index)
    }

    @objc private func addCameraTab() {
        var streams = settings.cameraStreams
        let nextNumber = streams.count + 1
        streams.append(CameraStream(name: "CAM\(nextNumber)", url: defaultURL(for: nextNumber)))
        settings.cameraStreams = streams
        switchToCamera(streams.count - 1)
    }

    private func deleteCameraTab(at index: Int) {
        var streams = settings.cameraStreams
        guard streams.count > 1,
              streams.indices.contains(index)
        else {
            return
        }

        let removedURL = streams[index].url
        streams.remove(at: index)
        let nextIndex = min(index, streams.count - 1)

        if streams.allSatisfy({ $0.url != removedURL }) {
            previewPlayersByURL[removedURL]?.stop()
            previewPlayersByURL[removedURL]?.media = nil
            previewPlayersByURL[removedURL]?.drawable = nil
            previewPlayersByURL.removeValue(forKey: removedURL)
        }

        currentCameraIndex = nextIndex
        settings.cameraStreams = streams
        settings.selectedCameraIndex = nextIndex
        switchToCamera(nextIndex)
    }

    private func renameCameraTab(at index: Int) {
        // Rename is intentionally disabled for now.
    }

    private func shouldRenameFromTabAction(index: Int) -> Bool {
        let wasAlreadySelected = index == currentCameraIndex
        let now = Date()
        defer {
            lastTabActionIndex = index
            lastTabActionAt = now
        }

        guard wasAlreadySelected,
              lastTabActionIndex == index,
              now.timeIntervalSince(lastTabActionAt) < 1.0
        else {
            return false
        }

        lastTabActionIndex = nil
        lastTabActionAt = .distantPast
        return true
    }

    private func commitCameraRename(index: Int, name: String) {
        var streams = settings.cameraStreams
        guard streams.indices.contains(index) else {
            return
        }

        streams[index].name = name
        settings.cameraStreams = streams
        settings.selectedCameraIndex = index
        configureCameraTabs()
    }

    @objc private func cameraStreamsDidChange() {
        let streams = settings.cameraStreams
        currentCameraIndex = min(currentCameraIndex, max(streams.count - 1, 0))
        settings.selectedCameraIndex = currentCameraIndex
        configureCameraTabs()
    }

    @objc private func showPreviousCamera() {
        let count = settings.cameraStreams.count
        guard count > 1 else {
            return
        }

        switchToCamera((currentCameraIndex - 1 + count) % count)
    }

    @objc private func showNextCamera() {
        let count = settings.cameraStreams.count
        guard count > 1 else {
            return
        }

        switchToCamera((currentCameraIndex + 1) % count)
    }

    private func installOverlayClickMonitorIfNeeded() {
        guard overlayClickMonitor == nil else {
            return
        }

        overlayClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            guard self?.handleVideoOverlayClick(event) == true else {
                return event
            }

            return nil
        }

        overlayGlobalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handlePanelScreenClick()
            }
        }
    }

    private func handleVideoOverlayClick(_ event: NSEvent) -> Bool {
        let point = videoOverlayView.convert(event.locationInWindow, from: nil)
        return handleVideoOverlayPoint(point)
    }

    private func handlePanelScreenClick() {
        guard let window = view.window,
              window.isVisible
        else {
            return
        }

        for screenPoint in mouseLocationCandidates() where window.frame.contains(screenPoint) {
            let windowPoint = NSPoint(
                x: screenPoint.x - window.frame.minX,
                y: screenPoint.y - window.frame.minY
            )
            let point = videoOverlayView.convert(windowPoint, from: nil)
            if handleVideoOverlayPoint(point) {
                return
            }
        }
    }

    private func handleVideoOverlayPoint(_ point: NSPoint) -> Bool {
        guard videoOverlayView.bounds.contains(point) else {
            return false
        }

        setVideoOverlayControlsVisible(true)
        return false
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

    private var currentCamera: CameraStream {
        let streams = settings.cameraStreams
        guard streams.indices.contains(currentCameraIndex) else {
            return streams.first ?? CameraStream(name: "CAM1", url: "")
        }

        return streams[currentCameraIndex]
    }

    private func switchToCamera(_ index: Int) {
        let streams = settings.cameraStreams
        guard streams.indices.contains(index) else {
            return
        }

        currentCameraIndex = index
        settings.selectedCameraIndex = index
        configureCameraTabs()
        cancelScheduledStop()
        player.drawable = nil
        player = playerForURL(currentCamera.url)
        player.drawable = videoView
        playCurrentCamera()
    }

    private func playCurrentCamera() {
        let camera = currentCamera
        urlField.stringValue = camera.url
        settings.selectedCameraIndex = currentCameraIndex
        play(urlString: camera.url)
    }

    private func updateCurrentCameraURL(_ url: String) {
        var streams = settings.cameraStreams
        guard streams.indices.contains(currentCameraIndex) else {
            return
        }

        streams[currentCameraIndex].url = url
        settings.setCameraStreamURL(url, at: currentCameraIndex, notify: false)
        settings.selectedCameraIndex = currentCameraIndex
    }

    private func play(urlString: String) {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            statusLabel.stringValue = "Invalid RTSP URL."
            return
        }

        player = playerForURL(urlString)
        player.drawable = videoView
        player.audio?.isMuted = settings.isMuted
        player.audio?.volume = Int32(settings.volume)

        if player.isPlaying {
            hideLoading()
            statusLabel.stringValue = "Playing \(currentCamera.name)."
            StreamStatusCenter.post(.playing)
            return
        }

        if player.media != nil {
            player.play()
            hideLoading()
            statusLabel.stringValue = "Playing \(currentCamera.name)."
            StreamStatusCenter.post(.playing)
            return
        }

        player.stop()
        player.media = VLCMedia(url: url)
        showLoading()
        StreamStatusCenter.post(.connecting)
        player.play()
        statusLabel.stringValue = "Connecting \(currentCamera.name)..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else {
                return
            }

            if self.player.isPlaying {
                self.hideLoading()
                self.statusLabel.stringValue = "Playing \(self.currentCamera.name)."
                StreamStatusCenter.post(.playing)
            }
        }
    }

    private func ensurePreviewPlayersStarted() {
        for stream in settings.cameraStreams {
            let urlString = stream.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: urlString), !urlString.isEmpty else {
                continue
            }

            let cachedPlayer = playerForURL(urlString)
            cachedPlayer.audio?.isMuted = settings.isMuted
            cachedPlayer.audio?.volume = Int32(settings.volume)

            if cachedPlayer.media == nil {
                cachedPlayer.media = VLCMedia(url: url)
            }

            if !cachedPlayer.isPlaying {
                cachedPlayer.play()
            }
        }
    }

    private func configureCameraTabs() {
        let streams = settings.cameraStreams
        currentCameraIndex = min(max(settings.selectedCameraIndex, 0), max(streams.count - 1, 0))
        cameraTabs.setTabs(streams.map(\.name))
        cameraTabs.selectedSegment = currentCameraIndex
        urlField.stringValue = currentCamera.url
        previousCameraButton.isHidden = true
        nextCameraButton.isHidden = true
        setVideoOverlayControlsVisible(false)
    }

    private func updateMuteButton() {
        let symbol = settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: settings.isMuted ? "Muted" : "Unmuted")
        styleIconButton(muteButton)
    }

    private func updateVolumeControls() {
        volumeSlider.doubleValue = Double(settings.volume)
        volumeLabel.stringValue = "\(settings.volume)"
    }

    private func styleIconButton(_ button: NSButton) {
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.alignment = .center
        button.contentTintColor = .labelColor
    }

    private func styleOverlayButton(_ button: NSButton) {
        styleIconButton(button)
        button.wantsLayer = true
        button.layer?.cornerRadius = 10
        button.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.48).cgColor
        button.contentTintColor = .white
    }

    private func setVideoOverlayControlsVisible(_ isVisible: Bool) {
        previousCameraButton.alphaValue = 0
        nextCameraButton.alphaValue = 0
        previousCameraButton.isEnabled = false
        nextCameraButton.isEnabled = false
    }

    private func playerForURL(_ urlString: String) -> VLCMediaPlayer {
        if let existing = previewPlayersByURL[urlString] {
            return existing
        }

        let newPlayer = VLCMediaPlayer()
        newPlayer.audio?.isMuted = settings.isMuted
        newPlayer.audio?.volume = Int32(settings.volume)
        previewPlayersByURL[urlString] = newPlayer
        return newPlayer
    }

    private func stopAllPreviewPlayers() {
        for player in previewPlayersByURL.values {
            player.stop()
            player.media = nil
            player.drawable = nil
        }
    }

    private func defaultURL(for cameraNumber: Int) -> String {
        let selectedURL = currentCamera.url
        if !selectedURL.isEmpty,
           let range = selectedURL.range(of: #"stream\d+$"#, options: .regularExpression) {
            return selectedURL.replacingCharacters(in: range, with: "stream\(cameraNumber)")
        }

        return "rtsp://user:password@192.168.0.45:554/stream\(cameraNumber)"
    }

    private func showLoading() {
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimation(nil)
    }

    private func hideLoading() {
        loadingSpinner.stopAnimation(nil)
        loadingOverlay.isHidden = true
    }
}

final class VideoHoverOverlayView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?
    private var trackingArea: NSTrackingArea?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseMoved(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseDown(with event: NSEvent) {
        onHoverChanged?(true)

        let point = convert(event.locationInWindow, from: nil)
        let edgeWidth: CGFloat = 72
        if point.x <= edgeWidth {
            onPrevious?()
        } else if point.x >= bounds.maxX - edgeWidth {
            onNext?()
        } else {
            super.mouseDown(with: event)
        }
    }
}

final class FirstMouseButton: NSButton {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

final class FirstMouseTextField: NSTextField {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

final class CameraTabBarView: NSView {
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?
    var isEditing = false {
        didSet { needsDisplay = true }
    }

    private var tabs: [String] = []
    private var hoverIndex: Int?
    private var trackingArea: NSTrackingArea?

    var segmentCount: Int { tabs.count }

    var selectedSegment = 0 {
        didSet {
            selectedSegment = min(max(selectedSegment, 0), max(tabs.count - 1, 0))
            needsDisplay = true
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        nil
    }

    func setTabs(_ names: [String]) {
        tabs = names
        selectedSegment = min(selectedSegment, max(names.count - 1, 0))
        needsDisplay = true
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let index = segmentIndex(at: convert(event.locationInWindow, from: nil))
        if hoverIndex != index {
            hoverIndex = index
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hoverIndex = nil
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        guard !isEditing else { return }

        let point = convert(event.locationInWindow, from: nil)
        let index = segmentIndex(at: point)
        guard index >= 0 else {
            return
        }

        if tabs.count > 1,
           closeRect(for: index).contains(point) {
            onClose?(index)
            return
        }

        selectedSegment = index
        onSelect?(index)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !tabs.isEmpty else {
            return
        }

        let basePath = NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7)
        NSColor.controlBackgroundColor.withAlphaComponent(0.46).setFill()
        basePath.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        basePath.lineWidth = 1
        basePath.stroke()

        for index in tabs.indices {
            let frame = segmentFrame(for: index)
            if index == selectedSegment {
                let selectedPath = NSBezierPath(roundedRect: frame.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6)
                NSColor.labelColor.withAlphaComponent(0.08).setFill()
                selectedPath.fill()
                NSColor.systemGreen.withAlphaComponent(0.18).setStroke()
                selectedPath.lineWidth = 1
                selectedPath.stroke()
            } else if index == hoverIndex && !isEditing {
                NSColor.white.withAlphaComponent(0.11).setFill()
                NSBezierPath(roundedRect: frame.insetBy(dx: 2, dy: 2), xRadius: 6, yRadius: 6).fill()
            }

            if index > 0,
               index != selectedSegment,
               index - 1 != selectedSegment {
                NSColor.separatorColor.withAlphaComponent(0.20).setStroke()
                let separator = NSBezierPath()
                separator.move(to: NSPoint(x: frame.minX, y: bounds.minY + 5))
                separator.line(to: NSPoint(x: frame.minX, y: bounds.maxY - 5))
                separator.stroke()
            }

            drawTitle(tabs[index], in: titleRect(for: index), selected: index == selectedSegment)

            if tabs.count > 1,
               (index == hoverIndex || index == selectedSegment),
               !isEditing {
                drawClose(in: closeRect(for: index), selected: index == selectedSegment)
            }
        }
    }

    func segmentFrame(for index: Int) -> NSRect {
        guard tabs.indices.contains(index), !tabs.isEmpty else { return .zero }
        let segmentWidth = bounds.width / CGFloat(tabs.count)
        return NSRect(x: segmentWidth * CGFloat(index), y: 0, width: segmentWidth, height: bounds.height)
    }

    private func segmentIndex(at point: NSPoint) -> Int {
        guard !tabs.isEmpty, bounds.contains(point) else {
            return -1
        }

        let segmentWidth = bounds.width / CGFloat(tabs.count)
        return min(max(Int(point.x / segmentWidth), 0), tabs.count - 1)
    }

    private func titleRect(for index: Int) -> NSRect {
        let frame = segmentFrame(for: index)
        let hasClose = tabs.count > 1 && (index == hoverIndex || index == selectedSegment) && !isEditing
        let rightInset: CGFloat = hasClose ? 34 : 10
        return NSRect(x: frame.minX + 10, y: frame.minY + 4, width: max(frame.width - rightInset - 10, 20), height: frame.height - 8)
    }

    private func closeRect(for index: Int) -> NSRect {
        let frame = segmentFrame(for: index)
        return NSRect(x: frame.maxX - 27, y: frame.minY + 2, width: 22, height: frame.height - 4)
    }

    private func drawTitle(_ title: String, in rect: NSRect, selected: Bool) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        title.draw(in: rect, withAttributes: attributes)
    }

    private func drawClose(in rect: NSRect, selected: Bool) {
        guard let symbol = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close tab") else {
            return
        }

        let imageRect = NSRect(x: rect.midX - 4.5, y: rect.midY - 4.5, width: 9, height: 9)
        symbol.isTemplate = true
        (selected ? NSColor.labelColor : NSColor.tertiaryLabelColor).set()
        symbol.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: selected ? 0.72 : 0.58)
    }

}

final class InlineTabRenameController: NSObject, NSTextFieldDelegate {
    private weak var tabBar: CameraTabBarView?
    private weak var parentView: NSView?
    private var textField: NSTextField?
    private var editingIndex: Int?
    private var isFinishing = false

    var onCommit: ((Int, String) -> Void)?
    var onFinish: (() -> Void)?

    init(tabBar: CameraTabBarView, parentView: NSView) {
        self.tabBar = tabBar
        self.parentView = parentView
        super.init()
    }

    func beginEditing(index: Int, value: String) {
        guard let tabBar,
              let parentView,
              tabBar.segmentCount > 0,
              index >= 0,
              index < tabBar.segmentCount
        else {
            return
        }

        finish(save: false)
        parentView.layoutSubtreeIfNeeded()
        tabBar.layoutSubtreeIfNeeded()

        let field = NSTextField()
        field.stringValue = value
        field.delegate = self
        field.font = .systemFont(ofSize: 12, weight: .semibold)
        field.alignment = .center
        field.lineBreakMode = .byTruncatingTail
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.drawsBackground = true
        field.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.98)
        field.focusRingType = .default
        field.frame = frameForSegment(index, in: tabBar, parentView: parentView).insetBy(dx: 3, dy: 1)
        parentView.addSubview(field, positioned: .above, relativeTo: nil)

        textField = field
        editingIndex = index
        tabBar.selectedSegment = index
        DispatchQueue.main.async { [weak parentView, weak field] in
            guard let parentView,
                  let field
            else {
                return
            }

            parentView.window?.makeFirstResponder(field)
            field.selectText(nil)
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard !isFinishing else {
            return
        }

        finish(save: true)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finish(save: true)
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            finish(save: false)
            return true
        }

        return false
    }

    private func finish(save: Bool) {
        guard let field = textField,
              let index = editingIndex
        else {
            return
        }

        isFinishing = true
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        textField = nil
        editingIndex = nil
        field.window?.makeFirstResponder(nil)
        field.removeFromSuperview()
        isFinishing = false

        if save, !name.isEmpty {
            onCommit?(index, name)
        }
        onFinish?()
    }

    private func frameForSegment(_ index: Int, in tabBar: CameraTabBarView, parentView: NSView) -> NSRect {
        tabBar.convert(tabBar.segmentFrame(for: index), to: parentView)
    }
}
