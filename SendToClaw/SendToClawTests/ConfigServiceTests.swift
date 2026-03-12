import Testing
import Foundation
@testable import SendToClaw

@Suite("ConfigService Tests")
struct ConfigServiceTests {

    @Test("Loads valid config from JSON")
    func loadValidConfig() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configJSON = """
        {
            "gateway": {
                "port": 19000,
                "auth": {
                    "token": "test-token-12345"
                }
            }
        }
        """
        let configFile = tempDir.appendingPathComponent("openclaw.json")
        try configJSON.write(to: configFile, atomically: true, encoding: .utf8)

        let service = ConfigService()
        let config = try service.loadConfigFrom(url: configFile)

        #expect(config.token == "test-token-12345")
        #expect(config.port == 19000)
        #expect(config.host == "127.0.0.1")
        #expect(config.name == "Local")
    }

    @Test("Uses default port when not specified")
    func defaultPort() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configJSON = """
        {
            "gateway": {
                "auth": {
                    "token": "abc"
                }
            }
        }
        """
        let configFile = tempDir.appendingPathComponent("openclaw.json")
        try configJSON.write(to: configFile, atomically: true, encoding: .utf8)

        let service = ConfigService()
        let config = try service.loadConfigFrom(url: configFile)
        #expect(config.port == 18789)
    }

    @Test("Throws on missing gateway key")
    func missingGateway() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configJSON = """
        { "other": {} }
        """
        let configFile = tempDir.appendingPathComponent("openclaw.json")
        try configJSON.write(to: configFile, atomically: true, encoding: .utf8)

        let service = ConfigService()
        #expect(throws: ConfigError.self) {
            try service.loadConfigFrom(url: configFile)
        }
    }

    @Test("Throws on missing token")
    func missingToken() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let configJSON = """
        { "gateway": { "port": 18789 } }
        """
        let configFile = tempDir.appendingPathComponent("openclaw.json")
        try configJSON.write(to: configFile, atomically: true, encoding: .utf8)

        let service = ConfigService()
        #expect(throws: ConfigError.self) {
            try service.loadConfigFrom(url: configFile)
        }
    }

    @Test("Channel round-trips through Codable")
    func configCodable() throws {
        let original = Channel(
            id: UUID(),
            type: .web,
            name: "Office LAN",
            host: "192.168.1.50",
            port: 19000,
            token: "secret-token"
        )

        let data = try JSONEncoder().encode([original])
        let decoded = try JSONDecoder().decode([Channel].self, from: data)

        #expect(decoded.count == 1)
        #expect(decoded[0].id == original.id)
        #expect(decoded[0].name == "Office LAN")
        #expect(decoded[0].host == "192.168.1.50")
        #expect(decoded[0].port == 19000)
        #expect(decoded[0].token == "secret-token")
    }

    @Test("Channel displayName for local vs remote")
    func configDisplayName() {
        let local = Channel(id: UUID(), type: .web, name: "Home", host: "127.0.0.1", port: 18789, token: "t")
        #expect(local.displayName == "Home (local:18789)")

        let localhost = Channel(id: UUID(), type: .web, name: "Dev", host: "localhost", port: 18789, token: "t")
        #expect(localhost.displayName == "Dev (local:18789)")

        let remote = Channel(id: UUID(), type: .web, name: "Cloud", host: "claw.example.com", port: 443, token: "t")
        #expect(remote.displayName == "Cloud (claw.example.com:443)")
    }
}
