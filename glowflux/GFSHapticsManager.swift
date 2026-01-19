import SwiftUI
import Combine
import UIKit

@MainActor
final class GFSHapticsManager: ObservableObject {

    static let shared = GFSHapticsManager()

    @Published var isEnabled: Bool = true

    private let impactSoft = UIImpactFeedbackGenerator(style: .soft)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactRigid = UIImpactFeedbackGenerator(style: .rigid)

    private let notify = UINotificationFeedbackGenerator()
    private let select = UISelectionFeedbackGenerator()

    private var didWarm: Bool = false
    private let enabledKey = "gfs.haptics.enabled"

    private init() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: enabledKey) != nil {
            isEnabled = defaults.bool(forKey: enabledKey)
        } else {
            isEnabled = true
        }
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: enabledKey)
        if value {
            warmIfNeeded()
        }
    }

    func warmIfNeeded() {
        guard isEnabled else { return }
        guard didWarm == false else { return }
        didWarm = true

        impactSoft.prepare()
        impactLight.prepare()
        impactMedium.prepare()
        impactRigid.prepare()
        notify.prepare()
        select.prepare()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.didWarm = false
        }
    }

    func tapSoft() {
        guard isEnabled else { return }
        impactSoft.impactOccurred(intensity: 0.75)
    }

    func tapLight() {
        guard isEnabled else { return }
        impactLight.impactOccurred(intensity: 0.85)
    }

    func tapMedium() {
        guard isEnabled else { return }
        impactMedium.impactOccurred(intensity: 0.9)
    }

    func tapRigid() {
        guard isEnabled else { return }
        impactRigid.impactOccurred(intensity: 0.9)
    }

    func selectTick() {
        guard isEnabled else { return }
        select.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        notify.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notify.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notify.notificationOccurred(.error)
    }
}
