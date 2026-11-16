import CityCore
import SwiftUI

/// Vertical R/C/I demand indicator showing positive growth above baseline and negative below.
struct DemandBarsView: View {
    let stats: CityStats

    var body: some View {
        HStack(spacing: 6) {
            demandColumn(label: "R", value: stats.resDemand, color: .green)
            demandColumn(label: "C", value: stats.comDemand, color: .blue)
            demandColumn(label: "I", value: stats.indDemand, color: .orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func demandColumn(label: String, value: Double, color: Color) -> some View {
        let clamped = max(-1.0, min(1.0, value))
        let halfBarHeight: CGFloat = 22

        return VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.primary.opacity(0.08))
                    .frame(width: 10, height: halfBarHeight * 2)

                VStack(spacing: 0) {
                    // Positive upper half
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(width: 10, height: halfBarHeight)
                        if clamped > 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color)
                                .frame(width: 10, height: halfBarHeight * CGFloat(clamped))
                        }
                    }

                    // Center zero baseline
                    Rectangle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 12, height: 1)

                    // Negative lower half
                    ZStack(alignment: .top) {
                        Color.clear
                            .frame(width: 10, height: halfBarHeight)
                        if clamped < 0 {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color.opacity(0.7))
                                .frame(width: 10, height: halfBarHeight * CGFloat(-clamped))
                        }
                    }
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
    }
}
