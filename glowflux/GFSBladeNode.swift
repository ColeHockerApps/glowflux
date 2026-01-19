import Foundation
import CoreGraphics
import Combine

@MainActor
final class GFSBladeNode: ObservableObject, Identifiable {

    enum State: Equatable {
        case idle
        case slicing
        case fading
    }

    struct Segment: Identifiable, Equatable {
        let id: UUID
        var a: CGPoint
        var b: CGPoint
        var life: CGFloat
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var segments: [Segment] = []

    @Published var maxSegments: Int = 18
    @Published var segmentLife: CGFloat = 0.22
    @Published var width: CGFloat = 6.0

    init() {}

    func begin(at p: CGPoint) {
        state = .slicing
        segments.removeAll(keepingCapacity: true)
        segments.append(
            Segment(
                id: UUID(),
                a: p,
                b: p,
                life: segmentLife
            )
        )
    }

    func move(to p: CGPoint) {
        guard state == .slicing else { return }
        guard let last = segments.last else { return }

        let seg = Segment(
            id: UUID(),
            a: last.b,
            b: p,
            life: segmentLife
        )
        segments.append(seg)

        if segments.count > maxSegments {
            segments.removeFirst(segments.count - maxSegments)
        }
    }

    func end() {
        guard state == .slicing else { return }
        state = .fading
    }

    func step(dt: CGFloat) {
        guard segments.isEmpty == false else {
            state = .idle
            return
        }

        for i in segments.indices {
            segments[i].life -= dt
        }

        segments.removeAll { $0.life <= 0 }

        if segments.isEmpty {
            state = .idle
        }
    }

    func activeSegments() -> [(CGPoint, CGPoint, CGFloat)] {
        segments.map { ($0.a, $0.b, max(0, $0.life / segmentLife)) }
    }

    func reset() {
        state = .idle
        segments.removeAll()
    }
}
