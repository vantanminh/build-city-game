import Foundation

/// Deterministic procedural terrain generator for new cities.
public enum TerrainGenerator {
    /// Generates a square city map using the given seed.
    public static func generate(size: Int = Balance.defaultMapSize, seed: UInt64) -> CityMap {
        generate(width: size, height: size, seed: seed)
    }

    /// Generates a city map of `width x height` tiles deterministically from `seed`.
    public static func generate(width: Int, height: Int, seed: UInt64) -> CityMap {
        var map = CityMap(width: width, height: height)
        var rng = SeededRandomNumberGenerator(seed: seed)

        // Assign fixed per-tile visual variant so grass/forests/buildings stay consistent.
        for y in 0..<height {
            for x in 0..<width {
                let p = GridPoint(x: x, y: y)
                var tile = map[p]
                tile.variant = UInt8(rng.next() & 0xFF)
                map[p] = tile
            }
        }

        let center = GridPoint(x: width / 2, y: height / 2)
        let isCenterProtected: (GridPoint) -> Bool = { p in
            p.chebyshevDistance(to: center) <= Balance.centerClearRadius
        }

        // Choose between a meandering river or 1-3 lakes.
        let useRiver = (rng.next() & 1) == 0 && min(width, height) > (Balance.centerClearRadius * 2 + 6)
        if useRiver {
            carveRiver(into: &map, rng: &rng, isProtected: isCenterProtected)
        } else {
            let lakeCount = Int.random(in: 1...3, using: &rng)
            carveLakes(count: lakeCount, into: &map, rng: &rng, isProtected: isCenterProtected)
        }

        plantForests(into: &map, rng: &rng, isProtected: isCenterProtected)
        return map
    }

    private static func carveRiver(
        into map: inout CityMap,
        rng: inout SeededRandomNumberGenerator,
        isProtected: (GridPoint) -> Bool
    ) {
        let horizontal = (rng.next() & 1) == 0
        let crossLength = horizontal ? map.height : map.width
        let runLength = horizontal ? map.width : map.height
        let centerCoord = crossLength / 2
        let margin = Balance.centerClearRadius + 3

        // Pick a starting lane clearly above or below the protected center zone.
        var candidates: [Int] = []
        if centerCoord - margin >= 2 {
            candidates.append(contentsOf: 2...(centerCoord - margin))
        }
        if centerCoord + margin <= crossLength - 3 {
            candidates.append(contentsOf: (centerCoord + margin)...(crossLength - 3))
        }
        guard !candidates.isEmpty else { return }

        var pos = candidates[Int.random(in: 0..<candidates.count, using: &rng)]
        let riverWidth = Int.random(in: 2...3, using: &rng)

        for step in 0..<runLength {
            let driftRoll = Double.random(in: 0..<1, using: &rng)
            if driftRoll < 0.22 {
                pos += (rng.next() & 1) == 0 ? 1 : -1
                pos = max(1, min(crossLength - riverWidth - 1, pos))
            }

            for offset in 0..<riverWidth {
                let p = horizontal
                    ? GridPoint(x: step, y: pos + offset)
                    : GridPoint(x: pos + offset, y: step)
                if map.contains(p) && !isProtected(p) {
                    var tile = map[p]
                    tile.kind = .water
                    map[p] = tile
                }
            }
        }
    }

    private static func carveLakes(
        count: Int,
        into map: inout CityMap,
        rng: inout SeededRandomNumberGenerator,
        isProtected: (GridPoint) -> Bool
    ) {
        for _ in 0..<count {
            guard let seedPoint = randomUnprotectedPoint(
                in: map,
                requiring: .grass,
                rng: &rng,
                isProtected: isProtected
            ) else { continue }

            let targetSize = Int.random(in: 25...75, using: &rng)
            growBlob(
                from: seedPoint,
                targetCount: targetSize,
                kind: .water,
                into: &map,
                rng: &rng,
                isProtected: isProtected
            )
        }
    }

    private static func plantForests(
        into map: inout CityMap,
        rng: inout SeededRandomNumberGenerator,
        isProtected: (GridPoint) -> Bool
    ) {
        let totalTiles = map.width * map.height
        let ratio = Double.random(in: Balance.forestMinRatio...Balance.forestMaxRatio, using: &rng)
        let targetForestTiles = Int(Double(totalTiles) * ratio)
        var placedForest = 0
        var attempts = 0
        let maxAttempts = max(100, totalTiles / 2)

        while placedForest < targetForestTiles && attempts < maxAttempts {
            attempts += 1
            guard let seedPoint = randomUnprotectedPoint(
                in: map,
                requiring: .grass,
                rng: &rng,
                isProtected: isProtected
            ) else { break }

            let remaining = targetForestTiles - placedForest
            let clusterTarget = min(remaining, Int.random(in: 6...18, using: &rng))
            placedForest += growBlob(
                from: seedPoint,
                targetCount: clusterTarget,
                kind: .forest,
                into: &map,
                rng: &rng,
                isProtected: isProtected
            )
        }
    }

    private static func randomUnprotectedPoint(
        in map: CityMap,
        requiring kind: TileKind,
        rng: inout SeededRandomNumberGenerator,
        isProtected: (GridPoint) -> Bool
    ) -> GridPoint? {
        for _ in 0..<200 {
            let p = GridPoint(
                x: Int.random(in: 0..<map.width, using: &rng),
                y: Int.random(in: 0..<map.height, using: &rng)
            )
            if !isProtected(p) && map[p].kind == kind {
                return p
            }
        }
        return nil
    }

    @discardableResult
    private static func growBlob(
        from start: GridPoint,
        targetCount: Int,
        kind: TileKind,
        into map: inout CityMap,
        rng: inout SeededRandomNumberGenerator,
        isProtected: (GridPoint) -> Bool
    ) -> Int {
        guard targetCount > 0, !isProtected(start), map[start].kind == .grass else { return 0 }

        var frontier: [GridPoint] = [start]
        var placed = 0

        while !frontier.isEmpty && placed < targetCount {
            let idx = Int.random(in: 0..<frontier.count, using: &rng)
            let current = frontier.remove(at: idx)
            guard !isProtected(current), map[current].kind == .grass else { continue }

            var tile = map[current]
            tile.kind = kind
            map[current] = tile
            placed += 1

            for neighbor in map.neighbors4(current) {
                if !isProtected(neighbor) && map[neighbor].kind == .grass {
                    frontier.append(neighbor)
                }
            }
        }

        return placed
    }
}
