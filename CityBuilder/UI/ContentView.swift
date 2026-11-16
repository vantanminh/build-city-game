import CityCore
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.blue)
            Text(L10n.appTitle)
                .font(.largeTitle.bold())
            Text(L10n.appSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("CityCore v\(CityCoreInfo.version)")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding()
    }
}
