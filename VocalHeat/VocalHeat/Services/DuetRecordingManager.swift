//
//  DuetRecordingManager.swift
//  VocalHeat
//
//  Coordinates recording and playback with async/await
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation

@MainActor
class DuetRecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordingDuration: TimeInterval = 0

    // MARK: - Properties

    private let audioRecorder = AudioRecorder()
    private var artistPlayer: AVAudioPlayer?
    private let audioSessionManager: AudioSessionManager

    private let fileManager = FileManager.default
    private let recordingsDirectory: URL

    // MARK: - Initialization

    init(audioSessionManager: AudioSessionManager) {
        self.audioSessionManager = audioSessionManager

        let documentsDir = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        self.recordingsDirectory = documentsDir.appendingPathComponent("Recordings")

        // Create directory
        try? fileManager.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )

        // Observe recorder state
        Task {
            for await isRecording in audioRecorder.$isRecording.values {
                self.isRecording = isRecording
            }
        }

        Task {
            for await duration in audioRecorder.$recordingDuration.values {
                self.recordingDuration = duration
            }
        }
    }

    // MARK: - Public Methods (Async/Await)

    func startDuetRecording(artistTrackURL: URL) async throws -> DuetSession {
        // Configure audio session
        audioSessionManager.configureSession()

        // Generate recording URL
        let recordingFilename = "\(UUID().uuidString).m4a"
        let recordingURL = recordingsDirectory.appendingPathComponent(recordingFilename)

        // Start artist playback
        try await startArtistPlayback(url: artistTrackURL)

        // Start recording (synchronized)
        let sharedStartTime = Date()

        try await audioRecorder.startRecording(to: recordingURL)

        // Get latency profile
        let latency = audioSessionManager.currentLatencyProfile ?? LatencyProfile(input: 0, output: 0)

        // Get artist duration
        let artistDuration = artistPlayer?.duration ?? 0

        // Create session
        let session = DuetSession(
            artistFileName: artistTrackURL.lastPathComponent,
            artistDurationSeconds: artistDuration,
            userMicFileName: recordingFilename,
            userMicDurationSeconds: 0, // Will update when recording stops
            sharedStartEpochMs: Int64(sharedStartTime.timeIntervalSince1970 * 1000),
            inputLatencyMs: latency.input,
            outputLatencyMs: latency.output
        )

        return session
    }

    func startSoloRecording() async throws -> DuetSession {
        // Configure audio session
        audioSessionManager.configureSession()

        // Generate recording URL
        let recordingFilename = "\(UUID().uuidString).m4a"
        let recordingURL = recordingsDirectory.appendingPathComponent(recordingFilename)

        // Start recording
        let sharedStartTime = Date()

        try await audioRecorder.startRecording(to: recordingURL)

        // Get latency profile
        let latency = audioSessionManager.currentLatencyProfile ?? LatencyProfile(input: 0, output: 0)

        // Create solo session
        let session = DuetSession(
            artistFileName: nil,
            artistDurationSeconds: nil,
            userMicFileName: recordingFilename,
            userMicDurationSeconds: 0,
            sharedStartEpochMs: Int64(sharedStartTime.timeIntervalSince1970 * 1000),
            inputLatencyMs: latency.input,
            outputLatencyMs: latency.output
        )

        return session
    }

    func stopRecording() async throws -> (recordingURL: URL, duration: TimeInterval) {
        // Stop artist playback if running
        artistPlayer?.stop()
        artistPlayer = nil
        isPlaying = false

        // Stop recording
        guard let recordingURL = await audioRecorder.stopRecording() else {
            throw RecordingError.noRecordingFound
        }

        // Get recording duration
        let audioFile = try AVAudioFile(forReading: recordingURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate

        return (recordingURL, duration)
    }

    func cancelRecording() async {
        // Stop everything
        artistPlayer?.stop()
        artistPlayer = nil

        _ = await audioRecorder.stopRecording()

        isRecording = false
        isPlaying = false
    }

    func getRecordingURL(filename: String) -> URL {
        return recordingsDirectory.appendingPathComponent(filename)
    }

    // MARK: - Private Methods

    private func startArtistPlayback(url: URL) async throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        player.play()

        artistPlayer = player
        isPlaying = true
    }
}

// MARK: - Recording Error

enum RecordingError: LocalizedError {
    case noRecordingFound
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .noRecordingFound:
            return "No recording was found."
        case .recordingFailed:
            return "Recording failed. Please try again."
        }
    }
}
