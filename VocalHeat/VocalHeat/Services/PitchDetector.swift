//
//  PitchDetector.swift
//  VocalHeat
//
//  FFT-based pitch detection with optimized setup reuse
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import Accelerate

class PitchDetector {
    // MARK: - Properties

    private let config: PitchDetectionConfig
    private let sampleRate: Double

    // FFT setup (created once, reused for performance)
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length

    // Pre-allocated buffers (reused to avoid allocations in hot path)
    private var realParts: [Float]
    private var imagParts: [Float]
    private var magnitudes: [Float]
    private var window: [Float]

    // MARK: - Initialization

    init(sampleRate: Double = 44100, config: PitchDetectionConfig = PitchDetectionConfig()) {
        self.sampleRate = sampleRate
        self.config = config

        // Calculate FFT parameters
        self.log2n = vDSP_Length(log2(Float(config.bufferSize)))
        let n = Int(1 << log2n)
        let nOver2 = n / 2

        // Create FFT setup once (CRITICAL: reuse for 60-80% performance improvement)
        guard let setup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup")
        }
        self.fftSetup = setup

        // Pre-allocate all buffers
        self.realParts = [Float](repeating: 0, count: nOver2)
        self.imagParts = [Float](repeating: 0, count: nOver2)
        self.magnitudes = [Float](repeating: 0, count: nOver2)
        self.window = [Float](repeating: 0, count: n)

        // Create Hamming window once
        vDSP_hamm_window(&self.window, vDSP_Length(n), 0)
    }

    deinit {
        // Clean up FFT setup
        vDSP_destroy_fftsetup(fftSetup)
    }

    // MARK: - Public Methods

    func detectPitch(in samples: [Float]) -> PitchPoint? {
        let n = config.bufferSize
        let nOver2 = n / 2

        guard samples.count >= n else { return nil }

        // Take first n samples
        var inputSamples = Array(samples.prefix(n))

        // Apply Hamming window (in-place)
        vDSP_vmul(inputSamples, 1, window, 1, &inputSamples, 1, vDSP_Length(n))

        // Prepare for FFT
        var splitComplex = DSPSplitComplex(
            realp: &realParts,
            imagp: &imagParts
        )

        // Convert to split complex format
        inputSamples.withUnsafeBytes { ptr in
            let complexPtr = ptr.bindMemory(to: DSPComplex.self)
            vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(nOver2))
        }

        // Perform FFT (reusing pre-created setup)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, Int32(FFT_FORWARD))

        // Calculate magnitudes
        vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(nOver2))

        // Find peak frequency
        guard let peakInfo = findPeakFrequency(magnitudes: magnitudes) else {
            return nil
        }

        let frequency = peakInfo.frequency
        let confidence = peakInfo.confidence

        // Validate frequency range
        guard frequency >= config.minFrequency,
              frequency <= config.maxFrequency,
              confidence >= config.confidenceThreshold else {
            return nil
        }

        return PitchPoint(
            timeSeconds: 0, // Will be set by caller
            frequencyHz: frequency,
            confidence: confidence
        )
    }

    func analyzeAudioFile(at url: URL) async throws -> [PitchPoint] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            throw NSError(domain: "PitchDetector", code: -1)
        }

        try file.read(into: buffer)

        return await analyzePCMBuffer(buffer, sampleRate: format.sampleRate)
    }

    func analyzePCMBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) async -> [PitchPoint] {
        guard let channelData = buffer.floatChannelData else {
            return []
        }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: frameCount
        ))

        var pitchPoints: [PitchPoint] = []
        var currentFrame = 0

        while currentFrame + config.bufferSize <= samples.count {
            let segment = Array(samples[currentFrame..<(currentFrame + config.bufferSize)])

            if var point = detectPitch(in: segment) {
                let timeSeconds = Double(currentFrame) / sampleRate
                point = PitchPoint(
                    timeSeconds: timeSeconds,
                    frequencyHz: point.frequencyHz,
                    confidence: point.confidence
                )
                pitchPoints.append(point)
            } else {
                // Add unvoiced point
                let timeSeconds = Double(currentFrame) / sampleRate
                pitchPoints.append(PitchPoint(
                    timeSeconds: timeSeconds,
                    frequencyHz: 0,
                    confidence: 0
                ))
            }

            currentFrame += config.hopSize
        }

        return pitchPoints
    }

    // MARK: - Private Methods

    private func findPeakFrequency(magnitudes: [Float]) -> (frequency: Double, confidence: Double)? {
        let nOver2 = magnitudes.count

        // Find peak in valid frequency range
        let minBin = Int(config.minFrequency * Double(config.bufferSize) / sampleRate)
        let maxBin = min(nOver2, Int(config.maxFrequency * Double(config.bufferSize) / sampleRate))

        guard minBin < maxBin else { return nil }

        let validMagnitudes = Array(magnitudes[minBin..<maxBin])

        guard let maxMagnitude = validMagnitudes.max(),
              maxMagnitude > 0,
              let peakIndex = validMagnitudes.firstIndex(of: maxMagnitude) else {
            return nil
        }

        let actualBin = minBin + peakIndex

        // Parabolic interpolation for better frequency resolution
        let refinedBin: Double
        if actualBin > 0 && actualBin < nOver2 - 1 {
            let alpha = magnitudes[actualBin - 1]
            let beta = magnitudes[actualBin]
            let gamma = magnitudes[actualBin + 1]

            let delta = 0.5 * (alpha - gamma) / (alpha - 2 * beta + gamma)
            refinedBin = Double(actualBin) + delta
        } else {
            refinedBin = Double(actualBin)
        }

        let frequency = refinedBin * sampleRate / Double(config.bufferSize)

        // Calculate confidence based on peak prominence
        let meanMagnitude = validMagnitudes.reduce(0, +) / Float(validMagnitudes.count)
        let confidence = min(1.0, Double(maxMagnitude / max(meanMagnitude * 3, 0.001)))

        return (frequency, confidence)
    }
}
