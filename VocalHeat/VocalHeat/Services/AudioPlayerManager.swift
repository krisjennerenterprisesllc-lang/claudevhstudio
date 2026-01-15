//
//  AudioPlayerManager.swift
//  VocalHeat
//
//  Simple AVAudioPlayer wrapper with proper lifecycle management
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // MARK: - Properties

    private var audioPlayer: AVAudioPlayer?
    private var updateTimer: Timer?

    // MARK: - Public Methods

    func load(url: URL) throws {
        // Stop any existing playback
        stop()

        // Create new player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = self
        audioPlayer?.prepareToPlay()

        duration = audioPlayer?.duration ?? 0
        currentTime = 0
    }

    func play() {
        guard let player = audioPlayer else { return }

        player.play()
        isPlaying = true

        // Start update timer
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }

        // Add to common run loop mode for proper UI updates
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false

        updateTimer?.invalidate()
        updateTimer = nil
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false

        updateTimer?.invalidate()
        updateTimer = nil

        currentTime = 0
    }

    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }

        player.currentTime = min(max(0, time), duration)
        currentTime = player.currentTime
    }

    // MARK: - Private Methods

    private func updateProgress() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime
    }

    // MARK: - Deinitialization

    deinit {
        updateTimer?.invalidate()
        audioPlayer?.stop()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.updateTimer?.invalidate()
            self.updateTimer = nil
            self.currentTime = 0
            player.currentTime = 0
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            print("Audio player decode error: \(error?.localizedDescription ?? "unknown")")
            self.stop()
        }
    }
}
