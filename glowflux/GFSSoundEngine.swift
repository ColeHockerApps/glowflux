import Foundation
import Combine
import AVFoundation

@MainActor
final class GFSSoundEngine: ObservableObject {

    static let shared = GFSSoundEngine()

    @Published var isEnabled: Bool = true
    @Published var volume: Float = 0.85

    private let enabledKey = "gfs.sound.enabled"
    private let volumeKey = "gfs.sound.volume"

    private var players: [String: AVAudioPlayer] = [:]
    private var sessionReady: Bool = false

    private init() {
        let defaults = UserDefaults.standard

        if defaults.object(forKey: enabledKey) != nil {
            isEnabled = defaults.bool(forKey: enabledKey)
        } else {
            isEnabled = true
        }

        if defaults.object(forKey: volumeKey) != nil {
            volume = max(0, min(1, defaults.float(forKey: volumeKey)))
        } else {
            volume = 0.85
        }
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        UserDefaults.standard.set(value, forKey: enabledKey)

        if value {
            prepareSessionIfNeeded()
        } else {
            stopAll()
        }
    }

    func setVolume(_ value: Float) {
        volume = max(0, min(1, value))
        UserDefaults.standard.set(volume, forKey: volumeKey)

        for p in players.values {
            p.volume = volume
        }
    }

    func primeIfNeeded() {
        guard isEnabled else { return }
        prepareSessionIfNeeded()
    }

    func playTap() { play(name: "tap", ext: "wav") }
    func playPop() { play(name: "pop", ext: "wav") }
    func playSlice() { play(name: "slice", ext: "wav") }
    func playDrop() { play(name: "drop", ext: "wav") }
    func playSuccess() { play(name: "success", ext: "wav") }
    func playFail() { play(name: "fail", ext: "wav") }

    func play(name: String, ext: String) {
        guard isEnabled else { return }
        prepareSessionIfNeeded()

        let key = "\(name).\(ext)"

        if let p = players[key] {
            p.currentTime = 0
            p.volume = volume
            p.play()
            return
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = volume
            p.numberOfLoops = 0
            p.prepareToPlay()
            players[key] = p
            p.play()
        } catch {
            return
        }
    }

    func stopAll() {
        for p in players.values {
            p.stop()
        }
    }

    private func prepareSessionIfNeeded() {
        guard sessionReady == false else { return }

        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.ambient, options: [.mixWithOthers])
            try s.setActive(true, options: [])
            sessionReady = true
        } catch {
            sessionReady = false
        }
    }
}
