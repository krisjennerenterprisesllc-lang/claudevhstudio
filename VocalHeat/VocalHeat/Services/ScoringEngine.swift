//
//  ScoringEngine.swift
//  VocalHeat
//
//  4-metric scoring system with genre-aware evaluation
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

class ScoringEngine {
    // MARK: - Public Methods

    func scorePerformance(
        userTrack: PitchTrack,
        artistTrack: PitchTrack?,
        vibratoSegments: [VibratoAnalysis],
        genre: MusicGenre
    ) -> AnalysisResults {
        let rules = genre.rules

        // Calculate metrics
        let pitchAccuracy = calculatePitchAccuracy(
            userTrack: userTrack,
            artistTrack: artistTrack,
            tolerance: rules.pitchTolerance
        )

        let vibratoStability = evaluateVibratoStability(
            vibratoSegments: vibratoSegments,
            expectations: rules.vibratoExpectations
        )

        let toneConsistency = calculateToneConsistency(
            userTrack: userTrack
        )

        let deliveryExpression = evaluateDeliveryExpression(
            userTrack: userTrack,
            vibratoSegments: vibratoSegments,
            genre: genre
        )

        // Calculate overall score (weighted average)
        let overallScore = Int(
            pitchAccuracy * 0.4 +
            toneConsistency * 0.3 +
            (vibratoStability.isHealthy ? 100 : 50) * 0.15 +
            expressionToScore(deliveryExpression) * 0.15
        )

        // Generate insight events
        let insights = generateInsightEvents(
            userTrack: userTrack,
            vibratoSegments: vibratoSegments,
            genre: genre
        )

        return AnalysisResults(
            pitchAccuracy: pitchAccuracy,
            vibratoStability: vibratoStability,
            toneConsistency: toneConsistency,
            deliveryExpression: deliveryExpression,
            overallScore: max(0, min(100, overallScore)),
            insightEvents: insights
        )
    }

    // MARK: - Private Methods

    private func calculatePitchAccuracy(
        userTrack: PitchTrack,
        artistTrack: PitchTrack?,
        tolerance: Double
    ) -> Double {
        let voicedPoints = userTrack.voicedPoints

        guard !voicedPoints.isEmpty else { return 0 }

        if let artistTrack = artistTrack {
            // Compare with artist track
            return compareWithReference(
                userPoints: voicedPoints,
                referenceTrack: artistTrack,
                tolerance: tolerance
            )
        } else {
            // Solo performance - evaluate consistency
            return evaluateConsistency(voicedPoints, tolerance: tolerance)
        }
    }

    private func compareWithReference(
        userPoints: [PitchPoint],
        referenceTrack: PitchTrack,
        tolerance: Double
    ) -> Double {
        var totalDeviation: Double = 0
        var comparisonCount = 0

        for userPoint in userPoints {
            // Find closest reference point in time
            if let refPoint = findClosestPoint(
                at: userPoint.timeSeconds,
                in: referenceTrack.pitchPoints
            ), refPoint.isVoiced {
                let deviation = abs(userPoint.frequencyHz.cents(relativeTo: refPoint.frequencyHz))
                totalDeviation += min(deviation, tolerance * 2) // Cap at 2x tolerance

                comparisonCount += 1
            }
        }

        guard comparisonCount > 0 else { return 50 }

        let avgDeviation = totalDeviation / Double(comparisonCount)
        let accuracy = max(0, 100 - (avgDeviation / tolerance) * 50)

        return accuracy
    }

    private func evaluateConsistency(_ points: [PitchPoint], tolerance: Double) -> Double {
        guard points.count > 2 else { return 50 }

        // Calculate median frequency
        let frequencies = points.map { $0.frequencyHz }
        let median = calculateMedian(frequencies)

        // Measure deviations from median
        var totalDeviation: Double = 0

        for point in points {
            let deviation = abs(point.frequencyHz.cents(relativeTo: median))
            totalDeviation += min(deviation, tolerance * 2)
        }

        let avgDeviation = totalDeviation / Double(points.count)
        let accuracy = max(0, 100 - (avgDeviation / tolerance) * 50)

        return accuracy
    }

    private func evaluateVibratoStability(
        vibratoSegments: [VibratoAnalysis],
        expectations: VibratoExpectations
    ) -> VibratoMeasurement {
        let healthySegments = vibratoSegments.filter { $0.isHealthy }

        guard !healthySegments.isEmpty else {
            return VibratoMeasurement(
                averageRate: nil,
                variance: nil,
                isHealthy: expectations.presence == .notExpected
            )
        }

        let rates = healthySegments.compactMap { $0.rate }
        let variances = healthySegments.compactMap { $0.rateVariance }

        guard !rates.isEmpty else {
            return VibratoMeasurement(
                averageRate: nil,
                variance: nil,
                isHealthy: expectations.presence == .notExpected
            )
        }

        let avgRate = rates.reduce(0, +) / Double(rates.count)
        let avgVariance = variances.isEmpty ? 0 : variances.reduce(0, +) / Double(variances.count)

        let isHealthy: Bool
        switch expectations.presence {
        case .required, .encouraged:
            isHealthy = true
        case .optional:
            isHealthy = true
        case .notExpected:
            isHealthy = false
        }

        return VibratoMeasurement(
            averageRate: avgRate,
            variance: avgVariance,
            isHealthy: isHealthy
        )
    }

    private func calculateToneConsistency(_ track: PitchTrack) -> Double {
        let voicedPoints = track.voicedPoints

        guard voicedPoints.count > 10 else { return 50 }

        // Analyze confidence consistency
        let confidences = voicedPoints.map { $0.confidence }
        let avgConfidence = confidences.reduce(0, +) / Double(confidences.count)

        // Analyze frequency stability within segments
        var segmentStabilities: [Double] = []

        let segmentSize = 10
        for i in stride(from: 0, to: voicedPoints.count - segmentSize, by: segmentSize) {
            let segment = Array(voicedPoints[i..<min(i + segmentSize, voicedPoints.count)])
            let frequencies = segment.map { $0.frequencyHz }
            let median = calculateMedian(frequencies)

            // Calculate MAD for this segment
            let deviations = frequencies.map { abs($0 - median) }
            let mad = calculateMedian(deviations)

            // Lower MAD = higher stability
            let stability = max(0, 100 - (mad / median) * 1000)
            segmentStabilities.append(stability)
        }

        guard !segmentStabilities.isEmpty else { return avgConfidence * 100 }

        let avgStability = segmentStabilities.reduce(0, +) / Double(segmentStabilities.count)

        return (avgConfidence * 50) + (avgStability * 0.5)
    }

    private func evaluateDeliveryExpression(
        userTrack: PitchTrack,
        vibratoSegments: [VibratoAnalysis],
        genre: MusicGenre
    ) -> String {
        let voicedPoints = userTrack.voicedPoints

        guard !voicedPoints.isEmpty else { return "C" }

        // Calculate dynamic range
        let frequencies = voicedPoints.map { $0.frequencyHz }
        let minFreq = frequencies.min() ?? 0
        let maxFreq = frequencies.max() ?? 0
        let dynamicRange = maxFreq > 0 ? maxFreq.cents(relativeTo: minFreq) : 0

        // Evaluate vibrato presence
        let hasVibrato = !vibratoSegments.isEmpty
        let vibratoQuality = vibratoSegments.filter { $0.isHealthy }.count

        // Genre-specific evaluation
        let expectations = genre.rules.vibratoExpectations

        var score = 0

        // Dynamic range scoring
        if dynamicRange > 1200 { score += 3 } // Full octave+
        else if dynamicRange > 800 { score += 2 }
        else { score += 1 }

        // Vibrato scoring
        switch expectations.presence {
        case .required:
            if vibratoQuality >= 3 { score += 3 }
            else if hasVibrato { score += 1 }
        case .encouraged:
            if vibratoQuality >= 2 { score += 2 }
            else if hasVibrato { score += 1 }
        case .optional:
            score += hasVibrato ? 2 : 1
        case .notExpected:
            score += hasVibrato ? 0 : 2
        }

        // Convert score to grade
        switch score {
        case 6...: return "A+"
        case 5: return "A"
        case 4: return "B+"
        case 3: return "B"
        case 2: return "C+"
        default: return "C"
        }
    }

    private func generateInsightEvents(
        userTrack: PitchTrack,
        vibratoSegments: [VibratoAnalysis],
        genre: MusicGenre
    ) -> [InsightEvent] {
        var insights: [InsightEvent] = []

        // Add vibrato events
        for vibrato in vibratoSegments.filter({ $0.isHealthy }) {
            insights.append(InsightEvent(
                type: .vibrato,
                startTime: vibrato.startTime,
                endTime: vibrato.endTime,
                title: "Healthy Vibrato",
                description: "Excellent vibrato control with \(String(format: "%.1f", vibrato.rate ?? 0)) Hz oscillation"
            ))
        }

        // Find sustained notes (long segments without much variation)
        let segments = findSustainedSegments(in: userTrack)

        for segment in segments.prefix(3) { // Top 3 sustained notes
            if let midiNote = segment.pitchPoints.first?.midiNote {
                let noteName = midiNoteToName(Int(midiNote))

                insights.append(InsightEvent(
                    type: .sustainedHighNote,
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    title: "Sustained \(noteName)",
                    description: "Held steady for \(String(format: "%.1f", segment.duration))s"
                ))
            }
        }

        return insights
    }

    // MARK: - Helper Methods

    private func findClosestPoint(at time: Double, in points: [PitchPoint]) -> PitchPoint? {
        return points.min(by: { abs($0.timeSeconds - time) < abs($1.timeSeconds - time) })
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

    private func expressionToScore(_ expression: String) -> Double {
        switch expression {
        case "A+": return 100
        case "A": return 95
        case "B+": return 85
        case "B": return 75
        case "C+": return 65
        default: return 50
        }
    }

    private func findSustainedSegments(in track: PitchTrack) -> [PitchSegment] {
        var segments: [PitchSegment] = []
        var currentSegment: [PitchPoint] = []
        var segmentStartTime: Double = 0

        for point in track.voicedPoints {
            if currentSegment.isEmpty {
                segmentStartTime = point.timeSeconds
                currentSegment = [point]
            } else {
                // Check if frequency is similar (within 50 cents)
                let lastFreq = currentSegment.last?.frequencyHz ?? 0
                let deviation = abs(point.frequencyHz.cents(relativeTo: lastFreq))

                if deviation < 50 {
                    currentSegment.append(point)
                } else {
                    // End current segment
                    if currentSegment.count > 20 { // At least 2 seconds at 10fps
                        segments.append(PitchSegment(
                            startTime: segmentStartTime,
                            endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                            pitchPoints: currentSegment
                        ))
                    }

                    segmentStartTime = point.timeSeconds
                    currentSegment = [point]
                }
            }
        }

        // Add final segment
        if currentSegment.count > 20 {
            segments.append(PitchSegment(
                startTime: segmentStartTime,
                endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                pitchPoints: currentSegment
            ))
        }

        return segments.sorted(by: { $0.duration > $1.duration })
    }

    private func midiNoteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }
}
