import Foundation

/// Checks GitHub Releases once a day and can run the installer to update in place.
final class Updater: ObservableObject {
    static let shared = Updater()

    static let repo = "MariosIgkiempor/iconvert"
    static let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"

    @Published private(set) var available: String?   // newer version, if any
    @Published private(set) var lastChecked: Date?
    @Published private(set) var checking = false
    @Published private(set) var updating = false

    private let defaults = UserDefaults.standard

    private init() {
        lastChecked = defaults.object(forKey: "lastUpdateCheck") as? Date
        apply(latest: defaults.string(forKey: "latestVersion"))
    }

    /// Call at launch and periodically; only hits the network if the last check is over a day old.
    func checkIfDue() {
        if let last = lastChecked, Date().timeIntervalSince(last) < 24 * 3600 { return }
        check()
    }

    func check() {
        guard !checking else { return }
        checking = true
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, _ in
            let tag = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["tag_name"] as? String
            DispatchQueue.main.async {
                self.checking = false
                guard let tag else { return }   // offline or rate-limited: try again next time
                let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                self.lastChecked = Date()
                self.defaults.set(self.lastChecked, forKey: "lastUpdateCheck")
                self.defaults.set(version, forKey: "latestVersion")
                self.apply(latest: version)
            }
        }.resume()
    }

    private func apply(latest: String?) {
        available = latest.flatMap { Self.isNewer($0, than: Self.current) ? $0 : nil }
    }

    /// Runs the same installer as the README. It replaces and relaunches this app.
    func install() {
        guard !updating else { return }
        updating = true
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = ["-c", "curl -fsSL https://github.com/\(Self.repo)/releases/latest/download/install.sh | bash"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        p.terminationHandler = { _ in
            // Only reached if the installer failed (on success it kills this app).
            DispatchQueue.main.async {
                self.updating = false
                notify("Update failed. Try again later.")
            }
        }
        do { try p.run() } catch { updating = false }
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}
