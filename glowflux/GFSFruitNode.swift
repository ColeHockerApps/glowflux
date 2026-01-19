import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSFruitNode: ObservableObject, Identifiable {

    enum Kind: Int, CaseIterable {
        case mango
        case pineapple
        case kiwi
        case papaya
        case lime
    }

    enum State: Equatable {
        case whole
        case sliced
        case expired
    }

    struct Half: Identifiable, Equatable {
        let id: UUID
        var position: CGPoint
        var velocity: CGVector
        var radius: CGFloat
        var spin: CGFloat
        var life: CGFloat
        var kind: Kind
    }

    let id: UUID = UUID()

    @Published private(set) var kind: Kind
    @Published private(set) var state: State = .whole

    @Published private(set) var position: CGPoint
    @Published private(set) var velocity: CGVector
    @Published private(set) var radius: CGFloat

    @Published private(set) var halves: [Half] = []

    var gravity: CGFloat = 820
    var linearDamping: CGFloat = 0.995
    var bounceDamping: CGFloat = 0.78

    var maxLife: CGFloat = 10.0
    private var lifeLeft: CGFloat

    init(
        kind: Kind,
        position: CGPoint,
        velocity: CGVector,
        radius: CGFloat = 22
    ) {
        self.kind = kind
        self.position = position
        self.velocity = velocity
        self.radius = max(6, radius)
        self.lifeLeft = maxLife
    }

    func applyImpulse(_ impulse: CGVector) {
        velocity = CGVector(dx: velocity.dx + impulse.dx, dy: velocity.dy + impulse.dy)
    }

    func step(dt: CGFloat, bounds: CGRect) {
        guard state != .expired else { return }

        lifeLeft -= dt
        if lifeLeft <= 0 {
            state = .expired
            return
        }

        switch state {
        case .whole:
            advanceWhole(dt: dt, bounds: bounds)
        case .sliced:
            advanceHalves(dt: dt, bounds: bounds)
        case .expired:
            break
        }
    }

    func slice(with blade: (CGPoint, CGPoint)) {
        guard state == .whole else { return }

        let a = blade.0
        let b = blade.1
        if !segmentIntersectsCircle(a: a, b: b, center: position, radius: radius) {
            return
        }

        state = .sliced

        let dir = normalize(CGVector(dx: b.x - a.x, dy: b.y - a.y))
        let n = CGVector(dx: -dir.dy, dy: dir.dx)

        let kick: CGFloat = 220
        let up: CGFloat = 120

        let base = velocity

        let h1 = Half(
            id: UUID(),
            position: CGPoint(x: position.x + n.dx * radius * 0.35, y: position.y + n.dy * radius * 0.35),
            velocity: CGVector(dx: base.dx + n.dx * kick, dy: base.dy + n.dy * kick + up),
            radius: radius * 0.78,
            spin: 3.4,
            life: 2.2,
            kind: kind
        )

        let h2 = Half(
            id: UUID(),
            position: CGPoint(x: position.x - n.dx * radius * 0.35, y: position.y - n.dy * radius * 0.35),
            velocity: CGVector(dx: base.dx - n.dx * kick, dy: base.dy - n.dy * kick + up),
            radius: radius * 0.78,
            spin: -3.4,
            life: 2.2,
            kind: kind
        )

        halves = [h1, h2]
    }

    var isAlive: Bool {
        state != .expired
    }
    private func advanceWhole(dt: CGFloat, bounds: CGRect) {
        velocity.dy += gravity * dt

        position.x += velocity.dx * dt
        position.y += velocity.dy * dt

        velocity.dx *= pow(linearDamping, max(1, dt * 60))
        velocity.dy *= pow(linearDamping, max(1, dt * 60))

        collide(bounds: bounds, position: &position, velocity: &velocity, r: radius)
    }

    private func advanceHalves(dt: CGFloat, bounds: CGRect) {
        if halves.isEmpty {
            state = .expired
            return
        }

        for i in halves.indices {
            halves[i].life -= dt
            halves[i].velocity.dy += gravity * dt

            halves[i].position.x += halves[i].velocity.dx * dt
            halves[i].position.y += halves[i].velocity.dy * dt

            halves[i].velocity.dx *= pow(linearDamping, max(1, dt * 60))
            halves[i].velocity.dy *= pow(linearDamping, max(1, dt * 60))

            var p = halves[i].position
            var v = halves[i].velocity
            collide(bounds: bounds, position: &p, velocity: &v, r: halves[i].radius)
            halves[i].position = p
            halves[i].velocity = v
        }

        halves.removeAll { $0.life <= 0 }

        if halves.isEmpty {
            state = .expired
        }
    }

    private func collide(bounds: CGRect, position: inout CGPoint, velocity: inout CGVector, r: CGFloat) {
        let minX = bounds.minX + r
        let maxX = bounds.maxX - r
        let minY = bounds.minY + r
        let maxY = bounds.maxY - r

        if position.x < minX {
            position.x = minX
            velocity.dx = abs(velocity.dx) * bounceDamping
        } else if position.x > maxX {
            position.x = maxX
            velocity.dx = -abs(velocity.dx) * bounceDamping
        }

        if position.y < minY {
            position.y = minY
            velocity.dy = abs(velocity.dy) * bounceDamping
        } else if position.y > maxY {
            position.y = maxY
            velocity.dy = -abs(velocity.dy) * bounceDamping
        }
    }

    private func segmentIntersectsCircle(a: CGPoint, b: CGPoint, center: CGPoint, radius: CGFloat) -> Bool {
        let ab = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let ac = CGVector(dx: center.x - a.x, dy: center.y - a.y)
        let abLen2 = ab.dx * ab.dx + ab.dy * ab.dy
        if abLen2 < 0.000001 {
            let d2 = (center.x - a.x) * (center.x - a.x) + (center.y - a.y) * (center.y - a.y)
            return d2 <= radius * radius
        }

        var t = (ac.dx * ab.dx + ac.dy * ab.dy) / abLen2
        t = max(0, min(1, t))
        let p = CGPoint(x: a.x + ab.dx * t, y: a.y + ab.dy * t)
        let dx = center.x - p.x
        let dy = center.y - p.y
        return (dx * dx + dy * dy) <= radius * radius
    }

    private func normalize(_ v: CGVector) -> CGVector {
        let len = sqrt(v.dx * v.dx + v.dy * v.dy)
        if len < 0.000001 { return .zero }
        return CGVector(dx: v.dx / len, dy: v.dy / len)
    }
}
