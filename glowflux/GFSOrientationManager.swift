import SwiftUI
import Combine
import UIKit

@MainActor
final class GFSOrientationManager: ObservableObject {

    enum Mode {
        case flexible
        case portrait
    }

    @Published private(set) var mode: Mode = .flexible
    @Published private(set) var activeValue: URL? = nil

    init() {}

    func allowFlexible() {
        mode = .flexible
        UIViewController.attemptRotationToDeviceOrientation()
    }

    func lockPortrait() {
        mode = .portrait
        UIViewController.attemptRotationToDeviceOrientation()
    }

    func setActiveValue(_ value: URL?) {
        activeValue = normalizeTrailingSlash(value)
    }

    private func normalizeTrailingSlash(_ point: URL?) -> URL? {
        guard let point else { return nil }

        let scheme = point.scheme?.lowercased() ?? ""
        guard scheme == "http" || scheme == "https" else { return point }

        guard var c = URLComponents(url: point, resolvingAgainstBaseURL: false) else { return point }

        if c.path.count > 1, c.path.hasSuffix("/") {
            while c.path.count > 1, c.path.hasSuffix("/") {
                c.path.removeLast()
            }
        }

        return c.url ?? point
    }

    var interfaceMask: UIInterfaceOrientationMask {
        switch mode {
        case .flexible:
            return [.portrait, .landscapeLeft, .landscapeRight]
        case .portrait:
            return [.portrait]
        }
    }
}
