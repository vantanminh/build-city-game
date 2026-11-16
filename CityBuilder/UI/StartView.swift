import CityCore
import SwiftUI

/// Launch screen allowing the player to continue a saved city or start a new seeded city.
struct StartView: View {
    @ObservedObject var controller: GameController

    @State private var cityNameInput: String = L10n.defaultCityName
    @State private var seedInput: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    if let toast = controller.toast {
                        Text(toast)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.92), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if let saved = controller.savedPreview {
                        continueCard(for: saved)
                    }

                    newCityCard
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.25, blue: 0.39),
                        Color(red: 0.18, green: 0.36, blue: 0.44),
                        Color(red: 0.22, green: 0.44, blue: 0.38)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white, .blue)
                .shadow(radius: 6)

            Text(L10n.appTitle)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text(L10n.startSubtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.top, 18)
    }

    private func continueCard(for saved: SaveGame) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(saved.name)
                        .font(.title3.bold())
                    Text("\(L10n.dateLabel(month: saved.date.month, year: saved.date.year)) · Dân: \(saved.stats.population.formatted()) · $\(saved.money.formatted())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                controller.continueSavedCity()
            } label: {
                Label(L10n.continueGame, systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var newCityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.newCitySection)
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.cityNameField)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(L10n.defaultCityName, text: $cityNameInput)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.seedField)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("VD: 123456", text: $seedInput)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.asciiCapable)
                    Button(L10n.randomSeedLabel) {
                        seedInput = String(UInt64.random(in: 1...999_999))
                    }
                    .buttonStyle(.bordered)
                }
            }

            Button {
                let seed = resolveSeed(from: seedInput)
                controller.newCity(name: cityNameInput, seed: seed)
            } label: {
                Label(L10n.startBuilding, systemImage: "hammer.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func resolveSeed(from raw: String) -> UInt64 {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return UInt64.random(in: 1...999_999)
        }
        if let parsed = UInt64(trimmed) {
            return parsed
        }
        // Deterministic FNV-1a 64-bit hash for text seeds.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in trimmed.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash
    }
}
