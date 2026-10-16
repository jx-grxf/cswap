import CSwapKit
import SwiftUI

/// A compact labelled usage meter (e.g. "5h ▓▓▓░ 9% · resets in 2h 10m").
struct UsageBarView: View {
    let label: String
    let window: UsageWindow

    var body: some View {
        HStack(spacing: Theme.s2) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(minWidth: 24, alignment: .leading)
                .fixedSize()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.trackFill)
                    Capsule()
                        .fill(UsageTint.color(for: window.currentUtilization))
                        .frame(width: max(5, geo.size.width * window.fraction))
                }
            }
            .frame(height: 5)

            Text("\(Int(window.currentUtilization.rounded()))%")
                .font(.caption2.monospacedDigit().weight(.medium))
                .frame(width: 34, alignment: .trailing)

            // Always reserve the column so every bar in the menu lines up.
            Text(window.resetText ?? "")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .frame(width: 96, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) usage")
        .accessibilityValue("\(Int(window.currentUtilization.rounded())) percent\(window.resetText.map { ", \($0)" } ?? "")")
    }
}
