import SwiftUI
import Combine
import CoreGraphics

@MainActor
final class GFSParticleFX: ObservableObject {

    struct Particle: Identifiable, Equatable {
        let id: UUID
        var bornAt: TimeInterval
        var life: TimeInterval

        var position: CGPoint
        var velocity: CGVector

        var size: CGFloat
        var spin: Double
        var spinVelocity: Double

        var opacity: Double
        var color: Color

        var symbol: Symbol

        enum Symbol: Int, CaseIterable {
            case sparkle
            case droplet
            case shard
            case jelly
        }
    }

    @Published private(set) var particles: [Particle] = []

    private var lastTick: TimeInterval = 0

    init() {}

    func reset() {
        particles.removeAll()
        lastTick = 0
    }

    func tick(now: TimeInterval) {
        if lastTick == 0 { lastTick = now }
        let dt = max(0, min(1.0 / 20.0, now - lastTick))
        lastTick = now

        if particles.isEmpty { return }

        var kept: [Particle] = []
        kept.reserveCapacity(particles.count)

        for var p in particles {
            let age = now - p.bornAt
            if age >= p.life { continue }

            let t = max(0, min(1, age / max(0.0001, p.life)))
            let ease = 1 - (1 - t) * (1 - t)

            p.position.x += p.velocity.dx * dt
            p.position.y += p.velocity.dy * dt

            p.velocity.dx *= CGFloat(pow(0.92, dt * 60))
            p.velocity.dy *= CGFloat(pow(0.92, dt * 60))
            p.velocity.dy += CGFloat(420 * dt)

            p.spin += p.spinVelocity * dt

            p.size *= CGFloat(pow(0.985, dt * 60))
            p.opacity = max(0, 1 - ease)

            kept.append(p)
        }

        particles = kept
    }

    func burst(at point: CGPoint, intensity: Int = 18) {
        let now = Date().timeIntervalSince1970
        let n = max(4, min(64, intensity))

        var out = particles
        out.reserveCapacity(out.count + n)

        for i in 0..<n {
            let ang = (Double(i) / Double(n)) * Double.pi * 2.0 + rand(-0.35, 0.35)
            let sp = rand(120, 520)
            let vx = CGFloat(cos(ang) * sp)
            let vy = CGFloat(sin(ang) * sp) - CGFloat(rand(80, 220))

            let sym: Particle.Symbol = {
                let r = Int.random(in: 0...10)
                if r <= 4 { return .sparkle }
                if r <= 6 { return .droplet }
                if r <= 8 { return .shard }
                return .jelly
            }()

            let col: Color = pickTropical()

            let p = Particle(
                id: UUID(),
                bornAt: now,
                life: rand(0.55, 1.25),
                position: CGPoint(x: point.x + CGFloat(rand(-10, 10)), y: point.y + CGFloat(rand(-10, 10))),
                velocity: CGVector(dx: vx, dy: vy),
                size: CGFloat(rand(6, 14)),
                spin: rand(-2.8, 2.8),
                spinVelocity: rand(-9.0, 9.0),
                opacity: 1.0,
                color: col,
                symbol: sym
            )
            out.append(p)
        }

        particles = out
    }

    func trail(from a: CGPoint, to b: CGPoint, density: Int = 10) {
        let now = Date().timeIntervalSince1970
        let n = max(2, min(30, density))

        var out = particles
        out.reserveCapacity(out.count + n)

        for i in 0..<n {
            let t = Double(i) / Double(max(1, n - 1))
            let x = a.x + (b.x - a.x) * CGFloat(t) + CGFloat(rand(-2.5, 2.5))
            let y = a.y + (b.y - a.y) * CGFloat(t) + CGFloat(rand(-2.5, 2.5))

            let ang = rand(0, Double.pi * 2)
            let sp = rand(40, 160)
            let vx = CGFloat(cos(ang) * sp)
            let vy = CGFloat(sin(ang) * sp) - CGFloat(rand(20, 80))

            let sym: Particle.Symbol = (Int.random(in: 0...10) < 7) ? .sparkle : .droplet

            let p = Particle(
                id: UUID(),
                bornAt: now,
                life: rand(0.22, 0.55),
                position: CGPoint(x: x, y: y),
                velocity: CGVector(dx: vx, dy: vy),
                size: CGFloat(rand(4, 9)),
                spin: rand(-1.8, 1.8),
                spinVelocity: rand(-10.0, 10.0),
                opacity: 1.0,
                color: pickTropical().opacity(0.95),
                symbol: sym
            )
            out.append(p)
        }

        particles = out
    }

    func view() -> some View {
        Canvas { ctx, _ in
            for p in self.particles {
                let alpha = max(0, min(1, p.opacity))
                var tr = ctx.transform
                tr = tr.translatedBy(x: p.position.x, y: p.position.y)
                tr = tr.rotated(by: p.spin)

                ctx.withCGContext { cg in
                    cg.saveGState()
                    cg.concatenate(tr)

                    let rect = CGRect(
                        x: -p.size * 0.5,
                        y: -p.size * 0.5,
                        width: p.size,
                        height: p.size
                    )

                    let ui = UIColor(p.color)
                    cg.setFillColor(ui.withAlphaComponent(alpha).cgColor)

                    switch p.symbol {
                    case .sparkle:
                        cg.addPath(self.starPath(in: rect, points: 4, inner: 0.42).cgPath)
                        cg.fillPath()

                    case .droplet:
                        cg.addPath(self.dropletPath(in: rect).cgPath)
                        cg.fillPath()

                    case .shard:
                        cg.addPath(self.shardPath(in: rect).cgPath)
                        cg.fillPath()

                    case .jelly:
                        cg.addPath(self.jellyPath(in: rect).cgPath)
                        cg.fillPath()
                    }

                    cg.restoreGState()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func starPath(in r: CGRect, points: Int, inner: Double) -> Path {
        let n = max(3, points)
        let center = CGPoint(x: r.midX, y: r.midY)
        let outer = Double(min(r.width, r.height)) * 0.5
        let innerR = outer * max(0.18, min(0.72, inner))

        var path = Path()
        var first: CGPoint? = nil

        for i in 0..<(n * 2) {
            let a = (Double(i) / Double(n * 2)) * Double.pi * 2 - Double.pi / 2
            let rr = (i % 2 == 0) ? outer : innerR
            let p = CGPoint(
                x: center.x + CGFloat(cos(a) * rr),
                y: center.y + CGFloat(sin(a) * rr)
            )

            if i == 0 {
                path.move(to: p)
                first = p
            } else {
                path.addLine(to: p)
            }
        }

        if let first { path.addLine(to: first) }
        path.closeSubpath()
        return path
    }

    private func dropletPath(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        let w = r.width
        let h = r.height

        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - h * 0.52))
        p.addQuadCurve(
            to: CGPoint(x: c.x + w * 0.42, y: c.y + h * 0.10),
            control: CGPoint(x: c.x + w * 0.46, y: c.y - h * 0.22)
        )
        p.addQuadCurve(
            to: CGPoint(x: c.x, y: c.y + h * 0.52),
            control: CGPoint(x: c.x + w * 0.38, y: c.y + h * 0.58)
        )
        p.addQuadCurve(
            to: CGPoint(x: c.x - w * 0.42, y: c.y + h * 0.10),
            control: CGPoint(x: c.x - w * 0.38, y: c.y + h * 0.58)
        )
        p.addQuadCurve(
            to: CGPoint(x: c.x, y: c.y - h * 0.52),
            control: CGPoint(x: c.x - w * 0.46, y: c.y - h * 0.22)
        )
        p.closeSubpath()
        return p
    }

    private func shardPath(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r.height * 0.54))
        p.addLine(to: CGPoint(x: c.x + r.width * 0.46, y: c.y - r.height * 0.10))
        p.addLine(to: CGPoint(x: c.x + r.width * 0.18, y: c.y + r.height * 0.54))
        p.addLine(to: CGPoint(x: c.x - r.width * 0.46, y: c.y + r.height * 0.10))
        p.closeSubpath()
        return p
    }

    private func jellyPath(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY)
        var p = Path()
        p.addRoundedRect(
            in: CGRect(x: c.x - r.width * 0.46, y: c.y - r.height * 0.40, width: r.width * 0.92, height: r.height * 0.88),
            cornerSize: CGSize(width: r.width * 0.38, height: r.height * 0.38),
            style: .continuous
        )
        p.move(to: CGPoint(x: c.x - r.width * 0.30, y: c.y + r.height * 0.04))
        p.addQuadCurve(
            to: CGPoint(x: c.x + r.width * 0.30, y: c.y + r.height * 0.04),
            control: CGPoint(x: c.x, y: c.y + r.height * 0.22)
        )
        return p
    }

    private func pickTropical() -> Color {
        let r = Int.random(in: 0...9)
        if r == 0 { return Color(red: 0.10, green: 0.93, blue: 0.78) }
        if r == 1 { return Color(red: 0.45, green: 0.88, blue: 1.00) }
        if r == 2 { return Color(red: 0.98, green: 0.44, blue: 0.88) }
        if r == 3 { return Color(red: 1.00, green: 0.78, blue: 0.25) }
        if r == 4 { return Color(red: 0.62, green: 0.52, blue: 1.00) }
        if r == 5 { return Color(red: 0.20, green: 0.75, blue: 0.33) }
        if r == 6 { return Color(red: 1.00, green: 0.40, blue: 0.28) }
        if r == 7 { return Color(red: 0.12, green: 0.60, blue: 1.00) }
        if r == 8 { return Color(red: 0.96, green: 0.94, blue: 1.00) }
        return Color(red: 0.18, green: 1.00, blue: 0.62)
    }

    private func rand(_ a: Double, _ b: Double) -> Double {
        let lo = min(a, b)
        let hi = max(a, b)
        return Double.random(in: lo...hi)
    }
}
