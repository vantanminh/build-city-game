import CityCore
import SwiftUI

/// Compact top HUD displaying treasury, population, date, happiness, speed selector, and settings trigger.
struct TopBarView: View {
    @ObservedObject var controller: GameController

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                metricItem(
                    icon: "dollarsign.circle.fill",
                    iconColor: controller.money >= 0 ? .green : .red,
                    text: "$\(controller.money.formatted())",
                    textColor: controller.money >= 0 ? .primary : .red
                )

                metricItem(
                    icon: "person.2.fill",
                    iconColor: .blue,
                    text: controller.stats.population.formatted()
                )

                Text(controller.dateText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                metricItem(
                    icon: happinessSymbol(controller.stats.happiness),
                    iconColor: happinessColor(controller.stats.happiness),
                    text: "\(Int(controller.stats.happiness.rounded()))%"
                )

                Button {
                    controller.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .padding(6)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(GameSpeed.allCases, id: \.self) { option in
                        let selected = controller.speed == option
                        Button {
                            controller.speed = option
                        } label: {
                            Text(option.label)
                                .font(.caption2.bold().monospacedDigit())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(
                                    Capsule().fill(selected ? Color.accentColor : Color.primary.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()

                if let warning = controller.warningText {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text(warning)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9), in: Capsule())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    private func metricItem(
        icon: String,
        iconColor: Color,
        text: String,
        textColor: Color = .primary
    ) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(iconColor)
            Text(text)
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(textColor)
                .lineLimit(1)
        }
    }

    private func happinessSymbol(_ value: Double) -> String {
        if value >= 65 { return "face.smiling.fill" }
        if value >= 40 { return "face.smiling" }
        return "exclamationmark.circle.fill"
    }

    private func happinessColor(_ value: Double) -> Color {
        if value >= 65 { return .green }
        if value >= 40 { return .orange }
        return .red
    }
}
