import CityCore
import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var controller = GameController()

    var body: some View {
        ZStack {
            SpriteView(
                scene: controller.scene,
                preferredFramesPerSecond: 60,
                options: [.ignoresSiblingOrder]
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(controller.cityName)
                            .font(.headline)
                        if let point = controller.selectedGridPoint, controller.city.map.contains(point) {
                            let tile = controller.city.map[point]
                            Text("(\(point.x), \(point.y)) · \(L10n.tileKindName(tile.kind))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text(L10n.appTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Text("$\(controller.money.formatted())")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(controller.money >= 0 ? Color.primary : Color.red)
                    Button(L10n.newSeedButton) {
                        controller.newCity(
                            name: L10n.defaultCityName,
                            seed: UInt64.random(in: 1...999_999)
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                if let toast = controller.toast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.78), in: Capsule())
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                ToolbarView(selectedTool: $controller.selectedTool)
            }
            .animation(.easeInOut(duration: 0.2), value: controller.toast)
        }
    }
}
