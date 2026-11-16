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

/// Detailed tile inspection payload shown when tapping a tile in `inspect` mode.
struct InspectedTile: Equatable {
    let point: GridPoint
    let tile: Tile
    let desirability: Int
}

/// Central @MainActor coordinator connecting `CityCore.City`, `CityScene`, and SwiftUI HUD.
@MainActor
final class GameController: ObservableObject {
    @Published private(set) var cityName: String
    @Published private(set) var money: Int
    @Published private(set) var stats: CityStats
    @Published private(set) var dateText: String
    @Published private(set) var history: [MonthRecord]
    @Published private(set) var monthlyBudget: MonthlyBudget
    @Published var selectedTool: Tool = .inspect {
        didSet {
            if selectedTool != .inspect {
                inspected = nil
            }
        }
    }
    @Published var speed: GameSpeed = .normal
    @Published var taxRate: Int {
        didSet {
            let clamped = max(Balance.minTaxRate, min(Balance.maxTaxRate, taxRate))
            if taxRate != clamped {
                taxRate = clamped
                return
            }
            city.taxRate = clamped
            Simulation.recomputeStats(city: city)
            stats = city.stats
            monthlyBudget = Economy.estimateMonthlyBudget(for: city)
        }
    }
    @Published var selectedGridPoint: GridPoint?
    @Published var inspected: InspectedTile?
    @Published var showSettings: Bool = false
    @Published var isBankrupt: Bool = false
    @Published var isPlaying: Bool = false
    @Published private(set) var savedPreview: SaveGame?
    @Published private(set) var warningText: String?
    @Published private(set) var toast: String?

    private(set) var city: City
    let scene: CityScene
    private let saveStore: SaveStore

    private var simRng: SeededRandomNumberGenerator
    private var accumulatedTime: TimeInterval = 0
    private var toastTask: Task<Void, Never>?
    private var lastErrorFeedbackAt: Date = .distantPast

    init(saveStore: SaveStore = SaveStore()) {
        self.saveStore = saveStore
        let initialCity: City
        let initialRngState: UInt64
        var preview: SaveGame?
        var corruptDetected = false

        switch saveStore.load() {
        case .loaded(let loadedCity, let snapshot):
            initialCity = loadedCity
            initialRngState = loadedCity.savedRngState
            preview = snapshot
        case .corrupted:
            let seed = UInt64.random(in: 1...999_999)
            initialCity = City(name: L10n.defaultCityName, seed: seed)
            initialCity.refreshInfrastructure()
            initialRngState = seed
            corruptDetected = true
        case .missing:
            let seed = UInt64.random(in: 1...999_999)
            initialCity = City(name: L10n.defaultCityName, seed: seed)
            initialCity.refreshInfrastructure()
            initialRngState = seed
        }

        self.city = initialCity
        self.savedPreview = preview
        self.cityName = initialCity.name
        self.money = initialCity.money
        self.stats = initialCity.stats
        self.taxRate = initialCity.taxRate
        self.history = initialCity.history
        self.monthlyBudget = Economy.estimateMonthlyBudget(for: initialCity)
        self.dateText = L10n.dateLabel(month: initialCity.date.month, year: initialCity.date.year)
        self.simRng = SeededRandomNumberGenerator(state: initialRngState)
        self.scene = CityScene()
        self.scene.controller = self
        updateWarning()

        if corruptDetected {
            showToast(L10n.corruptSaveToast, duration: 4.0)
        }
    }

    func tap(at point: GridPoint) {
        guard city.map.contains(point) else { return }
        selectedGridPoint = point
        if selectedTool == .inspect {
            city.refreshInfrastructure()
            inspected = InspectedTile(
                point: point,
                tile: city.map[point],
                desirability: city.desirability(at: point)
            )
            return
        }
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
            monthlyBudget = Economy.estimateMonthlyBudget(for: city)
            updateWarning()
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
        guard speed.rawValue > 0, !isBankrupt else { return }
        accumulatedTime += dt
        let stepInterval = 1.0 / Double(speed.rawValue)

        var steps = 0
        var changed: Set<GridPoint> = []
        var events: [CityEvent] = []
        while accumulatedTime >= stepInterval && steps < 5 {
            accumulatedTime -= stepInterval
            steps += 1
            let result = city.step(rng: &simRng)
            for p in result.changed {
                changed.insert(p)
            }
            events.append(contentsOf: result.events)
        }

        guard steps > 0 else { return }
        if !changed.isEmpty {
            scene.refresh(Array(changed))
        }
        stats = city.stats
        money = city.money
        history = city.history
        monthlyBudget = Economy.estimateMonthlyBudget(for: city)
        dateText = L10n.dateLabel(month: city.date.month, year: city.date.year)
        updateWarning()

        if let currentInspected = inspected {
            inspected = InspectedTile(
                point: currentInspected.point,
                tile: city.map[currentInspected.point],
                desirability: city.desirability(at: currentInspected.point)
            )
        }

        for event in events {
            switch event {
            case .milestone(let label):
                showToast(L10n.milestoneToast(label), duration: 3.0)
            case .monthEnded:
                save(showFeedback: false)
            case .bankrupt:
                speed = .paused
                isBankrupt = true
            }
        }
    }

    func cycleSpeed() {
        speed = speed.next
    }

    func continueSavedCity() {
        switch saveStore.load() {
        case .loaded(let loadedCity, let snapshot):
            savedPreview = snapshot
            applyLoadedCity(loadedCity, rngState: loadedCity.savedRngState)
            isPlaying = true
        case .corrupted:
            savedPreview = nil
            showToast(L10n.corruptSaveToast, duration: 4.0)
        case .missing:
            savedPreview = nil
        }
    }

    func newCity(name: String, seed: UInt64) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmed.isEmpty ? L10n.defaultCityName : trimmed
        let created = City(name: resolvedName, seed: seed)
        created.refreshInfrastructure()
        applyLoadedCity(created, rngState: seed)
        isPlaying = true
        save(showFeedback: false)
    }

    func save(showFeedback: Bool = false) {
        let snapshot = city.snapshot(rngState: simRng.state)
        do {
            try saveStore.save(snapshot)
            savedPreview = snapshot
            if showFeedback {
                showToast(L10n.savedToast)
            }
        } catch {
            if showFeedback {
                showToast(L10n.saveFailedToast)
            }
        }
    }

    func returnToStartMenu() {
        save(showFeedback: false)
        speed = .paused
        inspected = nil
        showSettings = false
        isPlaying = false
    }

    private func applyLoadedCity(_ nextCity: City, rngState: UInt64) {
        city = nextCity
        simRng = SeededRandomNumberGenerator(state: rngState)
        accumulatedTime = 0
        cityName = city.name
        money = city.money
        stats = city.stats
        taxRate = city.taxRate
        history = city.history
        monthlyBudget = Economy.estimateMonthlyBudget(for: city)
        dateText = L10n.dateLabel(month: city.date.month, year: city.date.year)
        selectedGridPoint = nil
        inspected = nil
        isBankrupt = false
        speed = .normal
        toast = nil
        updateWarning()
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
            monthlyBudget = Economy.estimateMonthlyBudget(for: city)
            updateWarning()
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

    private func updateWarning() {
        if city.money < 0 {
            warningText = L10n.warningNegativeMoney()
        } else if city.stats.unpoweredCount >= 3 {
            warningText = L10n.warningUnpowered(city.stats.unpoweredCount)
        } else if city.stats.noRoadCount >= 3 {
            warningText = L10n.warningNoRoad(city.stats.noRoadCount)
        } else {
            warningText = nil
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
