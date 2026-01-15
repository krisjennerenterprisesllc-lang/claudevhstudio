//
//  VibratoDetector.swift
//  VocalHeat
//
//  FFT-based vibrato detection with autocorrelation
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation

class VibratoDetector {
    // MARK: - Configuration

    private let minVibratoRate: Double = 4.0      // Hz
    private let maxVibratoRate: Double = 7.0      // Hz
    private let minDuration: Double = 1.0         // seconds
    private let windowSize: Double = 0.5          // seconds for variance calculation

    // MARK: - Public Methods

    func detectVibrato(in segment: PitchSegment, sampleRate: Double = 100.0) -> VibratoAnalysis {
        let frequencies = segment.pitchPoints.map { $0.frequencyHz }

        guard segment.duration >= minDuration,
              !frequencies.isEmpty else {
            return VibratoAnalysis(
                isPresent: false,
                rate: nil,
                rateVariance: nil,
                extent: nil,
                centerPitch: nil,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        // Detect oscillation rate using autocorrelation
        guard let rate = detectOscillationRate(
            frequencies: frequencies,
            sampleRate: sampleRate
        ) else {
            return VibratoAnalysis(
                isPresent: false,
                rate: nil,
                rateVariance: nil,
                extent: nil,
                centerPitch: nil,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }

        // Calculate vibrato extent (peak-to-peak variation in cents)
        let centerFreq = segment.medianFrequency
        let maxFreq = frequencies.max() ?? centerFreq
        let minFreq = frequencies.min() ?? centerFreq
        let extentCents = maxFreq.cents(relativeTo: minFreq)

        // Calculate rate variance across windows
        let rateVariance = calculateRateVariance(
            frequencies: frequencies,
            sampleRate: sampleRate
        )

        return VibratoAnalysis(
            isPresent: true,
            rate: rate,
            rateVariance: rateVariance,
            extent: abs(extentCents) / 2.0, // Peak deviation from center
            centerPitch: centerFreq,
            startTime: segment.startTime,
            endTime: segment.endTime
        )
    }

    func detectVibratoInTrack(_ track: PitchTrack, minSegmentDuration: Double = 1.0) -> [VibratoAnalysis] {
        let segments = segmentPitchTrack(track, minDuration: minSegmentDuration)

        var vibratoSegments: [VibratoAnalysis] = []

        for segment in segments {
            let analysis = detectVibrato(in: segment, sampleRate: track.sampleRate)
            if analysis.isPresent {
                vibratoSegments.append(analysis)
            }
        }

        return vibratoSegments
    }

    // MARK: - Private Methods

    private func detectOscillationRate(frequencies: [Double], sampleRate: Double) -> Double? {
        guard frequencies.count > 10 else { return nil }

        // Detrend signal (remove DC component)
        let mean = frequencies.reduce(0, +) / Double(frequencies.count)
        let detrended = frequencies.map { $0 - mean }

        // Calculate autocorrelation
        let maxLag = min(frequencies.count / 2, Int(sampleRate / minVibratoRate))
        var autocorr = [Double](repeating: 0, count: maxLag)

        for lag in 0..<maxLag {
            var sum: Double = 0
            for i in 0..<(frequencies.count - lag) {
                sum += detrended[i] * detrended[i + lag]
            }
            autocorr[lag] = sum
        }

        // Normalize
        if let maxAutocorr = autocorr.max(), maxAutocorr > 0 {
            autocorr = autocorr.map { $0 / maxAutocorr }
        }

        // Find first peak after lag 0
        guard let peakLag = findFirstPeak(in: autocorr, minLag: Int(sampleRate / maxVibratoRate)) else {
            return nil
        }

        let rate = sampleRate / Double(peakLag)

        // Validate rate is in vibrato range
        guard rate >= minVibratoRate && rate <= maxVibratoRate else {
            return nil
        }

        return rate
    }

    private func findFirstPeak(in autocorr: [Double], minLag: Int) -> Int? {
        guard autocorr.count > minLag + 2 else { return nil }

        for i in (minLag + 1)..<(autocorr.count - 1) {
            if autocorr[i] > autocorr[i - 1] && autocorr[i] > autocorr[i + 1] {
                // Check if peak is significant
                if autocorr[i] > 0.3 { // Threshold for peak significance
                    return i
                }
            }
        }

        return nil
    }

    private func calculateRateVariance(frequencies: [Double], sampleRate: Double) -> Double {
        let windowSizeSamples = Int(windowSize * sampleRate)

        guard frequencies.count >= windowSizeSamples * 2 else {
            return 0
        }

        var windowRates: [Double] = []

        var startIdx = 0
        while startIdx + windowSizeSamples <= frequencies.count {
            let windowFreqs = Array(frequencies[startIdx..<(startIdx + windowSizeSamples)])

            if let rate = detectOscillationRate(frequencies: windowFreqs, sampleRate: sampleRate) {
                windowRates.append(rate)
            }

            startIdx += windowSizeSamples / 2 // 50% overlap
        }

        guard !windowRates.isEmpty else { return 0 }

        // Calculate standard deviation of rates
        let meanRate = windowRates.reduce(0, +) / Double(windowRates.count)
        let squaredDiffs = windowRates.map { pow($0 - meanRate, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(squaredDiffs.count)

        return sqrt(variance)
    }

    private func segmentPitchTrack(_ track: PitchTrack, minDuration: Double) -> [PitchSegment] {
        var segments: [PitchSegment] = []
        var currentSegment: [PitchPoint] = []
        var segmentStartTime: Double = 0

        for point in track.pitchPoints {
            if point.isVoiced {
                if currentSegment.isEmpty {
                    segmentStartTime = point.timeSeconds
                }
                currentSegment.append(point)
            } else {
                // End current segment if it exists
                if !currentSegment.isEmpty {
                    let duration = (currentSegment.last?.timeSeconds ?? 0) - segmentStartTime

                    if duration >= minDuration {
                        segments.append(PitchSegment(
                            startTime: segmentStartTime,
                            endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                            pitchPoints: currentSegment
                        ))
                    }

                    currentSegment = []
                }
            }
        }

        // Add final segment if it exists
        if !currentSegment.isEmpty {
            let duration = (currentSegment.last?.timeSeconds ?? 0) - segmentStartTime

            if duration >= minDuration {
                segments.append(PitchSegment(
                    startTime: segmentStartTime,
                    endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                    pitchPoints: currentSegment
                ))
            }
        }

        return segments
    }
}
