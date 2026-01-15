//
//  PitchPoint.swift
//  VocalHeat
//
//  PHASE 4: Pitch Analysis Models
//  Data structures for pitch detection and analysis
//
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

// MARK: - Pitch Point

struct PitchPoint: Codable {
    let timeSeconds: Double         // Time in audio file
    let frequencyHz: Double         // Detected frequency (0 = silence/unvoiced)
    let confidence: Double          // Detection confidence (0-1)

    var isVoiced: Bool {
        frequencyHz > 0 && confidence > 0.5
    }

    var midiNote: Double? {
        guard isVoiced else { return nil }
        return 69 + 12 * log2(frequencyHz / 440.0)
    }
}

// MARK: - Pitch Track

struct PitchTrack: Codable {
    let audioFileName: String
    let sampleRate: Double              // Analysis sample rate (e.g., 100 Hz)
    let pitchPoints: [PitchPoint]
    let extractionDate: Date

    var duration: Double {
        guard let last = pitchPoints.last else { return 0 }
        return last.timeSeconds
    }

    var voicedPoints: [PitchPoint] {
        pitchPoints.filter { $0.isVoiced }
    }

    var averageFrequency: Double? {
        let voiced = voicedPoints
        guard !voiced.isEmpty else { return nil }
        return voiced.map { $0.frequencyHz }.reduce(0, +) / Double(voiced.count)
    }
}

// MARK: - Vibrato Analysis

struct VibratoAnalysis: Codable {
    let isPresent: Bool
    let rate: Double?                   // Hz (e.g., 6.2)
    let rateVariance: Double?           // ±Hz (e.g., 0.3)
    let extent: Double?                 // cents (e.g., ±35)
    let centerPitch: Double?            // Hz (if vibrato, this is "true" pitch)
    let startTime: Double
    let endTime: Double

    var isHealthy: Bool {
        guard isPresent,
              let rate = rate,
              let variance = rateVariance else {
            return false
        }

        // Healthy vibrato: 4-7 Hz, consistent (variance < 0.5 Hz)
        return (4...7).contains(rate) && variance < 0.5
    }

    var displayString: String {
        guard isPresent, let rate = rate, let variance = rateVariance else {
            return "No vibrato"
        }
        return String(format: "≈%.1f Hz ±%.1f", rate, variance)
    }
}

// MARK: - Pitch Segment

/// A continuous segment of pitched audio (used for analysis)
struct PitchSegment {
    let startTime: Double
    let endTime: Double
    let pitchPoints: [PitchPoint]

    var duration: Double {
        endTime - startTime
    }

    var averageFrequency: Double {
        let frequencies = pitchPoints.map { $0.frequencyHz }
        return frequencies.reduce(0, +) / Double(frequencies.count)
    }

    var medianFrequency: Double {
        let sorted = pitchPoints.map { $0.frequencyHz }.sorted()
        let mid = sorted.count / 2
        if sorted.count % 2 == 0 {
            return (sorted[mid - 1] + sorted[mid]) / 2.0
        } else {
            return sorted[mid]
        }
    }

    var variance: Double {
        let avg = averageFrequency
        let squaredDiffs = pitchPoints.map { pow($0.frequencyHz - avg, 2) }
        return squaredDiffs.reduce(0, +) / Double(squaredDiffs.count)
    }

    var standardDeviation: Double {
        sqrt(variance)
    }

    // Median Absolute Deviation (more robust than std dev)
    var mad: Double {
        let median = medianFrequency
        let deviations = pitchPoints.map { abs($0.frequencyHz - median) }
        let sortedDeviations = deviations.sorted()
        let mid = sortedDeviations.count / 2
        if sortedDeviations.count % 2 == 0 {
            return (sortedDeviations[mid - 1] + sortedDeviations[mid]) / 2.0
        } else {
            return sortedDeviations[mid]
        }
    }
}

// MARK: - Pitch Analysis Result

struct PitchAnalysisResult: Codable {
    let audioFileName: String
    let pitchTrack: PitchTrack
    let vibratoSegments: [VibratoAnalysis]
    let pitchSegments: [PitchSegmentData]   // For caching

    struct PitchSegmentData: Codable {
        let startTime: Double
        let endTime: Double
        let averageFrequency: Double
        let medianFrequency: Double
        let variance: Double
    }
}

// MARK: - Pitch Detection Configuration

struct PitchDetectionConfig {
    let minFrequency: Double = 80.0         // E2 (low male voice)
    let maxFrequency: Double = 1000.0       // B5 (high soprano)
    let sampleRate: Double = 100.0          // 100 Hz (every 10ms)
    let hopSize: Int = 441                  // For 44.1kHz audio, ~10ms
    let bufferSize: Int = 4096              // Analysis window
    let confidenceThreshold: Double = 0.5   // Minimum confidence for voiced

    // Vibrato detection
    let vibratoMinDuration: Double = 1.0    // Minimum 1 second for vibrato
    let vibratoMinRate: Double = 4.0        // Minimum 4 Hz
    let vibratoMaxRate: Double = 7.0        // Maximum 7 Hz

    // Segmentation
    let minSegmentDuration: Double = 0.5    // Minimum 0.5 seconds
    let silenceThreshold: Double = 0.3      // Confidence < 0.3 = silence
}

// MARK: - Helper Extensions

extension Double {
    /// Convert frequency to cents relative to reference
    func cents(relativeTo reference: Double) -> Double {
        1200 * log2(self / reference)
    }

    /// Convert cents deviation to frequency
    static func frequency(from cents: Double, reference: Double) -> Double {
        reference * pow(2, cents / 1200)
    }
}
