import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSChainResolver: ObservableObject {

    struct BladeTrace: Equatable {
        var a: CGPoint
        var b: CGPoint
        var radius: CGFloat

        init(a: CGPoint, b: CGPoint, radius: CGFloat = 10) {
            self.a = a
            self.b = b
            self.radius = max(0, radius)
        }
    }

    struct ResolveResult: Equatable {
        var didHit: Bool
        var didTrigger: Bool
        var didClear: Bool
        var scoreGained: Int
        var hitTileIDs: [UUID]
        var triggeredTileIDs: [UUID]
        var clearedTileIDs: [UUID]
    }
    
    
    
    

    private let minCluster: Int
    private let linkDistance: CGFloat
    private let scorePerTile: Int
    private let scorePerClusterBonus: Int

    init(
        minCluster: Int = 3,
        linkDistance: CGFloat = 22,
        scorePerTile: Int = 15,
        scorePerClusterBonus: Int = 25
    ) {
        self.minCluster = max(2, minCluster)
        self.linkDistance = max(0, linkDistance)
        self.scorePerTile = max(0, scorePerTile)
        self.scorePerClusterBonus = max(0, scorePerClusterBonus)
    }

    func applyBlade(_ trace: BladeTrace, to tiles: [GFSPuzzleTile], hitStrength: CGFloat = 1) -> ResolveResult {
        var hitIDs: [UUID] = []
        var triggeredIDs: [UUID] = []
        var clearedIDs: [UUID] = []
        var score = 0

        for t in tiles {
            if t.state == .cleared { continue }

            let hit = intersectsTile(trace: trace, tile: t)
            if hit {
                t.registerHit(strength: hitStrength)
                hitIDs.append(t.id)
            }
        }

        let chain = resolveChains(in: tiles)
        triggeredIDs = chain.triggered
        clearedIDs = chain.cleared
        score = chain.score

        return ResolveResult(
            didHit: !hitIDs.isEmpty,
            didTrigger: !triggeredIDs.isEmpty,
            didClear: !clearedIDs.isEmpty,
            scoreGained: score,
            hitTileIDs: hitIDs,
            triggeredTileIDs: triggeredIDs,
            clearedTileIDs: clearedIDs
        )
    }

    func resolveChains(in tiles: [GFSPuzzleTile]) -> ResolveResult {
        let chain = resolveChainsInternal(in: tiles)
        return ResolveResult(
            didHit: false,
            didTrigger: !chain.triggered.isEmpty,
            didClear: !chain.cleared.isEmpty,
            scoreGained: chain.score,
            hitTileIDs: [],
            triggeredTileIDs: chain.triggered,
            clearedTileIDs: chain.cleared
        )
    }

    private func resolveChainsInternal(in tiles: [GFSPuzzleTile]) -> (triggered: [UUID], cleared: [UUID], score: Int) {
        var visited: Set<UUID> = []
        var triggered: [UUID] = []
        var cleared: [UUID] = []
        var score = 0

        let active = tiles.filter { $0.state != .cleared }
        if active.isEmpty { return ([], [], 0) }

        for t in active {
            if visited.contains(t.id) { continue }
            if t.state == .idle { continue }

            let cluster = floodFill(from: t, tiles: active, visited: &visited)
            if cluster.count >= minCluster {
                for n in cluster {
                    if n.state != .cleared {
                        if n.state != .triggered {
                            n.trigger()
                            triggered.append(n.id)
                        }
                        if n.state == .cleared {
                            cleared.append(n.id)
                        }
                    }
                }

                let base = cluster.count * scorePerTile
                let bonus = max(0, (cluster.count - minCluster)) * scorePerClusterBonus
                score += base + bonus
            }
        }

        let postCleared = active.filter { $0.state == .cleared }.map(\.id)
        if !postCleared.isEmpty {
            var set = Set(cleared)
            for id in postCleared where !set.contains(id) {
                cleared.append(id)
                set.insert(id)
            }
        }

        return (triggered, cleared, score)
    }

    private func floodFill(from seed: GFSPuzzleTile, tiles: [GFSPuzzleTile], visited: inout Set<UUID>) -> [GFSPuzzleTile] {
        var out: [GFSPuzzleTile] = []
        var queue: [GFSPuzzleTile] = [seed]
        visited.insert(seed.id)

        while !queue.isEmpty {
            let cur = queue.removeFirst()
            out.append(cur)

            for n in tiles {
                if visited.contains(n.id) { continue }
                if n.kind != cur.kind { continue }
                if n.state == .idle || n.state == .cleared { continue }
                if isLinked(a: cur, b: n) == false { continue }

                visited.insert(n.id)
                queue.append(n)
            }
        }

        return out
    }

    private func isLinked(a: GFSPuzzleTile, b: GFSPuzzleTile) -> Bool {
        let dx = a.position.x - b.position.x
        let dy = a.position.y - b.position.y
        let d = sqrt(dx * dx + dy * dy)

        let ra = max(a.size.width, a.size.height) * 0.5
        let rb = max(b.size.width, b.size.height) * 0.5
        let threshold = ra + rb + linkDistance

        return d <= threshold
    }

    private func intersectsTile(trace: BladeTrace, tile: GFSPuzzleTile) -> Bool {
        let rect = CGRect(
            x: tile.position.x - tile.size.width * 0.5,
            y: tile.position.y - tile.size.height * 0.5,
            width: tile.size.width,
            height: tile.size.height
        )

        if rect.contains(trace.a) || rect.contains(trace.b) { return true }

        let inflated = rect.insetBy(dx: -trace.radius, dy: -trace.radius)
        if inflated.contains(trace.a) || inflated.contains(trace.b) { return true }

        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]

        for c in corners {
            if distancePointToSegment(p: c, a: trace.a, b: trace.b) <= trace.radius {
                return true
            }
        }

        let mid = CGPoint(x: (trace.a.x + trace.b.x) * 0.5, y: (trace.a.y + trace.b.y) * 0.5)
        if inflated.contains(mid) { return true }

        return false
    }

    private func distancePointToSegment(p: CGPoint, a: CGPoint, b: CGPoint) -> CGFloat {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y

        let ab2 = abx * abx + aby * aby
        if ab2 <= 0.000001 {
            let dx = p.x - a.x
            let dy = p.y - a.y
            return sqrt(dx * dx + dy * dy)
        }

        var t = (apx * abx + apy * aby) / ab2
        if t < 0 { t = 0 }
        if t > 1 { t = 1 }

        let cx = a.x + abx * t
        let cy = a.y + aby * t
        let dx = p.x - cx
        let dy = p.y - cy
        return sqrt(dx * dx + dy * dy)
    }
}


extension GFSChainResolver.ResolveResult {

    var triggered: [UUID] {
        triggeredTileIDs
    }

    var cleared: [UUID] {
        clearedTileIDs
    }

    var score: Int {
        scoreGained
    }
}
