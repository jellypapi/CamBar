import Foundation

extension Notification.Name {
    static let cameraStreamsDidChange = Notification.Name("cameraStreamsDidChange")
}

struct CameraStream {
    var name: String
    var url: String
}

enum PreviewKeepAliveMode: String {
    case always
    case fiveMinutes
    case immediate
}

final class CameraSettings {
    static let shared = CameraSettings()

    private let defaults = UserDefaults.standard
    private let defaultStream1 = "rtsp://user:password@192.168.0.45:554/stream1"
    private let defaultStream2 = "rtsp://user:password@192.168.0.45:554/stream2"

    var streamURL: String {
        get {
            if let url = cameraStreams[safe: selectedCameraIndex]?.url {
                return url
            }

            return defaults.string(forKey: "streamURL") ?? ""
        }
        set {
            defaults.set(newValue, forKey: "streamURL")
            setCameraStreamURL(newValue, at: selectedCameraIndex, notify: true)
        }
    }

    var cameraStreams: [CameraStream] {
        get {
            if let saved = defaults.array(forKey: "cameraStreams") as? [[String: String]],
               !saved.isEmpty {
                return saved.enumerated().map { index, item in
                    CameraStream(
                        name: item["name"]?.isEmpty == false ? item["name"]! : "CAM\(index + 1)",
                        url: item["url"] ?? ""
                    )
                }
            }

            let savedURL = defaults.string(forKey: "streamURL")
            let firstURL = savedURL?.isEmpty == false ? savedURL! : defaultStream1
            return [
                CameraStream(name: "Main", url: firstURL),
                CameraStream(name: "Sub", url: defaultStream2)
            ]
        }
        set {
            defaults.set(newValue.map { ["name": $0.name, "url": $0.url] }, forKey: "cameraStreams")
            NotificationCenter.default.post(name: .cameraStreamsDidChange, object: nil)
        }
    }

    var selectedCameraIndex: Int {
        get {
            let saved = defaults.object(forKey: "selectedCameraIndex") as? Int ?? 0
            return min(max(saved, 0), max(cameraStreams.count - 1, 0))
        }
        set {
            defaults.set(min(max(newValue, 0), max(cameraStreams.count - 1, 0)), forKey: "selectedCameraIndex")
        }
    }

    func setCameraStreamURL(_ url: String, at index: Int, notify: Bool) {
        var streams = cameraStreams
        guard streams.indices.contains(index) else {
            return
        }

        streams[index].url = url
        defaults.set(streams.map { ["name": $0.name, "url": $0.url] }, forKey: "cameraStreams")
        defaults.set(url, forKey: "streamURL")

        if notify {
            NotificationCenter.default.post(name: .cameraStreamsDidChange, object: nil)
        }
    }

    var isMuted: Bool {
        get {
            defaults.object(forKey: "isMuted") as? Bool ?? true
        }
        set {
            defaults.set(newValue, forKey: "isMuted")
        }
    }

    var volume: Int {
        get {
            let saved = defaults.object(forKey: "volume") as? Int
            return min(max(saved ?? 80, 0), 100)
        }
        set {
            defaults.set(min(max(newValue, 0), 100), forKey: "volume")
        }
    }

    var previewKeepAliveMode: PreviewKeepAliveMode {
        get {
            let rawValue = defaults.string(forKey: "previewKeepAliveMode") ?? PreviewKeepAliveMode.always.rawValue
            return PreviewKeepAliveMode(rawValue: rawValue) ?? .always
        }
        set {
            defaults.set(newValue.rawValue, forKey: "previewKeepAliveMode")
        }
    }

    var previewStopDelay: TimeInterval? {
        switch previewKeepAliveMode {
        case .always:
            return nil
        case .fiveMinutes:
            return 300
        case .immediate:
            return 0
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
