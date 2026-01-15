//
//  PitchVisualizationView.swift
//  VocalHeat
//
//  Real-time pitch graph with optimized rendering
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import SwiftUI
import Charts

struct PitchVisualizationView: View {
    @ObservedObject var analyzer: RealtimePitchAnalyzer

    let windowDuration: Double = 5.0 // Show last 5 seconds

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pitch")
                .font(.caption)
                .foregroundColor(.secondary)

            Chart {
                ForEach(visiblePitchPoints) { point in
                    if point.isVoiced {
                        LineMark(
                            x: .value("Time", point.time),
                            y: .value("Note", point.midiNote ?? 69)
                        )
                        .foregroundStyle(pitchColor(for: point))
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                }
            }
            .chartXScale(domain: visibleTimeRange)
            .chartYScale(domain: 50...90) // Roughly A2 to F6
            .chartYAxis {
                AxisMarks(values: .stride(by: 12)) { value in
                    if let midiNote = value.as(Int.self) {
                        AxisGridLine()
                        AxisValueLabel {
                            Text(midiNoteToName(midiNote))
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 150)

            // Current pitch display
            if let currentPitch = analyzer.currentPitch, currentPitch.isVoiced {
                HStack {
                    Text("Current:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(frequencyToNoteName(currentPitch.frequencyHz))
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(String(format: "%.1f Hz", currentPitch.frequencyHz))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    // Confidence indicator
                    ConfidenceIndicator(confidence: currentPitch.confidence)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    // MARK: - Computed Properties

    private var visiblePitchPoints: [PitchDataPoint] {
        let currentTime = analyzer.pitchHistory.last?.time ?? 0
        let startTime = max(0, currentTime - windowDuration)

        return analyzer.pitchHistory.filter { point in
            point.time >= startTime && point.time <= currentTime
        }
    }

    private var visibleTimeRange: ClosedRange<Double> {
        let currentTime = analyzer.pitchHistory.last?.time ?? 0
        let startTime = max(0, currentTime - windowDuration)
        return startTime...max(currentTime, startTime + 1)
    }

    // MARK: - Helper Methods

    private func pitchColor(for point: PitchDataPoint) -> Color {
        // Color by confidence
        if point.isVoiced {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func frequencyToNoteName(_ frequency: Double) -> String {
        let midiNote = 69 + 12 * log2(frequency / 440.0)
        return midiNoteToName(Int(round(midiNote)))
    }

    private func midiNoteToName(_ midiNote: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let noteName = noteNames[midiNote % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Confidence Indicator

struct ConfidenceIndicator: View {
    let confidence: Double

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(index < Int(confidence * 5) ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Preview

struct PitchVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        PitchVisualizationView(analyzer: RealtimePitchAnalyzer())
            .padding()
    }
}
