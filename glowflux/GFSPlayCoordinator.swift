import Combine
import SwiftUI

@MainActor
final class GFSPlayCoordinator: ObservableObject {

    @Published var isReady: Bool = false
    @Published var fadeIn: Bool = false
    @Published var dimLayer: Double = 1.0
    @Published var showOverlay: Bool = true

    private var didMarkReady: Bool = false

    init() {}

    func onAppear() {
        didMarkReady = false
        isReady = false
        fadeIn = false
        showOverlay = true
        dimLayer = 1.0

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.dimLayer = 0.0
        }
    }

    func markReady() {
        guard didMarkReady == false else { return }
        didMarkReady = true

        isReady = true
        fadeIn = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.showOverlay = false
        }
    }

    func resetOverlay() {
        showOverlay = true
        isReady = false
        fadeIn = false
        didMarkReady = false
    }
}
