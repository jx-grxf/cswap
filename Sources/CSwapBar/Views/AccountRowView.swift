import CSwapKit
import SwiftUI

struct AccountRowView: View {
    let info: SeatInfo
    let isDefault: Bool
    let usage: UsageSnapshot?
    let problem: UsageProblem?
    /// Short name of another account logged in to the same claude.ai login.
    let duplicateOf: String?
    /// Accounts this account's sessions can move to.
    let moveTargets: [SeatInfo]
    let showsDesktop: Bool
    let onMove: (RunningSession, SeatInfo) -> Void
    let onMakeDefault: () -> Void
    let onOpen: () -> Void
    let onOpenDesktop: () -> Void
    let onQuitDesktop: () -> Void
    let onRevealDesktop: () -> Void
    let onLogIn: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { if !isDefault { onMakeDefault() } }) {
            VStack(alignment: .leading, spacing: 10) {
                header

                if let duplicateOf {
                    warning("Same login as \(duplicateOf). Right-click and choose Log In Again with the right account.")
                }

                usageSection

                if showsDesktop, let desktop = info.desktop {
                    desktopRow(desktop)
                }

                if !info.sessions.isEmpty {
                    sessionList
                }
            }
            .padding(Theme.s3)
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(isDefault ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
        )
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : Theme.hover, value: isHovering)
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            avatar

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(info.email ?? info.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let plan = info.planLabel {
                        Text(plan)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Capsule().fill(Theme.trackFill))
                    }
                }
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 6)

            trailing
        }
    }

    /// Account name, plus live sessions when any run in this account.
    private var subtitle: String {
        var parts = [info.seat.isMain ? "main · ~/.claude" : info.title]
        switch info.runningSessions {
        case 0: break
        case 1: parts.append("1 session")
        case let count: parts.append("\(count) sessions")
        }
        return parts.joined(separator: " · ")
    }

    private var cardFill: Color {
        if isDefault { return Color.accentColor.opacity(0.10) }
        return isHovering ? Theme.cardHoverFill : Theme.cardFill
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(isDefault ? Color.accentColor : Color.secondary.opacity(0.22))
            Text(String((info.email ?? info.title).prefix(1)).uppercased())
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(isDefault ? Color.white : Color.primary)
        }
        .frame(width: 28, height: 28)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailing: some View {
        HStack(spacing: 2) {
            if isDefault {
                Label("Default", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.trailing, 4)
            } else if isHovering {
                Text("Use for new sessions")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.accentColor)
                    .padding(.trailing, 4)
                    .transition(.opacity)
            }

            if info.isLoggedIn {
                iconButton("terminal", help: "Open Claude Code with this account", action: onOpen)
                if showsDesktop {
                    iconButton(
                        "macwindow",
                        help: info.desktop == nil
                            ? "Set up Claude Desktop for this account"
                            : "Open Claude Desktop with this account",
                        action: onOpenDesktop
                    )
                }
            } else {
                Button("Log In", action: onLogIn)
                    .controlSize(.small)
            }
        }
    }

    private func iconButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }

    private func warning(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var contextMenu: some View {
        if !isDefault {
            Button("Use for New Sessions", action: onMakeDefault)
        }
        Button("Open Claude Code", action: onOpen)
            .disabled(!info.isLoggedIn)
        if showsDesktop {
            Button(info.desktop == nil ? "Set Up Claude Desktop…" : "Open Claude Desktop", action: onOpenDesktop)
                .disabled(!info.isLoggedIn)
            if info.desktop?.isRunning == true {
                Button("Quit Claude Desktop", action: onQuitDesktop)
            }
        }
        Divider()
        Button(info.isLoggedIn ? "Log In Again…" : "Log In…", action: onLogIn)
        Button("Show Folder in Finder", action: onReveal)
        if info.desktop != nil {
            Button("Show Desktop Profile in Finder", action: onRevealDesktop)
        }
        if !info.seat.isMain {
            Divider()
            Button("Remove Account…", role: .destructive, action: onRemove)
        }
    }

    // MARK: - Claude Desktop

    private func desktopRow(_ desktop: DesktopProfile) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "macwindow")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Claude Desktop")
                .font(.caption.weight(.medium))
            desktopState(desktop)
            Spacer(minLength: 4)
            if desktop.isRunning {
                Button("Quit", action: onQuitDesktop)
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(.borderless)
                    .help("Quit this Claude Desktop window")
            }
            Button(desktop.isRunning ? "Show" : "Open", action: onOpenDesktop)
                .font(.caption2.weight(.semibold))
                .buttonStyle(.borderless)
        }
        .padding(.horizontal, Theme.s2)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(Theme.rowFill)
        )
    }

    @ViewBuilder
    private func desktopState(_ desktop: DesktopProfile) -> some View {
        if info.desktopHasForeignLogin {
            Label("another account", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
                .help("This Desktop profile is logged in to a claude.ai account that none of your accounts use. Log out there and log in as \(info.email ?? info.title).")
        } else if !desktop.isLoggedIn {
            Label("waiting for login", systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption2)
                .foregroundStyle(.orange)
        } else if desktop.isRunning {
            Label("open", systemImage: "circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(DotLabelStyle(color: .green))
        } else {
            Text("closed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Running sessions

    private var sessionList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(info.sessions) { session in
                sessionRow(session)
            }
        }
    }

    private func sessionRow(_ session: RunningSession) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(session.isBusy ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
                .help(session.isBusy ? "Working on a reply" : "Waiting for input")
                .accessibilityLabel(session.isBusy ? "Working" : "Waiting for input")
            Text(session.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            if let cwd = session.cwd, (cwd as NSString).lastPathComponent != session.title {
                Text((cwd as NSString).lastPathComponent)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .help(abbreviated(cwd))
            }
            Spacer(minLength: 4)
            moveControl(for: session)
        }
        .padding(.horizontal, Theme.s2)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowRadius, style: .continuous)
                .fill(Theme.rowFill)
        )
    }

    @ViewBuilder
    private func moveControl(for session: RunningSession) -> some View {
        if moveTargets.count == 1, let target = moveTargets.first {
            Button {
                onMove(session, target)
            } label: {
                Label("Move to \(target.title)", systemImage: "arrow.right.circle")
                    .font(.caption2.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .help(moveHelp(session, to: target))
        } else if !moveTargets.isEmpty {
            Menu {
                ForEach(moveTargets) { target in
                    Button(target.email.map { "\(target.title) (\($0))" } ?? target.title) { onMove(session, target) }
                }
            } label: {
                Label("Move", systemImage: "arrow.right.circle")
                    .font(.caption2.weight(.semibold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Continue this conversation with another account")
        }
    }

    private func moveHelp(_ session: RunningSession, to target: SeatInfo) -> String {
        let base = "Continue this conversation with \(target.email ?? target.title), like /swap"
        return session.isBusy ? base + ". Interrupts the reply in progress." : base
    }

    private func abbreviated(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    // MARK: - Usage

    @ViewBuilder
    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let usage {
                if let five = usage.fiveHour {
                    UsageBarView(label: "5h", window: five)
                }
                if let seven = usage.sevenDay {
                    UsageBarView(label: "7d", window: seven)
                }
                ForEach(usage.scoped, id: \.name) { scoped in
                    UsageBarView(label: scoped.name, window: scoped.window)
                }
            }

            // Stale numbers stay visible; the note says how old they are and
            // why they aren't updating.
            if let problem {
                Label(problemText(problem), systemImage: problem == .idle ? "moon.zzz" : "clock.arrow.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            } else if usage == nil {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.mini)
                    Text("Loading usage…")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func problemText(_ problem: UsageProblem) -> String {
        guard let usage, problem != .notLoggedIn else { return problem.shortText }
        let age = usage.fetchedAt.formatted(.relative(presentation: .named))
        switch problem {
        case .idle: return "Updated \(age). Refreshes when this account runs again"
        default: return "Updated \(age). \(problem.shortText)"
        }
    }
}

/// A small colored dot in front of the title, for "open"-style states.
private struct DotLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            configuration.title
        }
    }
}
