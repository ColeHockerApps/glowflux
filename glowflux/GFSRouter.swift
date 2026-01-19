import SwiftUI
import Combine

@MainActor
final class GFSRouter: ObservableObject {

    enum Route: Equatable {
        case entry
    }

    @Published private(set) var route: Route = .entry

    init() {}

    func goEntry() {
        route = .entry
    }
}
