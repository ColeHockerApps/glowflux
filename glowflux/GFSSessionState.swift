import Foundation
import Combine

@MainActor
final class GFSSessionState: ObservableObject {

    @Published private(set) var isReady: Bool = false
    @Published private(set) var didReveal: Bool = false

    @Published private(set) var lastActivePoint: URL? = nil
    @Published private(set) var isAtBasePoint: Bool = true

    @Published var overlayDim: Double = 1.0
    @Published var fadeIn: Bool = false

    private let lastPointKey = "gfs.session.lastPoint"

    init() {
        restore()
    }

    func onAppear() {
        isReady = false
        didReveal = false
        fadeIn = false
        overlayDim = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.overlayDim = 0.0
        }
    }

    func markReady() {
        guard isReady == false else { return }
        isReady = true
        fadeIn = true
    }

    func setActivePoint(_ point: URL?, base: URL) {
        lastActivePoint = point
        isAtBasePoint = (normalize(point) == normalize(base))
        persistLast(point)
    }

    func markRevealedIfNeeded() {
        guard didReveal == false else { return }
        didReveal = true
    }

    private func persistLast(_ point: URL?) {
        let defaults = UserDefaults.standard
        if let point {
            defaults.set(point.absoluteString, forKey: lastPointKey)
        } else {
            defaults.removeObject(forKey: lastPointKey)
        }
    }

    private func restore() {
        let defaults = UserDefaults.standard
        if let s = defaults.string(forKey: lastPointKey),
           let u = URL(string: s) {
            lastActivePoint = u
        }
    }

    private func normalize(_ point: URL?) -> String {
        guard let point else { return "" }
        var s = point.absoluteString
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
