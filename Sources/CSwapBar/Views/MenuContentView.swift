import CSwapKit
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var store: AppState
    @State private var updates = UpdateService.shared
    @AppStorage("showsClaudeDesktop") private var showsClaudeDesktop = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if !store.isShellIntegrationInstalled {
                shellBanner
                Divider()
            }
            accountList
            if let error = store.errorMessage {
                Divider()
                errorBanner(error)
            }
            Divider()
            footer
        }
        .frame(width: 440)
        .background(GeometryReader { MenuWindowSizer(contentHeight: $0.size.height) })
        .task {
            store.reload()
            await store.refreshUsage()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: MenuBarIcon.appLogo)
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text("CSwap")
                    .font(.headline)
                Text(store.defaultSeat.map { "New sessions: \($0.email ?? $0.title)" } ?? "No default account")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            headerButton("plus", help: "Add Account") { AddAccountWindowController.show() }
            headerButton("arrow.clockwise", help: "Refresh usage") {
                Task { await store.refreshUsage(force: true) }
            }
            .disabled(store.isRefreshingUsage)
            headerButton("gearshape", help: "Settings") {
                SettingsWindowController.show()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func headerButton(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(help)
    }

    // MARK: - Shell integration banner

    private var shellBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text("Set up cswap once")
                    .font(.caption.weight(.semibold))
                Text("Adds the `cswap` command and one line to your shell's startup file.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Set Up") {
                store.installShellIntegration()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color.accentColor.opacity(0.08))
    }

    // MARK: - Account list

    private var accountList: some View {
        ScrollView(.vertical) {
            VStack(spacing: Theme.s2) {
                ForEach(store.seats) { info in
                    AccountRowView(
                        info: info,
                        isDefault: info.id == store.defaultSlug,
                        usage: store.usage[info.id],
                        problem: store.usageProblems[info.id],
                        duplicateOf: store.duplicate(of: info)?.title,
                        moveTargets: store.moveTargets(from: info),
                        showsDesktop: showsClaudeDesktop && store.isDesktopInstalled,
                        onMove: { session, target in store.move(session, to: target) },
                        onMakeDefault: { store.makeDefault(info) },
                        onOpen: { store.openSession(info) },
                        onOpenDesktop: { store.openDesktop(info) },
                        onQuitDesktop: { store.quitDesktop(info) },
                        onRevealDesktop: { store.revealDesktopFolder(info) },
                        onLogIn: { store.logIn(info.seat) },
                        onReveal: { store.revealInFinder(info) },
                        onRemove: { confirmRemoval(info) }
                    )
                }
                if store.seats.count < 2 {
                    addHint
                }
            }
            .padding(10)
        }
        .frame(maxHeight: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// An NSAlert rather than a confirmationDialog: a dialog attached to the
    /// menu bar window closes together with it once focus moves.
    private func confirmRemoval(_ info: SeatInfo) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Remove \(info.email ?? info.title)?"
        alert.informativeText = "Deletes this account's folder and login. Shared memory, settings and skills stay."
        alert.addButton(withTitle: "Remove").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            store.remove(info)
        }
    }

    private var addHint: some View {
        Button {
            AddAccountWindowController.show()
        } label: {
            Label("Add another account", systemImage: "plus.circle")
                .font(.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.borderless)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                store.errorMessage = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 8) {
            if let action = store.lastAction {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(action)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .font(.caption)
                .transition(.opacity)
            }

            HStack(spacing: 8) {
                Button {
                    store.makeBestDefault()
                } label: {
                    Label("Best Quota", systemImage: "wand.and.stars")
                }
                .help("Use the account with the most quota left (5h and weekly) for new sessions")
                .disabled(store.seats.filter(\.isLoggedIn).count < 2)

                Spacer()

                if store.isRefreshingUsage {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    updates.checkForUpdates()
                } label: {
                    Image(systemName: updates.isUpdateAvailable
                        ? "arrow.down.circle.fill"
                        : "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(updates.isUpdateAvailable ? Color.accentColor : Color.primary)
                .help(updates.isUpdateAvailable
                    ? "Install Available Update"
                    : "Check for Updates")
                .accessibilityLabel(updates.isUpdateAvailable
                    ? "Update available"
                    : "Check for Updates")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .buttonStyle(.borderless)
                .help("Quit CSwap")
                .accessibilityLabel("Quit")
            }
            .font(.caption)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .animation(reduceMotion ? nil : Theme.expand, value: store.lastAction)
    }
}

/// MenuBarExtra's window grows with its content but does not shrink back when
/// rows, banners or session lists go away; the menu then floats centered in
/// a too-tall window with empty bands above and below. Keep the window's
/// height pinned to the content, anchored at the top edge below the menu bar.
private struct MenuWindowSizer: NSViewRepresentable {
    let contentHeight: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        let height = contentHeight
        DispatchQueue.main.async {
            guard let window = view.window, height > 0 else { return }
            let content = window.contentRect(forFrameRect: window.frame)
            guard abs(content.height - height) > 0.5 else { return }
            let target = NSRect(x: content.minX, y: content.maxY - height,
                                width: content.width, height: height)
            window.setFrame(window.frameRect(forContentRect: target), display: true)
        }
    }
}
