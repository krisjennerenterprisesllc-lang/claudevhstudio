//
//  RecordingView.swift
//  VocalHeat
//
//  Duet/solo recording interface with real-time pitch visualization
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import SwiftUI

struct RecordingView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var persistenceManager: PersistenceManager
    @EnvironmentObject var audioSessionManager: AudioSessionManager

    @StateObject private var recordingManager: DuetRecordingManager
    @StateObject private var pitchAnalyzer = RealtimePitchAnalyzer()
    @StateObject private var audioRecorder = AudioRecorder()

    @State private var currentSession: DuetSession?
    @State private var recordingMode: RecordingMode = .solo
    @State private var selectedArtistTrack: ImportedAudioFile?
    @State private var selectedGenre: MusicGenre = .pop

    @State private var showError = false
    @State private var errorMessage = ""

    init() {
        // Initialize with injected audio session manager from environment
        let manager = AudioSessionManager()
        _recordingManager = StateObject(wrappedValue: DuetRecordingManager(audioSessionManager: manager))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Recording mode selector
                if currentSession == nil {
                    modeSelector
                    genreSelector

                    if recordingMode == .duet {
                        artistTrackSelector
                    }
                }

                // Pitch visualization
                if recordingManager.isRecording {
                    PitchVisualizationView(analyzer: pitchAnalyzer)
                }

                Spacer()

                // Recording duration
                if recordingManager.isRecording {
                    Text(formatDuration(recordingManager.recordingDuration))
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                }

                // Record button
                recordButton

                Spacer()
            }
            .padding()
            .navigationTitle("Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        Task {
                            await handleCancel()
                        }
                    }
                    .disabled(recordingManager.isRecording)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    private var modeSelector: some View {
        Picker("Mode", selection: $recordingMode) {
            Text("Solo").tag(RecordingMode.solo)
            Text("Duet").tag(RecordingMode.duet)
        }
        .pickerStyle(.segmented)
        .disabled(recordingManager.isRecording)
    }

    private var genreSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Genre")
                .font(.headline)

            Picker("Genre", selection: $selectedGenre) {
                ForEach(MusicGenre.allCases, id: \.self) { genre in
                    Text(genre.rawValue).tag(genre)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var artistTrackSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Artist Track")
                .font(.headline)

            Button(action: selectArtistTrack) {
                HStack {
                    Image(systemName: "music.note")
                    Text(selectedArtistTrack?.title ?? "Select Track...")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }

    private var recordButton: some View {
        Button(action: { Task { await toggleRecording() } }) {
            ZStack {
                Circle()
                    .fill(recordingManager.isRecording ? Color.red : Color.blue)
                    .frame(width: 80, height: 80)

                Image(systemName: recordingManager.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
        }
        .disabled(recordingMode == .duet && selectedArtistTrack == nil)
    }

    // MARK: - Actions

    private func toggleRecording() async {
        if recordingManager.isRecording {
            await stopRecording()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            // Start pitch analyzer
            pitchAnalyzer.start()

            // Connect audio recorder to pitch analyzer
            audioRecorder.onBufferReceived = { samples in
                Task { @MainActor in
                    pitchAnalyzer.processAudioBuffer(samples)
                }
            }

            // Start recording
            let session: DuetSession

            if recordingMode == .duet, let artistTrack = selectedArtistTrack {
                let importer = AudioFileImporter()
                let artistURL = importer.getFileURL(for: artistTrack)
                session = try await recordingManager.startDuetRecording(artistTrackURL: artistURL)
            } else {
                session = try await recordingManager.startSoloRecording()
            }

            // Update session with genre
            var updatedSession = session
            currentSession = updatedSession

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func stopRecording() async {
        do {
            // Stop recording
            let (recordingURL, duration) = try await recordingManager.stopRecording()

            // Stop pitch analyzer
            pitchAnalyzer.stop()

            // Update session with duration
            if var session = currentSession {
                session = DuetSession(
                    id: session.id,
                    artistFileName: session.artistFileName,
                    artistDurationSeconds: session.artistDurationSeconds,
                    userMicFileName: session.userMicFileName,
                    userMicDurationSeconds: duration,
                    sharedStartEpochMs: session.sharedStartEpochMs,
                    inputLatencyMs: session.inputLatencyMs,
                    outputLatencyMs: session.outputLatencyMs,
                    manualOffsetSeconds: session.manualOffsetSeconds,
                    genre: selectedGenre
                )

                // Save session
                persistenceManager.save(session)

                // Dismiss
                dismiss()
            }

        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func handleCancel() async {
        if recordingManager.isRecording {
            await recordingManager.cancelRecording()
            pitchAnalyzer.stop()
        }

        dismiss()
    }

    private func selectArtistTrack() {
        // TODO: Present file picker or library selector
        print("Select artist track")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Recording Mode

enum RecordingMode {
    case solo
    case duet
}

// MARK: - Preview

struct RecordingView_Previews: PreviewProvider {
    static var previews: some View {
        RecordingView()
            .environmentObject(PersistenceManager())
            .environmentObject(AudioSessionManager())
    }
}
