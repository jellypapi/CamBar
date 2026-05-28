import AppKit
import VLCKit

final class LargeCameraWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private let settings = CameraSettings.shared
    private var player = VLCMediaPlayer()
    private var largePlayersByURL: [String: VLCMediaPlayer] = [:]
    private let backgroundView = NSVisualEffectView()
    private let cameraTabs = CameraTabBarView()
    private let addCameraButton = NSButton()
    private let videoView = VLCVideoView()
    private let loadingOverlay = NSVisualEffectView()
    private let loadingSpinner = NSProgressIndicator()
    private let loadingLabel = NSTextField(labelWithString: "Connecting...")
    private let urlLabel = NSTextField(labelWithString: "Stream")
    private let urlField = NSTextField()
    private let statusLabel = NSTextField(labelWithString: "")
    private let playPauseButton = NSButton()
    private let reconnectButton = NSButton()
    private let stopButton = NSButton()
    private let muteButton = NSButton()
    private let settingsButton = NSButton()
    private let settingsPopover = NSPopover()
    private let settingsPanel = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 74))
    private let settingsViewController = NSViewController()
    private let previewModeControl = NSSegmentedControl(labels: ["Keep", "5 min", "Off"], trackingMode: .selectOne, target: nil, action: nil)
    private let volumeSlider = NSSlider(value: 80, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let volumeLabel = NSTextField(labelWithString: "80")
    private var lastURL: URL?
    private var currentPlayerURL: URL?
    private var retryCount = 0
    private var scheduledStop: DispatchWorkItem?
    private var lastTabActionIndex: Int?
    private var lastTabActionAt = Date.distantPast

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CamPeek"
        window.titlebarAppearsTransparent = false
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        super.init(window: window)
        window.delegate = self

        let contentView = NSView()
        window.contentView = contentView

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.material = .windowBackground
        backgroundView.blendingMode = .withinWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.addSubview(backgroundView)

        cameraTabs.translatesAutoresizingMaskIntoConstraints = false
        cameraTabs.onSelect = { [weak self] index in
            self?.showCamera(at: index)
        }
        cameraTabs.onClose = { [weak self] index in
            self?.deleteCameraTab(at: index)
        }
        contentView.addSubview(cameraTabs)

        addCameraButton.translatesAutoresizingMaskIntoConstraints = false
        addCameraButton.bezelStyle = .rounded
        addCameraButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add camera")
        addCameraButton.title = ""
        addCameraButton.target = self
        addCameraButton.action = #selector(addCameraTab)
        addCameraButton.toolTip = "Add camera"
        styleIconButton(addCameraButton)
        contentView.addSubview(addCameraButton)

        videoView.translatesAutoresizingMaskIntoConstraints = false
        videoView.wantsLayer = true
        videoView.layer?.backgroundColor = NSColor.black.cgColor
        videoView.layer?.cornerRadius = 12
        videoView.layer?.borderWidth = 1
        videoView.layer?.borderColor = NSColor.white.withAlphaComponent(0.34).cgColor
        videoView.layer?.masksToBounds = true
        contentView.addSubview(videoView)

        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.material = .underWindowBackground
        loadingOverlay.blendingMode = .withinWindow
        loadingOverlay.state = .active
        loadingOverlay.wantsLayer = true
        loadingOverlay.layer?.cornerRadius = 10
        loadingOverlay.isHidden = true
        contentView.addSubview(loadingOverlay)

        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        loadingSpinner.style = .spinning
        loadingSpinner.controlSize = .regular
        loadingOverlay.addSubview(loadingSpinner)

        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingLabel.textColor = .labelColor
        loadingLabel.font = .systemFont(ofSize: 13, weight: .medium)
        loadingLabel.alignment = .center
        loadingOverlay.addSubview(loadingLabel)

        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        urlLabel.textColor = .secondaryLabelColor
        urlLabel.font = .systemFont(ofSize: 12, weight: .medium)
        contentView.addSubview(urlLabel)

        urlField.translatesAutoresizingMaskIntoConstraints = false
        urlField.placeholderString = "rtsp://user:pass@192.168.0.45:554/stream1"
        urlField.stringValue = settings.streamURL
        urlField.lineBreakMode = .byTruncatingMiddle
        urlField.bezelStyle = .roundedBezel
        urlField.drawsBackground = true
        urlField.backgroundColor = NSColor.textBackgroundColor
        urlField.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        urlField.target = self
        urlField.action = #selector(saveAndPlay)
        urlField.delegate = self
        contentView.addSubview(urlField)

        let savePlayButton = makeTextButton("Play URL", action: #selector(saveAndPlay))
        contentView.addSubview(savePlayButton)

        playPauseButton.translatesAutoresizingMaskIntoConstraints = false
        playPauseButton.bezelStyle = .rounded
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlayPause)
        playPauseButton.toolTip = "Play or pause"
        contentView.addSubview(playPauseButton)

        reconnectButton.translatesAutoresizingMaskIntoConstraints = false
        reconnectButton.bezelStyle = .rounded
        reconnectButton.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reconnect")
        reconnectButton.title = ""
        styleIconButton(reconnectButton)
        reconnectButton.target = self
        reconnectButton.action = #selector(reconnect)
        reconnectButton.toolTip = "Reconnect"
        contentView.addSubview(reconnectButton)

        stopButton.translatesAutoresizingMaskIntoConstraints = false
        stopButton.bezelStyle = .rounded
        stopButton.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: "Stop")
        stopButton.title = ""
        styleIconButton(stopButton)
        stopButton.target = self
        stopButton.action = #selector(stopPlayback)
        stopButton.toolTip = "Stop"
        contentView.addSubview(stopButton)

        muteButton.translatesAutoresizingMaskIntoConstraints = false
        muteButton.bezelStyle = .rounded
        muteButton.target = self
        muteButton.action = #selector(toggleMute)
        muteButton.toolTip = "Mute"
        contentView.addSubview(muteButton)

        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.bezelStyle = .rounded
        settingsButton.image = NSImage(systemSymbolName: "clock", accessibilityDescription: "Stream close behavior")
        settingsButton.title = ""
        styleIconButton(settingsButton)
        settingsButton.target = self
        settingsButton.action = #selector(showSettingsPopover)
        settingsButton.toolTip = "Close behavior"
        contentView.addSubview(settingsButton)

        let volumeIcon = NSTextField(labelWithString: "Volume")
        volumeIcon.translatesAutoresizingMaskIntoConstraints = false
        volumeIcon.textColor = .secondaryLabelColor
        volumeIcon.font = .systemFont(ofSize: 12)
        contentView.addSubview(volumeIcon)

        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.doubleValue = Double(settings.volume)
        volumeSlider.target = self
        volumeSlider.action = #selector(changeVolume)
        volumeSlider.toolTip = "Volume"
        contentView.addSubview(volumeSlider)

        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        volumeLabel.alignment = .right
        volumeLabel.textColor = .secondaryLabelColor
        volumeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        contentView.addSubview(volumeLabel)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.stringValue = "Ready."
        statusLabel.lineBreakMode = .byTruncatingTail
        contentView.addSubview(statusLabel)

        settingsPanel.translatesAutoresizingMaskIntoConstraints = false
        settingsPanel.wantsLayer = true
        settingsPanel.layer?.backgroundColor = NSColor.clear.cgColor
        settingsViewController.view = settingsPanel
        settingsPopover.contentSize = settingsPanel.frame.size
        settingsPopover.behavior = .transient
        settingsPopover.contentViewController = settingsViewController

        let previewModeLabel = NSTextField(labelWithString: "On close")
        previewModeLabel.translatesAutoresizingMaskIntoConstraints = false
        previewModeLabel.textColor = .secondaryLabelColor
        previewModeLabel.font = .systemFont(ofSize: 12)
        settingsPanel.addSubview(previewModeLabel)

        previewModeControl.translatesAutoresizingMaskIntoConstraints = false
        previewModeControl.target = self
        previewModeControl.action = #selector(changePreviewKeepAliveMode)
        previewModeControl.toolTip = "Controls whether menu bar preview keeps streaming after the popover closes."
        settingsPanel.addSubview(previewModeControl)

        NSLayoutConstraint.activate([
            backgroundView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            backgroundView.topAnchor.constraint(equalTo: contentView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            cameraTabs.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            cameraTabs.trailingAnchor.constraint(equalTo: addCameraButton.leadingAnchor, constant: -8),
            cameraTabs.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            cameraTabs.heightAnchor.constraint(equalToConstant: 26),

            addCameraButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            addCameraButton.centerYAnchor.constraint(equalTo: cameraTabs.centerYAnchor),
            addCameraButton.widthAnchor.constraint(equalToConstant: 34),
            addCameraButton.heightAnchor.constraint(equalToConstant: 26),

            videoView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            videoView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            videoView.topAnchor.constraint(equalTo: cameraTabs.bottomAnchor, constant: 10),
            videoView.bottomAnchor.constraint(equalTo: urlField.topAnchor, constant: -12),

            loadingOverlay.centerXAnchor.constraint(equalTo: videoView.centerXAnchor),
            loadingOverlay.centerYAnchor.constraint(equalTo: videoView.centerYAnchor),
            loadingOverlay.widthAnchor.constraint(equalToConstant: 190),
            loadingOverlay.heightAnchor.constraint(equalToConstant: 72),

            loadingSpinner.leadingAnchor.constraint(equalTo: loadingOverlay.leadingAnchor, constant: 18),
            loadingSpinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),
            loadingSpinner.widthAnchor.constraint(equalToConstant: 20),
            loadingSpinner.heightAnchor.constraint(equalToConstant: 20),

            loadingLabel.leadingAnchor.constraint(equalTo: loadingSpinner.trailingAnchor, constant: 12),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingOverlay.trailingAnchor, constant: -16),
            loadingLabel.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor),

            urlLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            urlLabel.centerYAnchor.constraint(equalTo: urlField.centerYAnchor),
            urlLabel.widthAnchor.constraint(equalToConstant: 48),

            urlField.leadingAnchor.constraint(equalTo: urlLabel.trailingAnchor, constant: 8),
            urlField.trailingAnchor.constraint(equalTo: savePlayButton.leadingAnchor, constant: -8),
            urlField.bottomAnchor.constraint(equalTo: playPauseButton.topAnchor, constant: -10),
            urlField.heightAnchor.constraint(equalToConstant: 30),

            savePlayButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            savePlayButton.centerYAnchor.constraint(equalTo: urlField.centerYAnchor),
            savePlayButton.widthAnchor.constraint(equalToConstant: 86),
            savePlayButton.heightAnchor.constraint(equalTo: urlField.heightAnchor),

            stopButton.leadingAnchor.constraint(equalTo: urlField.leadingAnchor),
            stopButton.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8),
            stopButton.widthAnchor.constraint(equalToConstant: 42),
            stopButton.heightAnchor.constraint(equalToConstant: 30),

            playPauseButton.leadingAnchor.constraint(equalTo: stopButton.trailingAnchor, constant: 8),
            playPauseButton.centerYAnchor.constraint(equalTo: stopButton.centerYAnchor),
            playPauseButton.widthAnchor.constraint(equalToConstant: 42),
            playPauseButton.heightAnchor.constraint(equalTo: stopButton.heightAnchor),

            reconnectButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 8),
            reconnectButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            reconnectButton.widthAnchor.constraint(equalTo: playPauseButton.widthAnchor),
            reconnectButton.heightAnchor.constraint(equalTo: playPauseButton.heightAnchor),

            muteButton.leadingAnchor.constraint(equalTo: reconnectButton.trailingAnchor, constant: 8),
            muteButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            muteButton.widthAnchor.constraint(equalTo: playPauseButton.widthAnchor),
            muteButton.heightAnchor.constraint(equalTo: playPauseButton.heightAnchor),

            settingsButton.leadingAnchor.constraint(equalTo: muteButton.trailingAnchor, constant: 8),
            settingsButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalTo: playPauseButton.widthAnchor),
            settingsButton.heightAnchor.constraint(equalTo: playPauseButton.heightAnchor),

            volumeIcon.leadingAnchor.constraint(equalTo: settingsButton.trailingAnchor, constant: 14),
            volumeIcon.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),

            volumeSlider.leadingAnchor.constraint(equalTo: volumeIcon.trailingAnchor, constant: 8),
            volumeSlider.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            volumeSlider.widthAnchor.constraint(equalToConstant: 170),

            volumeLabel.leadingAnchor.constraint(equalTo: volumeSlider.trailingAnchor, constant: 8),
            volumeLabel.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            volumeLabel.widthAnchor.constraint(equalToConstant: 34),

            statusLabel.leadingAnchor.constraint(equalTo: urlField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: savePlayButton.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            statusLabel.heightAnchor.constraint(equalToConstant: 18),

            previewModeLabel.leadingAnchor.constraint(equalTo: settingsPanel.leadingAnchor, constant: 12),
            previewModeLabel.centerYAnchor.constraint(equalTo: settingsPanel.centerYAnchor),
            previewModeLabel.widthAnchor.constraint(equalToConstant: 70),

            previewModeControl.leadingAnchor.constraint(equalTo: previewModeLabel.trailingAnchor, constant: 10),
            previewModeControl.trailingAnchor.constraint(equalTo: settingsPanel.trailingAnchor, constant: -12),
            previewModeControl.centerYAnchor.constraint(equalTo: settingsPanel.centerYAnchor)
        ])

        player.drawable = videoView
        applyAudioSettings()
        configureCameraTabs()
        updateSettingsUI()
        updateControlState()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        switch settings.previewKeepAliveMode {
        case .always:
            statusLabel.stringValue = "Streaming in background."
            StreamStatusCenter.post(.playing)
        case .fiveMinutes:
            scheduleStop(after: 300)
            statusLabel.stringValue = "Streaming in background for 5 min."
            StreamStatusCenter.post(.playing)
        case .immediate:
            stopPlayerForClose()
        }

        updateControlState()
    }

    func show(urlString: String, muted: Bool, selectedIndex: Int? = nil) {
        guard let url = URL(string: urlString) else {
            statusLabel.stringValue = "Invalid RTSP URL."
            return
        }

        urlField.stringValue = urlString
        settings.isMuted = muted
        lastURL = url
        if let selectedIndex,
           settings.cameraStreams.indices.contains(selectedIndex) {
            settings.selectedCameraIndex = selectedIndex
        } else {
            selectCamera(for: urlString)
        }
        configureCameraTabs()
        retryCount = 0
        cancelScheduledStop()
        bringToFront()
        CameraWindowEvents.largeCameraDidOpen()

        showCachedPlayer(url: url)
    }

    func showExistingPlayer(_ existingPlayer: VLCMediaPlayer, urlString: String, muted: Bool, selectedIndex: Int? = nil) {
        if player === existingPlayer {
            player = VLCMediaPlayer()
        }

        urlField.stringValue = urlString
        settings.isMuted = muted
        lastURL = URL(string: urlString)
        currentPlayerURL = lastURL
        if let selectedIndex,
           settings.cameraStreams.indices.contains(selectedIndex) {
            settings.selectedCameraIndex = selectedIndex
        } else {
            selectCamera(for: urlString)
        }
        configureCameraTabs()
        retryCount = 0
        cancelScheduledStop()

        if player.isPlaying, player.media != nil {
            player.drawable = videoView
            applyAudioSettings()
            hideLoading()
            statusLabel.stringValue = "Playing."
            bringToFront()
            CameraWindowEvents.largeCameraDidOpen()
            StreamStatusCenter.post(.playing)
            updateControlState()
            return
        }

        bringToFront()
        CameraWindowEvents.largeCameraDidOpen()
        if let url = lastURL {
            DispatchQueue.main.async { [weak self] in
                self?.play(url: url)
            }
        }
    }

    func cancelScheduledStop() {
        scheduledStop?.cancel()
        scheduledStop = nil
    }

    func stopHiddenStreamIfNeeded(for urlString: String) {
        guard window?.isVisible != true,
              lastURL?.absoluteString == urlString,
              player.media != nil
        else {
            return
        }

        stopPlayerForClose()
    }

    func showWindowOnly() {
        let urlString = settings.streamURL
        if !urlString.isEmpty {
            show(urlString: urlString, muted: settings.isMuted)
            return
        }

        bringToFront()
    }

    func setMuted(_ muted: Bool) {
        settings.isMuted = muted
        for player in largePlayersByURL.values {
            player.audio?.isMuted = muted
        }
        updateControlState()
    }

    private func makeTextButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.bezelStyle = .rounded
        return button
    }

    private func play(url: URL) {
        let cachedPlayer = playerForURL(url.absoluteString)
        if player !== cachedPlayer {
            player.drawable = nil
            player = cachedPlayer
            player.drawable = videoView
        }
        currentPlayerURL = url

        applyAudioSettings()

        if player.media == nil {
            player.media = VLCMedia(url: url)
        }

        if player.isPlaying {
            hideLoading()
            statusLabel.stringValue = "Playing."
            StreamStatusCenter.post(.playing)
            updateControlState()
            return
        }

        showLoading("Connecting...")
        player.play()
        StreamStatusCenter.post(.connecting)
        statusLabel.stringValue = "Connecting..."
        updateControlState()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.retryIfNeeded()
            self?.updateControlState()
            self?.hideLoadingIfPlaying()
        }
    }

    private func applyAudioSettings() {
        player.audio?.isMuted = settings.isMuted
        player.audio?.volume = Int32(settings.volume)
        volumeSlider.doubleValue = Double(settings.volume)
        volumeLabel.stringValue = "\(settings.volume)"
    }

    @objc private func saveAndPlay() {
        let value = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        updateCurrentCameraURL(value)
        show(urlString: value, muted: settings.isMuted, selectedIndex: settings.selectedCameraIndex)
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
        let streams = settings.cameraStreams
        let selectedIndex = settings.selectedCameraIndex
        guard streams.indices.contains(selectedIndex),
              value != streams[selectedIndex].url
        else {
            return
        }

        updateCurrentCameraURL(value)
        show(urlString: value, muted: settings.isMuted, selectedIndex: selectedIndex)
    }

    @objc private func togglePlayPause() {
        if player.isPlaying {
            player.pause()
            statusLabel.stringValue = "Paused."
        } else if player.media != nil {
            player.play()
            statusLabel.stringValue = "Playing."
        } else {
            saveAndPlay()
        }

        updateControlState()
    }

    @objc private func reconnect() {
        let value = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), !value.isEmpty else {
            statusLabel.stringValue = "Invalid RTSP URL."
            return
        }

        updateCurrentCameraURL(value)
        lastURL = url
        retryCount = 0
        statusLabel.stringValue = "Reconnecting..."
        play(url: url)
    }

    @objc private func stopPlayback() {
        cancelScheduledStop()
        for player in largePlayersByURL.values {
            player.stop()
        }
        currentPlayerURL = nil
        statusLabel.stringValue = "Stopped."
        hideLoading()
        StreamStatusCenter.post(.idle)
        updateControlState()
    }

    @objc private func toggleMute() {
        settings.isMuted.toggle()
        for player in largePlayersByURL.values {
            player.audio?.isMuted = settings.isMuted
        }
        updateControlState()
    }

    @objc private func changeVolume() {
        settings.volume = Int(volumeSlider.doubleValue.rounded())
        if settings.volume > 0 {
            settings.isMuted = false
        }

        applyAudioSettings()
        updateControlState()
    }

    @objc private func showSettingsPopover() {
        if settingsPopover.isShown {
            settingsPopover.performClose(nil)
            return
        }

        settingsPopover.show(relativeTo: settingsButton.bounds, of: settingsButton, preferredEdge: .maxY)
    }

    @objc private func changePreviewKeepAliveMode() {
        switch previewModeControl.selectedSegment {
        case 0:
            settings.previewKeepAliveMode = .always
        case 1:
            settings.previewKeepAliveMode = .fiveMinutes
        default:
            settings.previewKeepAliveMode = .immediate
        }

        updateSettingsUI()
    }

    private func showCamera(at index: Int) {
        let streams = settings.cameraStreams
        guard streams.indices.contains(index) else {
            return
        }

        settings.selectedCameraIndex = index
        show(urlString: streams[index].url, muted: settings.isMuted, selectedIndex: index)
    }

    @objc private func selectCameraFromTabs() {
        let index = cameraTabs.selectedSegment
        if shouldRenameFromTabAction(index: index) {
            renameCameraTab(at: index)
            return
        }

        showCamera(at: index)
    }

    @objc private func addCameraTab() {
        var streams = settings.cameraStreams
        let nextNumber = streams.count + 1
        streams.append(CameraStream(name: "CAM\(nextNumber)", url: defaultURL(for: nextNumber)))
        settings.cameraStreams = streams
        settings.selectedCameraIndex = streams.count - 1
        configureCameraTabs()
        show(urlString: streams[streams.count - 1].url, muted: settings.isMuted)
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
            largePlayersByURL[removedURL]?.stop()
            largePlayersByURL[removedURL]?.media = nil
            largePlayersByURL[removedURL]?.drawable = nil
            largePlayersByURL.removeValue(forKey: removedURL)
        }

        settings.cameraStreams = streams
        settings.selectedCameraIndex = nextIndex
        configureCameraTabs()
        show(urlString: streams[nextIndex].url, muted: settings.isMuted, selectedIndex: nextIndex)
    }

    private func renameCameraTab(at index: Int) {
        // Rename is intentionally disabled for now.
    }

    private func updateCurrentCameraURL(_ url: String) {
        var streams = settings.cameraStreams
        let selectedIndex = settings.selectedCameraIndex
        guard streams.indices.contains(selectedIndex) else {
            return
        }

        streams[selectedIndex].url = url
        settings.setCameraStreamURL(url, at: selectedIndex, notify: false)
    }

    private func shouldRenameFromTabAction(index: Int) -> Bool {
        let wasAlreadySelected = index == settings.selectedCameraIndex
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

    private func bringToFront() {
        showWindow(nil)
        window?.orderFrontRegardless()
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(videoView)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func retryIfNeeded() {
        guard !player.isPlaying,
              retryCount < 2,
              let url = lastURL
        else {
            if player.isPlaying {
                statusLabel.stringValue = "Playing."
                StreamStatusCenter.post(.playing)
            }
            return
        }

        retryCount += 1
        statusLabel.stringValue = "Reconnecting..."
        showLoading("Reconnecting...")
        play(url: url)
    }

    private func scheduleStop(after delay: TimeInterval) {
        scheduledStop?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.stopPlayerForClose()
        }
        scheduledStop = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func stopPlayerForClose() {
        scheduledStop?.cancel()
        scheduledStop = nil
        for player in largePlayersByURL.values {
            player.stop()
            player.media = nil
            player.drawable = nil
        }
        largePlayersByURL.removeAll()
        player = VLCMediaPlayer()
        currentPlayerURL = nil
        statusLabel.stringValue = "Stopped."
        hideLoading()
        StreamStatusCenter.post(.idle)
    }

    private func showLoading(_ text: String) {
        loadingLabel.stringValue = text
        loadingOverlay.isHidden = false
        loadingSpinner.startAnimation(nil)
    }

    private func hideLoading() {
        loadingSpinner.stopAnimation(nil)
        loadingOverlay.isHidden = true
    }

    private func hideLoadingIfPlaying() {
        if player.isPlaying {
            hideLoading()
        }
    }

    private func showCachedPlayer(url: URL) {
        player.drawable = nil
        player = playerForURL(url.absoluteString)
        player.drawable = videoView
        currentPlayerURL = url
        applyAudioSettings()

        if player.media == nil || !player.isPlaying {
            play(url: url)
            return
        }

        hideLoading()
        statusLabel.stringValue = "Playing."
        StreamStatusCenter.post(.playing)
        updateControlState()
    }

    private func playerForURL(_ urlString: String) -> VLCMediaPlayer {
        if let existing = largePlayersByURL[urlString] {
            return existing
        }

        let newPlayer = VLCMediaPlayer()
        newPlayer.audio?.isMuted = settings.isMuted
        newPlayer.audio?.volume = Int32(settings.volume)
        largePlayersByURL[urlString] = newPlayer
        return newPlayer
    }

    private func updateControlState() {
        let playSymbol = player.isPlaying ? "pause.fill" : "play.fill"
        playPauseButton.image = NSImage(systemSymbolName: playSymbol, accessibilityDescription: "Play or pause")
        styleIconButton(playPauseButton)

        let muteSymbol = settings.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"
        muteButton.image = NSImage(systemSymbolName: muteSymbol, accessibilityDescription: "Mute")
        styleIconButton(muteButton)
        volumeLabel.stringValue = "\(settings.volume)"
    }

    private func styleIconButton(_ button: NSButton) {
        button.title = ""
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.alignment = .center
        button.contentTintColor = .labelColor
    }

    private func updateSettingsUI() {
        switch settings.previewKeepAliveMode {
        case .always:
            previewModeControl.selectedSegment = 0
        case .fiveMinutes:
            previewModeControl.selectedSegment = 1
        case .immediate:
            previewModeControl.selectedSegment = 2
        }
    }

    private func configureCameraTabs() {
        let streams = settings.cameraStreams
        cameraTabs.setTabs(streams.map(\.name))
        cameraTabs.selectedSegment = settings.selectedCameraIndex
    }

    private func selectCamera(for urlString: String) {
        if let index = settings.cameraStreams.firstIndex(where: { $0.url == urlString }) {
            settings.selectedCameraIndex = index
        }
    }

    private func defaultURL(for cameraNumber: Int) -> String {
        let selectedURL = settings.streamURL
        if !selectedURL.isEmpty,
           let range = selectedURL.range(of: #"stream\d+$"#, options: .regularExpression) {
            return selectedURL.replacingCharacters(in: range, with: "stream\(cameraNumber)")
        }

        return "rtsp://user:password@192.168.0.45:554/stream\(cameraNumber)"
    }
}
