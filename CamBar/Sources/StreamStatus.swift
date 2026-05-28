import Foundation

enum StreamStatus: String {
    case idle
    case connecting
    case playing
}

extension Notification.Name {
    static let streamStatusDidChange = Notification.Name("CamBar.streamStatusDidChange")
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
