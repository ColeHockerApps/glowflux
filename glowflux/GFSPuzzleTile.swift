import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSPuzzleTile: ObservableObject, Identifiable {

    enum Kind: Int, CaseIterable {
        case star
        case jelly
        case stone
        case shell
        case leaf
    }

    enum State: Equatable {
        case idle
        case armed
        case triggered
        case cleared
    }

    let id: UUID = UUID()

    @Published private(set) var kind: Kind
    @Published private(set) var state: State = .idle

    @Published private(set) var position: CGPoint
    @Published private(set) var size: CGSize
    @Published private(set) var angle: CGFloat = 0

    @Published private(set) var hitCount: Int = 0
    @Published private(set) var goalCount: Int = 1

    @Published private(set) var glow: CGFloat = 0
    @Published private(set) var wobble: CGFloat = 0

    private var life: CGFloat = 999
    private var pulseT: CGFloat = 0

    init(
        kind: Kind,
        position: CGPoint,
        size: CGSize = CGSize(width: 62, height: 62),
        goalCount: Int = 1
    ) {
        self.kind = kind
        self.position = position
        self.size = size
        self.goalCount = max(1, goalCount)
    }

    func setPosition(_ p: CGPoint) {
        position = p
    }

    func setSize(_ s: CGSize) {
        size = s
    }

    func arm() {
        guard state == .idle else { return }
        state = .armed
        glow = 0.6
        wobble = 0.18
    }

    func disarm() {
        guard state == .armed else { return }
        state = .idle
        glow = 0
        wobble = 0
    }

    func registerHit(strength: CGFloat = 1) {
        guard state != .cleared else { return }

        if state == .idle { state = .armed }
        hitCount += max(1, Int(round(strength)))

        glow = min(1.0, glow + 0.28)
        wobble = min(0.38, wobble + 0.12)

        if hitCount >= goalCount {
            trigger()
        }
    }

    func trigger() {
        guard state != .cleared else { return }
        state = .triggered
        glow = 1.0
        wobble = 0.55
        life = 0.32
    }

    func clear() {
        state = .cleared
        glow = 0
        wobble = 0
        life = 0
    }

    func step(dt: CGFloat) {
        guard state != .cleared else { return }

        pulseT += dt
        let slow = sin(pulseT * 2.2)
        let fast = sin(pulseT * 7.4)

        let targetGlow: CGFloat
        switch state {
        case .idle:
            targetGlow = 0.06 + max(0, slow) * 0.10
        case .armed:
            targetGlow = 0.18 + max(0, slow) * 0.22
        case .triggered:
            targetGlow = 0.85 + max(0, fast) * 0.15
        case .cleared:
            targetGlow = 0
        }

        glow = lerp(glow, targetGlow, k: 0.10)

        let targetWobble: CGFloat
        switch state {
        case .idle:
            targetWobble = 0
        case .armed:
            targetWobble = 0.10 + abs(fast) * 0.10
        case .triggered:
            targetWobble = 0.45 + abs(fast) * 0.22
        case .cleared:
            targetWobble = 0
        }

        wobble = lerp(wobble, targetWobble, k: 0.12)

        angle = wobble * sin(pulseT * 10.0) * 0.25

        if state == .triggered {
            life -= dt
            if life <= 0 {
                clear()
            }
        }
    }

    func contains(_ p: CGPoint) -> Bool {
        let rect = CGRect(
            x: position.x - size.width * 0.5,
            y: position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        return rect.contains(p)
    }

    func intersectsCircle(center: CGPoint, radius: CGFloat) -> Bool {
        let rect = CGRect(
            x: position.x - size.width * 0.5,
            y: position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
        let cx = max(rect.minX, min(center.x, rect.maxX))
        let cy = max(rect.minY, min(center.y, rect.maxY))
        let dx = center.x - cx
        let dy = center.y - cy
        return (dx * dx + dy * dy) <= radius * radius
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, k: CGFloat) -> CGFloat {
        a + (b - a) * max(0, min(1, k))
    }
}
