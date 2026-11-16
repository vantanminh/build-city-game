import CityCore
import Foundation
import SwiftUI

/// Renderer bridge notified whenever map tiles change visually.
@MainActor
protocol CityRenderer: AnyObject {
    func refresh(_ points: [GridPoint])
    func reloadAll()
    func animatePlacement(at point: GridPoint)
}

/// Central @MainActor coordinator connecting `CityCore.City`, `CityScene`, and SwiftUI HUD.
@MainActor
final class GameController: ObservableObject {
    @Published private(set) var cityName: String
    @Published private(set) var money: Int
    @Published private(set) var stats: CityStats
    @Published var selectedTool: Tool = .inspect
    @Published var selectedGridPoint: GridPoint?

    private(set) var city: City
    let scene: CityScene

    init(city: City = City(name: L10n.defaultCityName, seed: UInt64.random(in: 1...999_999))) {
        self.city = city
        self.cityName = city.name
        self.money = city.money
        self.stats = city.stats
        self.scene = CityScene()
        self.scene.controller = self
    }

    func tap(at point: GridPoint) {
        guard city.map.contains(point) else { return }
        selectedGridPoint = point
    }

    func paint(from start: GridPoint?, to end: GridPoint) {
        // Implemented in M3.
        guard city.map.contains(end) else { return }
        selectedGridPoint = end
    }

    func canPlaceHighlight(at point: GridPoint) -> Bool {
        guard city.map.contains(point) else { return false }
        let tile = city.map[point]
        switch selectedTool {
        case .inspect:
            return true
        case .bulldoze:
            return tile.kind != .water
        default:
            if tile.kind == .water { return false }
            if let target = selectedTool.resultingKind, tile.kind == target { return true }
            return !tile.kind.isBuilt
        }
    }

    func advance(dt: TimeInterval) {
        // Simulation loop wired in M4.
    }

    func newCity(name: String, seed: UInt64) {
        city = City(name: name, seed: seed)
        cityName = city.name
        money = city.money
        stats = city.stats
        selectedGridPoint = nil
        scene.reloadAll()
        scene.centerCamera()
    }
}
