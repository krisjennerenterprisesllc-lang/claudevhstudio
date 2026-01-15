//
//  AudioFileImporter.swift
//  VocalHeat
//
//  Audio file import with validation and secure storage
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import AVFoundation

@MainActor
class AudioFileImporter: ObservableObject {
    @Published var isImporting = false
    @Published var lastError: Error?

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let importedFilesDirectory: URL

    // MARK: - Initialization

    init() {
        let documentsDir = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        self.importedFilesDirectory = documentsDir.appendingPathComponent("ImportedAudio")

        // Create directory if needed
        try? fileManager.createDirectory(
            at: importedFilesDirectory,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Public Methods

    func importAudioFile(from sourceURL: URL) async throws -> ImportedAudioFile {
        isImporting = true
        lastError = nil

        defer {
            isImporting = false
        }

        // Validate file exists and is accessible
        guard sourceURL.startAccessingSecurityScopedResource() else {
            throw ImportError.accessDenied
        }

        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }

        // Validate audio format
        try validateAudioFile(at: sourceURL)

        // Generate unique filename
        let fileExtension = sourceURL.pathExtension
        let uniqueFilename = "\(UUID().uuidString).\(fileExtension)"
        let destinationURL = importedFilesDirectory.appendingPathComponent(uniqueFilename)

        // Copy file to app's documents directory
        let data = try Data(contentsOf: sourceURL)
        try data.write(to: destinationURL, options: [.atomic])

        // Extract metadata
        let duration = try extractDuration(from: destinationURL)
        let title = extractTitle(from: sourceURL)

        return ImportedAudioFile(
            id: UUID(),
            filename: uniqueFilename,
            originalFilename: sourceURL.lastPathComponent,
            title: title,
            duration: duration,
            importDate: Date()
        )
    }

    func deleteImportedFile(_ file: ImportedAudioFile) throws {
        let url = importedFilesDirectory.appendingPathComponent(file.filename)

        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    func getFileURL(for file: ImportedAudioFile) -> URL {
        return importedFilesDirectory.appendingPathComponent(file.filename)
    }

    // MARK: - Private Methods

    private func validateAudioFile(at url: URL) throws {
        // Check file exists
        guard fileManager.fileExists(atPath: url.path) else {
            throw ImportError.fileNotFound
        }

        // Validate using AVAudioFile
        do {
            let audioFile = try AVAudioFile(forReading: url)

            // Check minimum duration (0.5 seconds)
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            guard duration >= 0.5 else {
                throw ImportError.fileTooShort
            }

            // Check maximum duration (10 minutes)
            guard duration <= 600 else {
                throw ImportError.fileTooLong
            }

            // Validate format
            let format = audioFile.processingFormat
            guard format.channelCount > 0 && format.sampleRate > 0 else {
                throw ImportError.invalidFormat
            }

        } catch {
            throw ImportError.invalidAudioFile
        }
    }

    private func extractDuration(from url: URL) throws -> TimeInterval {
        let audioFile = try AVAudioFile(forReading: url)
        return Double(audioFile.length) / audioFile.processingFormat.sampleRate
    }

    private func extractTitle(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Import Error

enum ImportError: LocalizedError {
    case accessDenied
    case fileNotFound
    case invalidAudioFile
    case invalidFormat
    case fileTooShort
    case fileTooLong

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Cannot access the selected file."
        case .fileNotFound:
            return "The selected file was not found."
        case .invalidAudioFile:
            return "The selected file is not a valid audio file."
        case .invalidFormat:
            return "The audio format is not supported."
        case .fileTooShort:
            return "The audio file must be at least 0.5 seconds long."
        case .fileTooLong:
            return "The audio file must be less than 10 minutes long."
        }
    }
}

// MARK: - Imported Audio File Model

struct ImportedAudioFile: Codable, Identifiable {
    let id: UUID
    let filename: String           // Unique filename in app directory
    let originalFilename: String   // Original user filename
    let title: String
    let duration: TimeInterval
    let importDate: Date

    var displayDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
