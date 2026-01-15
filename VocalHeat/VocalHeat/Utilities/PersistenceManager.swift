//
//  PersistenceManager.swift
//  VocalHeat
//
//  Manages session persistence and file storage
//  Copyright © 2026 Kris Enterprises LLC. All rights reserved.
//

import Foundation
import Combine

@MainActor
class PersistenceManager: ObservableObject {
    @Published var sessions: [DuetSession] = []

    private let documentsDirectory: URL
    private let sessionsFileName = "sessions.json"

    init() {
        self.documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!

        loadSessions()
    }

    // MARK: - Public Methods

    func save(_ session: DuetSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        saveSessions()
    }

    func delete(_ session: DuetSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    // MARK: - Private Methods

    private func loadSessions() {
        let url = documentsDirectory.appendingPathComponent(sessionsFileName)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            sessions = try decoder.decode([DuetSession].self, from: data)
        } catch {
            print("Failed to load sessions: \(error)")
        }
    }

    private func saveSessions() {
        let url = documentsDirectory.appendingPathComponent(sessionsFileName)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(sessions)
            try data.write(to: url, options: [.atomic])
        } catch {
            print("Failed to save sessions: \(error)")
        }
    }
}
