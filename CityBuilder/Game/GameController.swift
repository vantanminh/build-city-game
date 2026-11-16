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

/// Simulation time progression speeds.
enum GameSpeed: Int, CaseIterable, Codable {
    case paused = 0
    case normal = 1
    case fast = 3
    case ultra = 10

    var label: String {
        switch self {
        case .paused: return "⏸"
        case .normal: return "1×"
        case .fast: return "3×"
        case .ultra: return "10×"
        }
    }

    var next: GameSpeed {
        switch self {
        case .paused: return .normal
        case .normal: return .fast
        case .fast: return .ultra
        case .ultra: return .paused
        }
    }
}

/// Central @MainActor coordinator connecting `CityCore.City`, `CityScene`, and SwiftUI HUD.
@MainActor
final class GameController: ObservableObject {
    @Published private(set) var cityName: String
    @Published private(set) var money: Int
    @Published private(set) var stats: CityStats
    @Published private(set) var dateText: String
    @Published var selectedTool: Tool = .inspect
    @Published var speed: GameSpeed = .normal
    @Published var selectedGridPoint: GridPoint?
    @Published private(set) var toast: String?

    private(set) var city: City
    let scene: CityScene

    private var simRng: SeededRandomNumberGenerator
    private var accumulatedTime: TimeInterval = 0
    private var toastTask: Task<Void, Never>?
    private var lastErrorFeedbackAt: Date = .distantPast

    init(city: City = City(name: L10n.defaultCityName, seed: UInt64.random(in: 1...999_999))) {
        self.city = city
        self.cityName = city.name
        self.money = city.money
        self.stats = city.stats
        self.dateText = L10n.dateLabel(month: city.date.month, year: city.date.year)
        self.simRng = SeededRandomNumberGenerator(seed: city.seed)
        self.scene = CityScene()
        self.scene.controller = self
    }

    func tap(at point: GridPoint) {
        guard city.map.contains(point) else { return }
        selectedGridPoint = point
        guard selectedTool != .inspect else { return }
        applySingleTool(at: point)
    }

    func paint(from start: GridPoint?, to end: GridPoint) {
        guard selectedTool != .inspect, isDragPaintable(selectedTool) else { return }

        let points: [GridPoint] = start.map { IsoMath.gridLine(from: $0, to: end) } ?? [end]
        var changedPoints: Set<GridPoint> = []
        var animatedPoints: [GridPoint] = []
        var outOfMoney = false
        var blockedReason: String?

        for p in points where city.map.contains(p) {
            let result = city.apply(selectedTool, at: p)
            switch result {
            case .placed:
                changedPoints.insert(p)
                if selectedTool == .road || selectedTool == .bulldoze {
                    for neighbor in city.map.neighbors4(p) {
                        changedPoints.insert(neighbor)
                    }
                }
                animatedPoints.append(p)
            case .unchanged:
                break
            case .notEnoughMoney:
                outOfMoney = true
            case .blocked(let reason):
                blockedReason = reason
            }
        }

        if !changedPoints.isEmpty {
            for infraPt in city.refreshInfrastructure() {
                changedPoints.insert(infraPt)
            }
            money = city.money
            stats = city.stats
            scene.refresh(Array(changedPoints))
            for p in animatedPoints {
                scene.animatePlacement(at: p)
            }
            Haptics.placementSuccess()
        }

        if outOfMoney {
            triggerErrorFeedback(L10n.notEnoughMoney, isDrag: true)
        } else if changedPoints.isEmpty, let reason = blockedReason {
            triggerErrorFeedback(reason, isDrag: true)
        }
    }

    func isDragPaintable(_ tool: Tool) -> Bool {
        switch tool {
        case .road, .residential, .commercial, .industrial, .park, .bulldoze:
            return true
        case .inspect, .powerPlant, .school, .hospital:
            return false
        }
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
        guard speed.rawValue > 0 else { return }
        accumulatedTime += dt
        let stepInterval = 1.0 / Double(speed.rawValue)

        var steps = 0
        var changed: Set<GridPoint> = []
        while accumulatedTime >= stepInterval && steps < 5 {
            accumulatedTime -= stepInterval
            steps += 1
            let result = city.step(rng: &simRng)
            for p in result.changed {
                changed.insert(p)
            }
        }

        guard steps > 0 else { return }
        if !changed.isEmpty {
            scene.refresh(Array(changed))
        }
        stats = city.stats
        money = city.money
        dateText = L10n.dateLabel(month: city.date.month, year: city.date.year)
    }

    func cycleSpeed() {
        speed = speed.next
    }

    func newCity(name: String, seed: UInt64) {
        city = City(name: name, seed: seed)
        simRng = SeededRandomNumberGenerator(seed: seed)
        accumulatedTime = 0
        cityName = city.name
        money = city.money
        stats = city.stats
        dateText = L10n.dateLabel(month: city.date.month, year: city.date.year)
        selectedGridPoint = nil
        toast = nil
        scene.reloadAll()
        scene.centerCamera()
    }

    func showToast(_ message: String, duration: TimeInterval = 2.0) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }

    private func applySingleTool(at point: GridPoint) {
        let result = city.apply(selectedTool, at: point)
        switch result {
        case .placed:
            var changed = Set([point])
            if selectedTool == .road || selectedTool == .bulldoze {
                for neighbor in city.map.neighbors4(point) {
                    changed.insert(neighbor)
                }
            }
            for infraPt in city.refreshInfrastructure() {
                changed.insert(infraPt)
            }
            money = city.money
            stats = city.stats
            scene.refresh(Array(changed))
            scene.animatePlacement(at: point)
            Haptics.placementSuccess()
        case .unchanged:
            break
        case .notEnoughMoney:
            triggerErrorFeedback(L10n.notEnoughMoney, isDrag: false)
        case .blocked(let reason):
            triggerErrorFeedback(reason, isDrag: false)
        }
    }

    private func triggerErrorFeedback(_ message: String, isDrag: Bool) {
        let now = Date()
        if isDrag && now.timeIntervalSince(lastErrorFeedbackAt) < 0.8 {
            return
        }
        lastErrorFeedbackAt = now
        Haptics.placementError()
        showToast(message)
    }
}
