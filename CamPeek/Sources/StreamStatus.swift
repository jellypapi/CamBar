import Foundation

enum StreamStatus: String {
    case idle
    case connecting
    case playing
}

extension Notification.Name {
    static let streamStatusDidChange = Notification.Name("CamPeek.streamStatusDidChange")
    static let largeCameraDidOpen = Notification.Name("CamPeek.largeCameraDidOpen")
}

enum StreamStatusCenter {
    static func post(_ status: StreamStatus) {
        NotificationCenter.default.post(
            name: .streamStatusDidChange,
            object: nil,
            userInfo: ["status": status.rawValue]
        )
    }
}

enum CameraWindowEvents {
    static func largeCameraDidOpen() {
        NotificationCenter.default.post(name: .largeCameraDidOpen, object: nil)
    }
}
