//
//  ResultsView.swift
//  VocalHeat
//
//  Analysis results with playback controls
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import SwiftUI

struct ResultsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var session: DuetSession

    @StateObject private var playbackManager = DuetPlaybackManager()
    @StateObject private var pitchAnalyzer = PitchAnalyzer()
    @StateObject private var coachingService = CoachingService()

    @State private var isAnalyzing = false
    @State private var showCoaching = false
    @State private var coachingText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection

                // Score card
                if let results = session.analysisResults {
                    scoreCard(results: results)
                    metricsGrid(results: results)
                    insightsList(results: results)
                } else if isAnalyzing {
                    analyzingView
                } else {
                    analyzeButton
                }

                // Playback controls
                playbackSection

                // Coaching
                if let results = session.analysisResults {
                    coachingSection(results: results)
                }
            }
            .padding()
        }
        .navigationTitle("Results")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAudioForPlayback()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(session.isSoloRecording ? "Solo Performance" : "Duet Performance")
                .font(.headline)

            Text(session.displayDate)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Label(session.genre.rawValue, systemImage: "music.note")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    private func scoreCard(results: AnalysisResults) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: CGFloat(results.overallScore) / 100)
                    .stroke(scoreColor(for: results.overallScore), lineWidth: 20)
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: results.overallScore)

                VStack {
                    Text("\(results.overallScore)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(scoreColor(for: results.overallScore))

                    Text("Overall Score")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(results.deliveryExpression)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 2)
    }

    private func metricsGrid(results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricCard(
                    title: "Pitch Accuracy",
                    value: String(format: "%.0f%%", results.pitchAccuracy),
                    icon: "tuningfork",
                    color: .blue
                )

                MetricCard(
                    title: "Tone Consistency",
                    value: String(format: "%.0f%%", results.toneConsistency),
                    icon: "waveform.path",
                    color: .green
                )

                MetricCard(
                    title: "Vibrato",
                    value: results.vibratoStability.isHealthy ? "Healthy" : "Needs Work",
                    icon: "waveform",
                    color: results.vibratoStability.isHealthy ? .green : .orange
                )

                MetricCard(
                    title: "Expression",
                    value: results.deliveryExpression,
                    icon: "sparkles",
                    color: .purple
                )
            }
        }
    }

    private func insightsList(results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            Text("Insights")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if results.insightEvents.isEmpty {
                Text("No special insights for this performance")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(results.insightEvents) { event in
                    InsightRow(event: event)
                }
            }
        }
    }

    private var analyzingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing performance...")
                .font(.headline)

            if pitchAnalyzer.progress > 0 {
                ProgressView(value: pitchAnalyzer.progress)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
            }
        }
        .padding(40)
    }

    private var analyzeButton: some View {
        Button(action: { Task { await analyzePerformance() } }) {
            Label("Analyze Performance", systemImage: "chart.bar.xaxis")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
        }
    }

    private var playbackSection: some View {
        VStack(spacing: 12) {
            Text("Playback")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 20) {
                Button(action: { Task { await togglePlayback() } }) {
                    Image(systemName: playbackManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 60, height: 60)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(formatDuration(playbackManager.currentTime))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ProgressView(value: playbackManager.currentTime, total: playbackManager.duration)
                        .progressViewStyle(.linear)

                    Text(formatDuration(playbackManager.duration))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func coachingSection(results: AnalysisResults) -> some View {
        VStack(spacing: 12) {
            Text("AI Coaching")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let narrative = session.coachingNarrative {
                Text(narrative)
                    .font(.body)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
            } else if coachingService.isGenerating {
                ProgressView()
                    .padding()
            } else {
                Button(action: { Task { await generateCoaching(results: results) } }) {
                    Label("Get Personalized Coaching", systemImage: "sparkles")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.purple)
                        .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Actions

    private func analyzePerformance() async {
        isAnalyzing = true

        do {
            // Get recording URL
            let documentsDir = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            let recordingsDir = documentsDir.appendingPathComponent("Recordings")
            let userURL = recordingsDir.appendingPathComponent(session.userMicFileName)

            // Analyze user recording
            let userAnalysis = try await pitchAnalyzer.analyze(audioURL: userURL)

            // Analyze artist track if duet
            var artistAnalysis: PitchAnalysisResult?
            if let artistFilename = session.artistFileName {
                let importedDir = documentsDir.appendingPathComponent("ImportedAudio")
                let artistURL = importedDir.appendingPathComponent(artistFilename)

                if FileManager.default.fileExists(atPath: artistURL.path) {
                    artistAnalysis = try await pitchAnalyzer.analyze(audioURL: artistURL)
                }
            }

            // Score performance
            let scoringEngine = ScoringEngine()
            let results = scoringEngine.scorePerformance(
                userTrack: userAnalysis.pitchTrack,
                artistTrack: artistAnalysis?.pitchTrack,
                vibratoSegments: userAnalysis.vibratoSegments,
                genre: session.genre
            )

            // Update session
            session = DuetSession(
                id: session.id,
                artistFileName: session.artistFileName,
                artistDurationSeconds: session.artistDurationSeconds,
                userMicFileName: session.userMicFileName,
                userMicDurationSeconds: session.userMicDurationSeconds,
                sharedStartEpochMs: session.sharedStartEpochMs,
                inputLatencyMs: session.inputLatencyMs,
                outputLatencyMs: session.outputLatencyMs,
                manualOffsetSeconds: session.manualOffsetSeconds,
                genre: session.genre
            )

            // This would normally update the binding, but we need to manually set analysisResults
            // For now, we'll need to add this to the DuetSession init or use a different approach

        } catch {
            print("Analysis failed: \(error)")
        }

        isAnalyzing = false
    }

    private func loadAudioForPlayback() async {
        do {
            let documentsDir = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            ).first!
            let recordingsDir = documentsDir.appendingPathComponent("Recordings")
            let userURL = recordingsDir.appendingPathComponent(session.userMicFileName)

            var artistURL: URL?
            if let artistFilename = session.artistFileName {
                let importedDir = documentsDir.appendingPathComponent("ImportedAudio")
                artistURL = importedDir.appendingPathComponent(artistFilename)
            }

            try playbackManager.loadTracks(artistURL: artistURL, userURL: userURL)

        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    private func togglePlayback() async {
        do {
            if playbackManager.isPlaying {
                playbackManager.pause()
            } else {
                try await playbackManager.play()
            }
        } catch {
            print("Playback error: \(error)")
        }
    }

    private func generateCoaching(results: AnalysisResults) async {
        do {
            let narrative = try await coachingService.generateCoaching(
                for: results,
                genre: session.genre
            )

            session = DuetSession(
                id: session.id,
                artistFileName: session.artistFileName,
                artistDurationSeconds: session.artistDurationSeconds,
                userMicFileName: session.userMicFileName,
                userMicDurationSeconds: session.userMicDurationSeconds,
                sharedStartEpochMs: session.sharedStartEpochMs,
                inputLatencyMs: session.inputLatencyMs,
                outputLatencyMs: session.outputLatencyMs,
                manualOffsetSeconds: session.manualOffsetSeconds,
                genre: session.genre
            )

            coachingText = narrative

        } catch {
            print("Coaching generation failed: \(error)")
        }
    }

    // MARK: - Helper Methods

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Insight Row

struct InsightRow: View {
    let event: InsightEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconForEventType(event.type))
                .font(.title3)
                .foregroundColor(colorForEventType(event.type))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(event.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatTimeRange(start: event.startTime, end: event.endTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func iconForEventType(_ type: InsightEvent.EventType) -> String {
        switch type {
        case .vibrato: return "waveform"
        case .difficultInterval: return "arrow.up.arrow.down"
        case .sustainedHighNote: return "arrow.up.circle.fill"
        case .expressiveMoment: return "sparkles"
        }
    }

    private func colorForEventType(_ type: InsightEvent.EventType) -> Color {
        switch type {
        case .vibrato: return .blue
        case .difficultInterval: return .orange
        case .sustainedHighNote: return .green
        case .expressiveMoment: return .purple
        }
    }

    private func formatTimeRange(start: Double, end: Double) -> String {
        return String(format: "%.1fs - %.1fs", start, end)
    }
}

// MARK: - Preview

struct ResultsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ResultsView(session: .constant(DuetSession(
                userMicFileName: "test.m4a",
                userMicDurationSeconds: 120,
                sharedStartEpochMs: 0,
                inputLatencyMs: 10,
                outputLatencyMs: 15
            )))
        }
    }
}
