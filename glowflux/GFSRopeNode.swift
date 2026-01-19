import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSRopeNode: ObservableObject, Identifiable {

    struct Point: Identifiable, Equatable {
        let id: UUID
        var p: CGPoint
        var v: CGVector
        var radius: CGFloat
        var invMass: CGFloat
        var isPinned: Bool
        var isActive: Bool

        init(
            id: UUID = UUID(),
            p: CGPoint,
            v: CGVector = .zero,
            radius: CGFloat = 3.5,
            invMass: CGFloat = 1.0,
            isPinned: Bool = false,
            isActive: Bool = true
        ) {
            self.id = id
            self.p = p
            self.v = v
            self.radius = max(0.5, radius)
            self.invMass = max(0.0, invMass)
            self.isPinned = isPinned
            self.isActive = isActive
        }
    }

    struct Link: Identifiable, Equatable {
        let id: UUID
        var a: UUID
        var b: UUID
        var rest: CGFloat
        var stiffness: CGFloat
        var isActive: Bool

        init(
            id: UUID = UUID(),
            a: UUID,
            b: UUID,
            rest: CGFloat,
            stiffness: CGFloat = 0.85,
            isActive: Bool = true
        ) {
            self.id = id
            self.a = a
            self.b = b
            self.rest = max(0.25, rest)
            self.stiffness = max(0.0, min(1.0, stiffness))
            self.isActive = isActive
        }
    }

    struct CutEvent: Identifiable, Equatable {
        let id: UUID
        let at: TimeInterval
        let linkId: UUID
        let a: UUID
        let b: UUID
    }

    @Published private(set) var points: [Point] = []
    @Published private(set) var links: [Link] = []
    @Published private(set) var recentCuts: [CutEvent] = []

    @Published var gravity: CGVector = CGVector(dx: 0, dy: 780)
    @Published var damping: CGFloat = 0.985
    @Published var drag: CGFloat = 0.0

    private var indexById: [UUID: Int] = [:]

    init() {}

    func reset() {
        points.removeAll()
        links.removeAll()
        recentCuts.removeAll()
        indexById.removeAll()
    }

    func buildLine(
        from a: CGPoint,
        to b: CGPoint,
        segments: Int,
        pointRadius: CGFloat = 3.5,
        stiffness: CGFloat = 0.88,
        pinStart: Bool = true,
        pinEnd: Bool = false
    ) {
        reset()

        let segs = max(1, segments)
        let totalDx = b.x - a.x
        let totalDy = b.y - a.y
        let step = 1.0 / CGFloat(segs)

        let rest = hypot(totalDx, totalDy) / CGFloat(segs)

        var ids: [UUID] = []
        ids.reserveCapacity(segs + 1)

        for i in 0...segs {
            let t = CGFloat(i) * step
            let p = CGPoint(x: a.x + totalDx * t, y: a.y + totalDy * t)
            let pinned = (i == 0 && pinStart) || (i == segs && pinEnd)

            let invMass: CGFloat = pinned ? 0.0 : 1.0

            let node = Point(
                p: p,
                v: .zero,
                radius: pointRadius,
                invMass: invMass,
                isPinned: pinned,
                isActive: true
            )
            points.append(node)
            ids.append(node.id)
        }

        rebuildIndex()

        for i in 0..<segs {
            let link = Link(a: ids[i], b: ids[i + 1], rest: rest, stiffness: stiffness, isActive: true)
            links.append(link)
        }
    }

    func pin(_ pointId: UUID, at position: CGPoint? = nil) {
        guard let i = indexById[pointId] else { return }
        points[i].isPinned = true
        points[i].invMass = 0.0
        if let position { points[i].p = position }
    }

    func unpin(_ pointId: UUID) {
        guard let i = indexById[pointId] else { return }
        points[i].isPinned = false
        points[i].invMass = 1.0
    }

    func setPointPosition(_ pointId: UUID, _ p: CGPoint, zeroVelocity: Bool = true) {
        guard let i = indexById[pointId] else { return }
        points[i].p = p
        if zeroVelocity { points[i].v = .zero }
    }

    func step(dt: CGFloat, iterations: Int = 4, bounds: CGRect? = nil) {
        if points.isEmpty { return }

        let h = max(0, dt)
        integrate(h, bounds: bounds)

        let it = max(1, min(24, iterations))
        for _ in 0..<it {
            satisfyLinks()
            if let bounds { collideBounds(bounds) }
        }
    }

    func cutNearest(to p: CGPoint, radius: CGFloat, now: TimeInterval) -> Bool {
        guard links.isEmpty == false else { return false }
        let rr = max(0.5, radius)

        var bestIndex: Int? = nil
        var bestDist2: CGFloat = .greatestFiniteMagnitude

        for i in links.indices {
            if links[i].isActive == false { continue }
            guard let ai = indexById[links[i].a], let bi = indexById[links[i].b] else { continue }

            let a = points[ai].p
            let b = points[bi].p
            let c = closestPointOnSegment(p, a, b)

            let dx = p.x - c.x
            let dy = p.y - c.y
            let d2 = dx * dx + dy * dy

            if d2 < bestDist2 {
                bestDist2 = d2
                bestIndex = i
            }
        }

        guard let idx = bestIndex else { return false }
        if bestDist2 > rr * rr { return false }

        let link = links[idx]
        links[idx].isActive = false

        recentCuts.append(
            CutEvent(id: UUID(), at: now, linkId: link.id, a: link.a, b: link.b)
        )
        if recentCuts.count > 24 {
            recentCuts.removeFirst(recentCuts.count - 24)
        }
        return true
    }

    func activeSegments() -> [(CGPoint, CGPoint)] {
        var out: [(CGPoint, CGPoint)] = []
        out.reserveCapacity(links.count)

        for l in links where l.isActive {
            guard let ai = indexById[l.a], let bi = indexById[l.b] else { continue }
            out.append((points[ai].p, points[bi].p))
        }
        return out
    }

    func totalLength() -> CGFloat {
        var sum: CGFloat = 0
        for l in links where l.isActive {
            guard let ai = indexById[l.a], let bi = indexById[l.b] else { continue }
            let a = points[ai].p
            let b = points[bi].p
            sum += hypot(b.x - a.x, b.y - a.y)
        }
        return sum
    }

    private func integrate(_ dt: CGFloat, bounds: CGRect?) {
        let g = gravity
        let damp = max(0.0, min(1.0, damping))
        let dragK = max(0.0, drag)

        for i in points.indices {
            if points[i].isActive == false { continue }
            if points[i].invMass <= 0.0 { continue }

            var v = points[i].v
            v.dx += g.dx * dt
            v.dy += g.dy * dt

            v.dx *= damp
            v.dy *= damp

            if dragK > 0.0001 {
                v.dx *= max(0, 1 - dragK * dt)
                v.dy *= max(0, 1 - dragK * dt)
            }

            var p = points[i].p
            p.x += v.dx * dt
            p.y += v.dy * dt

            points[i].v = v
            points[i].p = p
        }

        if let bounds {
            collideBounds(bounds)
        }
    }

    private func satisfyLinks() {
        if links.isEmpty { return }

        for li in links.indices {
            if links[li].isActive == false { continue }

            guard let ai = indexById[links[li].a], let bi = indexById[links[li].b] else { continue }

            let pa = points[ai].p
            let pb = points[bi].p

            let dx = pb.x - pa.x
            let dy = pb.y - pa.y
            let dist2 = dx * dx + dy * dy
            if dist2 <= 0.000001 { continue }

            let dist = sqrt(dist2)
            let target = links[li].rest
            let diff = (dist - target) / dist

            let stiff = links[li].stiffness
            let invA = points[ai].invMass
            let invB = points[bi].invMass
            let invSum = invA + invB
            if invSum <= 0.000001 { continue }

            let corrX = dx * diff * stiff
            let corrY = dy * diff * stiff

            if invA > 0 {
                points[ai].p.x += corrX * (invA / invSum)
                points[ai].p.y += corrY * (invA / invSum)
            }
            if invB > 0 {
                points[bi].p.x -= corrX * (invB / invSum)
                points[bi].p.y -= corrY * (invB / invSum)
            }
        }
    }

    private func collideBounds(_ bounds: CGRect) {
        for i in points.indices {
            if points[i].isActive == false { continue }

            let r = points[i].radius
            var p = points[i].p
            var v = points[i].v

            let minX = bounds.minX + r
            let maxX = bounds.maxX - r
            let minY = bounds.minY + r
            let maxY = bounds.maxY - r

            if p.x < minX {
                p.x = minX
                if v.dx < 0 { v.dx = -v.dx * 0.35 }
            } else if p.x > maxX {
                p.x = maxX
                if v.dx > 0 { v.dx = -v.dx * 0.35 }
            }

            if p.y < minY {
                p.y = minY
                if v.dy < 0 { v.dy = -v.dy * 0.35 }
            } else if p.y > maxY {
                p.y = maxY
                if v.dy > 0 { v.dy = -v.dy * 0.35 }
            }

            points[i].p = p
            if points[i].invMass > 0 {
                points[i].v = v
            } else {
                points[i].v = .zero
            }
        }
    }

    private func closestPointOnSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y

        let ab2 = abx * abx + aby * aby
        if ab2 <= 0.000001 { return a }

        let t = (apx * abx + apy * aby) / ab2
        let clamped = max(0, min(1, t))
        return CGPoint(x: a.x + abx * clamped, y: a.y + aby * clamped)
    }

    private func rebuildIndex() {
        indexById.removeAll(keepingCapacity: true)
        for i in points.indices {
            indexById[points[i].id] = i
        }
    }
}
