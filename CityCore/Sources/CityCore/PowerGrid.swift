import Foundation

/// Computes connected electrical grids across conducting tiles using 4-way BFS.
public enum PowerGrid {
    /// Recomputes `powered` across all tiles in `map` and returns any coordinates whose `powered` flag changed.
    @discardableResult
    public static func recompute(_ map: inout CityMap) -> [GridPoint] {
        let width = map.width
        let height = map.height
        var visited = Array(repeating: false, count: width * height)
        var newPowered = Array(repeating: false, count: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let startIdx = y * width + x
                guard !visited[startIdx] else { continue }

                let startPoint = GridPoint(x: x, y: y)
                let startTile = map[startPoint]
                guard startTile.kind.conductsPower else {
                    visited[startIdx] = true
                    continue
                }

                // Deterministic 4-way BFS over this connected conductive component.
                var queue: [GridPoint] = [startPoint]
                var head = 0
                visited[startIdx] = true
                var plantCount = 0

                while head < queue.count {
                    let current = queue[head]
                    head += 1

                    if map[current].kind == .powerPlant {
                        plantCount += 1
                    }

                    for neighbor in map.neighbors4(current) {
                        let nIdx = neighbor.y * width + neighbor.x
                        guard !visited[nIdx] else { continue }
                        if map[neighbor].kind.conductsPower {
                            visited[nIdx] = true
                            queue.append(neighbor)
                        }
                    }
                }

                var remainingCapacity = plantCount * Balance.powerPlantCapacity
                for point in queue {
                    let idx = point.y * width + point.x
                    let kind = map[point].kind
                    if kind.consumesPower {
                        if remainingCapacity > 0 {
                            newPowered[idx] = true
                            remainingCapacity -= 1
                        } else {
                            newPowered[idx] = false
                        }
                    } else {
                        newPowered[idx] = plantCount > 0
                    }
                }
            }
        }

        var changed: [GridPoint] = []
        for y in 0..<height {
            for x in 0..<width {
                let point = GridPoint(x: x, y: y)
                let idx = y * width + x
                if map[point].powered != newPowered[idx] {
                    var tile = map[point]
                    tile.powered = newPowered[idx]
                    map[point] = tile
                    changed.append(point)
                }
            }
        }
        return changed
    }
}
