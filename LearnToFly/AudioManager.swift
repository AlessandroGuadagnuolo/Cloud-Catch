import Foundation
import AVFoundation

final class AudioManager {
    static let shared = AudioManager()
    private var backgroundPlayer: AVAudioPlayer?
    private var fadeInTimer: Timer?
    private var fadeOutTimer: Timer?

    private init() {}

    func playBackgroundMusic(
        named name: String,
        fileExtension: String,
        targetVolume: Float = 0.3,
        fadeInDuration: TimeInterval = 0.0
    ) {
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        if backgroundPlayer?.isPlaying == true { return }

        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            print("Audio non trovato: \(name).\(fileExtension)")
            return
        }

        do {
            backgroundPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundPlayer?.numberOfLoops = -1 // loop infinito
            backgroundPlayer?.volume = fadeInDuration > 0 ? 0.0 : targetVolume
            backgroundPlayer?.prepareToPlay()
            backgroundPlayer?.play()
            startFadeInIfNeeded(duration: fadeInDuration, targetVolume: targetVolume)
        } catch {
            print("Errore audio: \(error)")
        }
    }

    func stopBackgroundMusic() {
        fadeInTimer?.invalidate()
        fadeInTimer = nil
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        backgroundPlayer?.stop()
        backgroundPlayer = nil
    }

    func pauseBackgroundMusic() {
        fadeInTimer?.invalidate()
        fadeInTimer = nil
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil
        backgroundPlayer?.pause()
    }

    func resumeBackgroundMusic() {
        guard let backgroundPlayer, !backgroundPlayer.isPlaying else { return }
        backgroundPlayer.play()
    }

    func fadeOutBackgroundMusic(duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeInTimer?.invalidate()
        fadeInTimer = nil
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil

        guard duration > 0, let player = backgroundPlayer, player.isPlaying else {
            stopBackgroundMusic()
            completion?()
            return
        }

        let initialVolume = player.volume
        let steps = 10
        let tick = duration / Double(steps)
        let volumeStep = initialVolume / Float(steps)

        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] timer in
            guard let self, let activePlayer = self.backgroundPlayer, activePlayer === player else {
                timer.invalidate()
                completion?()
                return
            }

            let nextVolume = max(0.0, activePlayer.volume - volumeStep)
            activePlayer.volume = nextVolume

            if nextVolume <= 0.001 {
                timer.invalidate()
                self.fadeOutTimer = nil
                self.stopBackgroundMusic()
                completion?()
            }
        }
    }

    private func startFadeInIfNeeded(duration: TimeInterval, targetVolume: Float) {
        fadeInTimer?.invalidate()
        fadeInTimer = nil

        guard duration > 0 else { return }
        guard let player = backgroundPlayer else { return }

        let steps = 10
        let tick = duration / Double(steps)
        let volumeStep = targetVolume / Float(steps)

        fadeInTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] timer in
            guard let self, let activePlayer = self.backgroundPlayer, activePlayer === player else {
                timer.invalidate()
                return
            }

            let nextVolume = min(targetVolume, activePlayer.volume + volumeStep)
            activePlayer.volume = nextVolume

            if nextVolume >= targetVolume {
                timer.invalidate()
                self.fadeInTimer = nil
            }
        }
    }
}
