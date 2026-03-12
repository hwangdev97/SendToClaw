import Foundation

/// Legacy struct for migration only
private struct LegacyOpenClawConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var host: String
    var port: Int
    var token: String
}

class ConfigService {
    private static let channelsKey = "channels"
    private static let activeChannelKey = "active_channel_id"
    private static let legacyServersKey = "openclaw_servers"
    private static let legacyActiveServerKey = "openclaw_active_server_id"

    // MARK: - Local config file

    func loadLocalConfig() throws -> Channel {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configURL = homeDir.appendingPathComponent(".openclaw/openclaw.json")
        return try loadConfigFrom(url: configURL)
    }

    func loadConfigFrom(url: URL) throws -> Channel {
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let gateway = json?["gateway"] as? [String: Any] else {
            throw ConfigError.missingKey("gateway")
        }

        guard let auth = gateway["auth"] as? [String: Any],
              let token = auth["token"] as? String else {
            throw ConfigError.missingKey("gateway.auth.token")
        }

        let port = gateway["port"] as? Int ?? 18789

        return Channel(
            id: UUID(),
            type: .web,
            name: "Local",
            host: "127.0.0.1",
            port: port,
            token: token
        )
    }

    // MARK: - Channels (UserDefaults)

    func loadChannels() -> [Channel] {
        // Try new key first
        if let data = UserDefaults.standard.data(forKey: Self.channelsKey),
           let channels = try? JSONDecoder().decode([Channel].self, from: data) {
            return channels
        }

        // Migrate from legacy servers
        if let data = UserDefaults.standard.data(forKey: Self.legacyServersKey),
           let oldServers = try? JSONDecoder().decode([LegacyOpenClawConfig].self, from: data) {
            let channels = oldServers.map { server in
                Channel(id: server.id, type: .web, name: server.name,
                        host: server.host, port: server.port, token: server.token)
            }
            saveChannels(channels)
            // Clean up legacy keys
            UserDefaults.standard.removeObject(forKey: Self.legacyServersKey)
            return channels
        }

        // First launch: try to import local config
        if let local = try? loadLocalConfig() {
            saveChannels([local])
            return [local]
        }
        return []
    }

    func saveChannels(_ channels: [Channel]) {
        if let data = try? JSONEncoder().encode(channels) {
            UserDefaults.standard.set(data, forKey: Self.channelsKey)
        }
    }

    func loadActiveChannelId() -> UUID? {
        // Try new key first
        if let str = UserDefaults.standard.string(forKey: Self.activeChannelKey) {
            return UUID(uuidString: str)
        }
        // Migrate from legacy
        if let str = UserDefaults.standard.string(forKey: Self.legacyActiveServerKey) {
            UserDefaults.standard.removeObject(forKey: Self.legacyActiveServerKey)
            if let id = UUID(uuidString: str) {
                saveActiveChannelId(id)
                return id
            }
        }
        return nil
    }

    func saveActiveChannelId(_ id: UUID?) {
        UserDefaults.standard.set(id?.uuidString, forKey: Self.activeChannelKey)
    }
}

enum ConfigError: LocalizedError {
    case missingKey(String)

    var errorDescription: String? {
        switch self {
        case .missingKey(let key):
            return "Missing configuration key: \(key)"
        }
    }
}
