//
//  AudioRecorder.swift
//  VocalHeat
//
//  AVAudioEngine-based audio recorder with real-time buffer callback
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation
import Accelerate

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0

    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private var recordingTimer: Timer?
    private var recordingStartTime: Date?

    // Audio buffer callback
    var onBufferReceived: (([Float]) -> Void)?

    // Pre-allocated buffer for windowing (reused to avoid allocations)
    private var windowedBuffer: [Float]
    private let fftSize: Int

    // MARK: - Initialization

    override init() {
        self.fftSize = 4096
        self.windowedBuffer = [Float](repeating: 0, count: fftSize)
        super.init()
    }

    // MARK: - Public Methods

    func startRecording(to url: URL) async throws {
        guard !isRecording else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Create audio file
        audioFile = try AVAudioFile(
            forWriting: url,
            settings: recordingFormat.settings
        )

        // Install tap for real-time processing
        inputNode.installTap(
            onBus: 0,
            bufferSize: 4096,
            format: recordingFormat
        ) { [weak self] buffer, time in
            guard let self = self else { return }

            // Write to file
            try? self.audioFile?.write(from: buffer)

            // Extract samples for real-time analysis
            if let onBufferReceived = self.onBufferReceived {
                let samples = self.extractSamples(from: buffer)
                Task { @MainActor in
                    onBufferReceived(samples)
                }
            }
        }

        // Start audio engine
        try audioEngine.start()

        // Update state
        isRecording = true
        recordingStartTime = Date()

        // Start timer for duration tracking
        recordingTimer = Timer.scheduledTimer(
            withTimeInterval: 0.1,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self,
                      let startTime = self.recordingStartTime else { return }
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }

        // Add timer to common run loop mode for UI updates
        if let timer = recordingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopRecording() async -> URL? {
        guard isRecording else { return nil }

        // Stop timer
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop engine
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        // Get file URL before closing
        let fileURL = audioFile?.url

        // Close file
        audioFile = nil

        // Update state
        isRecording = false
        recordingDuration = 0
        recordingStartTime = nil

        return fileURL
    }

    // MARK: - Private Methods

    private func extractSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: frameCount
        ))

        return samples
    }

    // MARK: - Deinitialization

    deinit {
        recordingTimer?.invalidate()
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }
}
