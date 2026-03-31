import AVFoundation
import UIKit

class SoundManager: ObservableObject {
    static let shared = SoundManager()

    @Published var isMusicEnabled: Bool = true {
        didSet { isMusicEnabled ? resumeMusic() : pauseMusic() }
    }
    @Published var isSoundEnabled: Bool = true

    private var bgPlayer: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []

    private init() {
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }

    // MARK: - Background Music (procedurally generated jazz-lounge loop)

    func startBackgroundMusic() {
        guard isMusicEnabled, bgPlayer == nil || bgPlayer?.isPlaying == false else { return }

        let data = generateAmbientLoop()
        do {
            bgPlayer = try AVAudioPlayer(data: data)
            bgPlayer?.numberOfLoops = -1
            bgPlayer?.volume = 0.25
            bgPlayer?.prepareToPlay()
            bgPlayer?.play()
        } catch {}
    }

    func pauseMusic() {
        bgPlayer?.pause()
    }

    func resumeMusic() {
        guard isMusicEnabled else { return }
        if bgPlayer == nil {
            startBackgroundMusic()
        } else {
            bgPlayer?.play()
        }
    }

    func stopMusic() {
        bgPlayer?.stop()
        bgPlayer = nil
    }

    // MARK: - Sound Effects

    func playDealCard() {
        guard isSoundEnabled else { return }
        playSFX(frequency: 800, duration: 0.06, volume: 0.3)
    }

    func playChipBet() {
        guard isSoundEnabled else { return }
        playSFX(frequency: 1200, duration: 0.04, volume: 0.25)
    }

    func playCheck() {
        guard isSoundEnabled else { return }
        playSFX(frequency: 600, duration: 0.05, volume: 0.2)
    }

    func playFold() {
        guard isSoundEnabled else { return }
        playSFX(frequency: 300, duration: 0.1, volume: 0.2)
    }

    func playWin() {
        guard isSoundEnabled else { return }
        playChord(frequencies: [523.25, 659.25, 783.99], duration: 0.5, volume: 0.35)
    }

    func playAllIn() {
        guard isSoundEnabled else { return }
        playChord(frequencies: [440, 554.37, 659.25], duration: 0.3, volume: 0.35)
    }

    func playButtonTap() {
        guard isSoundEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Audio Generation

    private func playSFX(frequency: Double, duration: Double, volume: Float) {
        let data = generateTone(frequency: frequency, duration: duration, volume: volume)
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.play()
        sfxPlayers.append(player)
        sfxPlayers = sfxPlayers.filter { $0.isPlaying }
    }

    private func playChord(frequencies: [Double], duration: Double, volume: Float) {
        let data = generateChord(frequencies: frequencies, duration: duration, volume: volume)
        guard let player = try? AVAudioPlayer(data: data) else { return }
        player.volume = volume
        player.play()
        sfxPlayers.append(player)
        sfxPlayers = sfxPlayers.filter { $0.isPlaying }
    }

    private func generateTone(frequency: Double, duration: Double, volume: Float, sampleRate: Double = 44100) -> Data {
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(t / 0.005, (duration - t) / 0.01))
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope) * volume
        }

        return buildWAV(samples: samples, sampleRate: Int(sampleRate))
    }

    private func generateChord(frequencies: [Double], duration: Double, volume: Float, sampleRate: Double = 44100) -> Data {
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)
        let scale = 1.0 / Float(frequencies.count)

        for i in 0..<numSamples {
            let t = Double(i) / sampleRate
            let envelope = min(1.0, min(t / 0.01, (duration - t) / 0.05))
            var sum: Float = 0
            for freq in frequencies {
                sum += Float(sin(2.0 * .pi * freq * t))
            }
            samples[i] = sum * scale * Float(envelope) * volume
        }

        return buildWAV(samples: samples, sampleRate: Int(sampleRate))
    }

    private func generateAmbientLoop() -> Data {
        let sampleRate = 44100.0
        let duration = 16.0
        let numSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: numSamples)

        // Warm pad chords that cycle through a jazz progression
        let chords: [[Double]] = [
            [130.81, 164.81, 196.00, 246.94],  // C major 7
            [146.83, 174.61, 220.00, 261.63],   // D minor 7
            [164.81, 196.00, 246.94, 311.13],   // E minor 7
            [174.61, 220.00, 261.63, 329.63],   // F major 7
        ]

        let chordDuration = duration / Double(chords.count)
        let fadeLen = Int(sampleRate * 0.5)

        for (ci, chord) in chords.enumerated() {
            let startSample = Int(Double(ci) * chordDuration * sampleRate)
            let endSample = min(Int(Double(ci + 1) * chordDuration * sampleRate), numSamples)

            for i in startSample..<endSample {
                let local = i - startSample
                let localLen = endSample - startSample
                let t = Double(i) / sampleRate

                // Smooth fade in/out between chords
                var envelope = 1.0
                if local < fadeLen {
                    envelope = Double(local) / Double(fadeLen)
                }
                if local > localLen - fadeLen {
                    envelope = Double(localLen - local) / Double(fadeLen)
                }

                var sum: Float = 0
                for freq in chord {
                    // Soft sine with slight detuning for warmth
                    sum += Float(sin(2.0 * .pi * freq * t)) * 0.12
                    sum += Float(sin(2.0 * .pi * freq * 1.002 * t)) * 0.06
                }

                // Subtle sub bass
                sum += Float(sin(2.0 * .pi * chord[0] * 0.5 * t)) * 0.08

                samples[i] += sum * Float(envelope)
            }
        }

        // Apply overall envelope for seamless loop
        let loopFade = Int(sampleRate * 1.0)
        for i in 0..<loopFade {
            let factor = Float(i) / Float(loopFade)
            samples[i] *= factor
            samples[numSamples - 1 - i] *= factor
        }

        // Normalize
        let peak = samples.map { abs($0) }.max() ?? 1.0
        if peak > 0 {
            let norm = 0.3 / peak
            for i in 0..<numSamples {
                samples[i] *= norm
            }
        }

        return buildWAV(samples: samples, sampleRate: Int(sampleRate))
    }

    private func buildWAV(samples: [Float], sampleRate: Int) -> Data {
        let numChannels: Int = 1
        let bitsPerSample: Int = 16
        let byteRate = sampleRate * numChannels * bitsPerSample / 8
        let blockAlign = numChannels * bitsPerSample / 8
        let dataSize = samples.count * blockAlign

        var data = Data()

        func appendUInt32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func appendUInt16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        appendUInt32(UInt32(36 + dataSize))
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        appendUInt32(16)
        appendUInt16(1) // PCM
        appendUInt16(UInt16(numChannels))
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(UInt16(blockAlign))
        appendUInt16(UInt16(bitsPerSample))

        // data chunk
        data.append(contentsOf: "data".utf8)
        appendUInt32(UInt32(dataSize))

        for sample in samples {
            let clamped = max(-1.0, min(1.0, sample))
            let intSample = Int16(clamped * 32767)
            withUnsafeBytes(of: intSample.littleEndian) { data.append(contentsOf: $0) }
        }

        return data
    }
}
