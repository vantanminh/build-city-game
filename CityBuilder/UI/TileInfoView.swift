import CityCore
import SwiftUI

/// Compact inspection card displayed when tapping a tile with the `inspect` tool.
struct TileInfoView: View {
    let info: InspectedTile
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tileKindName(info.tile.kind))
                        .font(.subheadline.bold())
                    Text("(\(info.point.x), \(info.point.y))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            HStack(spacing: 14) {
                if info.tile.kind.isZone {
                    statBadge(label: L10n.inspectLevel, value: "\(info.tile.level)/3", color: .blue)
                }

                if info.tile.kind.consumesPower {
                    statBadge(
                        label: L10n.inspectPower,
                        value: info.tile.powered ? L10n.poweredYes : L10n.poweredNo,
                        color: info.tile.powered ? .green : .orange
                    )
                }

                if info.tile.kind.isBuilt && info.tile.kind != .road {
                    statBadge(
                        label: L10n.inspectRoad,
                        value: info.tile.hasRoadAccess ? L10n.roadYes : L10n.roadNo,
                        color: info.tile.hasRoadAccess ? .green : .red
                    )
                }

                statBadge(
                    label: L10n.inspectDesirability,
                    value: "\(info.desirability)/100",
                    color: info.desirability >= 65 ? .green : (info.desirability >= 40 ? .primary : .orange)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    private func statBadge(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}
