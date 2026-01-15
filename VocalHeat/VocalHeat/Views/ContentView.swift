//
//  ContentView.swift
//  VocalHeat
//
//  Main app interface with session list
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var persistenceManager: PersistenceManager

    var body: some View {
        NavigationView {
            VStack {
                if persistenceManager.sessions.isEmpty {
                    emptyStateView
                } else {
                    sessionListView
                }
            }
            .navigationTitle("VocalHeat")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startNewRecording) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Recordings Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Tap + to start your first vocal session")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var sessionListView: some View {
        List {
            ForEach(persistenceManager.sessions) { session in
                SessionRowView(session: session)
            }
            .onDelete(perform: deleteSessions)
        }
    }

    private func startNewRecording() {
        // TODO: Navigate to recording view
        print("Start new recording")
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = persistenceManager.sessions[index]
            persistenceManager.delete(session)
        }
    }
}

// MARK: - Session Row View

struct SessionRowView: View {
    let session: DuetSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.isSoloRecording ? "Solo Session" : "Duet Session")
                    .font(.headline)

                Spacer()

                if let results = session.analysisResults {
                    Text("\(results.overallScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor(for: results.overallScore))
                }
            }

            Text(session.displayDate)
                .font(.caption)
                .foregroundColor(.secondary)

            if let results = session.analysisResults {
                HStack(spacing: 12) {
                    MetricBadge(
                        icon: "tuningfork",
                        value: String(format: "%.0f%%", results.pitchAccuracy)
                    )

                    MetricBadge(
                        icon: "waveform.path",
                        value: String(format: "%.0f%%", results.toneConsistency)
                    )

                    if results.vibratoStability.isHealthy {
                        MetricBadge(
                            icon: "checkmark.circle.fill",
                            value: "Vibrato"
                        )
                    }
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100: return .green
        case 75..<90: return .blue
        case 60..<75: return .orange
        default: return .red
        }
    }
}

// MARK: - Metric Badge

struct MetricBadge: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PersistenceManager())
    }
}
