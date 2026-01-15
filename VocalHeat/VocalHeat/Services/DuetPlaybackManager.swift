//
//  DuetPlaybackManager.swift
//  VocalHeat
//
//  Synchronized dual-track playback with AVAudioEngine
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class DuetPlaybackManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private var artistPlayerNode: AVAudioPlayerNode?
    private var userPlayerNode: AVAudioPlayerNode?

    private var artistFile: AVAudioFile?
    private var userFile: AVAudioFile?

    private var startTime: TimeInterval = 0
    private var pausedTime: TimeInterval = 0

    private var updateTimer: Timer?

    // MARK: - Public Methods

    func loadTracks(artistURL: URL?, userURL: URL) throws {
        // Stop any existing playback
        stop()

        // Load user track (required)
        userFile = try AVAudioFile(forReading: userURL)

        // Load artist track (optional for duets)
        if let artistURL = artistURL {
            artistFile = try AVAudioFile(forReading: artistURL)
        }

        // Calculate duration
        if let userFile = userFile {
            duration = Double(userFile.length) / userFile.processingFormat.sampleRate
        }

        currentTime = 0
    }

    func play() async throws {
        guard let userFile = userFile else { return }

        // Setup audio engine if needed
        if artistPlayerNode == nil || userPlayerNode == nil {
            try setupAudioEngine()
        }

        // Schedule files
        let userPlayerNode = self.userPlayerNode!
        let artistPlayerNode = self.artistPlayerNode

        // Calculate start frame based on paused time
        let startFrame = AVAudioFramePosition(pausedTime * userFile.processingFormat.sampleRate)

        // Schedule user audio
        let userFrameCount = AVAudioFrameCount(userFile.length - startFrame)
        if userFrameCount > 0 {
            userPlayerNode.scheduleSegment(
                userFile,
                startingFrame: startFrame,
                frameCount: userFrameCount,
                at: nil
            ) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackComplete()
                }
            }
        }

        // Schedule artist audio if available
        if let artistFile = artistFile, let artistPlayerNode = artistPlayerNode {
            let artistFrameCount = AVAudioFrameCount(artistFile.length - startFrame)
            if artistFrameCount > 0 {
                artistPlayerNode.scheduleSegment(
                    artistFile,
                    startingFrame: startFrame,
                    frameCount: artistFrameCount,
                    at: nil
                )
            }
        }

        // Start engine
        if !audioEngine.isRunning {
            try audioEngine.start()
        }

        // Start playback
        userPlayerNode.play()
        artistPlayerNode?.play()

        isPlaying = true
        startTime = Date().timeIntervalSinceReferenceDate - pausedTime

        // Start update timer
        updateTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateProgress()
            }
        }

        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func pause() {
        userPlayerNode?.stop()
        artistPlayerNode?.stop()

        isPlaying = false
        pausedTime = currentTime

        updateTimer?.invalidate()
        updateTimer = nil
    }

    func stop() {
        userPlayerNode?.stop()
        artistPlayerNode?.stop()

        audioEngine.stop()

        isPlaying = false
        currentTime = 0
        pausedTime = 0

        updateTimer?.invalidate()
        updateTimer = nil
    }

    func seek(to time: TimeInterval) async throws {
        let wasPlaying = isPlaying

        // Stop current playback
        stop()

        // Set paused time
        pausedTime = min(max(0, time), duration)
        currentTime = pausedTime

        // Resume if was playing
        if wasPlaying {
            try await play()
        }
    }

    // MARK: - Private Methods

    private func setupAudioEngine() throws {
        // Create player nodes
        let artistNode = AVAudioPlayerNode()
        let userNode = AVAudioPlayerNode()

        artistPlayerNode = artistNode
        userPlayerNode = userNode

        // Attach nodes
        audioEngine.attach(artistNode)
        audioEngine.attach(userNode)

        // Get output format
        let mainMixer = audioEngine.mainMixerNode
        let outputFormat = mainMixer.outputFormat(forBus: 0)

        // Connect artist node
        if let artistFile = artistFile {
            audioEngine.connect(
                artistNode,
                to: mainMixer,
                format: artistFile.processingFormat
            )
        }

        // Connect user node
        if let userFile = userFile {
            audioEngine.connect(
                userNode,
                to: mainMixer,
                format: userFile.processingFormat
            )
        }

        // Prepare engine
        audioEngine.prepare()
    }

    private func updateProgress() {
        guard isPlaying else { return }

        let elapsed = Date().timeIntervalSinceReferenceDate - startTime
        currentTime = min(elapsed, duration)

        // Auto-stop at end
        if currentTime >= duration {
            stop()
        }
    }

    private func handlePlaybackComplete() {
        isPlaying = false
        currentTime = 0
        pausedTime = 0

        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Deinitialization

    deinit {
        updateTimer?.invalidate()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}
