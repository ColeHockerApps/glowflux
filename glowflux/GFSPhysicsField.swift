import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSPhysicsField: ObservableObject {

    struct Body: Identifiable, Equatable {
        let id: UUID
        var position: CGPoint
        var velocity: CGVector
        var radius: CGFloat
        var mass: CGFloat
        var restitution: CGFloat
        var damping: CGFloat
        var isStatic: Bool
        var isActive: Bool
        var tag: Int

        init(
            id: UUID = UUID(),
            position: CGPoint,
            velocity: CGVector = .zero,
            radius: CGFloat,
            mass: CGFloat = 1.0,
            restitution: CGFloat = 0.55,
            damping: CGFloat = 0.985,
            isStatic: Bool = false,
            isActive: Bool = true,
            tag: Int = 0
        ) {
            self.id = id
            self.position = position
            self.velocity = velocity
            self.radius = max(0.5, radius)
            self.mass = max(0.0001, mass)
            self.restitution = max(0, min(1, restitution))
            self.damping = max(0.0, min(1.0, damping))
            self.isStatic = isStatic
            self.isActive = isActive
            self.tag = tag
        }
    }

    struct Segment: Identifiable, Equatable {
        let id: UUID
        var a: CGPoint
        var b: CGPoint
        var thickness: CGFloat
        var restitution: CGFloat
        var isActive: Bool
        var tag: Int

        init(
            id: UUID = UUID(),
            a: CGPoint,
            b: CGPoint,
            thickness: CGFloat = 1.0,
            restitution: CGFloat = 0.35,
            isActive: Bool = true,
            tag: Int = 0
        ) {
            self.id = id
            self.a = a
            self.b = b
            self.thickness = max(0.25, thickness)
            self.restitution = max(0, min(1, restitution))
            self.isActive = isActive
            self.tag = tag
        }
    }

    struct FieldStep: Equatable {
        var dt: CGFloat
        var bodyCount: Int
        var collisions: Int
        var clipped: Int
    }

    @Published private(set) var bodies: [Body] = []
    @Published private(set) var segments: [Segment] = []

    @Published var gravity: CGVector = CGVector(dx: 0, dy: 720)
    @Published var worldBounds: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    private var pendingRemove: Set<UUID> = []
    private var pendingRemoveSegments: Set<UUID> = []

    init() {}

    func reset(bounds: CGRect) {
        bodies.removeAll()
        segments.removeAll()
        pendingRemove.removeAll()
        pendingRemoveSegments.removeAll()
        worldBounds = sanitized(bounds)
    }

    func setBounds(_ bounds: CGRect) {
        worldBounds = sanitized(bounds)
    }

    func addBody(_ body: Body) {
        bodies.append(body)
    }

    func addSegment(_ segment: Segment) {
        segments.append(segment)
    }

    func removeBody(_ id: UUID) {
        pendingRemove.insert(id)
    }

    func removeSegment(_ id: UUID) {
        pendingRemoveSegments.insert(id)
    }

    func setBodyActive(_ id: UUID, _ active: Bool) {
        if let i = bodies.firstIndex(where: { $0.id == id }) {
            bodies[i].isActive = active
        }
    }

    func setSegmentActive(_ id: UUID, _ active: Bool) {
        if let i = segments.firstIndex(where: { $0.id == id }) {
            segments[i].isActive = active
        }
    }

    func step(dt: CGFloat, substeps: Int = 2) -> FieldStep {
        let safeBounds = sanitized(worldBounds)
        worldBounds = safeBounds

        let steps = max(1, min(12, substeps))
        let h = max(0, dt) / CGFloat(steps)

        var collisions = 0
        var clipped = 0

        for _ in 0..<steps {
            applyPendingRemovals()

            for i in bodies.indices {
                if bodies[i].isActive == false { continue }
                if bodies[i].isStatic { continue }

                var v = bodies[i].velocity
                v.dx += gravity.dx * h
                v.dy += gravity.dy * h

                v.dx *= bodies[i].damping
                v.dy *= bodies[i].damping

                var p = bodies[i].position
                p.x += v.dx * h
                p.y += v.dy * h

                bodies[i].velocity = v
                bodies[i].position = p

                let before = bodies[i].position
                resolveBounds(i, safeBounds)
                if before != bodies[i].position {
                    clipped += 1
                }
            }

            collisions += resolveBodyBody()
            collisions += resolveBodySegments()
        }

        return FieldStep(dt: dt, bodyCount: bodies.count, collisions: collisions, clipped: clipped)
    }

    private func applyPendingRemovals() {
        if pendingRemove.isEmpty == false {
            bodies.removeAll { pendingRemove.contains($0.id) }
            pendingRemove.removeAll()
        }
        if pendingRemoveSegments.isEmpty == false {
            segments.removeAll { pendingRemoveSegments.contains($0.id) }
            pendingRemoveSegments.removeAll()
        }
    }

    private func resolveBounds(_ index: Int, _ bounds: CGRect) {
        let r = bodies[index].radius
        var p = bodies[index].position
        var v = bodies[index].velocity
        let e = bodies[index].restitution

        let minX = bounds.minX + r
        let maxX = bounds.maxX - r
        let minY = bounds.minY + r
        let maxY = bounds.maxY - r

        if p.x < minX {
            p.x = minX
            if v.dx < 0 { v.dx = -v.dx * e }
        } else if p.x > maxX {
            p.x = maxX
            if v.dx > 0 { v.dx = -v.dx * e }
        }

        if p.y < minY {
            p.y = minY
            if v.dy < 0 { v.dy = -v.dy * e }
        } else if p.y > maxY {
            p.y = maxY
            if v.dy > 0 { v.dy = -v.dy * e }
        }

        bodies[index].position = p
        bodies[index].velocity = v
    }

    private func resolveBodyBody() -> Int {
        var hits = 0
        guard bodies.count >= 2 else { return 0 }

        for i in 0..<(bodies.count - 1) {
            if bodies[i].isActive == false { continue }
            for j in (i + 1)..<bodies.count {
                if bodies[j].isActive == false { continue }

                let pi = bodies[i].position
                let pj = bodies[j].position
                let ri = bodies[i].radius
                let rj = bodies[j].radius

                let dx = pj.x - pi.x
                let dy = pj.y - pi.y
                let rr = ri + rj
                let dist2 = dx * dx + dy * dy

                if dist2 <= 0.000001 {
                    continue
                }

                if dist2 >= rr * rr {
                    continue
                }

                let dist = sqrt(dist2)
                let nx = dx / dist
                let ny = dy / dist

                let penetration = rr - dist
                let push = penetration * 0.5

                if bodies[i].isStatic == false {
                    bodies[i].position.x -= nx * push
                    bodies[i].position.y -= ny * push
                }
                if bodies[j].isStatic == false {
                    bodies[j].position.x += nx * push
                    bodies[j].position.y += ny * push
                }

                let vi = bodies[i].velocity
                let vj = bodies[j].velocity

                let relVx = vj.dx - vi.dx
                let relVy = vj.dy - vi.dy

                let relAlong = relVx * nx + relVy * ny
                if relAlong > 0 {
                    hits += 1
                    continue
                }

                let ei = bodies[i].restitution
                let ej = bodies[j].restitution
                let e = (ei + ej) * 0.5

                let mi = bodies[i].mass
                let mj = bodies[j].mass
                let invMi: CGFloat = bodies[i].isStatic ? 0 : (1.0 / mi)
                let invMj: CGFloat = bodies[j].isStatic ? 0 : (1.0 / mj)

                let denom = invMi + invMj
                if denom <= 0.000001 {
                    hits += 1
                    continue
                }

                let jImpulse = -(1 + e) * relAlong / denom
                let ix = jImpulse * nx
                let iy = jImpulse * ny

                if bodies[i].isStatic == false {
                    bodies[i].velocity = CGVector(dx: vi.dx - ix * invMi, dy: vi.dy - iy * invMi)
                }
                if bodies[j].isStatic == false {
                    bodies[j].velocity = CGVector(dx: vj.dx + ix * invMj, dy: vj.dy + iy * invMj)
                }

                hits += 1
            }
        }

        return hits
    }

    private func resolveBodySegments() -> Int {
        var hits = 0
        guard bodies.isEmpty == false, segments.isEmpty == false else { return 0 }

        for si in segments.indices {
            if segments[si].isActive == false { continue }

            let a = segments[si].a
            let b = segments[si].b
            let thick = segments[si].thickness
            let eSeg = segments[si].restitution

            for bi in bodies.indices {
                if bodies[bi].isActive == false { continue }
                if bodies[bi].isStatic { continue }

                let p = bodies[bi].position
                let r = bodies[bi].radius

                let closest = closestPointOnSegment(p, a, b)
                let dx = p.x - closest.x
                let dy = p.y - closest.y
                let dist2 = dx * dx + dy * dy
                let limit = (r + thick)

                if dist2 <= 0.000001 {
                    continue
                }

                if dist2 > limit * limit {
                    continue
                }

                let dist = sqrt(dist2)
                let nx = dx / dist
                let ny = dy / dist

                let penetration = limit - dist
                bodies[bi].position.x += nx * penetration
                bodies[bi].position.y += ny * penetration

                var v = bodies[bi].velocity
                let vn = v.dx * nx + v.dy * ny
                if vn < 0 {
                    let eBody = bodies[bi].restitution
                    let e = (eBody + eSeg) * 0.5
                    v.dx -= (1 + e) * vn * nx
                    v.dy -= (1 + e) * vn * ny
                    bodies[bi].velocity = v
                }

                hits += 1
            }
        }

        return hits
    }

    private func closestPointOnSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGPoint {
        let abx = b.x - a.x
        let aby = b.y - a.y
        let apx = p.x - a.x
        let apy = p.y - a.y

        let ab2 = abx * abx + aby * aby
        if ab2 <= 0.000001 {
            return a
        }

        let t = (apx * abx + apy * aby) / ab2
        let clamped = max(0, min(1, t))
        return CGPoint(x: a.x + abx * clamped, y: a.y + aby * clamped)
    }

    private func sanitized(_ r: CGRect) -> CGRect {
        let w = max(1, r.width)
        let h = max(1, r.height)
        return CGRect(x: r.minX, y: r.minY, width: w, height: h)
    }
}
