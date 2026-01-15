//
//  PitchSanitizer.swift
//  VocalHeat
//
//  Octave correction and outlier removal for pitch tracks
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

class PitchSanitizer {
    // MARK: - Configuration

    private let madThreshold: Double = 3.5  // Median Absolute Deviation threshold

    // MARK: - Public Methods

    func sanitize(_ pitchPoints: [PitchPoint]) -> [PitchPoint] {
        var sanitized = pitchPoints

        // Step 1: Fix octave errors
        sanitized = correctOctaveErrors(sanitized)

        // Step 2: Remove outliers using MAD
        sanitized = removeOutliers(sanitized)

        return sanitized
    }

    // MARK: - Private Methods

    private func correctOctaveErrors(_ points: [PitchPoint]) -> [PitchPoint] {
        guard points.count > 2 else { return points }

        var corrected = points
        let voicedIndices = points.enumerated().compactMap { $0.element.isVoiced ? $0.offset : nil }

        guard voicedIndices.count > 2 else { return points }

        // Calculate median frequency for reference
        let voicedFreqs = voicedIndices.map { points[$0].frequencyHz }
        let medianFreq = calculateMedian(voicedFreqs)

        // Check each voiced point
        for i in voicedIndices {
            let freq = points[i].frequencyHz

            // Check if it's an octave error (2x or 0.5x expected)
            let ratio = freq / medianFreq

            if ratio >= 1.8 && ratio <= 2.2 {
                // Octave too high - divide by 2
                corrected[i] = PitchPoint(
                    timeSeconds: points[i].timeSeconds,
                    frequencyHz: freq / 2.0,
                    confidence: points[i].confidence
                )
            } else if ratio >= 0.45 && ratio <= 0.55 {
                // Octave too low - multiply by 2
                corrected[i] = PitchPoint(
                    timeSeconds: points[i].timeSeconds,
                    frequencyHz: freq * 2.0,
                    confidence: points[i].confidence
                )
            }
        }

        return corrected
    }

    private func removeOutliers(_ points: [PitchPoint]) -> [PitchPoint] {
        let voicedPoints = points.filter { $0.isVoiced }

        guard voicedPoints.count > 5 else { return points }

        // Calculate median and MAD
        let frequencies = voicedPoints.map { $0.frequencyHz }
        let median = calculateMedian(frequencies)
        let deviations = frequencies.map { abs($0 - median) }
        let mad = calculateMedian(deviations)

        guard mad > 0 else { return points }

        // Remove outliers (points more than madThreshold * MAD from median)
        return points.map { point in
            guard point.isVoiced else { return point }

            let deviation = abs(point.frequencyHz - median)
            let isOutlier = deviation > madThreshold * mad

            if isOutlier {
                // Mark as unvoiced
                return PitchPoint(
                    timeSeconds: point.timeSeconds,
                    frequencyHz: 0,
                    confidence: 0
                )
            }

            return point
        }
    }

    private func calculateMedian(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }

        let sorted = values.sorted()
        let count = sorted.count

        if count % 2 == 0 {
            return (sorted[count / 2 - 1] + sorted[count / 2]) / 2.0
        } else {
            return sorted[count / 2]
        }
    }
}
