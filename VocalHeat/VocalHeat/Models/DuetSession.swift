//
//  DuetSession.swift
//  VocalHeat
//
//  Models for duet recording sessions and analysis results
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

// MARK: - Duet Session Model

struct DuetSession: Codable, Identifiable {
    let id: UUID
    let artistFileName: String?             // Optional - nil for solo recordings
    let artistDurationSeconds: Double?      // Optional - nil for solo recordings
    let userMicFileName: String
    let userMicDurationSeconds: Double
    let sharedStartEpochMs: Int64
    let inputLatencyMs: Int
    let outputLatencyMs: Int
    let manualOffsetSeconds: Double
    let createdAtISO8601: String
    let genre: MusicGenre                   // Genre for scoring rules

    // Analysis results (populated after analysis)
    var analysisResults: AnalysisResults?
    var coachingNarrative: String?

    var isSoloRecording: Bool {
        return artistFileName == nil
    }

    init(
        id: UUID = UUID(),
        artistFileName: String? = nil,
        artistDurationSeconds: Double? = nil,
        userMicFileName: String,
        userMicDurationSeconds: Double,
        sharedStartEpochMs: Int64,
        inputLatencyMs: Int,
        outputLatencyMs: Int,
        manualOffsetSeconds: Double = 0.0,
        genre: MusicGenre = .pop
    ) {
        self.id = id
        self.artistFileName = artistFileName
        self.artistDurationSeconds = artistDurationSeconds
        self.userMicFileName = userMicFileName
        self.userMicDurationSeconds = userMicDurationSeconds
        self.sharedStartEpochMs = sharedStartEpochMs
        self.inputLatencyMs = inputLatencyMs
        self.outputLatencyMs = outputLatencyMs
        self.manualOffsetSeconds = manualOffsetSeconds
        self.genre = genre
        self.createdAtISO8601 = ISO8601DateFormatter().string(from: Date())
    }
}

// MARK: - Analysis Results

struct AnalysisResults: Codable {
    let pitchAccuracy: Double           // 0-100%
    let vibratoStability: VibratoMeasurement
    let toneConsistency: Double         // 0-100%
    let deliveryExpression: String      // "A+", "A", "B+", etc.
    let overallScore: Int               // 0-100

    // Detailed metrics
    let insightEvents: [InsightEvent]
}

// MARK: - Vibrato Measurement

struct VibratoMeasurement: Codable {
    let averageRate: Double?            // Hz (e.g., 6.2)
    let variance: Double?               // ±Hz (e.g., 0.3)
    let isHealthy: Bool

    var displayString: String {
        guard let rate = averageRate, let variance = variance else {
            return "No vibrato detected"
        }
        return String(format: "≈%.1f Hz ±%.1f", rate, variance)
    }
}

// MARK: - Insight Events

struct InsightEvent: Codable, Identifiable {
    let id: UUID
    let type: EventType
    let startTime: Double               // Seconds
    let endTime: Double                 // Seconds
    let title: String
    let description: String

    enum EventType: String, Codable {
        case vibrato = "vibrato"
        case difficultInterval = "difficult_interval"
        case sustainedHighNote = "sustained_high_note"
        case expressiveMoment = "expressive_moment"
    }

    init(
        id: UUID = UUID(),
        type: EventType,
        startTime: Double,
        endTime: Double,
        title: String,
        description: String
    ) {
        self.id = id
        self.type = type
        // Safety: Clamp to valid range, minimum 0.5 seconds
        self.startTime = max(0, startTime)
        self.endTime = max(startTime + 0.5, endTime)
        self.title = title
        self.description = description
    }
}

// MARK: - Latency Profile

struct LatencyProfile {
    let input: Int      // Input latency in ms
    let output: Int     // Output latency in ms
}

// MARK: - Helper Extensions

extension DuetSession {
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if let date = ISO8601DateFormatter().date(from: createdAtISO8601) {
            return formatter.string(from: date)
        }
        return createdAtISO8601
    }

    var scoreDisplay: String {
        if let results = analysisResults {
            return "\(results.overallScore)"
        }
        return "Not analyzed"
    }
}
