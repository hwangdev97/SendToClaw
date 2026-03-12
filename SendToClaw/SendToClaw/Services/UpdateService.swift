import Foundation

struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
    let body: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}

enum UpdateCheckResult {
    case upToDate
    case updateAvailable(version: String, url: URL, notes: String?)
    case error(String)
}

class UpdateService {
    private static let repoOwner = "hwangdev97"
    private static let repoName = "SendToClaw"
    private static let checkIntervalSeconds: TimeInterval = 24 * 60 * 60

    private let defaults = UserDefaults.standard
    private let lastCheckKey = "update_last_check_time"
    private let skippedVersionKey = "update_skipped_version"

    func currentAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
    }

    func checkForUpdate() async -> UpdateCheckResult {
        let urlString = "https://api.github.com/repos/\(Self.repoOwner)/\(Self.repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            return .error("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .error("Invalid response")
            }
            guard httpResponse.statusCode == 200 else {
                return .error("HTTP \(httpResponse.statusCode)")
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName.hasPrefix("v")
                ? String(release.tagName.dropFirst())
                : release.tagName

            if isNewerVersion(remoteVersion, than: currentAppVersion()),
               let releaseURL = URL(string: release.htmlUrl) {
                return .updateAvailable(version: remoteVersion, url: releaseURL, notes: release.body)
            }
            return .upToDate
        } catch {
            return .error(error.localizedDescription)
        }
    }

    // MARK: - Throttle & skip

    func shouldAutoCheck() -> Bool {
        let lastCheck = defaults.double(forKey: lastCheckKey)
        guard lastCheck > 0 else { return true }
        return Date().timeIntervalSince1970 - lastCheck >= Self.checkIntervalSeconds
    }

    func recordCheckTime() {
        defaults.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
    }

    func skipVersion(_ version: String) {
        defaults.set(version, forKey: skippedVersionKey)
    }

    func isVersionSkipped(_ version: String) -> Bool {
        defaults.string(forKey: skippedVersionKey) == version
    }

    // MARK: - Version comparison

    private func isNewerVersion(_ remote: String, than local: String) -> Bool {
        let remoteParts = remote.split(separator: ".").compactMap { Int($0) }
        let localParts = local.split(separator: ".").compactMap { Int($0) }
        let count = max(remoteParts.count, localParts.count)
        for i in 0..<count {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }
}
