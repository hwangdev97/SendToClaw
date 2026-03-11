import Foundation

struct OpenClawConfig {
    let token: String
    let port: Int
    let host: String
}

class ConfigService {
    func loadConfig() throws -> OpenClawConfig {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configURL = homeDir.appendingPathComponent(".openclaw/openclaw.json")
        return try loadConfigFrom(url: configURL)
    }

    func loadConfigFrom(url: URL) throws -> OpenClawConfig {
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
        let host = "127.0.0.1"

        return OpenClawConfig(token: token, port: port, host: host)
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
