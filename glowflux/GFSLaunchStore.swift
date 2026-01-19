import Foundation
import Combine

@MainActor
final class GFSLaunchStore: ObservableObject {

    @Published private(set) var mainPoint: URL

    private let mainKey = "gfs.launch.main"
    private let resumeKey = "gfs.launch.resume"
    private let marksKey = "gfs.launch.marks"

    private var didStoreResume = false

    init() {
        let defaults = UserDefaults.standard

        if let saved = defaults.string(forKey: mainKey),
           let v = URL(string: saved) {
            mainPoint = v
        } else {
            mainPoint = URL(string: "https://aslankaplangames.github.io/glowflux/")!
            defaults.set(mainPoint.absoluteString, forKey: mainKey)
        }
    }

    func updateMain(_ value: String) {
        guard let v = URL(string: value) else { return }
        mainPoint = v
        UserDefaults.standard.set(value, forKey: mainKey)
    }

    func storeResumeIfNeeded(_ point: URL) {
        guard didStoreResume == false else { return }
        didStoreResume = true

        let defaults = UserDefaults.standard
        if defaults.string(forKey: resumeKey) != nil { return }
        defaults.set(point.absoluteString, forKey: resumeKey)
    }

    func restoreResume() -> URL? {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: resumeKey),
           let v = URL(string: saved) {
            return v
        }
        return nil
    }

    func saveMarks(_ items: [[String: Any]]) {
        UserDefaults.standard.set(items, forKey: marksKey)
    }

    func loadMarks() -> [[String: Any]]? {
        UserDefaults.standard.array(forKey: marksKey) as? [[String: Any]]
    }

    func resetAll() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: mainKey)
        defaults.removeObject(forKey: resumeKey)
        defaults.removeObject(forKey: marksKey)
        didStoreResume = false
    }

    func normalize(_ u: URL) -> String {
        var s = u.absoluteString
        while s.count > 1, s.hasSuffix("/") { s.removeLast() }
        return s
    }
}
