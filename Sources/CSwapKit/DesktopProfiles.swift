import AppKit
import Foundation

/// One Claude Desktop data folder. The normal app uses
/// `~/Library/Application Support/Claude`; CSwap starts further instances
/// with `--user-data-dir` pointing at `Claude-cswap-<slug>`, each with its own
/// claude.ai login. (`CLAUDE_USER_DATA_DIR` would be the obvious switch, but
/// signed builds ignore it.)
public struct DesktopProfile: Identifiable, Hashable, Sendable {
    public let dataDir: URL
    /// Seat named by the folder: `main` for the normal folder.
    public let folderSlug: String
    public var accountUUID: String?
    public var isLoggedIn: Bool
    public var pid: Int32?

    public var id: String { dataDir.path }
    public var isMain: Bool { folderSlug == Seat.mainSlug }
    public var isRunning: Bool { pid != nil }
}

public struct DesktopProfileStore: Sendable {

    public enum DesktopError: LocalizedError {
        case appNotFound
        case launchFailed(String)

        public var errorDescription: String? {
            switch self {
            case .appNotFound:
                return "Claude Desktop isn't installed. Download it from claude.ai/download."
            case let .launchFailed(message):
                return "Couldn't start Claude Desktop: \(message)"
            }
        }
    }

    public enum OpenResult: Sendable {
        case launched
        case activated
    }

    public static let bundleIdentifier = "com.anthropic.claudefordesktop"
    static let folderPrefix = "Claude-cswap-"
    static let configFileName = "claude_desktop_config.json"

    public let seats: SeatStore

    public init(seats: SeatStore = SeatStore()) {
        self.seats = seats
    }

    private var fileManager: FileManager { .default }

    var supportDirectory: URL {
        seats.home.appendingPathComponent("Library/Application Support")
    }

    public var mainDataDir: URL {
        supportDirectory.appendingPathComponent("Claude")
    }

    /// Folder a new profile for `seat` goes into. `main` gets the normal
    /// folder only while nobody uses it yet; it may already hold another
    /// account's login.
    public func newDataDir(for seat: Seat) -> URL {
        if seat.isMain, !fileManager.fileExists(atPath: mainDataDir.path) { return mainDataDir }
        return supportDirectory.appendingPathComponent(Self.folderPrefix + seat.slug)
    }

    public var appURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleIdentifier)
    }

    // MARK: - Listing

    /// The normal folder plus every folder CSwap created, with login and
    /// running state.
    public func profiles() -> [DesktopProfile] {
        var folders: [(URL, String)] = []
        if fileManager.fileExists(atPath: mainDataDir.path) {
            folders.append((mainDataDir, Seat.mainSlug))
        }
        let entries = (try? fileManager.contentsOfDirectory(atPath: supportDirectory.path)) ?? []
        for name in entries.sorted() where name.hasPrefix(Self.folderPrefix) {
            let slug = String(name.dropFirst(Self.folderPrefix.count))
            guard slug == Seat.mainSlug || Seat.isValidSlug(slug) else { continue }
            folders.append((supportDirectory.appendingPathComponent(name), slug))
        }

        let running = runningInstances()
        return folders.map { dir, slug in
            let config = readJSON(dir.appendingPathComponent("config.json")) ?? [:]
            let token = (config["oauth:tokenCacheV2"] as? String) ?? (config["oauth:tokenCache"] as? String)
            return DesktopProfile(
                dataDir: dir.standardizedFileURL,
                folderSlug: slug,
                accountUUID: config["lastKnownAccountUuid"] as? String,
                isLoggedIn: token?.isEmpty == false,
                pid: running[dir.standardizedFileURL.path]
            )
        }
    }

    /// Which seat each profile belongs to: the seat logged in to the same
    /// claude.ai account, otherwise the seat named by the folder. Keyed by
    /// seat slug.
    public func assign(_ profiles: [DesktopProfile], to seatList: [Seat]) -> [String: [DesktopProfile]] {
        var byAccount: [String: String] = [:]
        for seat in seatList {
            if let uuid = seats.profile(of: seat)?.accountUUID, byAccount[uuid] == nil {
                byAccount[uuid] = seat.slug
            }
        }
        let known = Set(seatList.map(\.slug))
        var result: [String: [DesktopProfile]] = [:]
        for profile in profiles {
            let owner = profile.isLoggedIn ? profile.accountUUID.flatMap { byAccount[$0] } : nil
            let slug = owner ?? (known.contains(profile.folderSlug) ? profile.folderSlug : Seat.mainSlug)
            result[slug, default: []].append(profile)
        }
        return result
    }

    /// The profile `cswap desktop <seat>` and the menu open for `seat`.
    public func profile(for seat: Seat) -> DesktopProfile? {
        Self.preferred(assign(profiles(), to: seats.seats())[seat.slug] ?? [])
    }

    /// A logged-in profile wins over one still waiting for its login.
    public static func preferred(_ profiles: [DesktopProfile]) -> DesktopProfile? {
        profiles.first { $0.isRunning && $0.isLoggedIn } ?? profiles.first(where: \.isLoggedIn) ?? profiles.first
    }

    /// Opens the seat's profile, creating one when it has none.
    @discardableResult
    public func open(seat: Seat) throws -> OpenResult {
        try open(profile(for: seat)?.dataDir ?? newDataDir(for: seat))
    }

    // MARK: - Open / quit

    /// Brings a running instance to the front, or starts one. A profile that
    /// doesn't exist yet is created and opens on Claude's login screen.
    @discardableResult
    public func open(_ dataDir: URL) throws -> OpenResult {
        let dataDir = dataDir.standardizedFileURL
        if let pid = runningInstances()[dataDir.path],
           let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
            return .activated
        }
        guard let appURL else { throw DesktopError.appNotFound }

        let isMain = dataDir == mainDataDir.standardizedFileURL
        var arguments = ["-n", "-a", appURL.path]
        if !isMain {
            try prepare(dataDir)
            arguments += ["--args", "--user-data-dir=\(dataDir.path)"]
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        // Claude Desktop runs its own Claude Code; a CLAUDE_CONFIG_DIR handed
        // down from a seat would point it at that seat's login.
        process.environment = TerminalLauncher.cleanEnvironment()
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            throw DesktopError.launchFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return .launched
    }

    /// Asks the instance to quit the way the Dock's Quit does.
    public func quit(_ profile: DesktopProfile) {
        guard let pid = profile.pid else { return }
        kill(pid, SIGTERM)
    }

    // MARK: - Shared config

    /// Creates the folder and shares MCP servers from the normal profile.
    ///
    /// Claude Desktop rewrites `claude_desktop_config.json` by replacing the
    /// file, which turns a symlink into a copy on the first start. So the
    /// first start copies the whole file, and later starts merge
    /// `mcpServers` from the normal profile in. Only call this while the
    /// instance is stopped; a running one overwrites the file on quit.
    func prepare(_ dataDir: URL) throws {
        try fileManager.createDirectory(at: dataDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let source = mainDataDir.appendingPathComponent(Self.configFileName)
        let target = dataDir.appendingPathComponent(Self.configFileName)
        guard let main = readJSON(source) else { return }

        guard var config = readJSON(target) else {
            try fileManager.copyItem(at: source, to: target)
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            return
        }
        let mainServers = main["mcpServers"] as? [String: Any] ?? [:]
        let ownServers = config["mcpServers"] as? [String: Any] ?? [:]
        let merged = ownServers.merging(mainServers) { _, fromMain in fromMain }
        guard !NSDictionary(dictionary: merged).isEqual(to: ownServers) else { return }
        config["mcpServers"] = merged
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: target, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
    }

    // MARK: - Running instances

    /// Data folder path → PID of each running Claude Desktop instance.
    public func runningInstances() -> [String: Int32] {
        var result: [String: Int32] = [:]
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier) {
            let pid = app.processIdentifier
            let arguments = Self.arguments(of: pid) ?? []
            let dir = Self.userDataDir(in: arguments).map { URL(fileURLWithPath: $0) } ?? mainDataDir
            result[dir.standardizedFileURL.path] = pid
        }
        return result
    }

    static func userDataDir(in arguments: [String]) -> String? {
        for (index, argument) in arguments.enumerated() {
            if argument.hasPrefix("--user-data-dir=") {
                return String(argument.dropFirst("--user-data-dir=".count))
            }
            if argument == "--user-data-dir", index + 1 < arguments.count {
                return arguments[index + 1]
            }
        }
        return nil
    }

    /// argv of another process of this user, from `KERN_PROCARGS2`: argc,
    /// the executable path, padding, then the NUL-separated arguments.
    static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }

        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }

        var arguments: [String] = []
        while arguments.count < argc, index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }

    private func readJSON(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
