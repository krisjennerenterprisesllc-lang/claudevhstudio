//
//  PitchAnalyzer.swift
//  VocalHeat
//
//  Orchestrates pitch analysis pipeline with caching
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import CryptoKit

@MainActor
class PitchAnalyzer: ObservableObject {
    @Published var isAnalyzing = false
    @Published var progress: Double = 0

    // MARK: - Properties

    private let pitchDetector: PitchDetector
    private let pitchSanitizer: PitchSanitizer
    private let vibratoDetector: VibratoDetector

    private let cacheDirectory: URL
    private var analysisCache: [String: PitchAnalysisResult] = [:]

    // MARK: - Initialization

    init() {
        self.pitchDetector = PitchDetector()
        self.pitchSanitizer = PitchSanitizer()
        self.vibratoDetector = VibratoDetector()

        // Setup cache directory
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        self.cacheDirectory = documentsDir.appendingPathComponent("PitchCache")

        // Create cache directory if needed
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )

        loadCache()
    }

    // MARK: - Public Methods

    func analyze(audioURL: URL) async throws -> PitchAnalysisResult {
        isAnalyzing = true
        progress = 0

        defer {
            isAnalyzing = false
            progress = 0
        }

        // Check cache using stable hash
        let cacheKey = try generateCacheKey(for: audioURL)

        if let cached = analysisCache[cacheKey] {
            return cached
        }

        // Step 1: Detect pitch (30% progress)
        progress = 0.1
        var pitchPoints = try await pitchDetector.analyzeAudioFile(at: audioURL)
        progress = 0.3

        // Step 2: Sanitize (10% progress)
        pitchPoints = pitchSanitizer.sanitize(pitchPoints)
        progress = 0.4

        // Step 3: Create pitch track
        let pitchTrack = PitchTrack(
            audioFileName: audioURL.lastPathComponent,
            sampleRate: 100.0,
            pitchPoints: pitchPoints,
            extractionDate: Date()
        )
        progress = 0.5

        // Step 4: Detect vibrato (40% progress)
        let vibratoSegments = vibratoDetector.detectVibratoInTrack(pitchTrack)
        progress = 0.9

        // Step 5: Create segments for caching
        let pitchSegments = createPitchSegments(from: pitchTrack)
        progress = 1.0

        let result = PitchAnalysisResult(
            audioFileName: audioURL.lastPathComponent,
            pitchTrack: pitchTrack,
            vibratoSegments: vibratoSegments,
            pitchSegments: pitchSegments
        )

        // Cache result
        analysisCache[cacheKey] = result
        saveCache()

        return result
    }

    func clearCache() {
        analysisCache.removeAll()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(
            at: cacheDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Private Methods

    private func generateCacheKey(for url: URL) throws -> String {
        // Use file path and modification date for stable caching
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let modificationDate = attributes[.modificationDate] as? Date ?? Date()

        let combined = url.lastPathComponent + modificationDate.description
        let data = combined.data(using: .utf8) ?? Data()

        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func createPitchSegments(from track: PitchTrack) -> [PitchAnalysisResult.PitchSegmentData] {
        var segments: [PitchAnalysisResult.PitchSegmentData] = []
        var currentSegment: [PitchPoint] = []
        var segmentStartTime: Double = 0

        for point in track.pitchPoints {
            if point.isVoiced {
                if currentSegment.isEmpty {
                    segmentStartTime = point.timeSeconds
                }
                currentSegment.append(point)
            } else {
                if !currentSegment.isEmpty {
                    let segment = PitchSegment(
                        startTime: segmentStartTime,
                        endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                        pitchPoints: currentSegment
                    )

                    segments.append(PitchAnalysisResult.PitchSegmentData(
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        averageFrequency: segment.averageFrequency,
                        medianFrequency: segment.medianFrequency,
                        variance: segment.variance
                    ))

                    currentSegment = []
                }
            }
        }

        // Add final segment
        if !currentSegment.isEmpty {
            let segment = PitchSegment(
                startTime: segmentStartTime,
                endTime: currentSegment.last?.timeSeconds ?? segmentStartTime,
                pitchPoints: currentSegment
            )

            segments.append(PitchAnalysisResult.PitchSegmentData(
                startTime: segment.startTime,
                endTime: segment.endTime,
                averageFrequency: segment.averageFrequency,
                medianFrequency: segment.medianFrequency,
                variance: segment.variance
            ))
        }

        return segments
    }

    private func loadCache() {
        let cacheFile = cacheDirectory.appendingPathComponent("cache.json")

        guard FileManager.default.fileExists(atPath: cacheFile.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: cacheFile)
            analysisCache = try JSONDecoder().decode([String: PitchAnalysisResult].self, from: data)
        } catch {
            print("Failed to load pitch analysis cache: \(error)")
        }
    }

    private func saveCache() {
        let cacheFile = cacheDirectory.appendingPathComponent("cache.json")

        do {
            let data = try JSONEncoder().encode(analysisCache)
            try data.write(to: cacheFile, options: [.atomic])
        } catch {
            print("Failed to save pitch analysis cache: \(error)")
        }
    }
}
