import SwiftUI
import Combine

@MainActor
final class GFSLoadingModel: ObservableObject {

    @Published private(set) var progress: Double = 0
    @Published private(set) var isRunning: Bool = false

    private var timer: AnyCancellable?
    private var startTime: TimeInterval = 0
    private var duration: TimeInterval = 0

    deinit {
        timer?.cancel()
        timer = nil
    }

    func start(minSeconds: Double) {
        stop()
        isRunning = true
        progress = 0
        startTime = Date().timeIntervalSince1970
        duration = max(0.2, minSeconds)

        timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.tick()
            }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        isRunning = false
    }

    func completeNow() {
        progress = 1
        stop()
    }

    private func tick() {
        let now = Date().timeIntervalSince1970
        let t = (now - startTime) / max(0.001, duration)
        let clamped = max(0, min(1, t))
        progress = easeInOut(clamped)

        if clamped >= 1 {
            stop()
        }
    }

    private func easeInOut(_ x: Double) -> Double {
        if x <= 0 { return 0 }
        if x >= 1 { return 1 }
        return x * x * (3 - 2 * x)
    }
}
