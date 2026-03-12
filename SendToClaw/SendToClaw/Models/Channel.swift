import Foundation

enum ChannelType: String, Codable {
    case web
    case telegram
}

struct Channel: Codable, Identifiable, Equatable {
    var id: UUID
    var type: ChannelType
    var name: String

    // Web (OpenClaw) fields
    var host: String?
    var port: Int?
    var token: String?

    // Telegram fields
    var botUsername: String?  // e.g. "my_openclaw_bot" (without @)

    var displayName: String {
        switch type {
        case .web:
            let h = host ?? ""
            let p = port ?? 0
            if h == "127.0.0.1" || h == "localhost" {
                return "\(name) (local:\(p))"
            }
            return "\(name) (\(h):\(p))"
        case .telegram:
            return "\(name) (Telegram)"
        }
    }
}
