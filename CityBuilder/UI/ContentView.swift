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

            VStack(spacing: 8) {
                TopBarView(controller: controller)

                HStack(alignment: .top) {
                    DemandBarsView(stats: controller.stats)
                        .padding(.leading, 10)
                    Spacer()
                }

                if let toast = controller.toast {
                    Text(toast)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.78), in: Capsule())
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer()

                if let inspected = controller.inspected {
                    TileInfoView(info: inspected) {
                        controller.inspected = nil
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                ToolbarView(selectedTool: $controller.selectedTool)
            }
            .animation(.easeInOut(duration: 0.2), value: controller.toast)
            .animation(.easeInOut(duration: 0.2), value: controller.inspected)
        }
        .sheet(isPresented: $controller.showSettings) {
            SettingsSheet(controller: controller)
        }
        .alert(L10n.bankruptTitle, isPresented: $controller.isBankrupt) {
            Button(L10n.playAgainLabel) {
                controller.newCity(
                    name: L10n.defaultCityName,
                    seed: UInt64.random(in: 1...999_999)
                )
            }
        } message: {
            Text(L10n.bankruptMessage)
        }
    }
}
