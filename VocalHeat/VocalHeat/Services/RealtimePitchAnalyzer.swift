//
//  RealtimePitchAnalyzer.swift
//  VocalHeat
//
//  Live pitch analysis with 30fps throttling and optimized buffers
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import Combine

@MainActor
class RealtimePitchAnalyzer: ObservableObject {
    @Published var currentPitch: PitchPoint?
    @Published var pitchHistory: [PitchDataPoint] = []
    @Published var isRunning = false

    // MARK: - Properties

    private let pitchDetector: PitchDetector
    private var startTime: Date?
    private var lastUpdateTime: Date?
    private let updateInterval: TimeInterval = 1.0 / 30.0 // 30fps throttling

    // MARK: - Initialization

    init() {
        self.pitchDetector = PitchDetector()
    }

    // MARK: - Public Methods

    func start() {
        isRunning = true
        startTime = Date()
        lastUpdateTime = Date()
        pitchHistory.removeAll(keepingCapacity: true) // Keep capacity for performance
    }

    func stop() {
        isRunning = false
        startTime = nil
        lastUpdateTime = nil
    }

    func processAudioBuffer(_ samples: [Float]) {
        guard isRunning else { return }

        // Throttle updates to 30fps
        let now = Date()
        if let lastUpdate = lastUpdateTime,
           now.timeIntervalSince(lastUpdate) < updateInterval {
            return
        }

        lastUpdateTime = now

        // Detect pitch
        if var point = pitchDetector.detectPitch(in: samples) {
            // Calculate time since start
            let timeSeconds = startTime.map { now.timeIntervalSince($0) } ?? 0

            point = PitchPoint(
                timeSeconds: timeSeconds,
                frequencyHz: point.frequencyHz,
                confidence: point.confidence
            )

            currentPitch = point

            // Add to history
            let dataPoint = PitchDataPoint(
                time: timeSeconds,
                frequency: point.frequencyHz,
                isVoiced: point.isVoiced
            )

            pitchHistory.append(dataPoint)

            // Limit history to last 10 seconds (300 points at 30fps)
            if pitchHistory.count > 300 {
                pitchHistory.removeFirst()
            }
        }
    }

    func reset() {
        pitchHistory.removeAll()
        currentPitch = nil
        startTime = Date()
        lastUpdateTime = Date()
    }
}

// MARK: - Pitch Data Point

struct PitchDataPoint: Identifiable {
    let id = UUID()
    let time: Double
    let frequency: Double
    let isVoiced: Bool

    var midiNote: Double? {
        guard isVoiced, frequency > 0 else { return nil }
        return 69 + 12 * log2(frequency / 440.0)
    }
}
