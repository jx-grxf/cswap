import SwiftUI

/// Spacing, radii and motion for the popover and settings. Values follow the
/// other menu bar apps (PortPirate, NotchTray) so they feel like one family.
enum Theme {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16

    static let cardRadius: CGFloat = 12
    /// Nested rows (sessions, Desktop) sit inside a card with 12 pt padding,
    /// so 12 - 4 keeps the corners concentric.
    static let rowRadius: CGFloat = 8

    static let cardFill = Color.primary.opacity(0.035)
    static let cardHoverFill = Color.primary.opacity(0.06)
    static let rowFill = Color.primary.opacity(0.045)
    static let trackFill = Color.primary.opacity(0.08)

    static let hover = Animation.snappy(duration: 0.16)
    static let expand = Animation.snappy(duration: 0.22)
}

/// Fill for a usage meter: state colors only, picked where Claude Code
/// starts warning (around 85 %).
enum UsageTint {
    static func color(for utilization: Double) -> Color {
        switch utilization {
        case ..<60: return .green
        case ..<85: return .orange
        default: return .red
        }
    }
}
